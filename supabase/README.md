# Barabari backend

Barabari syncs through one Supabase project: Postgres, Auth and PostgREST. No custom server code is needed.

## How sync works

- **Local first.** The iPhone writes every change to its own SwiftData store immediately, so the app works offline. The sync engine pushes changed rows and pulls everyone else's in the background.
- **Identity.** Each install gets its own ledger user id. An anonymous Supabase session claims it through `register_profile`, so there is no email or password.
- **Access.** Row level security limits every table to members of the group (`is_group_member`). There are no delete policies; deletions travel as tombstones (`deleted_at`, `removed_at`).
- **Conflicts.** Triggers keep the newest `updated_at`, never bring a tombstone back to life, and bump `server_updated_at`, which is the pull cursor.
- **Money.** Amounts are stored in paise (`bigint`), and a trigger checks that splits add up to the expense total.
- **Invites.** `group_preview` shows what a link points at, and `join_group` adds you to the group. It can also claim a spot someone added for you by name, moving that person's history onto your account.

## Applying migrations

Migrations in `migrations/` are applied in order through the Supabase MCP server (`apply_migration`) or the dashboard SQL editor.

## Project settings

- **Authentication → Sign In / Providers → Allow anonymous sign-ins:** on
- The app reads the project URL and the publishable (anon) key from `Barabari/Barabari/Info.plist`. Both are safe to ship in the app, because row level security protects the data.
