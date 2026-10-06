-- Row level security and sync-rule checks for the Barabari schema.
-- Run: psql -f 00_supabase_stub.sql, the migration, then this file.
\set ON_ERROR_STOP on
\set QUIET on
insert into auth.users values
  ('aaaaaaaa-0000-0000-0000-000000000001'), ('bbbbbbbb-0000-0000-0000-000000000002'), ('cccccccc-0000-0000-0000-000000000003');

create function pg_temp.as_user(auth_id text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', auth_id, false); $$;
create function pg_temp.expect(ok boolean, what text) returns void language plpgsql as $$
  begin if not ok then raise exception 'FAILED: %', what; end if; raise notice 'ok  %', what; end $$;

-- Phone A (Nabeegh) creates the trip and adds Sara by name -------------------
set role authenticated;
select pg_temp.as_user('aaaaaaaa-0000-0000-0000-000000000001');
select public.register_profile('a0000000-0000-0000-0000-00000000000a', 'Nabeegh');
insert into public.groups (id, name, owner_id, created_at, updated_at)
values ('99999999-0000-0000-0000-000000000099', 'Hunza Trip', 'a0000000-0000-0000-0000-00000000000a', now(), now())
on conflict (id) do update set name = excluded.name;
insert into public.group_members (id, group_id, user_id, role, display_name, joined_at, updated_at) values
  ('11111111-0000-0000-0000-000000000001', '99999999-0000-0000-0000-000000000099', 'a0000000-0000-0000-0000-00000000000a', 'owner', 'Nabeegh', now(), now()),
  ('11111111-0000-0000-0000-000000000002', '99999999-0000-0000-0000-000000000099', '5a5a5a5a-0000-0000-0000-00000000005a', 'member', 'Sara Khan', now(), now());
insert into public.expenses (id, group_id, title, total_minor, currency_code, paid_by, split_method, splits, category, occurred_at, created_by, created_at, updated_at)
values ('eeeeeeee-0000-0000-0000-0000000000e1', '99999999-0000-0000-0000-000000000099', 'Hotel in Karimabad', 1800000, 'PKR',
        'a0000000-0000-0000-0000-00000000000a',
        '{"kind":"exact","values":[{"user_id":"a0000000-0000-0000-0000-00000000000a","value":900000},{"user_id":"5a5a5a5a-0000-0000-0000-00000000005a","value":900000}]}',
        '[{"user_id":"A0000000-0000-0000-0000-00000000000A","amount_minor":900000},{"user_id":"5a5a5a5a-0000-0000-0000-00000000005a","amount_minor":900000}]',
        'travel', now(), 'a0000000-0000-0000-0000-00000000000a', now(), now());
insert into public.activity_events (id, group_id, actor_user_id, kind, subject_id, occurred_at, created_at)
values ('acacacac-0000-0000-0000-0000000000a1', '99999999-0000-0000-0000-000000000099', 'a0000000-0000-0000-0000-00000000000a', 'groupCreated', '99999999-0000-0000-0000-000000000099', now(), now());
select pg_temp.expect((select count(*) from public.expenses) = 1, 'owner can read their expense');

-- Phone B (Ali) is a stranger until he joins ---------------------------------
select pg_temp.as_user('bbbbbbbb-0000-0000-0000-000000000002');
select public.register_profile('b0000000-0000-0000-0000-00000000000b', 'Ali');
select pg_temp.expect((select count(*) from public.groups) = 0, 'stranger cannot see the group');
select pg_temp.expect((select count(*) from public.expenses) = 0, 'stranger cannot see expenses');
select pg_temp.expect((select name from public.group_preview('99999999-0000-0000-0000-000000000099')) = 'Hunza Trip', 'invite preview shows the group name');
select pg_temp.expect((select jsonb_array_length(open_spots) from public.group_preview('99999999-0000-0000-0000-000000000099')) = 1, 'invite preview lists Sara as an open spot');
do $$ begin
  insert into public.expenses (id, group_id, title, total_minor, currency_code, paid_by, split_method, splits, occurred_at, created_by, created_at, updated_at)
  values (gen_random_uuid(), '99999999-0000-0000-0000-000000000099', 'Sneaky', 100, 'PKR', 'b0000000-0000-0000-0000-00000000000b',
          '{"kind":"equal"}', '[{"user_id":"b0000000-0000-0000-0000-00000000000b","amount_minor":100}]', now(), 'b0000000-0000-0000-0000-00000000000b', now(), now());
  raise exception 'FAILED: stranger inserted an expense';
exception when insufficient_privilege then raise notice 'ok  stranger cannot add expenses';
end $$;

-- Phone C claims Sara's spot -------------------------------------------------
select pg_temp.as_user('cccccccc-0000-0000-0000-000000000003');
select public.register_profile('c0000000-0000-0000-0000-00000000000c', 'Sara');
select public.join_group('99999999-0000-0000-0000-000000000099', 'Sara', '5a5a5a5a-0000-0000-0000-00000000005a');
select pg_temp.expect((select count(*) from public.expenses) = 1, 'after joining, Sara sees the expense');
select pg_temp.expect(
  (select bool_and((s ->> 'user_id')::uuid <> '5a5a5a5a-0000-0000-0000-00000000005a') from public.expenses e, jsonb_array_elements(e.splits) s),
  'claim moved her split onto her account');
select pg_temp.expect(
  (select count(*) from public.expenses e, jsonb_array_elements(e.splits) s where (s ->> 'user_id')::uuid = 'c0000000-0000-0000-0000-00000000000c') = 1,
  'her split now uses her id');
select pg_temp.expect(
  (select count(*) from public.expenses e, jsonb_array_elements(e.split_method -> 'values') v where (v ->> 'user_id')::uuid = 'c0000000-0000-0000-0000-00000000000c') = 1,
  'exact split values were remapped too');
select pg_temp.expect(
  (select count(*) from public.group_members where user_id = 'c0000000-0000-0000-0000-00000000000c' and display_name = 'Sara') = 1,
  'her member row is hers, named Sara');

-- Ali joins as a new member, and cannot take Sara's spot again ---------------
select pg_temp.as_user('bbbbbbbb-0000-0000-0000-000000000002');
do $$ begin
  perform public.join_group('99999999-0000-0000-0000-000000000099', 'Ali', '5a5a5a5a-0000-0000-0000-00000000005a');
  raise exception 'FAILED: claimed a spot twice';
exception when raise_exception then
  if sqlerrm like 'FAILED%' then raise; end if;
  raise notice 'ok  a claimed spot cannot be claimed again (%)', sqlerrm;
end $$;
select public.join_group('99999999-0000-0000-0000-000000000099', 'Ali', null);
select public.join_group('99999999-0000-0000-0000-000000000099', 'Ali', null);
select pg_temp.expect((select count(*) from public.group_members where user_id = 'b0000000-0000-0000-0000-00000000000b') = 1, 'joining twice is idempotent');
select pg_temp.expect((select count(*) from public.group_members) = 3, 'group has three members');

-- Sync rules -----------------------------------------------------------------
-- A stale write (older updated_at) is ignored.
insert into public.expenses (id, group_id, title, total_minor, currency_code, paid_by, split_method, splits, occurred_at, created_by, created_at, updated_at)
select id, group_id, 'STALE', total_minor, currency_code, paid_by, split_method, splits, occurred_at, created_by, created_at, updated_at - interval '1 hour'
  from public.expenses where id = 'eeeeeeee-0000-0000-0000-0000000000e1'
on conflict (id) do update set title = excluded.title, updated_at = excluded.updated_at;
select pg_temp.expect((select title from public.expenses) = 'Hotel in Karimabad', 'stale write is ignored');

-- A newer tombstone sticks, and a later write without it cannot undo it.
update public.expenses set deleted_at = now(), updated_at = now() + interval '1 minute' where id = 'eeeeeeee-0000-0000-0000-0000000000e1';
update public.expenses set deleted_at = null, title = 'Back from the dead', updated_at = now() + interval '1 hour' where id = 'eeeeeeee-0000-0000-0000-0000000000e1';
select pg_temp.expect((select deleted_at is not null from public.expenses), 'deletions never come back');

-- Splits must add up.
do $$ begin
  insert into public.expenses (id, group_id, title, total_minor, currency_code, paid_by, split_method, splits, occurred_at, created_by, created_at, updated_at)
  values (gen_random_uuid(), '99999999-0000-0000-0000-000000000099', 'Bad maths', 1000, 'PKR', 'b0000000-0000-0000-0000-00000000000b',
          '{"kind":"equal"}', '[{"user_id":"b0000000-0000-0000-0000-00000000000b","amount_minor":999}]', now(), 'b0000000-0000-0000-0000-00000000000b', now(), now());
  raise exception 'FAILED: accepted splits that do not add up';
exception when check_violation then raise notice 'ok  splits that do not add up are rejected';
end $$;

-- A member who is not the owner can re-push the group row (PostgREST upsert path).
insert into public.groups (id, name, owner_id, created_at, updated_at)
select id, name, owner_id, created_at, updated_at from public.groups
on conflict (id) do update set name = excluded.name, updated_at = excluded.updated_at;
select pg_temp.expect(true, 'member upsert of an existing group is allowed');

-- Activity is append-only for clients.
select pg_temp.as_user('aaaaaaaa-0000-0000-0000-000000000001');
update public.activity_events set kind = 'tampered' where id = 'acacacac-0000-0000-0000-0000000000a1';
select pg_temp.expect((select kind from public.activity_events where id = 'acacacac-0000-0000-0000-0000000000a1') = 'groupCreated', 'activity cannot be rewritten');

-- Identity cannot be hijacked.
select pg_temp.as_user('bbbbbbbb-0000-0000-0000-000000000002');
do $$ begin
  perform public.register_profile('a0000000-0000-0000-0000-00000000000a', 'Imposter');
  raise exception 'FAILED: hijacked another identity';
exception when raise_exception then
  if sqlerrm like 'FAILED%' then raise; end if;
  raise notice 'ok  cannot claim another phone''s identity (%)', sqlerrm;
end $$;

-- Strangers cannot create a group in someone else's name or overwrite one.
select pg_temp.as_user('cccccccc-0000-0000-0000-000000000003');
select public.register_profile('c0000000-0000-0000-0000-00000000000c', 'Sara');
do $$ begin
  insert into public.groups (id, name, owner_id, created_at, updated_at)
  values (gen_random_uuid(), 'Fake', 'a0000000-0000-0000-0000-00000000000a', now(), now());
  raise exception 'FAILED: created a group for someone else';
exception when insufficient_privilege then raise notice 'ok  cannot create a group in someone else''s name';
end $$;
reset role;
insert into auth.users values ('dddddddd-0000-0000-0000-000000000004');
set role authenticated;
select pg_temp.as_user('dddddddd-0000-0000-0000-000000000004');
select public.register_profile('d0000000-0000-0000-0000-00000000000d', 'Stranger');
do $$ begin
  insert into public.groups (id, name, owner_id, created_at, updated_at)
  values ('99999999-0000-0000-0000-000000000099', 'Hijacked', 'd0000000-0000-0000-0000-00000000000d', now(), now() + interval '1 day')
  on conflict (id) do update set name = excluded.name, updated_at = excluded.updated_at;
  raise exception 'FAILED: stranger overwrote a group';
exception when insufficient_privilege then raise notice 'ok  strangers cannot overwrite a group';
end $$;

-- Anonymous (signed-out) callers get nothing.
reset role;
set role anon;
do $$ begin
  perform count(*) from public.groups;
  raise exception 'FAILED: anon could read groups';
exception when insufficient_privilege then raise notice 'ok  signed-out requests are refused';
end $$;
reset role;
\echo ALL SQL CHECKS PASSED
