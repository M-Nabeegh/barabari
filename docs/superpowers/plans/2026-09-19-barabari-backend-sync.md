# Barabari Backend and Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide Barabari with a secure, idempotent, modular backend for authentication, groups, expenses, balances, settlements, activity, and offline synchronisation without introducing microservices.

**Architecture:** Use one Supabase project with managed Postgres and Auth, SQL migrations, Row Level Security, and small Edge Functions only for transactional commands that need server-side validation. The iOS app talks through its `RemoteRepository` contracts and never embeds provider-specific logic in SwiftUI or Domain.

**Tech Stack:** Supabase CLI, PostgreSQL, SQL migrations, Supabase Auth, Deno/TypeScript Edge Functions, JSON over HTTPS, local Supabase test stack, Postgres integration tests

**Spec:** `docs/superpowers/specs/2026-09-19-barabari-design.md`

**Repository root:** `/Users/nabeegh/Documents/claude/Barabari`. Run backend commands from that directory unless a command explicitly changes into `backend/`.

**Task-table paths:** File paths in the task tables use the workspace-level `Barabari/` prefix so they can be located from `/Users/nabeegh/Documents/claude`; the repository itself is the `Barabari/` directory.

## Global Constraints

- V1 is one managed backend deployment, not a collection of microservices.
- The server is authoritative for membership, split validity, idempotency, and balances.
- All money is `BIGINT` minor units with a `currency_code` constrained to `PKR` in V1.
- Every mutable financial record has a UUID, revision, created timestamp, updated timestamp, and optional tombstone timestamp.
- Every retryable command has an idempotency key and a payload fingerprint.
- Row Level Security is enabled on every user-visible table.
- No endpoint moves money or stores payment credentials.
- Provider-specific code remains behind the API contract consumed by the iOS RemoteRepository layer.
- Activity records are append-friendly and corrections are represented explicitly.

## Review Focus

- RLS bypass attempts: a user outside a group must receive no group data and cannot create commands for it.
- Idempotency collisions: reusing a key with a different payload must fail instead of mutating the original command.
- Split conservation: stored splits must equal the expense total in minor units.
- Revision pulls: a sync pull must not erase a newer pending local command.
- Partial settlements: balance summaries must conserve net positions after multiple settlements.

---

### Task 1: Establish the Supabase project, local stack, and API contract

**Files:**
- Create: `Barabari/backend/supabase/config.toml`
- Create: `Barabari/backend/.env.example`
- Create: `Barabari/backend/README.md`
- Create: `Barabari/backend/docs/API.md`
- Create: `Barabari/backend/tests/health.test.ts`

**Interfaces:**
- API base path is `/v1`.
- Authenticated requests use the Supabase access token.
- Commands accept `Idempotency-Key: UUID`.
- Error responses use `{ "code": String, "message": String, "request_id": UUID }`.

- [ ] **Step 1: Write the health contract test**

```ts
const baseURL = Deno.env.get("BARABARI_API_URL") ?? "http://127.0.0.1:54321/functions/v1";

test("health endpoint returns the Barabari API version", async () => {
  const response = await fetch(`${baseURL}/v1/health`);
  expect(response.status).toBe(200);
  expect(await response.json()).toEqual({ service: "barabari", version: "v1" });
});
```

- [ ] **Step 2: Run the health test to verify failure**

Run: `cd backend && deno test --allow-net tests/health.test.ts`

Expected: FAIL because the local backend configuration and health function do not exist.

- [ ] **Step 3: Initialise the local Supabase stack and health function**

Run: `supabase init` from `Barabari/backend`, add the `supabase/config.toml`, create `supabase/functions/health/index.ts`, and document local start and reset commands in `README.md`.

- [ ] **Step 4: Run the health test to verify success**

Run: `supabase start` followed by `cd backend && deno test --allow-net tests/health.test.ts`

Expected: PASS.

- [ ] **Step 5: Commit backend foundation**

```bash
git add .
git commit -m "chore: add Barabari backend foundation"
```

### Task 2: Add identity, groups, memberships, and invite security

**Files:**
- Create: `Barabari/backend/supabase/migrations/001_identity_and_groups.sql`
- Create: `Barabari/backend/supabase/functions/create-invite/index.ts`
- Create: `Barabari/backend/supabase/functions/join-invite/index.ts`
- Create: `Barabari/backend/tests/groups.test.ts`
- Create: `Barabari/backend/tests/rls_groups.test.ts`

**Interfaces:**
- Tables: `profiles`, `groups`, `group_members`, `invites`.
- RPCs: `create_group(name text, description text)`, `join_group_by_invite(token text)`.
- Query endpoints: `GET /v1/me`, `GET /v1/groups`, `GET /v1/groups/{groupID}`.
- Command endpoint: `POST /v1/groups/{groupID}/invites`.

- [ ] **Step 1: Write failing group and RLS tests**

Cover group creation, owner membership, active-member reads, invite expiry, a member joining an invite, a non-member read, and a non-member write.

- [ ] **Step 2: Run the tests to verify failure**

Run: `cd backend && deno test --allow-net tests/groups.test.ts tests/rls_groups.test.ts`

Expected: FAIL because the tables, policies, and functions do not exist.

- [ ] **Step 3: Implement the identity and group migration**

Create UUID primary keys, timestamps, membership roles, invite hashes rather than raw invite secrets, and RLS policies based on `auth.uid()`. Enable RLS before inserting test data.

- [ ] **Step 4: Implement invite functions and query handlers**

Generate a short-lived opaque invite token, store only its hash, return a shareable URL payload, and make joining idempotent for an existing member.

- [ ] **Step 5: Run the tests to verify success**

Run: `supabase db reset` followed by `cd backend && deno test --allow-net tests/groups.test.ts tests/rls_groups.test.ts`

Expected: PASS, including negative authorization tests.

- [ ] **Step 6: Commit identity and groups**

```bash
git add .
git commit -m "feat: add secure Barabari groups and invites"
```

### Task 3: Add expenses, splits, balance calculation, and activity events

**Files:**
- Create: `Barabari/backend/supabase/migrations/002_expenses_and_balances.sql`
- Create: `Barabari/backend/supabase/functions/create-expense/index.ts`
- Create: `Barabari/backend/supabase/functions/update-expense/index.ts`
- Create: `Barabari/backend/supabase/functions/delete-expense/index.ts`
- Create: `Barabari/backend/supabase/functions/group-balance/index.ts`
- Create: `Barabari/backend/tests/expenses.test.ts`
- Create: `Barabari/backend/tests/balance.test.ts`

**Interfaces:**
- Tables: `expenses`, `expense_splits`, `activity_events`.
- RPCs: `create_expense_with_splits(payload jsonb, idempotency_key uuid)`, `calculate_group_balance(group_id uuid)`.
- Command endpoint: `POST /v1/groups/{groupID}/expenses`.
- Query endpoints: `GET /v1/groups/{groupID}/expenses`, `GET /v1/groups/{groupID}/balances`, `GET /v1/groups/{groupID}/activity`.

- [ ] **Step 1: Write failing expense and balance tests**

Cover an equal split, exact split, percentage split, shares split, indivisible paisa remainder, invalid totals, non-member payer, non-member participant, edit revision, soft delete, and debt simplification conservation.

- [ ] **Step 2: Run the tests to verify failure**

Run: `cd backend && deno test --allow-net tests/expenses.test.ts tests/balance.test.ts`

Expected: FAIL because the financial tables and functions do not exist.

- [ ] **Step 3: Implement the expense and split schema**

Use `BIGINT` for `total_minor_units` and `amount_minor_units`, constrain `currency_code` to `PKR`, add `revision`, `deleted_at`, and foreign keys to group membership. Enforce split total equality in a transaction.

- [ ] **Step 4: Implement transactional expense commands**

The create command validates group membership, payer membership, participants, positive total, split conservation, and idempotency before inserting the expense, splits, and activity event in one transaction.

- [ ] **Step 5: Implement canonical balance calculation**

Build net positions from active expenses and settlements, then simplify debts deterministically. Return positive receivables and negative payables with an explicit `settled` state for zero.

- [ ] **Step 6: Run the tests to verify success**

Run: `supabase db reset` followed by `cd backend && deno test --allow-net tests/expenses.test.ts tests/balance.test.ts`

Expected: PASS, including rounding and authorization failures.

- [ ] **Step 7: Commit expenses and balances**

```bash
git add .
git commit -m "feat: add Barabari expenses and balances"
```

### Task 4: Add settlements and settlement activity

**Files:**
- Create: `Barabari/backend/supabase/migrations/003_settlements.sql`
- Create: `Barabari/backend/supabase/functions/create-settlement/index.ts`
- Create: `Barabari/backend/tests/settlements.test.ts`

**Interfaces:**
- Table: `settlements`.
- RPC: `create_settlement(payload jsonb, idempotency_key uuid)`.
- Command endpoint: `POST /v1/groups/{groupID}/settlements`.
- Query endpoint: `GET /v1/groups/{groupID}/settlements`.
- Methods: `cash`, `raast`, `bank_transfer`, `easypaisa`, `jazzcash`, `other`.

- [ ] **Step 1: Write failing settlement tests**

Cover full debt settlement, partial settlement, settlement between two valid members, invalid non-member sender, invalid non-member recipient, non-positive amount, and activity event creation.

- [ ] **Step 2: Run the settlement tests to verify failure**

Run: `cd backend && deno test --allow-net tests/settlements.test.ts`

Expected: FAIL because the settlement table and command do not exist.

- [ ] **Step 3: Implement the settlement schema and command**

Store the method as an enum or constrained text value, store no payment credentials, validate both users are active group members, and insert the settlement plus activity event transactionally.

- [ ] **Step 4: Re-run balance tests with settlements**

Run: `supabase db reset` followed by `cd backend && deno test --allow-net tests/balance.test.ts tests/settlements.test.ts`

Expected: PASS with remaining debt correctly reduced after partial settlement.

- [ ] **Step 5: Commit settlements**

```bash
git add .
git commit -m "feat: add Barabari settlements"
```

### Task 5: Add idempotency, revisions, and sync pull/push

**Files:**
- Create: `Barabari/backend/supabase/migrations/004_sync_and_idempotency.sql`
- Create: `Barabari/backend/supabase/functions/sync-push/index.ts`
- Create: `Barabari/backend/supabase/functions/sync-pull/index.ts`
- Create: `Barabari/backend/tests/idempotency.test.ts`
- Create: `Barabari/backend/tests/sync.test.ts`

**Interfaces:**
- Tables: `idempotency_keys`, `sync_cursors`.
- Endpoints: `POST /v1/sync/push`, `POST /v1/sync/pull`.
- Push response: `{ accepted: SyncRecord[], rejected: SyncRejection[] }`.
- Pull response: `{ records: SyncRecord[], nextCursor: String? }`.
- `SyncRecord` contains `entityType`, `entityID`, `revision`, `operation`, `payload`, and `serverTimestamp`.

- [ ] **Step 1: Write failing idempotency and revision tests**

Cover a repeated create with the same key and identical payload, a reused key with a different payload, stale update revision, tombstone pull, cursor pagination, and a pending local command surviving a pull.

- [ ] **Step 2: Run sync tests to verify failure**

Run: `cd backend && deno test --allow-net tests/idempotency.test.ts tests/sync.test.ts`

Expected: FAIL because idempotency and sync storage do not exist.

- [ ] **Step 3: Implement idempotency storage**

Store the request hash, authenticated user, operation type, canonical response, and creation timestamp. Return the original response for an identical retry and a conflict error for a different payload.

- [ ] **Step 4: Implement revision-aware push**

Reject stale destructive updates, preserve tombstones, validate membership and domain rules again, and return canonical records for accepted operations.

- [ ] **Step 5: Implement cursor-based pull**

Return changes ordered by server revision and timestamp, include tombstones until their retention period, and make the cursor opaque to the iOS client.

- [ ] **Step 6: Run sync tests to verify success**

Run: `supabase db reset` followed by `cd backend && deno test --allow-net tests/idempotency.test.ts tests/sync.test.ts`

Expected: PASS.

- [ ] **Step 7: Commit sync**

```bash
git add .
git commit -m "feat: add idempotent Barabari sync"
```

### Task 6: Add pagination, error contracts, and the iOS remote adapter contract

**Files:**
- Create: `Barabari/backend/docs/API-EXAMPLES.md`
- Create: `Barabari/backend/tests/api_contract.test.ts`
- Modify: `Barabari/docs/superpowers/plans/2026-09-19-barabari-ios-v1.md` only if an exact transport type must be clarified before implementation.

**Interfaces:**
- Page response: `{ items: T[], nextCursor: String? }`.
- Error response: `{ code: String, message: String, request_id: UUID }`.
- Required error codes: `unauthorized`, `forbidden`, `not_found`, `validation_failed`, `idempotency_conflict`, `stale_revision`, `rate_limited`, `server_error`.

- [ ] **Step 1: Write contract tests for page and error shapes**

Assert exact JSON keys, cursor behaviour, stable error codes, and that no response contains payment credentials or unrelated group data.

- [ ] **Step 2: Run contract tests to verify failure**

Run: `cd backend && deno test --allow-net tests/api_contract.test.ts`

Expected: FAIL until all handlers use the shared response helpers.

- [ ] **Step 3: Add shared response helpers and examples**

Document request and response examples for group creation, expense creation, balance reads, settlement creation, and sync push/pull. Keep examples in PKR and use integer minor units.

- [ ] **Step 4: Run contract tests to verify success**

Run: `cd backend && deno test --allow-net tests/api_contract.test.ts`

Expected: PASS.

- [ ] **Step 5: Commit the API contract**

```bash
git add .
git commit -m "docs: define Barabari API contracts"
```

### Task 7: Verify security, deployment configuration, and end-to-end sync

**Files:**
- Create: `Barabari/backend/tests/security_regression.test.ts`
- Create: `Barabari/backend/tests/e2e_sync.test.ts`
- Create: `Barabari/backend/docs/DEPLOYMENT.md`
- Create: `Barabari/backend/.github/workflows/backend-tests.yml`

**Interfaces:**
- The deployment checklist covers migrations, secrets, Auth redirect configuration, Edge Function deployment, RLS verification, and rollback of the last migration.
- The CI job runs local migrations and all backend tests without printing secrets.

- [ ] **Step 1: Write security regression tests**

Cover cross-group reads, cross-group writes, invite token reuse after expiry, unauthenticated access, idempotency conflict, and response redaction.

- [ ] **Step 2: Run the security and end-to-end tests to establish failures**

Run: `supabase db reset` followed by `cd backend && deno test --allow-net tests/security_regression.test.ts tests/e2e_sync.test.ts`

Expected: Any missing policy or sync mismatch is reported before deployment work.

- [ ] **Step 3: Add deployment documentation and CI**

Document how to link a Supabase project, apply migrations, deploy functions, configure Auth providers, rotate secrets, and roll back a bad migration. CI must run `supabase db reset` and all test files.

- [ ] **Step 4: Run the complete backend test suite**

Run: `supabase db reset` followed by `cd backend && deno test --allow-net tests`

Expected: PASS with all authorization, financial, idempotency, and sync tests included.

- [ ] **Step 5: Run an end-to-end iOS adapter smoke test**

Configure the iOS Debug environment against the local Supabase URL, sign in a test user, create a group, add an expense, create a settlement, stop the network, create another expense, restore the network, and verify the canonical records and balance.

- [ ] **Step 6: Commit deployment readiness**

```bash
git add .
git commit -m "test: verify Barabari backend security and sync"
```

## Plan self-review

### Spec coverage

- Identity, groups, members, and invites are covered by Task 2.
- Expense validation, balances, and activity are covered by Task 3.
- Settlements and local payment methods are covered by Task 4.
- Idempotency, revisions, tombstones, and cursor sync are covered by Task 5.
- Transport contracts and pagination are covered by Task 6.
- RLS, deployment, and end-to-end reconciliation are covered by Task 7.
- No payment custody, bank connection, or microservice is introduced.

### Placeholder scan

No task uses TBD, TODO, or a generic “handle edge cases” instruction. Provider configuration is fixed to Supabase for this implementation plan; the iOS boundary still permits a future backend replacement.

### Type consistency

The endpoint names and `SyncRecord` fields match the iOS `SyncRepository` contract. The group, expense, settlement, and activity table identifiers match the Domain entities in the iOS plan. Error codes are stable strings and are not translated into UI copy inside the backend.

### Review-focus coverage

- RLS bypass is tested in Tasks 2 and 7.
- Idempotency collisions are tested in Task 5.
- Split conservation is tested in Task 3.
- Revision pulls are tested in Task 5.
- Partial settlements are tested in Task 4 and the balance suite.
