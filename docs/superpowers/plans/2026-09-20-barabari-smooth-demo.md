# Barabari Smooth Demo Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the existing local Barabari demo into a smooth, touch-reliable, native-feeling iPhone experience without expanding V1 into backend or payment work.

**Architecture:** Keep the current SwiftUI, SwiftData, repository, and use-case boundaries. Replace the custom root overlay with a persistent native `TabView(selection:)`, add one narrow `LedgerSession` revision signal for local writes, move activity and formatter work behind focused view-model/value-type boundaries, and keep Liquid Glass limited to the system tab bar and small high-value actions.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, iOS 17 minimum, iOS 26 Liquid Glass APIs behind availability checks, XCTest/XCUITest, Xcode build settings, asset catalog PNG fallback.

**Spec:** `docs/superpowers/specs/2026-09-20-barabari-smooth-demo-design.md`

## Global constraints

- Work from `/Users/nabeegh/Documents/claude/Barabari/.worktrees/barabari-v1`.
- Preserve the existing dirty Xcode project rewrite and workspace metadata until their ownership and required content are verified. Stage only intentional files per commit.
- Do not add backend, authentication, network sync, push notifications, payment initiation, wallet behavior, or account deletion in this pass.
- Keep monetary values as `Int64` minor units. Do not introduce `Double` for ledger arithmetic.
- Keep leaf views independent of concrete persistence implementations. New refresh or export seams must use small protocols, callbacks, or value models.
- Use `apply_patch` for source edits. Do not use destructive Git commands.
- Every visible button or row action must have a minimum 44 by 44 point hit area, a complete-row `contentShape` where applicable, and a deterministic disabled/saving state.
- Keep user-facing copy truthful about local-only demo behavior.

## Review focus

- Native navigation must own safe-area and keyboard behavior.
- Tab switching must not recreate feature view models or erase an unfinished Add Expense draft.
- A successful local write must refresh Home, Groups, Group Detail, and Activity without relaunching.
- Activity must be incrementally rendered and navigable to detail.
- Settings must expose only working local actions.
- The app icon must be configured without committing a personal signing team to shared product configuration.
- Verify light/dark mode, Dynamic Type, VoiceOver labels, Reduce Motion, keyboard use, and bottom safe-area behavior where the available simulator/device permits.

---

## Task 1: Add explicit session refresh state and persistent native navigation

**Files:**

- Create `Barabari/Barabari/App/LedgerSession.swift`.
- Modify `Barabari/Barabari/Features/Root/RootView.swift`.
- Modify `Barabari/Barabari/App/AppRouter.swift` only if stable per-tab route state is required.
- Modify `Barabari/Barabari/Features/Home/HomeView.swift` and `HomeViewModel.swift` for explicit revision refresh.
- Modify `Barabari/Barabari/Features/Groups/GroupsView.swift` and `GroupsViewModel.swift` for explicit revision refresh.
- Modify `Barabari/Barabari/Features/Groups/GroupDetailView.swift` and `GroupDetailViewModel.swift` for explicit revision refresh.
- Modify `Barabari/Barabari/Features/Expenses/AddExpenseView.swift` to receive and retain one `AddExpenseViewModel` from the root and to call `LedgerSession.markChanged()` after a successful save.
- Modify `Barabari/Barabari/Features/Activity/ActivityView.swift` and `Barabari/Barabari/Features/Settings/SettingsView.swift` to sit inside their own persistent `NavigationStack` tab roots.
- Modify target membership only if the new file is not picked up automatically by the project.
- Create `Barabari/BarabariTests/App/LedgerSessionTests.swift`.

**Steps:**

- [ ] Add the `@MainActor` `LedgerSession` observable object with a private-set `revision` and wrapping `markChanged()` increment.
- [ ] Give `RootView` state objects for `AppRouter`, `LedgerSession`, `HomeViewModel`, `GroupsViewModel`, and one `AddExpenseViewModel` created in `init(environment:)`.
- [ ] Replace the `ZStack` custom tab overlay and hard-coded bottom padding with `TabView(selection: $router.selectedTab)`.
- [ ] Put each feature in its own `NavigationStack`; keep the Groups path local to the Groups tab so switching tabs does not mutate unrelated navigation state.
- [ ] Use `.tabItem` with the existing `AppTab.title` and `AppTab.systemImage`, and use the Add tab as a normal selection rather than a button overlay.
- [ ] Pass `session.revision` into the relevant view-model tasks using `.task(id:)` or a named refresh method so a local write updates derived screens.
- [ ] Make Add Expense save call the session only after `CreateExpense` returns successfully. Keep its draft and saved confirmation alive when the user changes tabs.
- [ ] Keep `BarabariTabBar.swift` out of the root path. Leave the component available only if a later focused use needs it, with no primary navigation dependency.
- [ ] Add unit coverage for revision monotonicity and the no-reset behavior of the root-owned Add Expense model.

**Verification:**

```bash
xcodebuild -project Barabari/Barabari.xcodeproj -scheme Barabari -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Barabari/Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,id=3A10C54D-4D4B-4BEC-B196-68EE205462B0' test -only-testing:BarabariTests/App/LedgerSessionTests
```

**Commit:** `refactor: use persistent native tab navigation`

## Task 2: Make touch targets and feedback reliable

**Files:**

- Create `Barabari/Barabari/DesignSystem/BarabariInteraction.swift`.
- Modify `Barabari/Barabari/DesignSystem/Components/PrimaryActionButton.swift`.
- Modify `Barabari/Barabari/Features/Groups/GroupsView.swift`.
- Modify `Barabari/Barabari/Features/Balances/BalanceSummaryView.swift`.
- Modify `Barabari/Barabari/Features/Expenses/ExpenseSplitEditorView.swift` and `AddExpenseView.swift`.
- Modify `Barabari/Barabari/Features/Settlements/SettlementView.swift`.
- Modify any shared row component that is reused by these views.
- Modify `Barabari/BarabariUITests/NavigationUITests.swift`, `ExpenseFlowUITests.swift`, and `SettlementFlowUITests.swift`.

**Steps:**

- [ ] Define a single minimum hit-size constant and a small feedback helper that respects a user haptics preference and Reduce Motion.
- [ ] Increase the Groups create action to at least 44 by 44 points and give the full visible row a rectangular content shape.
- [ ] Give settlement rows, split-mode controls, participant rows, payer controls, Save, Retry, and confirmation actions a minimum 44-point vertical target.
- [ ] Use `.buttonStyle(.plain)` only when the complete row still has a clear pressed state, accessibility label, and hit shape.
- [ ] Prevent duplicate taps while async Save or settlement writes are in progress and show a local progress state inside the action.
- [ ] Add success/error haptics only after the write result is known. Do not fire haptics from `body` or every render.
- [ ] Add UI checks that switch tabs repeatedly, tap bottom-area controls, tap Save twice quickly, and verify one resulting expense/settlement.

**Verification:**

```bash
xcodebuild -project Barabari/Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,id=3A10C54D-4D4B-4BEC-B196-68EE205462B0' test -only-testing:BarabariUITests/NavigationUITests -only-testing:BarabariUITests/ExpenseFlowUITests -only-testing:BarabariUITests/SettlementFlowUITests
```

**Commit:** `fix: harden Barabari touch targets and feedback`

## Task 3: Remove avoidable rendering work and make activity incremental

**Files:**

- Modify `Barabari/Barabari/DesignSystem/Components/AmountText.swift`.
- Modify `Barabari/Barabari/Features/Expenses/AddExpenseViewModel.swift`.
- Create `Barabari/Barabari/Features/Activity/ActivityViewModel.swift`.
- Modify `Barabari/Barabari/Features/Activity/ActivityView.swift`.
- Modify `Barabari/Barabari/Domain/Repositories/GroupRepository.swift` or the concrete local repository only if a focused activity-page seam is required.
- Add `Barabari/BarabariTests/DesignSystem/AmountFormatterTests.swift` if the target structure supports it, otherwise extend `DesignSystemTests.swift`.
- Add `Barabari/BarabariTests/Features/ActivityViewModelTests.swift`.
- Extend `Barabari/BarabariTests/Features/AddExpenseViewModelTests.swift` for stale-selection protection.

**Steps:**

- [ ] Cache PKR and other currency formatters by currency/locale key in a thread-safe or main-actor-safe value type; keep the public formatting API stable.
- [ ] Ensure AmountText computes the display string once per body evaluation and reuses it for text and accessibility.
- [ ] Replace the unstructured group-member load with a cancellable task property or generation token. Cancel the previous task before selecting a new group and ignore stale results.
- [ ] Extract Activity row construction into a main-actor view model using stable `ActivityRow` value models.
- [ ] Load an initial activity page, join only the visible page's expenses and settlements, and expose `loadNextPageIfNeeded(lastID:)` with a loading guard.
- [ ] Render activity in `LazyVStack`, use stable UUID identity, and show a footer progress indicator while loading the next page.
- [ ] Add explicit loading, empty, failure, and retry states without rebuilding the navigation shell.
- [ ] Test formatter output, activity ordering/page boundaries, duplicate-load prevention, and selected-group stale-result rejection.

**Verification:**

```bash
xcodebuild -project Barabari/Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,id=3A10C54D-4D4B-4BEC-B196-68EE205462B0' test -only-testing:BarabariTests/DesignSystemTests -only-testing:BarabariTests/Features/ActivityViewModelTests -only-testing:BarabariTests/Features/AddExpenseViewModelTests
```

**Commit:** `perf: streamline activity and money rendering`

## Task 4: Finish the local demo surface and route activity details

**Files:**

- Modify `Barabari/Barabari/Features/Groups/GroupsView.swift` to remove the dead-end Join Group action.
- Modify `Barabari/Barabari/Features/Activity/ActivityView.swift` to make rows navigable.
- Modify `Barabari/Barabari/Features/Expenses/ExpenseDetailView.swift` and add a settlement/event detail view only if the current model has no suitable destination.
- Modify `Barabari/Barabari/Features/Settings/SettingsView.swift`.
- Modify `Barabari/Barabari/Features/Settings/SettingsViewModel.swift`.
- Add a small local export service/value encoder under `Barabari/Barabari/Features/Settings/` or `Domain/` with focused tests.
- Extend `Barabari/BarabariTests/Features` and `Barabari/BarabariUITests/NavigationUITests.swift`.

**Steps:**

- [ ] Remove Join Group from the visible local demo until a real local join flow is implemented. Keep the empty-state copy useful and action-oriented.
- [ ] Add typed Activity routes for expense detail and settlement/event detail. Make each tappable row expose a clear chevron/accessibility hint.
- [ ] Reuse the existing ExpenseDetailView and add only the smallest settlement detail screen needed to make settlement activity inspectable.
- [ ] Replace unavailable Settings alerts with working local controls: appearance preference, haptics toggle, privacy explanation, local JSON/CSV export through a share sheet, and a local-demo status row.
- [ ] Do not show Notifications or Delete Account in this local build because neither action is real.
- [ ] Ensure export contains no credentials or hidden persistence internals and is generated from domain values only.
- [ ] Test appearance/haptics persistence, export generation, activity navigation, and the absence of dead-end rows.

**Verification:**

```bash
xcodebuild -project Barabari/Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,id=3A10C54D-4D4B-4BEC-B196-68EE205462B0' test -only-testing:BarabariTests/Features -only-testing:BarabariUITests/NavigationUITests
```

**Commit:** `feat: complete local demo flows`

## Task 5: Add the Barabari icon and normalize project configuration

**Files:**

- Add `Barabari/Barabari/Assets.xcassets/Contents.json`.
- Add `Barabari/Barabari/Assets.xcassets/AppIcon.appiconset/Contents.json`.
- Add the selected high-resolution icon artwork under the app icon set.
- Modify only the intentional app target settings in `Barabari/Barabari.xcodeproj/project.pbxproj`.
- Inspect `Barabari/Barabari.xcodeproj/project.xcworkspace/contents.xcworkspacedata` and keep it only if Xcode requires it for the current project format.
- Add an icon asset verification test or build inspection script under `Barabari/BarabariTests/` only if it gives a stable deterministic check.

**Steps:**

- [ ] Generate three Barabari Balance Mark candidates with the image-generation skill, select the clearest equal/balance mark, and keep the final artwork text-free and legible at small sizes.
- [ ] Prefer vector-friendly or high-resolution layered artwork. Add a 1024 by 1024 asset-catalog fallback so the app has a real icon on iOS 17 through 26.
- [ ] Set `ASSETCATALOG_COMPILER_APPICON_NAME` to the intentional asset name and verify it is present on the app target.
- [ ] Do not add or remove the user's personal `DEVELOPMENT_TEAM` value without inspecting the current diff. Keep signing identity local to the developer machine.
- [ ] Accept the recommended warnings, Debug active-architecture setting, and script sandboxing intentionally. Add string/asset symbol generation only when the corresponding asset/catalog files exist.
- [ ] Review the Xcode project diff for accidental target membership, bundle identifier, signing, or source-file changes before staging.

**Verification:**

```bash
xcodebuild -project Barabari/Barabari.xcodeproj -scheme Barabari -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
git diff --check
```

**Commit:** `feat: add Barabari app icon and project polish`

## Task 6: Run the release-quality verification pass

**Files:** No source changes expected unless verification finds a concrete regression.

**Steps:**

- [ ] Run the generic unsigned iOS build.
- [ ] Run all focused unit tests, then the complete BarabariTests target.
- [ ] Run the existing UI tests on the available iPhone 17 Pro iOS 26.5 simulator if it is already booted or if the user explicitly requests a simulator run. Do not claim a physical-device smoke test without a connected device.
- [ ] Inspect accessibility identifiers and labels for tab selection, Save, Add Group, activity rows, and export.
- [ ] Validate light/dark mode, larger text, Reduce Motion, keyboard dismissal, and bottom safe-area behavior in the simulator or on the user's phone.
- [ ] Run `git diff --check`, inspect `git status --short`, and separate intentional source commits from preserved user/Xcode changes.
- [ ] Document the exact build/test commands and any device-only checks remaining.

**Commit:** `test: verify Barabari smooth demo release path` only if verification requires a source fix; otherwise leave no empty commit.

## Handoff

After all tasks pass, report the commits, the build/test evidence, the icon asset location, the remaining backend/deferred scope, and the exact Xcode steps for running on the user's iPhone. Do not claim backend sync, notifications, payment initiation, or account deletion is implemented.
