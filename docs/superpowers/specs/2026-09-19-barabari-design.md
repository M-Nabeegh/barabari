# Barabari V1 Product Requirements and Architecture

**Status:** Approved for implementation planning

**Date:** 2026-09-19

**Product:** Barabari

**Platform:** Native iPhone app built with SwiftUI and Xcode

**Document role:** Canonical V1 product requirements and technical design. The implementation plan must trace every task back to this document.

## 1. Product brief

Barabari is a Pakistan-first expense-sharing app for friends, flatmates, trips, families, and small groups. It records shared expenses in PKR, calculates fair balances, and lets people record how they settled through cash, Raast, bank transfer, Easypaisa, JazzCash, or another method.

The product promise is:

> Split fairly. Settle simply.

Barabari is a ledger and coordination tool in V1. It does not hold money, initiate payments, connect to bank accounts, or act as a wallet.

The design direction is inspired by the clarity of modern Pakistani fintech apps and the polish of native Apple software. It must be recognisably Barabari, not a visual copy of another product.

## 2. Product requirements

### 2.1 Problem

Shared spending is currently tracked through chat messages, screenshots, memory, and informal spreadsheets. These methods create three recurring problems:

1. People do not know the current balance.
2. Small expenses are forgotten or calculated incorrectly.
3. Settlements happen through different local methods and are difficult to record consistently.

Barabari should make the truth visible without making expense entry feel like accounting.

### 2.2 Primary users

#### Friends and flatmates

They share meals, groceries, rent, utilities, transport, and household purchases. They need quick entry, recurring expenses later, and a clear settlement view.

#### Travel and event groups

They need a temporary group, unequal splits, itemised expenses later, and a simple final settlement.

#### Families and informal groups

They need a low-friction ledger that works with cash, bank transfers, and local wallets without requiring everyone to connect a financial account.

### 2.3 V1 goals

- Let a user create or join a group in under two minutes.
- Let a user record a basic expense in a few seconds.
- Calculate balances correctly using integer minor units, never floating-point money.
- Work when the phone is offline and reconcile safely when it reconnects.
- Make settlement status understandable at a glance.
- Keep the iPhone interface fast, calm, accessible, and visually light.
- Keep domain modules independent enough that a future backend or payment integration can replace one adapter without rewriting the UI.

### 2.4 V1 non-goals

The following are explicitly outside the first release:

- Holding, transferring, or custody of user funds.
- Wallet accounts or stored payment credentials.
- Bank account linking or bank transaction scraping.
- Direct Raast, Easypaisa, or JazzCash payment initiation.
- Lending, credit, instalments, or interest calculations.
- Automatic SMS parsing.
- Receipt OCR.
- Business accounting, invoices, tax reports, or payroll.
- Public social feeds.
- A web dashboard.
- Multi-currency conversion.
- A large analytics or charting surface.

### 2.5 V1 scope by priority

#### P0, required for the first usable release

- Sign in with Apple or email authentication.
- Create a group.
- Join a group through a link or QR code.
- Add, edit, and soft-delete an expense.
- Choose the payer.
- Split equally, by exact amount, by percentage, or by shares.
- Use PKR as the V1 currency.
- View group balances and simplified debts.
- Record a settlement using cash, Raast, bank transfer, Easypaisa, JazzCash, or other.
- View a group activity timeline.
- Persist data locally with SwiftData.
- Queue offline writes and synchronise them safely.
- Show clear loading, empty, offline, error, and success states.
- Run from Xcode on a physical iPhone.

#### P1, only after P0 is stable

- Recurring expenses.
- Itemised bill splitting.
- Receipt photo attachment.
- Settlement notes and reference IDs.
- Local settlement reminders.
- English, Urdu, and Roman Urdu copy support.
- CSV or JSON export.

#### P2, not part of the first implementation plan

- Receipt OCR.
- Payment deep links or payment-provider integrations.
- Multi-currency groups.
- Web client.
- Advanced charts.
- Merchant or business workflows.

### 2.6 User stories and acceptance criteria

#### Authentication

As a user, I can sign in without giving Barabari access to my contacts or financial accounts.

Acceptance criteria:

- A new user can complete authentication and reach the home screen.
- A returning user sees locally cached data after authentication state is restored.
- Tokens are stored in Keychain, not UserDefaults.
- An expired session presents a recoverable sign-in state.

#### Groups

As a user, I can create a group with a name and optional description.

Acceptance criteria:

- The creator becomes the group owner.
- The group is visible immediately from the local store.
- The server rejects access by users who are not members.
- An invite link or QR code can be generated without exposing private group data in the URL.

#### Expenses

As a group member, I can enter an expense and choose who shares it.

Acceptance criteria:

- The amount is validated as a positive PKR value.
- The payer must be a group member.
- Every selected participant receives a non-negative share.
- Equal, exact, percentage, and shares splits reconcile to the total in paisa.
- The UI updates immediately from the local write.
- Retrying a request cannot create a duplicate expense.

#### Balances

As a group member, I can see what I owe and what others owe me.

Acceptance criteria:

- The client can show a provisional balance while offline.
- The server recomputes and validates the authoritative balance.
- Zero balances are displayed as settled, not as debt.
- Rounding differences are resolved deterministically and documented in the split algorithm.

#### Settlements

As a user, I can record that a debt was paid using a local payment method.

Acceptance criteria:

- A settlement records payer, recipient, amount, method, timestamp, and optional note.
- A settlement never changes money outside the app.
- Partial settlement is supported by the domain model, even if the first UI uses a single full-debt action.
- Both parties can see the settlement in the activity timeline.
- A settlement can be corrected through an adjustment event rather than silent deletion.

#### Offline use

As a user, I can add an expense without internet access.

Acceptance criteria:

- The expense appears locally without waiting for the network.
- The outbox retries with bounded exponential backoff.
- The same logical command is applied once on the server.
- A failed operation has an actionable status and does not disappear silently.

### 2.7 Primary user flows

#### First launch

1. Launch Barabari.
2. Show a short value statement.
3. Authenticate.
4. Show an empty home state with one action: create or join a group.

#### Create a group

1. Tap Create group.
2. Enter group name.
3. Confirm.
4. Show the group detail screen.
5. Offer invite link and QR code.

#### Add an expense

1. Tap the central Add expense action.
2. Enter the amount with a numeric keypad.
3. Select the payer.
4. Select participants.
5. Select split type.
6. Review the split preview.
7. Save.

The basic equal split path should not require a long form.

#### Settle a debt

1. Open a debt card.
2. Choose a settlement method.
3. Review the amount and recipient.
4. Tap Mark as paid.
5. Show the updated balance and activity event.

## 3. UI and interaction specification

### 3.1 Screen map

```text
AppShell
├── Home
│   ├── Balance summary
│   ├── Pending settlement cards
│   └── Recent activity
├── Groups
│   ├── Group list
│   ├── Group detail
│   ├── Members
│   └── Invite
├── Add Expense
│   ├── Amount
│   ├── Payer
│   ├── Participants
│   ├── Split method
│   └── Review and save
├── Activity
└── Settings
    ├── Account
    ├── Appearance
    ├── Notifications
    ├── Privacy
    └── Data export and deletion
```

### 3.2 Design system rules

- Use SwiftUI and native controls wherever they provide the required behaviour.
- Use semantic system colours for light and dark appearance.
- Use one Barabari accent for interactive emphasis. Success, warning, and error colours remain semantic.
- Use SF Pro for body copy and SF Rounded selectively for friendly display values.
- Use tabular or monospaced digits for amounts and aligned numeric columns.
- Use a small spacing scale: 8, 12, 16, 20, 26, and 32 points.
- Use one card treatment: 16 to 20 point radius, a subtle hairline, and no static drop shadow.
- Keep primary screen padding at 16 points.
- Keep interactive targets at least 44 by 44 points.
- Use motion mostly for state changes, approximately 150 to 250ms.
- Respect Dynamic Type, VoiceOver, Reduce Motion, and increased contrast.
- Never use colour as the only indicator of debt or status.
- Avoid decorative gradients, heavy blur, excessive charts, nested cards, and long onboarding.

### 3.3 Copy rules

- Say what happened and what the user can do next.
- Use “Add expense,” “Save expense,” “Mark as paid,” and “Try again” consistently.
- Use “You owe” and “You are owed” for the two primary balance directions.
- Do not expose implementation terms such as “outbox,” “revision,” or “reconciliation” in normal user copy.
- Error messages must name the failed action and offer a recovery.

## 4. Technical architecture

### 4.1 Architecture principles

1. Keep V1 as one native iOS app and one modular backend deployment.
2. Put business rules in testable domain types and use cases, not SwiftUI views.
3. Hide persistence and networking behind repository protocols.
4. Make local writes immediate and network reconciliation asynchronous.
5. Treat financial records as an append-friendly audit trail.
6. Use stable IDs, explicit versions, and idempotency keys everywhere a retry is possible.
7. Do not add a third-party dependency when a small native implementation is sufficient.
8. Extract a microservice only when there is a separate scaling, security, ownership, or deployment requirement demonstrated by usage.

### 4.2 iOS project structure

The first implementation is one Xcode project. Feature folders provide isolation without introducing runtime or package overhead. Local Swift Package Manager modules may be added later when a boundary is stable and independently reusable.

```text
Barabari/
├── App/
├── DesignSystem/
├── Domain/
│   ├── Models/
│   ├── ValueTypes/
│   ├── UseCases/
│   └── Repositories/
├── Data/
│   ├── SwiftData/
│   ├── LocalRepositories/
│   ├── RemoteRepositories/
│   └── Sync/
├── Features/
│   ├── Authentication/
│   ├── Home/
│   ├── Groups/
│   ├── Expenses/
│   ├── Settlements/
│   ├── Activity/
│   └── Settings/
├── Infrastructure/
│   ├── APIClient/
│   ├── Keychain/
│   ├── Notifications/
│   └── Logging/
└── Tests/
```

### 4.3 iOS dependency direction

```text
Features -> Domain
Features -> DesignSystem
Data -> Domain
Infrastructure -> Domain contracts
App -> Features, Data, DesignSystem
Domain -> Foundation only
```

Rules:

- A SwiftUI view cannot import the remote API client.
- A domain use case cannot import SwiftData.
- A repository implementation can depend on SwiftData or the API client, but the protocol lives in Domain.
- Shared state is limited to session, appearance, and app-level routing.
- Each feature owns its view state and loading/error transitions.

### 4.4 Core interfaces

The interfaces below are the coupling seams that later tasks must preserve.

```swift
protocol GroupRepository {
    func listGroups() async throws -> [Group]
    func createGroup(name: String, description: String?) async throws -> Group
    func invite(groupID: Group.ID) async throws -> Invite
}

protocol ExpenseRepository {
    func listExpenses(groupID: Group.ID, cursor: String?) async throws -> Page<Expense>
    func saveExpense(_ expense: Expense, idempotencyKey: UUID) async throws -> Expense
    func requestExpenseDeletion(id: Expense.ID, idempotencyKey: UUID) async throws
}

protocol BalanceRepository {
    func summary(groupID: Group.ID) async throws -> BalanceSummary
}

protocol SettlementRepository {
    func listSettlements(groupID: Group.ID, cursor: String?) async throws -> Page<Settlement>
    func saveSettlement(_ settlement: Settlement, idempotencyKey: UUID) async throws -> Settlement
}

protocol SyncEngine {
    func enqueue(_ operation: SyncOperation) async
    func syncNow() async
}
```

The concrete signatures may be refined during implementation, but the dependency direction must remain unchanged.

### 4.5 Local persistence

SwiftData is the local persistence layer. `ModelContainer` owns the schema and store, and the app uses explicit schema versions for migrations. SwiftData's model and persistence APIs are documented by Apple in [SwiftData](https://developer.apple.com/documentation/swiftdata?changes=lat_6__4_8&language=objc) and [ModelContainer](https://developer.apple.com/documentation/swiftdata/modelcontainer?changes=_1).

Local storage has two roles:

- A responsive cache for server-backed data.
- An offline source of truth for pending local commands.

The app must be usable from cached data before a network request completes.

### 4.6 Backend deployment

V1 uses a modular monolith:

```text
Auth module
Groups module
Expenses module
Balances module
Settlements module
Activity module
Sync module
Notifications module
        |
   Postgres database
```

The recommended fast deployment is managed Postgres plus managed authentication, such as Supabase or an equivalent provider. Provider-specific calls must live behind `RemoteRepository` implementations so the UI and Domain layers do not depend on the provider.

A small custom API can replace the managed adapter later. A Swift/Vapor backend is an option if owning the server runtime becomes important, but it is not required for V1.

### 4.7 API shape

Use JSON over HTTPS with authenticated requests, cursor pagination, and idempotency keys.

Core query endpoints:

```text
GET  /v1/me
GET  /v1/groups
GET  /v1/groups/{groupID}
GET  /v1/groups/{groupID}/expenses?cursor=
GET  /v1/groups/{groupID}/activity?cursor=
GET  /v1/groups/{groupID}/balances
```

Core command endpoints:

```text
POST /v1/groups
POST /v1/groups/{groupID}/invites
POST /v1/groups/{groupID}/expenses
POST /v1/groups/{groupID}/settlements
POST /v1/sync/push
POST /v1/sync/pull
```

Commands must accept an `Idempotency-Key` header or equivalent request field. Server responses should include the canonical record, revision, and server timestamp.

The server is authoritative for permission checks, canonical splits, and balances. The client may calculate a provisional balance for immediate feedback, but it cannot bypass server validation.

### 4.8 Data model

#### User

```text
id: UUID
displayName: String
email: String?
avatarURL: URL?
createdAt: Date
updatedAt: Date
```

#### Group

```text
id: UUID
name: String
description: String?
currencyCode: String = "PKR"
ownerID: UUID
createdAt: Date
updatedAt: Date
revision: Int
deletedAt: Date?
```

#### GroupMember

```text
id: UUID
groupID: UUID
userID: UUID
role: owner | member
status: active | invited | left
joinedAt: Date?
createdAt: Date
updatedAt: Date
```

#### Expense

```text
id: UUID
groupID: UUID
title: String
note: String?
totalMinorUnits: Int64
currencyCode: String = "PKR"
paidByUserID: UUID
occurredAt: Date
createdByUserID: UUID
createdAt: Date
updatedAt: Date
revision: Int
deletedAt: Date?
```

#### ExpenseSplit

```text
id: UUID
expenseID: UUID
userID: UUID
amountMinorUnits: Int64
weight: Int64?
percentageBasisPoints: Int64?
```

Only one split representation is canonical after creation. The original split method and input may be retained for audit and display.

#### Settlement

```text
id: UUID
groupID: UUID
fromUserID: UUID
toUserID: UUID
amountMinorUnits: Int64
currencyCode: String = "PKR"
method: cash | raast | bankTransfer | easypaisa | jazzcash | other
note: String?
occurredAt: Date
createdByUserID: UUID
createdAt: Date
updatedAt: Date
revision: Int
deletedAt: Date?
```

#### ActivityEvent

```text
id: UUID
groupID: UUID
actorUserID: UUID
kind: expenseCreated | expenseChanged | settlementCreated | memberJoined | memberLeft
subjectID: UUID
createdAt: Date
metadata: JSON
```

#### SyncOperation

```text
id: UUID
entityID: UUID
operation: create | update | delete
entityType: group | expense | settlement | membership
payload: JSON
idempotencyKey: UUID
attemptCount: Int
nextAttemptAt: Date?
status: pending | syncing | succeeded | failed
lastErrorCode: String?
createdAt: Date
```

All persisted records use UUIDs. Money uses `Int64` minor units and an explicit currency code. `Double` is prohibited for financial amounts.

### 4.9 Balance calculation

The balance engine receives expenses and settlements for a group and produces net positions per member.

Rules:

- A positive net position means the member should receive money.
- A negative net position means the member owes money.
- Expense split totals must equal the expense total exactly in minor units.
- Settlement amounts reduce the sender's debt and the recipient's receivable.
- Debt simplification must conserve the total net amount.
- A deterministic remainder rule assigns unavoidable one-paisa rounding differences by stable participant ordering.
- The server repeats the calculation and returns the canonical result.

The algorithm lives in Domain and is tested independently of SwiftUI, SwiftData, and networking.

### 4.10 Offline and synchronisation

Write path:

```text
User action
  -> Domain validation
  -> SwiftData transaction
  -> UI updates immediately
  -> SyncOperation added to outbox
  -> Remote push with idempotency key
  -> Server validation
  -> Canonical response stored locally
```

Read path:

```text
SwiftData cache -> render screen immediately
Remote pull -> merge by revision and tombstone
```

Conflict rules:

- A server revision wins when a record has changed remotely.
- An unsynchronised local command is not discarded because a read is stale.
- Commands are retried, not duplicated.
- Financial corrections create explicit events or adjustment records.
- Soft-deleted records remain available for reconciliation and audit.

Background refresh is opportunistic. The app must sync at launch, foreground entry, and after a successful authenticated request. Apple documents BackgroundTasks for scheduled or deferred work, but V1 must not treat background execution as guaranteed. [BackgroundTasks](https://developer.apple.com/documentation/BackgroundTasks?changes=_4)

### 4.11 Authentication and security

- Use Sign in with Apple or email authentication.
- Keep access and refresh tokens in Keychain.
- Enforce group membership and role checks on the backend.
- Use HTTPS for every remote request.
- Never trust a client-provided group membership or balance.
- Avoid contacts permission in V1.
- Do not store CNIC data, wallet passwords, bank credentials, or payment secrets.
- Add optional Face ID app lock after the core flow is stable.
- Log technical identifiers and error codes, not raw expense notes or unnecessary financial details.
- Provide account deletion and data export flows before public release.

### 4.12 Notifications

V1 notification scope:

- In-app activity updates.
- Optional local reminders for pending settlements.

Remote push can follow once sync and authentication are stable. Remote notifications require a provider server to send requests to APNs, as described in [Apple's remote notification setup](https://developer.apple.com/documentation/UserNotifications/setting-up-a-remote-notification-server?changes=__9).

### 4.13 Performance and reliability targets

These are target budgets to verify on a physical iPhone:

- Cached home screen visible within 300ms after the app is ready to render.
- Basic local expense creation responds immediately without waiting for the network.
- Cold launch target under 1.5 seconds after profiling and optimisation.
- Activity and expense lists use pagination rather than loading unlimited history.
- No network request blocks first content.
- No heavy charting framework or large UI dependency is included in V1.
- The app remains useful in airplane mode after initial data has loaded.
- Sync failures remain visible and recoverable.

### 4.14 Observability

- Use `Logger` with subsystem categories for auth, sync, persistence, and UI errors.
- Use signposts only for profiling and remove noisy production logging.
- Capture a stable error code and correlation ID for failed remote operations.
- Do not send raw notes, contact lists, or full financial histories to analytics.
- Add privacy-safe counters for screen load, sync success, sync failure, and expense-save latency.

## 5. Testing strategy

### Domain tests

- Equal split with an indivisible remainder.
- Exact split total mismatch.
- Percentage split that does not total 100 percent.
- Shares split with zero or negative weights.
- Zero and negative expense amounts.
- Large PKR amounts near the storage limit.
- Debt simplification conservation.
- Full and partial settlements.
- Multiple settlements between the same pair.

### Persistence and sync tests

- Outbox insertion is atomic with the local expense write.
- A retry with the same idempotency key produces one server record.
- Failed operations expose a recoverable error state.
- A newer server revision replaces stale local data.
- A pending local command survives a foreground/background cycle.
- Soft deletion does not resurrect a record during pull.

### API and authorization tests

- A non-member cannot read a group.
- A non-member cannot create an expense in a group.
- A member cannot change another user's role without authorization.
- The server rejects a split whose parts do not equal the total.
- The server rejects duplicate idempotency keys with conflicting payloads.

### UI tests

- First-launch authentication.
- Create group.
- Join group through invite.
- Add equal expense.
- Add exact expense.
- View balance and settlement card.
- Mark a debt as paid.
- Offline add followed by reconnect.
- Light mode, dark mode, Dynamic Type, VoiceOver labels, and Reduce Motion.

## 6. Delivery plan

### Milestone 1: iPhone foundation

- Create the `Barabari.xcodeproj` SwiftUI app.
- Add the design tokens and navigation shell.
- Add SwiftData schema and demo seed data.
- Add an app configuration that runs without a remote backend.
- Verify the app launches on a physical iPhone from Xcode.

### Milestone 2: Core ledger

- Implement User, Group, GroupMember, Expense, ExpenseSplit, and ActivityEvent.
- Implement group creation and invitations.
- Implement the amount-first expense flow.
- Implement split validation and balance calculation.
- Add domain, persistence, and UI tests.

### Milestone 3: Remote sync

- Add authentication.
- Add the RemoteRepository adapter.
- Add the sync outbox and idempotent push.
- Add cursor-based pull and revision merging.
- Verify airplane-mode and reconnect scenarios.

### Milestone 4: Settlements and release polish

- Add Settlement and payment-method UI.
- Add settlement cards and activity events.
- Add local reminders.
- Complete accessibility and error states.
- Profile launch, scrolling, and save latency on a physical iPhone.
- Produce a TestFlight-ready build.

## 7. Definition of done for V1

V1 is complete only when all of the following are true:

- The app installs and runs on a physical iPhone from Xcode.
- A user can authenticate, create a group, and invite another member.
- A user can add equal, exact, percentage, and shares expenses.
- Balances remain correct for rounding, edits, deletions, and settlements.
- A user can record cash, Raast, bank transfer, Easypaisa, JazzCash, and other settlements.
- The app works offline after initial data has loaded.
- Reconnection does not create duplicate expenses or lose local changes.
- Server authorization prevents cross-group access.
- Core domain and sync tests pass.
- Light mode, dark mode, Dynamic Type, VoiceOver, and Reduce Motion have been checked on device.
- The app does not claim to send or receive money.
- Privacy copy, account deletion, and data export behaviour are documented.

## 8. Architecture decision record

### ADR-001: Modular monolith before microservices

**Decision:** Ship V1 as one backend deployment with explicit modules and repository boundaries.

**Reason:** Barabari needs simple deployment, strong consistency for balances, and fast iteration. Microservices would add operational complexity before independent scaling or ownership boundaries exist.

**Extraction path:** A future service may be split out only when it has its own scaling profile, security boundary, release cadence, or ownership. Candidate modules are Notifications and Sync. Expenses, Settlements, and Balances should remain close until the consistency model is proven.

### ADR-002: Local-first iPhone data

**Decision:** SwiftData is the local cache and offline write store.

**Reason:** It provides native persistence with a small dependency footprint and allows the interface to render cached data before network completion.

### ADR-003: Ledger-only payments in V1

**Decision:** Record payment method and settlement confirmation without moving money.

**Reason:** It keeps V1 safer, simpler, and easier to ship while still matching how Pakistani groups actually settle through multiple channels.

## 9. Future extension seams

The following are intentionally isolated for later work:

- `PaymentMethodResolver` for provider-specific deep links.
- `NotificationService` for APNs and server-side reminders.
- `ReceiptAttachmentStore` for photos and OCR.
- `CurrencyProvider` for multi-currency groups.
- `RemoteRepository` for replacing the managed backend.
- `SyncEngine` for a more advanced event stream if scale requires it.

These seams are extension points, not V1 features. Do not build unused provider abstractions or microservices before a real requirement exists.

## 10. Review checklist before implementation

- [ ] The app name is Barabari everywhere.
- [ ] The first release remains PKR-only and ledger-only.
- [ ] No SwiftUI view directly depends on networking or SwiftData.
- [ ] Every money value uses integer minor units.
- [ ] Every retryable command has an idempotency key.
- [ ] Group access is enforced on the backend.
- [ ] Offline writes are visible and recoverable.
- [ ] The design uses one accent and semantic status colours.
- [ ] The interface remains lightweight on a physical iPhone.
- [ ] Microservices are not introduced without a measured reason.
