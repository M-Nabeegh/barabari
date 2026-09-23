# Barabari Premium Core UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the existing Barabari app target into the approved quiet-luxury experience with two themes, richer core flows, restrained motion, and complete state handling.

**Architecture:** Keep the modular monolith and repository boundaries. Add pure presentation models and focused reusable SwiftUI components, leaving financial domain models and persistence independent from UI. Every task follows test-first implementation and produces a runnable app.

**Tech Stack:** Swift 5 language mode in the current Xcode toolchain, SwiftUI, SwiftData, Combine, XCTest, XCUITest, native Liquid Glass on iOS 26 with the existing material fallback.

**Spec:** `docs/superpowers/specs/2026-09-23-barabari-premium-ui-design.md`

## Global Constraints

- The app remains a local ledger and never claims to transfer money.
- Store and calculate money with `Int64` minor units, never `Double`.
- Expose exactly two appearance choices: Obsidian and Pearl.
- Keep Home, Groups, Add, Activity, and Settings immediately reachable through the custom tab bar.
- Use semantic design-system colours; no feature view hard-codes theme colours.
- Use Liquid Glass only for the bottom navigation and appropriate interactive controls.
- Keep animations bounded to 120 to 240ms, except a settlement success moment capped at 700ms.
- Respect Reduce Motion, Dynamic Type, VoiceOver, increased contrast, and the 44-point minimum target.
- Add no third-party dependency.
- Preserve the existing one-tap keyboard dismissal and stable custom-tab behavior introduced by commit `e57d50f`.
- The program preflight must first commit the approved user-owned Xcode project baseline. After that gate, register each new Swift file in only its intended target and review the now task-owned `project.pbxproj` diff before staging it normally.
- Resolve one available iPhone Simulator UDID during program preflight and use it as `$BARABARI_SIMULATOR_UDID` in every command.

## Review Focus

- Legacy stored appearance values `dark`, `light`, `system`, empty, and unknown must migrate without a launch failure or invisible UI.
- Very large PKR amounts, long group names, long notes, and AX-XXXL text must wrap without hiding the primary action.
- The Add Expense sticky action must remain visible and hittable above the decimal keyboard and custom tab bar, and a single tap must create one expense.
- Activity day grouping must be timezone-stable, and a later-page failure must retain already loaded rows with a retry action.
- Reduce Motion must remove tab bounce, card scale, entrance movement, and settlement sparkles while leaving every final state visible.

---

## File structure

### Create

- `Barabari/Barabari/DesignSystem/BarabariMotion.swift`: shared animation decisions.
- `Barabari/Barabari/DesignSystem/Components/BarabariSkeleton.swift`: lightweight loading placeholders.
- `Barabari/Barabari/DesignSystem/Components/GroupIdentityBadge.swift`: deterministic monogram identity.
- `Barabari/Barabari/DesignSystem/Components/StickyActionBar.swift`: keyboard-safe primary action container.
- `Barabari/Barabari/DesignSystem/Components/SettlementSuccessMoment.swift`: bounded confirmation animation.
- `Barabari/Barabari/Features/Home/HomeHeroPresentation.swift`: pure contextual hero presentation.
- `Barabari/Barabari/Features/Groups/GroupCardPresentation.swift`: pure group-card presentation.
- `Barabari/Barabari/Features/Expenses/ExpenseDetailViewModel.swift`: receipt data join and state.
- `Barabari/Barabari/Features/Activity/ActivityDaySection.swift`: timezone-aware grouping.
- `Barabari/BarabariTests/Features/HomeHeroPresentationTests.swift`
- `Barabari/BarabariTests/Features/GroupCardPresentationTests.swift`
- `Barabari/BarabariTests/Features/ExpenseDetailViewModelTests.swift`
- `Barabari/BarabariTests/Features/ActivityDaySectionTests.swift`

### Modify

- `Barabari/Barabari/DesignSystem/BarabariColors.swift`
- `Barabari/Barabari/DesignSystem/Components/BarabariCard.swift`
- `Barabari/Barabari/DesignSystem/Components/BarabariTabBar.swift`
- `Barabari/Barabari/DesignSystem/Components/PrimaryActionButton.swift`
- `Barabari/Barabari/Features/Settings/SettingsViewModel.swift`
- `Barabari/Barabari/Features/Settings/SettingsView.swift`
- `Barabari/Barabari/Features/Root/RootView.swift`
- `Barabari/Barabari/Features/Home/HomeViewModel.swift`
- `Barabari/Barabari/Features/Home/HomeView.swift`
- `Barabari/Barabari/Features/Groups/GroupsViewModel.swift`
- `Barabari/Barabari/Features/Groups/GroupsView.swift`
- `Barabari/Barabari/Features/Expenses/AddExpenseViewModel.swift`
- `Barabari/Barabari/Features/Expenses/AddExpenseView.swift`
- `Barabari/Barabari/Features/Expenses/ExpenseDetailView.swift`
- `Barabari/Barabari/Features/Activity/ActivityViewModel.swift`
- `Barabari/Barabari/Features/Activity/ActivityView.swift`
- `Barabari/Barabari/Features/Settlements/SettlementViewModel.swift`
- `Barabari/Barabari/Features/Settlements/SettlementView.swift`
- `Barabari/Barabari/App/BarabariApp.swift`
- `Barabari/BarabariTests/DesignSystemTests.swift`
- `Barabari/BarabariTests/Features/ActivityViewModelTests.swift`
- `Barabari/BarabariTests/Features/AddExpenseViewModelTests.swift`
- `Barabari/BarabariTests/Features/SettlementViewModelTests.swift`
- `Barabari/BarabariUITests/NavigationUITests.swift`
- `Barabari/BarabariUITests/ExpenseFlowUITests.swift`
- `Barabari/BarabariUITests/SettlementFlowUITests.swift`
- `Barabari/Barabari.xcodeproj/project.pbxproj` only for explicit registration of files created by the active task.

---

### Task 1: Obsidian and Pearl theme contract

**Files:**
- Modify: `Barabari/Barabari/Features/Settings/SettingsViewModel.swift`
- Modify: `Barabari/Barabari/Features/Settings/SettingsView.swift`
- Modify: `Barabari/Barabari/Features/Root/RootView.swift`
- Modify: `Barabari/Barabari/DesignSystem/BarabariColors.swift`
- Modify: `Barabari/BarabariTests/DesignSystemTests.swift`
- Modify: `Barabari/BarabariUITests/NavigationUITests.swift`

**Interfaces:**
- Produces: `BarabariAppearance.init(storedValue: String)`, `.obsidian`, `.pearl`, `title`, and `colorScheme`.
- Produces: `BarabariColors` semantic tokens resolving correctly under the selected scheme.

- [ ] **Step 1: Write failing appearance migration and token tests**

```swift
func testNamedAppearancesMigrateLegacyStoredValues() {
    XCTAssertEqual(BarabariAppearance(storedValue: "dark"), .obsidian)
    XCTAssertEqual(BarabariAppearance(storedValue: "light"), .pearl)
    XCTAssertEqual(BarabariAppearance(storedValue: "system"), .obsidian)
    XCTAssertEqual(BarabariAppearance(storedValue: "unknown"), .obsidian)
    XCTAssertEqual(BarabariAppearance.allCases, [.obsidian, .pearl])
}

func testNamedAppearancesResolveExpectedColorSchemes() {
    XCTAssertEqual(BarabariAppearance.obsidian.colorScheme, .dark)
    XCTAssertEqual(BarabariAppearance.pearl.colorScheme, .light)
}
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```sh
xcodebuild -project Barabari/Barabari.xcodeproj -scheme Barabari \
  -destination "platform=iOS Simulator,id=$BARABARI_SIMULATOR_UDID" \
  -only-testing:BarabariTests/DesignSystemTests test
```

Expected: compilation fails because `.obsidian`, `.pearl`, and `init(storedValue:)` do not exist.

- [ ] **Step 3: Implement the named appearance migration**

```swift
enum BarabariAppearance: String, CaseIterable, Identifiable {
    case obsidian
    case pearl

    init(storedValue: String) {
        switch storedValue {
        case "pearl", "light": self = .pearl
        case "obsidian", "dark", "system": self = .obsidian
        default: self = .obsidian
        }
    }

    var id: Self { self }
    var title: String { self == .obsidian ? "Obsidian" : "Pearl" }
    var colorScheme: ColorScheme { self == .obsidian ? .dark : .light }
}
```

Make `RootView` read the stored string through `init(storedValue:)`. Make `SettingsViewModel` write only the new raw values. Define Pearl with a warm off-white background and ink foreground while preserving the existing Obsidian values.

- [ ] **Step 4: Add a failing UI test for theme persistence**

```swift
func testPearlThemePersistsAfterRelaunch() {
    let app = makeApp(arguments: ["-uiTestingDemoState", "-uiTestingResetDefaults"])
    app.launch()
    app.buttons["Settings"].tap()
    app.buttons["appearance-picker"].tap()
    app.buttons["Pearl"].tap()
    XCTAssertEqual(app.buttons["appearance-picker"].value as? String, "Pearl")
    app.terminate()
    app.launchArguments = ["-uiTestingDemoState"]
    app.launch()
    app.buttons["Settings"].tap()
    XCTAssertEqual(app.buttons["appearance-picker"].value as? String, "Pearl")
}
```

Add deterministic reset handling in `BarabariApp` for `-uiTestingResetDefaults` before `RootView` is created.

- [ ] **Step 5: Run focused tests and commit**

Run the DesignSystem and Navigation suites. Expected: all selected tests pass.

```sh
git add Barabari/Barabari/DesignSystem Barabari/Barabari/Features/Settings \
  Barabari/Barabari/Features/Root Barabari/Barabari/App/BarabariApp.swift \
  Barabari/BarabariTests/DesignSystemTests.swift Barabari/BarabariUITests/NavigationUITests.swift
git commit -m "feat: add Obsidian and Pearl themes"
```

---

### Task 2: Shared premium motion and state components

**Files:**
- Create: `Barabari/Barabari/DesignSystem/BarabariMotion.swift`
- Create: `Barabari/Barabari/DesignSystem/Components/BarabariSkeleton.swift`
- Create: `Barabari/Barabari/DesignSystem/Components/GroupIdentityBadge.swift`
- Create: `Barabari/Barabari/DesignSystem/Components/StickyActionBar.swift`
- Create: `Barabari/Barabari/DesignSystem/Components/SettlementSuccessMoment.swift`
- Modify: `Barabari/Barabari/DesignSystem/Components/BarabariCard.swift`
- Modify: `Barabari/Barabari/DesignSystem/Components/BarabariTabBar.swift`
- Modify: `Barabari/Barabari/DesignSystem/Components/PrimaryActionButton.swift`
- Modify: `Barabari/BarabariTests/DesignSystemTests.swift`
- Modify: `Barabari/Barabari.xcodeproj/project.pbxproj` only to register the five new source files.

**Interfaces:**
- Produces: `BarabariMotion.animation(_:, reduceMotion:) -> Animation?`.
- Produces: pure `GroupIdentity.make(name:)` plus `GroupIdentityBadge(name:size:)` with deterministic initials and palette index.
- Produces: `StickyActionBar` wrapping a caller-owned action.
- Produces: `SettlementSuccessMoment(isGroupSettled:)`.
- Produces: a test-only motion override at the root environment boundary while production continues to use SwiftUI's `accessibilityReduceMotion` value.

- [ ] **Step 1: Write failing pure tests for initials, palette, and motion policy**

```swift
func testGroupIdentityUsesStableInitialsAndPalette() {
    XCTAssertEqual(GroupIdentity.make(name: "Weekend Lahore").initials, "WL")
    XCTAssertEqual(GroupIdentity.make(name: "  Home  ").initials, "H")
    XCTAssertEqual(
        GroupIdentity.make(name: "Weekend Lahore").paletteIndex,
        GroupIdentity.make(name: "Weekend Lahore").paletteIndex
    )
}

func testReduceMotionRemovesMovementAnimation() {
    XCTAssertNil(BarabariMotion.animation(.stateChange, reduceMotion: true))
    XCTAssertNotNil(BarabariMotion.animation(.stateChange, reduceMotion: false))
}
```

- [ ] **Step 2: Run focused tests and verify RED**

Expected: missing symbols.

- [ ] **Step 3: Implement focused components**

Use a stable UTF-8 hash for `paletteIndex`, not Swift's randomised `hashValue`. `BarabariSkeleton` uses a static raised surface with a short opacity transition, not a continuous shimmer. `StickyActionBar` uses `safeAreaInset(edge: .bottom)` and never owns keyboard state. `SettlementSuccessMoment` uses a checkmark and at most four bounded mint sparkles.

- [ ] **Step 4: Apply Reduce Motion to existing interactive components**

Replace unconditional `.snappy` and press-scale animations in the tab bar, card style, and primary action with `BarabariMotion`. Keep selection immediate and animate only the selected visual.

- [ ] **Step 5: Run DesignSystem tests, build, and commit**

```sh
git add Barabari/Barabari/DesignSystem Barabari/BarabariTests/DesignSystemTests.swift
git add Barabari/Barabari.xcodeproj/project.pbxproj
git commit -m "feat: add premium motion and shared UI components"
```

Before committing, confirm the project-file patch contains only references and Sources build-phase entries for this task's five new files. The user-owned baseline must already be committed by program preflight.

---

### Task 3: Contextual Home hero and premium group cards

**Files:**
- Create: `Barabari/Barabari/Features/Home/HomeHeroPresentation.swift`
- Create: `Barabari/Barabari/Features/Groups/GroupCardPresentation.swift`
- Create: `Barabari/BarabariTests/Features/HomeHeroPresentationTests.swift`
- Create: `Barabari/BarabariTests/Features/GroupCardPresentationTests.swift`
- Modify: `Barabari/Barabari/Features/Home/HomeViewModel.swift`
- Modify: `Barabari/Barabari/Features/Home/HomeView.swift`
- Modify: `Barabari/Barabari/Features/Groups/GroupsViewModel.swift`
- Modify: `Barabari/Barabari/Features/Groups/GroupsView.swift`
- Modify: `Barabari/Barabari/App/AppRouter.swift`
- Modify: `Barabari/Barabari/Features/Root/RootView.swift`
- Modify: `Barabari/Barabari.xcodeproj/project.pbxproj` only to register the four new source and test files.

**Interfaces:**
- Produces: `RelevantDebt { groupID, transfer }`, `HomeSnapshot.relevantDebt: RelevantDebt?`, and `HomeHeroPresentation.make(netMinorUnits:relevantDebt:currentUserID:counterpartyName:)`.
- Produces: `GroupCardPresentation: Identifiable` containing group, member count, last activity date, and current-user amount.
- Produces: explicit router intents for `.settle(groupID:)`, `.openGroup(groupID:)`, and `.addExpense`.

- [ ] **Step 1: Write failing Home presentation tests**

Test the settled, outgoing, incoming, and multi-transfer deterministic cases with literal PKR values. The action must be `.settle(groupID:)`, `.openGroup(groupID:)`, or `.addExpense`.

```swift
func testOutgoingTransferProducesSettleCopyAndAction() {
    let presentation = HomeHeroPresentation.make(
        netMinorUnits: -100_000,
        relevantDebt: RelevantDebt(groupID: groupID, transfer: fixtureOutgoingTransfer),
        currentUserID: currentUserID,
        counterpartyName: "Member 2"
    )
    XCTAssertEqual(presentation.summary, "You owe Member 2 PKR 1,000")
    XCTAssertEqual(presentation.action, .settle(groupID: groupID))
}
```

- [ ] **Step 2: Run Home tests and verify RED**

- [ ] **Step 3: Extend HomeViewModel with bounded transfer context**

While already loading each group balance, select the largest absolute transfer involving the current user. Resolve only the selected counterparty through existing demo naming rules. Do not fetch or sort inside `HomeView.body`.

- [ ] **Step 4: Write failing group-card presentation tests**

Cover long names, no activity, settled, owed, and owing states. Assert stable monograms and literal accessibility summaries.

- [ ] **Step 5: Build group presentations in GroupsViewModel**

For each loaded group, fetch members, balance summary, and recent group activity outside the view. Publish `[GroupCardPresentation]` once all bounded local work completes. Preserve the existing `groups` array until all call sites migrate.

- [ ] **Step 6: Replace the Home and Groups layouts**

Use `ContextualBalanceHero`, `GroupIdentityBadge`, skeletons, and the existing `BarabariCard`. Route each hero action explicitly through `AppRouter` and `RootView`. Add stable accessibility identifiers for hero action and group summaries. Preserve Create and Join behavior.

- [ ] **Step 7: Run focused unit and navigation tests, then commit**

```sh
git add Barabari/Barabari/Features/Home Barabari/Barabari/Features/Groups \
  Barabari/Barabari/App/AppRouter.swift Barabari/Barabari/Features/Root/RootView.swift \
  Barabari/BarabariTests/Features/HomeHeroPresentationTests.swift \
  Barabari/BarabariTests/Features/GroupCardPresentationTests.swift
git add Barabari/Barabari.xcodeproj/project.pbxproj
git commit -m "feat: add contextual home and premium group cards"
```

---

### Task 4: Fast Add Expense flow with sticky action

**Files:**
- Modify: `Barabari/Barabari/Features/Expenses/AddExpenseViewModel.swift`
- Modify: `Barabari/Barabari/Features/Expenses/AddExpenseView.swift`
- Modify: `Barabari/Barabari/Features/Expenses/ExpenseSplitEditorView.swift`
- Modify: `Barabari/BarabariTests/Features/AddExpenseViewModelTests.swift`
- Modify: `Barabari/BarabariUITests/ExpenseFlowUITests.swift`

**Interfaces:**
- Produces: `AddExpenseViewModel.applyQuickAmount(_ minorUnits: Int64)`.
- Produces: session-scoped `lastSelectedGroupID` and `lastSelectedPayerID` defaults without changing persisted ledger data.
- Consumes: `StickyActionBar` from Task 2.

- [ ] **Step 1: Write failing view-model tests for quick amounts and session defaults**

```swift
func testQuickAmountUsesExactPKRMinorUnits() async {
    let viewModel = makeViewModel()
    viewModel.applyQuickAmount(100_000)
    XCTAssertEqual(viewModel.amountText, "1000")
}
```

Also verify that an unavailable previous group or payer is ignored safely.

- [ ] **Step 2: Run focused AddExpense tests and verify RED**

- [ ] **Step 3: Implement quick amounts and bounded session defaults**

Keep defaults in `AddExpenseViewModel` or a small app-session preference object injected from `RootView`. Do not write group or payer selections to the domain store.

- [ ] **Step 4: Write a failing UI regression for one-tap sticky save**

The test enters amount and title, keeps the decimal keyboard visible, asserts `save-expense-sticky` is hittable, taps once, and verifies exactly one saved confirmation. Remove existing duplicate-tap retries.

- [ ] **Step 5: Refactor AddExpenseView**

Move Save into `StickyActionBar`. Show quick chips only when amount is empty. Keep equal split compact; reveal exact controls only after selecting Exact. Put validation near the sticky action. Preserve ScrollViewReader focus scrolling and one-tap tab dismissal.

- [ ] **Step 6: Run AddExpense unit/UI tests and commit**

```sh
git add Barabari/Barabari/Features/Expenses/AddExpenseView.swift \
  Barabari/Barabari/Features/Expenses/AddExpenseViewModel.swift \
  Barabari/Barabari/Features/Expenses/ExpenseSplitEditorView.swift \
  Barabari/BarabariTests/Features/AddExpenseViewModelTests.swift \
  Barabari/BarabariUITests/ExpenseFlowUITests.swift
git commit -m "feat: streamline premium expense entry"
```

---

### Task 5: Digital receipt expense detail

**Files:**
- Create: `Barabari/Barabari/Features/Expenses/ExpenseDetailViewModel.swift`
- Create: `Barabari/BarabariTests/Features/ExpenseDetailViewModelTests.swift`
- Modify: `Barabari/Barabari/Features/Expenses/ExpenseDetailView.swift`
- Modify: `Barabari/Barabari/Features/Expenses/AddExpenseViewModel.swift`
- Modify: `Barabari/Barabari/App/AppRouter.swift`
- Modify: `Barabari/Barabari/Features/Activity/ActivityView.swift`
- Modify: `Barabari/BarabariTests/Features/AddExpenseViewModelTests.swift`
- Modify: `Barabari/BarabariUITests/NavigationUITests.swift`
- Modify: `Barabari/Barabari.xcodeproj/project.pbxproj` only to register the new view-model and test files.

**Interfaces:**
- Produces: `ExpenseReceiptPresentation` with title, amount, date, group name, payer name, participant shares, split method, note, and share text.
- Produces: `ExpenseDetailView.init(environment:expense:)`.
- Produces: an explicit `.duplicateExpense(ExpenseDraft)` route that prefills Add Expense without writing until the user confirms.

- [ ] **Step 1: Write failing receipt-presentation tests**

Use a fixture with two members, an exact split, and a note. Assert literal payer/participant names, PKR share values, date input, and share text that says “recorded” rather than “paid” or “transferred.”

- [ ] **Step 2: Run the test and verify RED**

- [ ] **Step 3: Implement ExpenseDetailViewModel**

Load groups once, select `expense.groupID`, load members once, and map demo names deterministically. Publish loading, loaded, and failed states. Build share text from the loaded presentation. No repository access occurs in `body`.

- [ ] **Step 4: Add the tested duplicate draft route**

Create an `ExpenseDraft` from the receipt's group, title, note, amount, payer, splits, and split method. Add a failing router or view-model test proving Duplicate opens Add Expense with those fields prefilled while keeping a new identifier and performing no repository write. Implement the smallest route and initializer required to make the test pass.

- [ ] **Step 5: Build the digital receipt UI**

Use amount, metadata, payer, participant rows, split method, note, local-only badge, Duplicate action, and ShareLink. Duplicate passes an `ExpenseDraft` through the router and never writes directly from the detail view. Edit and soft-delete remain out of this pass because the current repositories do not expose safe interfaces for them.

- [ ] **Step 6: Update Activity route construction and add UI coverage**

Pass `AppEnvironment` into `ExpenseDetailView`. Assert the seeded receipt shows group, payer, two participant shares, date, and local-only copy. Tap Duplicate and assert the Add Expense form is prefilled without an additional Activity row until Save is tapped.

- [ ] **Step 7: Run receipt tests and commit**

```sh
git add Barabari/Barabari/Features/Expenses/ExpenseDetailView* \
  Barabari/Barabari/Features/Expenses/AddExpenseViewModel.swift \
  Barabari/Barabari/App/AppRouter.swift \
  Barabari/Barabari/Features/Activity/ActivityView.swift \
  Barabari/BarabariTests/Features/AddExpenseViewModelTests.swift \
  Barabari/BarabariTests/Features/ExpenseDetailViewModelTests.swift \
  Barabari/BarabariUITests/NavigationUITests.swift
git add Barabari/Barabari.xcodeproj/project.pbxproj
git commit -m "feat: add digital expense receipts"
```

---

### Task 6: Day-grouped Activity with resilient pagination

**Files:**
- Create: `Barabari/Barabari/Features/Activity/ActivityDaySection.swift`
- Create: `Barabari/Barabari/Features/Activity/ActivityPageLoading.swift`
- Create: `Barabari/BarabariTests/Features/ActivityDaySectionTests.swift`
- Modify: `Barabari/Barabari/Features/Activity/ActivityViewModel.swift`
- Modify: `Barabari/Barabari/Features/Activity/ActivityView.swift`
- Modify: `Barabari/BarabariTests/Features/ActivityViewModelTests.swift`
- Modify: `Barabari/BarabariUITests/NavigationUITests.swift`
- Modify: `Barabari/Barabari.xcodeproj/project.pbxproj` only to register the new loader, day-section, and test files.

**Interfaces:**
- Produces: `ActivityDaySection.make(rows:now:calendar:) -> [ActivityDaySection]`.
- Produces: `ActivityViewModel.nextPageError: String?` and `retryNextPage()`.
- Produces: injected `ActivityPageLoading`, `now: () -> Date`, and `Calendar` dependencies so failure and day-boundary tests are deterministic.

- [ ] **Step 1: Write failing timezone-aware grouping tests**

Use a Gregorian calendar with `Asia/Karachi`, a fixed noon reference date, and rows just before/after local midnight. Assert Today, Yesterday, then formatted older sections in descending order.

- [ ] **Step 2: Write failing state tests for initial and later-page failures**

Initial failure must remain `.failed`. A later-page failure must keep `.loaded`, retain existing rows, and set `nextPageError`.

- [ ] **Step 3: Run Activity tests and verify RED**

- [ ] **Step 4: Correct the Activity state machine**

Remove the unreachable outer `do/catch`. Inject a page loader backed by `AppEnvironment.activityPage` in production and scripted by tests. Make `appendNextPage` throw or return a typed result so `load()` cannot overwrite `.failed` with `.empty`. Add request generation so stale refresh results cannot replace a newer load. Keep already-loaded rows during pagination failure. Build sections from the injected clock and calendar, never from `Date()` inside the view.

- [ ] **Step 5: Build day sections and retry footer UI**

Render section headings and timeline decoration through a `LazyVStack`. Hide connecting lines from accessibility. Use time beneath rows, and show a compact `Try again` footer when `nextPageError` is present.

- [ ] **Step 6: Run Activity tests and commit**

```sh
git add Barabari/Barabari/Features/Activity \
  Barabari/BarabariTests/Features/ActivityDaySectionTests.swift \
  Barabari/BarabariTests/Features/ActivityViewModelTests.swift \
  Barabari/BarabariUITests/NavigationUITests.swift
git add Barabari/Barabari.xcodeproj/project.pbxproj
git commit -m "feat: group and harden activity timeline"
```

---

### Task 7: Settlement completion experience

**Files:**
- Modify: `Barabari/Barabari/Features/Settlements/SettlementViewModel.swift`
- Modify: `Barabari/Barabari/Features/Settlements/SettlementView.swift`
- Modify: `Barabari/BarabariTests/Features/SettlementViewModelTests.swift`
- Modify: `Barabari/BarabariUITests/SettlementFlowUITests.swift`

**Interfaces:**
- Produces: `SettlementSaveOutcome { let settlement: Settlement; let isGroupSettled: Bool }`.
- Consumes: `SettlementSuccessMoment` from Task 2.

- [ ] **Step 1: Write failing full-settlement outcome tests**

Record the remaining debt, then assert the refreshed balance summary contains only zero positions and `isGroupSettled == true`. Keep the existing partial and overpayment tests.

- [ ] **Step 2: Run SettlementViewModel tests and verify RED**

- [ ] **Step 3: Implement the post-save balance check**

After `RecordSettlement` succeeds, ask `balanceRepository.summary(groupID:)` for the authoritative local result. Set `isGroupSettled` when every position is zero. Fire one success haptic in the view after receiving the outcome, never from the repository.

- [ ] **Step 4: Build the bounded success state**

Show “Settlement recorded” for partial outcomes and “All settled” for zeroed groups. Render `SettlementSuccessMoment` for at most 700ms. With Reduce Motion, show only the final static checkmark. Keep copy explicit that this is a local ledger record.

- [ ] **Step 5: Remove flaky duplicate-tap test logic and add full-settlement UI coverage**

Wait for `mark-settlement-paid` to become enabled, tap once, and assert one Activity settlement row. Add a Reduce Motion launch configuration and assert the final state exists without waiting for animation completion.

- [ ] **Step 6: Run Settlement tests and commit**

```sh
git add Barabari/Barabari/Features/Settlements \
  Barabari/BarabariTests/Features/SettlementViewModelTests.swift \
  Barabari/BarabariUITests/SettlementFlowUITests.swift
git commit -m "feat: add premium settlement confirmation"
```

---

### Task 8: Deterministic UX fixtures, accessibility, and full verification

**Files:**
- Modify: `Barabari/Barabari/App/BarabariApp.swift`
- Modify: `Barabari/BarabariUITests/NavigationUITests.swift`
- Modify: `Barabari/BarabariUITests/ExpenseFlowUITests.swift`
- Modify: `Barabari/BarabariUITests/SettlementFlowUITests.swift`
- Modify: relevant views only when an accessibility defect is demonstrated by a failing test.

**Interfaces:**
- Produces deterministic launch parsing for appearance reset, fixed clock, Reduce Motion fixtures, complete receipt, and controlled Activity days/failures.

- [ ] **Step 1: Add failing accessibility and large-text UI tests**

Add tests that launch AX-XXXL content size, verify the sticky action, receipt participant rows, and five tab buttons remain present and hittable. Assert selected tab traits, combined receipt labels, and named appearance values.

- [ ] **Step 2: Add failing Reduce Motion UI tests**

Use a deterministic launch override consumed through the same abstraction as `accessibilityReduceMotion`. Assert navigation, settlement final state, and card content remain visible without movement-dependent waits.

- [ ] **Step 3: Implement deterministic test configuration**

Parse documented launch arguments in `BarabariApp` into a `UITestConfiguration`. Inject only time, calendar/timezone, fixture state, appearance reset, and a test motion override. Production components continue to derive motion from SwiftUI's `accessibilityReduceMotion` environment when the override is nil. Production behavior remains unchanged when no UI-test argument is present.

- [ ] **Step 4: Fix demonstrated accessibility defects**

Replace fixed horizontal share layouts with adaptive vertical layouts at accessibility sizes. Make the Privacy sheet scrollable and allow a large detent. Ensure timeline decoration is accessibility-hidden and semantic status includes text and symbols.

- [ ] **Step 5: Complete the primary-screen state matrix**

For Home, Groups, Add Expense, Expense Detail, Activity, Settlement, and Settings, verify the applicable loading, empty, error, offline or local-only, and success states from the specification. Add deterministic fixtures and failing UI tests for any state that is not already covered. Reuse the shared skeleton and state components, keep one recovery action, and do not introduce spinner-only full screens where useful structure can render.

- [ ] **Step 6: Verify bounded haptics and entrance motion**

Confirm the Haptics setting gates selection feedback for split method, group, payer, and settlement method, plus success feedback after confirmed expense and settlement writes. Limit entrance animation to the initial visible Home and Activity items, prevent replay after refresh, and remove movement under Reduce Motion.

- [ ] **Step 7: Run the complete suite**

```sh
xcodebuild -project Barabari/Barabari.xcodeproj -scheme Barabari \
  -destination "platform=iOS Simulator,id=$BARABARI_SIMULATOR_UDID" test
```

Expected: every discovered test passes with zero failures. Record simulator-only keyboard warnings separately and do not mislabel them as app errors.

- [ ] **Step 8: Build and run the final core UI app**

Use XcodeBuildMCP with the configured Barabari project, scheme, and iPhone 17 Pro simulator. Launch with seeded second-member and debt fixtures. Verify Home, Groups, Add, receipt, Activity, Settlement, Settings, Obsidian, and Pearl visually.

- [ ] **Step 9: Run code-first performance review**

Confirm no collection sorting/filtering, QR rendering, formatter creation, or persistence fetch occurs inside frequently evaluated `body` paths. Stress keyboard-to-tab transitions and rapid tab switching. Capture a focused trace only if the fixed build still shows observable jank.

- [ ] **Step 10: Commit final core verification adjustments**

```sh
git add Barabari/Barabari Barabari/BarabariTests Barabari/BarabariUITests
git commit -m "test: verify premium Barabari experience"
```

Inspect `git diff -- Barabari/Barabari.xcodeproj/project.pbxproj` before the commit. The preflight baseline means any remaining project-file diff must be task-owned; do not stage unrelated changes.
