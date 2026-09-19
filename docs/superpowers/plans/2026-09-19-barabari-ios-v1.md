# Barabari iOS V1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a lightweight native iPhone app that lets authenticated users create groups, record PKR expenses, calculate balances, record settlements, and use the ledger offline.

**Architecture:** One SwiftUI Xcode project with Domain, Features, Data, DesignSystem, and Infrastructure boundaries. Domain rules depend only on Foundation; SwiftData and the remote API are repository implementations behind protocols; feature views never call persistence or networking directly.

**Tech Stack:** Swift 5.9+ compatible with Swift 6 concurrency, SwiftUI, SwiftData, Foundation, XCTest, XCUITest, URLSession, Keychain Services, iOS 17.0+

**Spec:** `docs/superpowers/specs/2026-09-19-barabari-design.md`

**Repository root:** `/Users/nabeegh/Documents/claude/Barabari`. All commands in this plan run from that directory.

**Task-table paths:** File paths in the task tables use the workspace-level `Barabari/` prefix so they can be located from `/Users/nabeegh/Documents/claude`; the repository itself is the `Barabari/` directory.

## Global Constraints

- The app name is Barabari everywhere in the UI, Xcode target, documentation, and test fixtures.
- V1 is PKR-only and ledger-only. It never holds or transfers user money.
- Every financial amount is `Int64` minor units with an explicit currency code; `Double` is prohibited for money.
- SwiftUI views cannot import the remote API client or SwiftData implementation.
- The first implementation is one Xcode project; local Swift packages are not introduced until a boundary is stable and independently reusable.
- All retryable commands carry an idempotency key.
- Offline writes are visible, durable, and recoverable.
- No heavy UI framework, charting library, analytics SDK, or payment SDK is added to V1.
- The design uses semantic light and dark appearances, one interactive accent, and semantic status colours.
- The minimum deployment target is iOS 17.0 because the local persistence design uses SwiftData.

## Review Focus

- Paisa rounding and indivisible splits: every split must reconcile exactly to the expense total.
- Duplicate offline retries: the same idempotency key must not create a second expense or settlement.
- Stale server revisions: a newer server record must not erase a pending local command.
- Cross-group access: a local UI state must never be treated as authorization.
- Accessibility and small screens: Dynamic Type, VoiceOver, Reduce Motion, and a physical iPhone must remain usable.

---

### Task 1: Create the Xcode project and development configuration

**Files:**
- Create: `Barabari/Barabari.xcodeproj`
- Create: `Barabari/Barabari/App/BarabariApp.swift`
- Create: `Barabari/Barabari/App/AppEnvironment.swift`
- Create: `Barabari/Barabari/Config/Debug.xcconfig`
- Create: `Barabari/BarabariTests/BarabariLaunchTests.swift`
- Create: `Barabari/.gitignore`
- Create: `Barabari/README.md`

**Interfaces:**
- Produces `struct AppEnvironment` with `static let live`, `static let demo`, and `let modelContainer: ModelContainer`.
- Produces `@main struct BarabariApp: App` that injects `AppEnvironment.demo` for previews and a live environment for the app target.

- [ ] **Step 1: Create the failing launch test**

```swift
import XCTest

final class BarabariLaunchTests: XCTestCase {
    func testLaunchConfigurationHasBarabariDisplayName() throws {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, "Barabari")
    }
}
```

- [ ] **Step 2: Run the test to verify the project is not configured**

Run: `xcodebuild -project Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,name=iPhone 15' test -only-testing:BarabariTests/BarabariLaunchTests`

Expected: FAIL because the project and test target do not exist yet.

- [ ] **Step 3: Create the iOS App project in Xcode**

Create an iOS App named `Barabari`, set Interface to SwiftUI, Language to Swift, deployment target to iOS 17.0, and create separate `BarabariTests` and `BarabariUITests` targets. Set the display name to `Barabari` and do not add third-party packages.

- [ ] **Step 4: Add the app environment and demo configuration**

Create a demo environment that uses an in-memory SwiftData container and seeded records. Keep the provider base URL and authentication mode in `Debug.xcconfig`; do not place secrets in source control.

- [ ] **Step 5: Run the launch test to verify it passes**

Run: `xcodebuild -project Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,name=iPhone 15' test -only-testing:BarabariTests/BarabariLaunchTests`

Expected: PASS.

- [ ] **Step 6: Commit the foundation**

```bash
git add .
git commit -m "chore: create Barabari iOS foundation"
```

### Task 2: Add the lightweight Barabari design system

**Files:**
- Create: `Barabari/Barabari/DesignSystem/BarabariColors.swift`
- Create: `Barabari/Barabari/DesignSystem/BarabariTypography.swift`
- Create: `Barabari/Barabari/DesignSystem/BarabariSpacing.swift`
- Create: `Barabari/Barabari/DesignSystem/Components/BarabariCard.swift`
- Create: `Barabari/Barabari/DesignSystem/Components/PrimaryActionButton.swift`
- Create: `Barabari/Barabari/DesignSystem/Components/AmountText.swift`
- Create: `Barabari/Barabari/DesignSystem/Components/StatusBadge.swift`
- Create: `Barabari/BarabariTests/DesignSystemTests.swift`

**Interfaces:**
- Produces `enum BarabariColors` with semantic `background`, `surface`, `raised`, `textPrimary`, `textSecondary`, `accent`, `success`, `warning`, and `danger` colours.
- Produces `enum BarabariSpacing` with `screen`, `card`, `section`, `row`, and `compact` values.
- Produces `AmountText(minorUnits: Int64, currencyCode: String, style: AmountText.Style)`.
- Produces `enum AmountFormatter { static func string(minorUnits: Int64, currencyCode: String) -> String }`.
- Produces reusable `BarabariCard`, `PrimaryActionButton`, and `StatusBadge` views that accept content closures and do not own navigation.

- [ ] **Step 1: Write token tests**

```swift
func testSpacingScaleIsStable() {
    XCTAssertEqual(BarabariSpacing.screen, 16)
    XCTAssertEqual(BarabariSpacing.section, 26)
}

func testAmountFormatterUsesPKR() {
    let value = AmountFormatter.string(minorUnits: 325000, currencyCode: "PKR")
    XCTAssertTrue(value.contains("PKR") || value.contains("Rs"))
}
```

- [ ] **Step 2: Run the tests and verify they fail**

Run: `xcodebuild -project Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,name=iPhone 15' test -only-testing:BarabariTests/DesignSystemTests`

Expected: FAIL because the tokens and components are not defined.

- [ ] **Step 3: Implement semantic tokens and components**

Use system colours where available, define light and dark variants, use tabular digits for amounts, keep cards to one hairline treatment, and preserve a 44-point minimum hit area.

- [ ] **Step 4: Run the tests and verify they pass**

Run: `xcodebuild -project Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,name=iPhone 15' test -only-testing:BarabariTests/DesignSystemTests`

Expected: PASS.

- [ ] **Step 5: Commit the design system**

```bash
git add .
git commit -m "feat: add Barabari lightweight design system"
```

### Task 3: Implement money values and split calculation in Domain

**Files:**
- Create: `Barabari/Barabari/Domain/ValueTypes/Money.swift`
- Create: `Barabari/Barabari/Domain/ValueTypes/PercentageBasisPoints.swift`
- Create: `Barabari/Barabari/Domain/Models/ExpenseSplit.swift`
- Create: `Barabari/Barabari/Domain/Models/SplitMethod.swift`
- Create: `Barabari/Barabari/Domain/Services/SplitCalculator.swift`
- Create: `Barabari/BarabariTests/Domain/SplitCalculatorTests.swift`

**Interfaces:**
- `struct Money: Equatable, Codable, Sendable { let minorUnits: Int64; let currencyCode: String }`.
- `enum SplitMethod: Equatable, Codable, Sendable { case equal; case exact([UUID: Int64]); case percentage([UUID: Int64]); case shares([UUID: Int64]) }`.
- `struct ExpenseSplit: Equatable, Codable, Sendable { let userID: UUID; let amount: Money }`.
- `enum SplitCalculator { static func calculate(total: Money, participants: [UUID], method: SplitMethod) throws -> [ExpenseSplit] }`.
- `enum SplitError: Error { case nonPositiveTotal; case noParticipants; case invalidExactTotal; case invalidPercentageTotal; case invalidShare; case unknownParticipant; case currencyMismatch }`.

- [ ] **Step 1: Write failing tests for the split contract**

Cover equal division with remainder, exact amounts, 100 percent validation, shares, zero participants, negative values, unknown participants, and currency mismatch. Assert that the sum of returned minor units equals the total in every valid case.

- [ ] **Step 2: Run the split tests to verify failure**

Run: `xcodebuild -project Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,name=iPhone 15' test -only-testing:BarabariTests/SplitCalculatorTests`

Expected: FAIL because `Money`, `SplitMethod`, and `SplitCalculator` are not implemented.

- [ ] **Step 3: Implement the smallest correct money and split types**

Use integer arithmetic only. For equal splits, assign unavoidable remainder paisa to participants sorted by UUID bytes so the result is deterministic. Reject invalid exact, percentage, and shares inputs before producing output.

- [ ] **Step 4: Run the split tests to verify success**

Run: `xcodebuild -project Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,name=iPhone 15' test -only-testing:BarabariTests/SplitCalculatorTests`

Expected: PASS.

- [ ] **Step 5: Commit the domain calculator**

```bash
git add .
git commit -m "feat: add precise PKR split calculator"
```

### Task 4: Add domain entities, repositories, and ledger use cases

**Files:**
- Create: `Barabari/Barabari/Domain/Models/User.swift`
- Create: `Barabari/Barabari/Domain/Models/Group.swift`
- Create: `Barabari/Barabari/Domain/Models/GroupMember.swift`
- Create: `Barabari/Barabari/Domain/Models/Expense.swift`
- Create: `Barabari/Barabari/Domain/Models/Settlement.swift`
- Create: `Barabari/Barabari/Domain/Models/ActivityEvent.swift`
- Create: `Barabari/Barabari/Domain/Models/BalanceSummary.swift`
- Create: `Barabari/Barabari/Domain/Repositories/GroupRepository.swift`
- Create: `Barabari/Barabari/Domain/Repositories/ExpenseRepository.swift`
- Create: `Barabari/Barabari/Domain/Repositories/SettlementRepository.swift`
- Create: `Barabari/Barabari/Domain/Repositories/BalanceRepository.swift`
- Create: `Barabari/Barabari/Domain/UseCases/CreateGroup.swift`
- Create: `Barabari/Barabari/Domain/UseCases/CreateExpense.swift`
- Create: `Barabari/Barabari/Domain/UseCases/RecordSettlement.swift`
- Create: `Barabari/Barabari/Domain/Services/BalanceCalculator.swift`
- Create: `Barabari/BarabariTests/Domain/LedgerUseCaseTests.swift`

**Interfaces:**
- `protocol GroupRepository { func listGroups() async throws -> [Group]; func createGroup(name: String, description: String?, ownerID: UUID) async throws -> Group; func members(groupID: UUID) async throws -> [GroupMember] }`.
- `protocol ExpenseRepository { func listExpenses(groupID: UUID, cursor: String?) async throws -> Page<Expense>; func saveExpense(_ expense: Expense, idempotencyKey: UUID) async throws -> Expense; func requestExpenseDeletion(id: UUID, idempotencyKey: UUID) async throws }`.
- `protocol SettlementRepository { func listSettlements(groupID: UUID, cursor: String?) async throws -> Page<Settlement>; func saveSettlement(_ settlement: Settlement, idempotencyKey: UUID) async throws -> Settlement }`.
- `protocol BalanceRepository { func summary(groupID: UUID) async throws -> BalanceSummary }`.
- `struct Page<Item>: Equatable, Sendable { let items: [Item]; let nextCursor: String? }`.
- `struct ExpenseDraft: Sendable { let groupID: UUID; let title: String; let note: String?; let total: Money; let paidByUserID: UUID; let participantIDs: [UUID]; let splitMethod: SplitMethod; let occurredAt: Date; let createdByUserID: UUID }`.
- `struct SettlementDraft: Sendable { let groupID: UUID; let fromUserID: UUID; let toUserID: UUID; let amount: Money; let method: SettlementMethod; let note: String?; let occurredAt: Date; let createdByUserID: UUID }`.
- `enum SettlementMethod: String, Codable, Sendable { case cash, raast, bankTransfer, easypaisa, jazzcash, other }`.
- `struct CreateExpense { let repository: ExpenseRepository; func call(draft: ExpenseDraft, idempotencyKey: UUID) async throws -> Expense }`.
- `struct RecordSettlement { let repository: SettlementRepository; func call(draft: SettlementDraft, idempotencyKey: UUID) async throws -> Settlement }`.
- `struct BalanceCalculator { static func calculate(expenses: [Expense], settlements: [Settlement], members: [GroupMember]) throws -> BalanceSummary }`.

- [ ] **Step 1: Write failing tests for group, expense, balance, and settlement rules**

Use in-memory repository fakes. Test that expense participants are group members, the payer is a member, balances conserve net positions, and settlement amounts reduce the correct direction.

- [ ] **Step 2: Run the domain tests to verify failure**

Run: `xcodebuild -project Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,name=iPhone 15' test -only-testing:BarabariTests/LedgerUseCaseTests`

Expected: FAIL because the entities, protocols, and use cases are not defined.

- [ ] **Step 3: Implement entities and use cases**

Keep models Codable, Equatable where practical, and Sendable where safe. Keep authorization checks as explicit use-case inputs; repository implementations must not infer permission from a view state.

- [ ] **Step 4: Run the domain tests to verify success**

Run: `xcodebuild -project Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,name=iPhone 15' test -only-testing:BarabariTests/LedgerUseCaseTests`

Expected: PASS.

- [ ] **Step 5: Commit the ledger domain**

```bash
git add .
git commit -m "feat: add Barabari ledger domain"
```

### Task 5: Persist the domain locally with SwiftData

**Files:**
- Create: `Barabari/Barabari/Data/SwiftData/BarabariSchema.swift`
- Create: `Barabari/Barabari/Data/SwiftData/SwiftDataModels.swift`
- Create: `Barabari/Barabari/Data/SwiftData/BarabariModelContainer.swift`
- Create: `Barabari/Barabari/Data/LocalRepositories/LocalGroupRepository.swift`
- Create: `Barabari/Barabari/Data/LocalRepositories/LocalExpenseRepository.swift`
- Create: `Barabari/Barabari/Data/LocalRepositories/LocalSettlementRepository.swift`
- Create: `Barabari/Barabari/Data/LocalRepositories/LocalBalanceRepository.swift`
- Create: `Barabari/BarabariTests/Data/SwiftDataRepositoryTests.swift`

**Interfaces:**
- `enum BarabariModelContainer { static func make(inMemory: Bool) throws -> ModelContainer }`.
- `final actor LocalGroupRepository: GroupRepository`.
- `final actor LocalExpenseRepository: ExpenseRepository`.
- `final actor LocalSettlementRepository: SettlementRepository`.
- `final actor LocalBalanceRepository: BalanceRepository`.

- [ ] **Step 1: Write failing in-memory persistence tests**

Test that a group, expense, split, settlement, and activity event can be saved and fetched from an in-memory `ModelContainer`. Test that a soft-deleted expense is excluded from normal queries but remains available to sync reconciliation.

- [ ] **Step 2: Run the persistence tests to verify failure**

Run: `xcodebuild -project Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,name=iPhone 15' test -only-testing:BarabariTests/SwiftDataRepositoryTests`

Expected: FAIL because the SwiftData schema and repositories are not implemented.

- [ ] **Step 3: Implement the schema and local repositories**

Use stable UUIDs, explicit revision fields, tombstones, and a schema version. Keep conversion between SwiftData models and Domain models in the Data layer. Do not annotate Domain models with SwiftData-specific concerns.

- [ ] **Step 4: Run the persistence tests to verify success**

Run: `xcodebuild -project Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,name=iPhone 15' test -only-testing:BarabariTests/SwiftDataRepositoryTests`

Expected: PASS.

- [ ] **Step 5: Commit local persistence**

```bash
git add .
git commit -m "feat: add SwiftData local repositories"
```

### Task 6: Build the navigation shell, Home, and Groups features

**Files:**
- Create: `Barabari/Barabari/App/AppRouter.swift`
- Create: `Barabari/Barabari/Features/Root/RootView.swift`
- Create: `Barabari/Barabari/Features/Home/HomeView.swift`
- Create: `Barabari/Barabari/Features/Home/HomeViewModel.swift`
- Create: `Barabari/Barabari/Features/Groups/GroupsView.swift`
- Create: `Barabari/Barabari/Features/Groups/GroupsViewModel.swift`
- Create: `Barabari/Barabari/Features/Groups/GroupDetailView.swift`
- Create: `Barabari/Barabari/Features/Groups/GroupDetailViewModel.swift`
- Create: `Barabari/BarabariUITests/NavigationUITests.swift`

**Interfaces:**
- `@MainActor final class AppRouter: ObservableObject` exposes the selected tab and group route.
- `struct HomeSnapshot { let amountOwed: Money; let amountOwing: Money; let recentActivity: [ActivityEvent] }`.
- `enum HomeState { case loading; case loaded(HomeSnapshot); case empty; case offline(HomeSnapshot); case failed(String) }`.
- `@MainActor final class HomeViewModel: ObservableObject` exposes `homeState: HomeState`, `load()`, and `refresh()`.
- `@MainActor final class GroupsViewModel: ObservableObject` exposes `groups`, `load()`, and `createGroup(name:description:)`.

- [ ] **Step 1: Write UI tests for the navigation and empty states**

Assert that Home, Groups, Add expense, Activity, and Settings are reachable; the empty group state offers Create group and Join group; cached demo data renders without a network request.

- [ ] **Step 2: Run UI tests to verify failure**

Run: `xcodebuild -project Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,name=iPhone 15' test -only-testing:BarabariUITests/NavigationUITests`

Expected: FAIL because the navigation shell and screens are not implemented.

- [ ] **Step 3: Implement the shell and feature view models**

Use one primary action for Add expense, render summary before detail, and show loading, empty, offline, and error states. Keep view models dependent on use cases and repositories, not on SwiftData types.

- [ ] **Step 4: Run UI tests to verify success**

Run: `xcodebuild -project Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,name=iPhone 15' test -only-testing:BarabariUITests/NavigationUITests`

Expected: PASS.

- [ ] **Step 5: Commit the app shell**

```bash
git add .
git commit -m "feat: add Barabari navigation and group screens"
```

### Task 7: Implement the amount-first expense flow

**Files:**
- Create: `Barabari/Barabari/Features/Expenses/AddExpenseView.swift`
- Create: `Barabari/Barabari/Features/Expenses/AddExpenseViewModel.swift`
- Create: `Barabari/Barabari/Features/Expenses/ExpenseSplitEditorView.swift`
- Create: `Barabari/Barabari/Features/Expenses/ExpenseReviewView.swift`
- Create: `Barabari/Barabari/Features/Expenses/ExpenseDetailView.swift`
- Create: `Barabari/BarabariUITests/ExpenseFlowUITests.swift`

**Interfaces:**
- `@MainActor final class AddExpenseViewModel: ObservableObject` exposes `amountText`, `title`, `payerID`, `participantIDs`, `splitMethod`, `validationMessage`, `previewSplits`, `save() async`.
- The view model creates an `ExpenseDraft` and passes it to `CreateExpense` with a new idempotency key for each user command.

- [ ] **Step 1: Write UI tests for equal and exact expense flows**

Cover amount entry, payer selection, participant selection, split preview, invalid exact total, save success, and a local confirmation state.

- [ ] **Step 2: Run UI tests to verify failure**

Run: `xcodebuild -project Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,name=iPhone 15' test -only-testing:BarabariUITests/ExpenseFlowUITests`

Expected: FAIL because the expense flow is not implemented.

- [ ] **Step 3: Implement the amount-first flow**

Use a numeric amount input, preserve the keyboard-friendly path, show the split preview before saving, and display validation beside the field that needs correction. The save action writes locally before attempting remote sync.

- [ ] **Step 4: Run UI tests to verify success**

Run: `xcodebuild -project Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,name=iPhone 15' test -only-testing:BarabariUITests/ExpenseFlowUITests`

Expected: PASS.

- [ ] **Step 5: Commit the expense flow**

```bash
git add .
git commit -m "feat: add amount-first expense flow"
```

### Task 8: Add balances, activity, settlements, and settings

**Files:**
- Create: `Barabari/Barabari/Features/Balances/BalanceSummaryView.swift`
- Create: `Barabari/Barabari/Features/Settlements/SettlementView.swift`
- Create: `Barabari/Barabari/Features/Settlements/SettlementViewModel.swift`
- Create: `Barabari/Barabari/Features/Activity/ActivityView.swift`
- Create: `Barabari/Barabari/Features/Settings/SettingsView.swift`
- Create: `Barabari/Barabari/Features/Settings/SettingsViewModel.swift`
- Create: `Barabari/BarabariUITests/SettlementFlowUITests.swift`

**Interfaces:**
- `@MainActor final class SettlementViewModel: ObservableObject` exposes `amount`, `recipient`, `method`, `note`, `save() async`.
- `SettlementMethod` is the Domain enum with `cash`, `raast`, `bankTransfer`, `easypaisa`, `jazzcash`, and `other`.
- Activity rows render Domain `ActivityEvent` values without exposing persistence models.

- [ ] **Step 1: Write tests for debt cards and settlement confirmation**

Assert that “You owe,” “You are owed,” and “Settled” states are distinct; settlement method and amount are shown in activity; partial settlement updates the remaining amount.

- [ ] **Step 2: Run the settlement UI tests to verify failure**

Run: `xcodebuild -project Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,name=iPhone 15' test -only-testing:BarabariUITests/SettlementFlowUITests`

Expected: FAIL because the balance, settlement, and activity screens are not implemented.

- [ ] **Step 3: Implement settlement, activity, and settings views**

Use the signature settlement card, expose payment methods as recording options only, and include appearance, notifications, privacy, export, and account deletion entry points with honest availability states.

- [ ] **Step 4: Run the settlement UI tests to verify success**

Run: `xcodebuild -project Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,name=iPhone 15' test -only-testing:BarabariUITests/SettlementFlowUITests`

Expected: PASS.

- [ ] **Step 5: Commit balances and settlements**

```bash
git add .
git commit -m "feat: add balances settlements and activity"
```

### Task 9: Implement the offline outbox and local sync engine

**Files:**
- Create: `Barabari/Barabari/Domain/Models/SyncOperation.swift`
- Create: `Barabari/Barabari/Domain/Repositories/SyncRepository.swift`
- Create: `Barabari/Barabari/Data/Sync/OutboxStore.swift`
- Create: `Barabari/Barabari/Data/Sync/SyncEngine.swift`
- Create: `Barabari/Barabari/Data/Sync/RetryPolicy.swift`
- Create: `Barabari/BarabariTests/Sync/SyncEngineTests.swift`

**Interfaces:**
- `struct SyncOperation: Codable, Sendable { let id: UUID; let entityID: UUID; let entityType: String; let operation: String; let payload: Data; let idempotencyKey: UUID; let attemptCount: Int; let nextAttemptAt: Date? }`.
- `protocol SyncRepository { func push(_ operation: SyncOperation) async throws -> SyncResult; func pull(cursor: String?) async throws -> SyncPage }`.
- `struct SyncResult: Sendable { let record: SyncRecord }`.
- `struct SyncPage: Sendable { let records: [SyncRecord]; let nextCursor: String? }`.
- `struct SyncRecord: Sendable { let entityType: String; let entityID: UUID; let revision: Int; let operation: String; let payload: Data; let serverTimestamp: Date }`.
- `actor OutboxStore { func enqueue(_ operation: SyncOperation) throws; func nextBatch(limit: Int) throws -> [SyncOperation]; func markSucceeded(id: UUID) throws; func markFailed(id: UUID, errorCode: String, nextAttemptAt: Date?) throws }`.
- `actor SyncEngine { init(outbox: OutboxStore, remote: SyncRepository, now: @escaping @Sendable () -> Date); func enqueue(_ operation: SyncOperation) async; func syncNow() async }`.

- [ ] **Step 1: Write failing tests for outbox atomicity and retries**

Cover enqueue, retry ordering, bounded exponential backoff, success removal, failure retention, and repeated idempotency keys. Add a test proving a pending local operation survives a fresh engine instance.

- [ ] **Step 2: Run sync tests to verify failure**

Run: `xcodebuild -project Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,name=iPhone 15' test -only-testing:BarabariTests/SyncEngineTests`

Expected: FAIL because the outbox and sync engine are not implemented.

- [ ] **Step 3: Implement the outbox and engine**

Persist operations in SwiftData, use idempotency keys as stable command identity, retry only retryable transport/server errors, and leave actionable failures visible. Do not block view rendering on sync.

- [ ] **Step 4: Run sync tests to verify success**

Run: `xcodebuild -project Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,name=iPhone 15' test -only-testing:BarabariTests/SyncEngineTests`

Expected: PASS.

- [ ] **Step 5: Commit offline sync**

```bash
git add .
git commit -m "feat: add offline outbox and sync engine"
```

### Task 10: Add Keychain-backed session handling and authentication seams

**Files:**
- Create: `Barabari/Barabari/Domain/Repositories/SessionRepository.swift`
- Create: `Barabari/Barabari/Infrastructure/Keychain/KeychainTokenStore.swift`
- Create: `Barabari/Barabari/Infrastructure/Authentication/SessionStore.swift`
- Create: `Barabari/Barabari/Features/Authentication/AuthenticationView.swift`
- Create: `Barabari/Barabari/Features/Authentication/AuthenticationViewModel.swift`
- Create: `Barabari/BarabariTests/Infrastructure/KeychainTokenStoreTests.swift`

**Interfaces:**
- `protocol TokenStore { func read() throws -> AuthTokens?; func save(_ tokens: AuthTokens) throws; func clear() throws }`.
- `struct AuthTokens: Codable, Sendable { let accessToken: String; let refreshToken: String; let expiresAt: Date }`.
- `@MainActor final class SessionStore: ObservableObject` exposes `state`, `restore()`, `signIn() async`, and `signOut()`.
- `SessionState` is `signedOut`, `loading`, `signedIn(User)`, or `failed(message: String)`.

- [ ] **Step 1: Write failing Keychain tests**

Test save, read, replacement, and clear using an isolated Keychain access group or an injectable in-memory security client for tests.

- [ ] **Step 2: Run Keychain tests to verify failure**

Run: `xcodebuild -project Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,name=iPhone 15' test -only-testing:BarabariTests/KeychainTokenStoreTests`

Expected: FAIL because the token store is not implemented.

- [ ] **Step 3: Implement the token store and authentication seam**

Keep provider-specific Sign in with Apple or email code behind `SessionRepository`. Never persist tokens in UserDefaults or log them.

- [ ] **Step 4: Run Keychain tests to verify success**

Run: `xcodebuild -project Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,name=iPhone 15' test -only-testing:BarabariTests/KeychainTokenStoreTests`

Expected: PASS.

- [ ] **Step 5: Commit session security**

```bash
git add .
git commit -m "feat: add secure Barabari session storage"
```

### Task 11: Add accessibility, performance checks, and physical iPhone verification

**Files:**
- Create: `Barabari/BarabariUITests/AccessibilityUITests.swift`
- Create: `Barabari/BarabariUITests/OfflineReconnectUITests.swift`
- Create: `Barabari/docs/IOS-TESTING.md`
- Modify: affected feature and design-system files for accessibility or performance fixes found during testing.

**Interfaces:**
- The final app exposes stable accessibility identifiers for `homeBalance`, `addExpenseButton`, `expenseAmountField`, `saveExpenseButton`, `settlementMethodPicker`, and `markAsPaidButton`.

- [ ] **Step 1: Write accessibility and offline UI tests**

Assert that key controls have labels, the primary actions are reachable at large Dynamic Type, VoiceOver can identify amount direction, Reduce Motion does not remove required feedback, and offline expense creation remains visible after relaunch.

- [ ] **Step 2: Run UI tests to establish failures**

Run: `xcodebuild -project Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,name=iPhone 15' test -only-testing:BarabariUITests/AccessibilityUITests -only-testing:BarabariUITests/OfflineReconnectUITests`

Expected: Any missing identifier, label, or offline persistence issue is reported before device verification.

- [ ] **Step 3: Profile on a physical iPhone**

Use Xcode Instruments or the Debug navigator to measure cached Home render, cold launch, expense save latency, and scrolling with at least 500 seeded activity rows. Record results in `Barabari/docs/IOS-TESTING.md`.

- [ ] **Step 4: Run the full test suite**

Run: `xcodebuild -project Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,name=iPhone 15' test`

Expected: PASS with no ignored core tests.

- [ ] **Step 5: Install and run on the user's iPhone**

Select the signed physical device in Xcode, build and run the Debug scheme, create a group, add expenses, record a settlement, enable airplane mode, add another expense, disable airplane mode, and verify reconciliation.

- [ ] **Step 6: Commit release verification**

```bash
git add .
git commit -m "test: verify Barabari accessibility and device readiness"
```

## Plan self-review

### Spec coverage

- Product scope and non-goals are covered by Tasks 6 through 8.
- PKR integer money and split correctness are covered by Task 3.
- Groups, memberships, expenses, settlements, and activity are covered by Tasks 4, 6, 7, and 8.
- SwiftData persistence and schema isolation are covered by Task 5.
- Local-first writes, idempotency, retries, and revisions are covered by Task 9.
- Authentication and Keychain storage are covered by Task 10.
- Accessibility, performance, and physical-device acceptance are covered by Task 11.
- The no-microservices and no-payment-custody decisions remain global constraints.

### Placeholder scan

No task relies on TBD, TODO, a generic “handle edge cases” instruction, or an undefined neighbouring interface. The only future-facing work is explicitly outside V1 in the source specification.

### Type consistency

The Domain types introduced in Task 3 are consumed by Task 4, persisted by Task 5, and rendered by Tasks 6 through 8. `SyncOperation` and `SyncRepository` introduced in Task 9 are the only sync contracts consumed by the feature layer. `TokenStore` and `SessionStore` introduced in Task 10 are isolated from the Domain ledger.

### Review-focus coverage

- Rounding is tested in Task 3.
- Duplicate retries are tested in Task 9.
- Revision merge and pending commands are tested in Task 9.
- Authorization remains a backend requirement and is tested in the companion backend plan.
- Accessibility and physical-device behaviour are tested in Task 11.
