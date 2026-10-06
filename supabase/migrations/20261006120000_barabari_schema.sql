-- Barabari cloud sync schema.
--
-- The iPhone app is local-first: every record is created on the device with a
-- client-generated UUID and later upserted here. The server keeps the shared
-- copy for each group, enforces who may see it (row level security), and
-- resolves concurrent writes with last-writer-wins on `updated_at`.
--
-- Identity: each install has its own `app_user_id` (the id used in the local
-- ledger). An anonymous Supabase auth user claims it once through
-- `register_profile`, and every policy resolves membership through `app_uid()`.

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.profiles (
    auth_id      uuid primary key references auth.users (id) on delete cascade,
    app_user_id  uuid not null unique,
    display_name text check (display_name is null or char_length(display_name) <= 80),
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now()
);

create table public.groups (
    id                uuid primary key,
    name              text not null check (char_length(btrim(name)) between 1 and 80),
    description       text check (description is null or char_length(description) <= 280),
    owner_id          uuid not null,
    created_at        timestamptz not null,
    updated_at        timestamptz not null,
    revision          integer not null default 1,
    deleted_at        timestamptz,
    server_updated_at timestamptz not null default now()
);

create table public.group_members (
    id                uuid primary key,
    group_id          uuid not null references public.groups (id) on delete cascade,
    user_id           uuid not null,
    role              text not null check (role in ('owner', 'member')),
    display_name      text check (display_name is null or char_length(display_name) <= 80),
    joined_at         timestamptz not null,
    updated_at        timestamptz not null,
    revision          integer not null default 1,
    removed_at        timestamptz,
    server_updated_at timestamptz not null default now()
);

create table public.expenses (
    id                uuid primary key,
    group_id          uuid not null references public.groups (id) on delete cascade,
    title             text not null check (char_length(btrim(title)) between 1 and 120),
    note              text,
    total_minor       bigint not null check (total_minor > 0),
    currency_code     text not null check (currency_code = 'PKR'),
    paid_by           uuid not null,
    -- {"kind": "equal"} or {"kind": "exact", "values": [{"user_id": uuid, "value": int}]}
    split_method      jsonb not null,
    -- [{"user_id": uuid, "amount_minor": int}]
    splits            jsonb not null check (jsonb_typeof(splits) = 'array' and jsonb_array_length(splits) > 0),
    category          text,
    occurred_at       timestamptz not null,
    created_by        uuid not null,
    created_at        timestamptz not null,
    updated_at        timestamptz not null,
    revision          integer not null default 1,
    deleted_at        timestamptz,
    server_updated_at timestamptz not null default now()
);

create table public.settlements (
    id                uuid primary key,
    group_id          uuid not null references public.groups (id) on delete cascade,
    from_user         uuid not null,
    to_user           uuid not null check (to_user <> from_user),
    amount_minor      bigint not null check (amount_minor > 0),
    currency_code     text not null check (currency_code = 'PKR'),
    method            text not null,
    note              text,
    occurred_at       timestamptz not null,
    created_by        uuid not null,
    created_at        timestamptz not null,
    updated_at        timestamptz not null,
    revision          integer not null default 1,
    deleted_at        timestamptz,
    server_updated_at timestamptz not null default now()
);

create table public.activity_events (
    id                uuid primary key,
    group_id          uuid not null references public.groups (id) on delete cascade,
    actor_user_id     uuid not null,
    kind              text not null,
    subject_id        uuid not null,
    occurred_at       timestamptz not null,
    created_at        timestamptz not null,
    revision          integer not null default 1,
    deleted_at        timestamptz,
    server_updated_at timestamptz not null default now()
);

create index group_members_user_idx on public.group_members (user_id) where removed_at is null;
create index group_members_group_idx on public.group_members (group_id);
create index groups_sync_idx on public.groups (server_updated_at);
create index group_members_sync_idx on public.group_members (server_updated_at);
create index expenses_group_idx on public.expenses (group_id);
create index expenses_sync_idx on public.expenses (server_updated_at);
create index settlements_group_idx on public.settlements (group_id);
create index settlements_sync_idx on public.settlements (server_updated_at);
create index activity_group_idx on public.activity_events (group_id);
create index activity_sync_idx on public.activity_events (server_updated_at);

-- ---------------------------------------------------------------------------
-- Write rules: last writer wins, tombstones never resurrect
-- ---------------------------------------------------------------------------

-- Mutable rows: an older (or identical) write is ignored, deletions stick, and
-- every accepted write bumps `server_updated_at` so other devices pull it.
create function public.sync_merge_mutable()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    old_tombstone timestamptz;
    new_tombstone timestamptz;
begin
    if tg_op = 'INSERT' then
        new.server_updated_at := now();
        return new;
    end if;

    if tg_table_name = 'group_members' then
        old_tombstone := old.removed_at;
        new_tombstone := new.removed_at;
    else
        old_tombstone := old.deleted_at;
        new_tombstone := new.deleted_at;
    end if;

    -- A stale write may still carry a tombstone the server has not seen.
    if new.updated_at <= old.updated_at and (new_tombstone is null or old_tombstone is not null) then
        return old;
    end if;

    if tg_table_name = 'group_members' then
        new.removed_at := coalesce(old.removed_at, new.removed_at);
    else
        new.deleted_at := coalesce(old.deleted_at, new.deleted_at);
    end if;
    new.server_updated_at := now();
    return new;
end;
$$;

-- Activity is append-only: only a tombstone can change an existing event.
create function public.sync_merge_activity()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if tg_op = 'INSERT' then
        new.server_updated_at := now();
        return new;
    end if;
    -- join_group may move a claimed person's history onto the joiner.
    if current_setting('barabari.claiming', true) = 'on' then
        new.server_updated_at := now();
        return new;
    end if;
    if new.deleted_at is null or old.deleted_at is not null then
        return old;
    end if;
    old.deleted_at := new.deleted_at;
    old.server_updated_at := now();
    return old;
end;
$$;

-- Splits must add up to the expense total, to the paisa.
create function public.validate_expense_splits()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    split_total bigint;
begin
    select coalesce(sum((s ->> 'amount_minor')::bigint), 0)
      into split_total
      from jsonb_array_elements(new.splits) as s;
    if split_total <> new.total_minor then
        raise exception 'splits (%) must add up to the expense total (%)', split_total, new.total_minor
            using errcode = 'check_violation';
    end if;
    return new;
end;
$$;

create trigger groups_merge before insert or update on public.groups
    for each row execute function public.sync_merge_mutable();
create trigger group_members_merge before insert or update on public.group_members
    for each row execute function public.sync_merge_mutable();
create trigger expenses_merge before insert or update on public.expenses
    for each row execute function public.sync_merge_mutable();
create trigger settlements_merge before insert or update on public.settlements
    for each row execute function public.sync_merge_mutable();
create trigger activity_merge before insert or update on public.activity_events
    for each row execute function public.sync_merge_activity();
create trigger expenses_validate_splits before insert or update on public.expenses
    for each row execute function public.validate_expense_splits();

-- ---------------------------------------------------------------------------
-- Identity helpers
-- ---------------------------------------------------------------------------

create function public.app_uid()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
    select p.app_user_id from public.profiles p where p.auth_id = auth.uid()
$$;

create function public.is_group_member(target_group uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
          from public.group_members m
         where m.group_id = target_group
           and m.user_id = public.app_uid()
           and m.removed_at is null
    )
$$;

create function public.owns_group(target_group uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1 from public.groups g
         where g.id = target_group and g.owner_id = public.app_uid()
    )
$$;

-- ---------------------------------------------------------------------------
-- Row level security
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.expenses enable row level security;
alter table public.settlements enable row level security;
alter table public.activity_events enable row level security;

create policy "own profile" on public.profiles
    for select to authenticated using (auth_id = auth.uid());

create policy "members read groups" on public.groups
    for select to authenticated
    using (owner_id = public.app_uid() or public.is_group_member(id));
-- Members may also "insert": a PostgREST upsert of an existing group checks the
-- insert rule even when it ends up updating.
create policy "owners create groups" on public.groups
    for insert to authenticated
    with check (owner_id = public.app_uid() or public.is_group_member(id));
create policy "members update groups" on public.groups
    for update to authenticated
    using (owner_id = public.app_uid() or public.is_group_member(id))
    with check (owner_id = public.app_uid() or public.is_group_member(id));

create policy "members read members" on public.group_members
    for select to authenticated
    using (public.is_group_member(group_id) or public.owns_group(group_id));
create policy "members add members" on public.group_members
    for insert to authenticated
    with check (public.is_group_member(group_id) or public.owns_group(group_id));
create policy "members update members" on public.group_members
    for update to authenticated
    using (public.is_group_member(group_id) or public.owns_group(group_id))
    with check (public.is_group_member(group_id) or public.owns_group(group_id));

create policy "members read expenses" on public.expenses
    for select to authenticated using (public.is_group_member(group_id));
create policy "members add expenses" on public.expenses
    for insert to authenticated with check (public.is_group_member(group_id));
create policy "members update expenses" on public.expenses
    for update to authenticated
    using (public.is_group_member(group_id)) with check (public.is_group_member(group_id));

create policy "members read settlements" on public.settlements
    for select to authenticated using (public.is_group_member(group_id));
create policy "members add settlements" on public.settlements
    for insert to authenticated with check (public.is_group_member(group_id));
create policy "members update settlements" on public.settlements
    for update to authenticated
    using (public.is_group_member(group_id)) with check (public.is_group_member(group_id));

create policy "members read activity" on public.activity_events
    for select to authenticated using (public.is_group_member(group_id));
create policy "members add activity" on public.activity_events
    for insert to authenticated with check (public.is_group_member(group_id));
create policy "members update activity" on public.activity_events
    for update to authenticated
    using (public.is_group_member(group_id)) with check (public.is_group_member(group_id));

-- No delete policies: removals travel as tombstones.

-- ---------------------------------------------------------------------------
-- RPCs
-- ---------------------------------------------------------------------------

-- Links this auth session to the install's ledger identity (idempotent).
create function public.register_profile(p_app_user_id uuid, p_display_name text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    existing uuid;
    trimmed  text := nullif(btrim(coalesce(p_display_name, '')), '');
begin
    if auth.uid() is null then
        raise exception 'not authenticated' using errcode = '28000';
    end if;

    select app_user_id into existing from public.profiles where auth_id = auth.uid();
    if existing is not null then
        if existing <> p_app_user_id then
            raise exception 'identity_mismatch' using errcode = 'P0001';
        end if;
        update public.profiles
           set display_name = coalesce(trimmed, display_name), updated_at = now()
         where auth_id = auth.uid();
    else
        if exists (select 1 from public.profiles where app_user_id = p_app_user_id) then
            raise exception 'identity_taken' using errcode = 'P0001';
        end if;
        insert into public.profiles (auth_id, app_user_id, display_name)
        values (auth.uid(), p_app_user_id, trimmed);
    end if;

    -- Keep this person's name current in every group they belong to.
    if trimmed is not null then
        update public.group_members
           set display_name = trimmed, updated_at = now()
         where user_id = p_app_user_id
           and display_name is distinct from trimmed;
    end if;
    return p_app_user_id;
end;
$$;

-- What an invite link points at, for someone who is not a member yet.
create function public.group_preview(p_group_id uuid)
returns table (group_id uuid, name text, member_count integer, open_spots jsonb)
language sql
stable
security definer
set search_path = ''
as $$
    select g.id,
           g.name,
           (select count(*)::integer from public.group_members m
             where m.group_id = g.id and m.removed_at is null),
           -- People added by name who have not joined from their own phone yet.
           coalesce((
               select jsonb_agg(jsonb_build_object('user_id', m.user_id, 'display_name', m.display_name)
                                order by m.joined_at)
                 from public.group_members m
                where m.group_id = g.id
                  and m.removed_at is null
                  and m.display_name is not null
                  and not exists (select 1 from public.profiles p where p.app_user_id = m.user_id)
           ), '[]'::jsonb)
      from public.groups g
     where g.id = p_group_id and g.deleted_at is null and auth.uid() is not null
$$;

-- Joins a group from an invite. Optionally claims a spot someone created for
-- you by name, moving that person's history onto your identity.
create function public.join_group(
    p_group_id      uuid,
    p_display_name  text default null,
    p_claim_user_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    me      uuid := public.app_uid();
    trimmed text := nullif(btrim(coalesce(p_display_name, '')), '');
    ts      timestamptz := now();
begin
    if me is null then
        raise exception 'register_profile first' using errcode = 'P0001';
    end if;
    if not exists (select 1 from public.groups where id = p_group_id and deleted_at is null) then
        raise exception 'group_not_found' using errcode = 'P0002';
    end if;

    if exists (select 1 from public.group_members
                where group_id = p_group_id and user_id = me and removed_at is null) then
        return p_group_id;
    end if;

    if p_claim_user_id is not null then
        if not exists (select 1 from public.group_members
                        where group_id = p_group_id and user_id = p_claim_user_id and removed_at is null)
           or exists (select 1 from public.profiles where app_user_id = p_claim_user_id) then
            raise exception 'spot_unavailable' using errcode = 'P0001';
        end if;

        update public.group_members
           set user_id = me, display_name = coalesce(trimmed, display_name),
               updated_at = ts, revision = revision + 1
         where group_id = p_group_id and user_id = p_claim_user_id;

        update public.expenses e
           set paid_by    = case when e.paid_by = p_claim_user_id then me else e.paid_by end,
               created_by = case when e.created_by = p_claim_user_id then me else e.created_by end,
               splits = (
                   select jsonb_agg(case when (s ->> 'user_id')::uuid = p_claim_user_id
                                         then jsonb_set(s, '{user_id}', to_jsonb(me::text))
                                         else s end)
                     from jsonb_array_elements(e.splits) s
               ),
               split_method = case
                   when e.split_method ? 'values' then jsonb_set(e.split_method, '{values}', coalesce((
                       select jsonb_agg(case when (v ->> 'user_id')::uuid = p_claim_user_id
                                             then jsonb_set(v, '{user_id}', to_jsonb(me::text))
                                             else v end)
                         from jsonb_array_elements(e.split_method -> 'values') v
                   ), '[]'::jsonb))
                   else e.split_method end,
               updated_at = ts, revision = e.revision + 1
         where e.group_id = p_group_id
           and (e.paid_by = p_claim_user_id or e.created_by = p_claim_user_id
                or exists (select 1 from jsonb_array_elements(e.splits) s
                            where (s ->> 'user_id')::uuid = p_claim_user_id));

        update public.settlements
           set from_user  = case when from_user = p_claim_user_id then me else from_user end,
               to_user    = case when to_user = p_claim_user_id then me else to_user end,
               created_by = case when created_by = p_claim_user_id then me else created_by end,
               updated_at = ts, revision = revision + 1
         where group_id = p_group_id
           and p_claim_user_id in (from_user, to_user, created_by);

        -- Activity is append-only for clients; allow this one rewrite.
        perform set_config('barabari.claiming', 'on', true);
        update public.activity_events
           set actor_user_id = me
         where group_id = p_group_id and actor_user_id = p_claim_user_id;
        perform set_config('barabari.claiming', 'off', true);
    else
        insert into public.group_members (id, group_id, user_id, role, display_name, joined_at, updated_at)
        values (gen_random_uuid(), p_group_id, me, 'member', trimmed, ts, ts);
    end if;

    insert into public.activity_events (id, group_id, actor_user_id, kind, subject_id, occurred_at, created_at)
    values (gen_random_uuid(), p_group_id, me, 'memberJoined', p_group_id, ts, ts);

    return p_group_id;
end;
$$;

-- RPCs and helpers are for signed-in devices only.
revoke all on function public.register_profile(uuid, text) from public, anon;
revoke all on function public.group_preview(uuid) from public, anon;
revoke all on function public.join_group(uuid, text, uuid) from public, anon;
revoke all on function public.app_uid() from public, anon;
revoke all on function public.is_group_member(uuid) from public, anon;
revoke all on function public.owns_group(uuid) from public, anon;
grant execute on function public.register_profile(uuid, text) to authenticated;
grant execute on function public.group_preview(uuid) to authenticated;
grant execute on function public.join_group(uuid, text, uuid) to authenticated;
grant execute on function public.app_uid() to authenticated;
grant execute on function public.is_group_member(uuid) to authenticated;
grant execute on function public.owns_group(uuid) to authenticated;

revoke all on all tables in schema public from anon;
