# Barabari Balance Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Every implementation and review agent must use `model="gpt-5.6-luna"` with `reasoning_effort="max"`. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an optional, privacy-safe Home Screen widget showing only the current user's aggregate ledger position and last update time, without networking or exposing group and member names.

**Architecture:** The main app writes a tiny Codable snapshot into an App Group UserDefaults suite after ledger revisions. A separate WidgetKit extension reads that snapshot and renders small and medium timelines. Entitlement and signing work is explicitly gated so widget setup can never break the runnable main app.

**Tech Stack:** Swift 5 language mode in the current Xcode toolchain, SwiftUI, WidgetKit, App Groups, UserDefaults, XCTest.

**Depends on:** Core premium UI and local app lock plans.

**Spec:** `docs/superpowers/specs/2026-09-23-barabari-premium-ui-design.md`

## Global Constraints

- The widget is optional V1 polish. Main-app buildability takes priority.
- Show only aggregate owed, owing, net position, settled state, and last update time.
- Never place group names, member names, expense titles, notes, invite codes, or raw ledger objects in the shared container.
- Never fetch repositories or perform network activity inside the widget extension.
- Snapshot values use `Int64` minor units and explicit schema versioning.
- If App Group capability cannot be provisioned for both bundle identifiers, defer the extension and leave the main app unchanged.
- The app lock does not claim to secure widget content, so the snapshot is intentionally low-sensitivity and can be disabled later without a migration.
- The program preflight must commit the approved user-owned Xcode project baseline before this plan begins. All later target and source-registration diffs must then be task-owned and reviewed normally.
- Use the preflight-selected `$BARABARI_SIMULATOR_UDID` in every test command.

## Review Focus

- Corrupt, missing, future-version, and stale snapshots render a safe placeholder.
- Widget dates and currency are locale-aware but never allocate formatters in a frequently evaluated body path.
- Small and medium families remain legible in Obsidian and Pearl, increased contrast, and accessibility sizes supported by WidgetKit.
- Snapshot writes occur after successful ledger changes, not on a timer and not while nothing changes.
- A missing App Group suite cannot crash either target.

---

## Proposed Identifiers

- Main app: existing `com.nabeegh.Barabari`
- Widget extension: `com.nabeegh.Barabari.BalanceWidget`
- App Group: `group.com.nabeegh.Barabari`

These are proposals only until the Apple Developer signing check confirms they are available for team `MZ65MFRV8X`.

## File Structure

### Create as source shared by the app and widget targets

- `Barabari/Shared/BalanceWidgetSnapshot.swift`: versioned, Codable, privacy-safe data contract.
- `Barabari/Shared/BalanceWidgetSnapshotStore.swift`: Foundation-only App Group storage boundary.

### Create in the app target

- `Barabari/Barabari/Widgets/BalanceWidgetSnapshotWriter.swift`: changed-write detection and timeline reload abstraction.
- `Barabari/BarabariTests/Widgets/BalanceWidgetSnapshotTests.swift`
- `Barabari/BarabariTests/Widgets/BalanceWidgetSnapshotWriterTests.swift`
- `Barabari/Barabari/Barabari.entitlements` only after the capability gate passes.

### Create in the optional widget target

- `Barabari/BarabariBalanceWidget/BarabariBalanceWidget.swift`
- `Barabari/BarabariBalanceWidget/BalanceWidgetProvider.swift`
- `Barabari/BarabariBalanceWidget/BalanceWidgetView.swift`
- `Barabari/BarabariBalanceWidget/Info.plist`
- `Barabari/BarabariBalanceWidget/BarabariBalanceWidget.entitlements`
- `Barabari/BarabariBalanceWidgetTests/BalanceWidgetProviderTests.swift` if the target can be provisioned cleanly.

### Modify

- `Barabari/Barabari/App/LedgerSession.swift`
- `Barabari/Barabari/App/BarabariApp.swift`
- `Barabari/Barabari.xcodeproj/project.pbxproj` for app/test file registration in Task 2 and isolated target creation plus shared-source target membership in Task 4.

---

### Task 1: Read-only capability and signing gate

**Files:**
- Inspect only: `Barabari/Barabari.xcodeproj/project.pbxproj`
- Inspect only: current signing identities and provisioning capability output.

**Produces:** A recorded go or defer decision before any entitlement or project-file edit.

- [ ] **Step 1: Capture a clean baseline**

Run the complete main-app test suite and save its result. Confirm the program preflight committed the approved project-file baseline and `git diff -- Barabari/Barabari.xcodeproj/project.pbxproj` is empty before widget work begins.

- [ ] **Step 2: Verify local signing prerequisites without changing the project**

Confirm Xcode recognises team `MZ65MFRV8X`, the main bundle identifier, and a valid iPhone development identity. Check whether the Apple account can create or use `group.com.nabeegh.Barabari` for both proposed bundle identifiers. Do not create capabilities through ad hoc command-line edits.

- [ ] **Step 3: Apply the gate**

- **Go:** Both targets can share the proposed App Group under the same team. Continue to Task 2.
- **Defer:** Capability availability cannot be confirmed or provisioning fails. Record the exact failure in the implementation report, make no entitlement or project-file changes, and stop this plan with the main app still passing.

No commit is required for a read-only go result. If deferred, commit only a short decision note under `docs/superpowers/reports/` after user review.

---

### Task 2: Versioned privacy-safe snapshot contract

**Files:**
- Create: `Barabari/Shared/BalanceWidgetSnapshot.swift`
- Create: `Barabari/Shared/BalanceWidgetSnapshotStore.swift`
- Create: `Barabari/Barabari/Widgets/BalanceWidgetSnapshotWriter.swift`
- Create: `Barabari/BarabariTests/Widgets/BalanceWidgetSnapshotTests.swift`
- Create: `Barabari/BarabariTests/Widgets/BalanceWidgetSnapshotWriterTests.swift`
- Modify: `Barabari/Barabari.xcodeproj/project.pbxproj` only to register the five new app and unit-test files in the app/test targets.

**Interfaces:**
- Produces: `BalanceWidgetSnapshot(schemaVersion:netMinorUnits:owedMinorUnits:owingMinorUnits:updatedAt:)`.
- Produces: `BalanceWidgetSnapshotStore.write(_:) throws`, `read() throws -> BalanceWidgetSnapshot?`, and `remove() throws` with `WidgetSnapshotStoreError.suiteUnavailable`, `.corruptData`, and `.unsupportedVersion`.
- Produces: `BalanceWidgetSnapshotWriter.writeIfChanged(_:)` for app-only timeline reload behavior.
- Produces: injected `WidgetTimelineReloading` so tests do not invoke WidgetCenter.

- [ ] **Step 1: Write failing contract tests**

Cover Codable round trip, exact `Int64` values, settled zero state, missing data, corrupt data, and unsupported future schema. Use an isolated UserDefaults suite.

```swift
func testSnapshotRoundTripsExactMinorUnits() throws {
    let snapshot = BalanceWidgetSnapshot(
        schemaVersion: 1,
        netMinorUnits: -125_050,
        owedMinorUnits: 0,
        owingMinorUnits: 125_050,
        updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
    )

    try store.write(snapshot)

    XCTAssertEqual(try store.read(), snapshot)
}
```

- [ ] **Step 2: Run focused tests and verify RED**

Expected: missing snapshot, store, and writer symbols.

- [ ] **Step 3: Implement the contract and storage boundary**

Encode one small Data value under `barabari.balanceWidgetSnapshot.v1`. The production store obtains `UserDefaults(suiteName: "group.com.nabeegh.Barabari")`; missing suite, corrupt data, and future schema versions throw typed errors instead of crashing. `read()` returns `nil` only when no snapshot exists. The app-only writer reloads `BarabariBalanceWidget` only after a successful changed write.

- [ ] **Step 4: Prove the privacy boundary in tests**

Encode the snapshot and assert it contains no known seeded member, group, expense, or note text. Keep this as a regression test even though those fields do not exist on the type.

- [ ] **Step 5: Run tests and commit**

```sh
git add Barabari/Shared Barabari/Barabari/Widgets Barabari/BarabariTests/Widgets
git add Barabari/Barabari.xcodeproj/project.pbxproj
git commit -m "feat: add privacy-safe widget snapshot"
```

Before committing, verify that the project-file patch contains only app/test references and Sources entries for this task's five files. The user-owned baseline must already be committed by program preflight.

---

### Task 3: Write snapshots after successful ledger revisions

**Files:**
- Modify: `Barabari/Barabari/App/LedgerSession.swift`
- Modify: `Barabari/Barabari/App/BarabariApp.swift`
- Modify: `Barabari/BarabariTests/App/LedgerSessionTests.swift`

**Interfaces:**
- Produces: injected async snapshot refresh closure or `BalanceWidgetSnapshotRefreshing` protocol.
- Consumes existing repository summaries outside SwiftUI body evaluation.

- [ ] **Step 1: Write failing LedgerSession tests**

Verify one successful `markChanged()` schedules one coalesced refresh, rapid revisions coalesce, refresh failure does not block or roll back the ledger revision, and no write occurs when the aggregate snapshot is unchanged.

- [ ] **Step 2: Run LedgerSession tests and verify RED**

- [ ] **Step 3: Implement aggregate snapshot refresh**

At app composition, create a refresher that loads groups, requests each local balance summary, and sums only the current user's positions using `Int64` checked arithmetic. Trigger it after ledger revisions and once when the active app starts. Coalesce overlapping requests and discard stale results.

- [ ] **Step 4: Keep storage optional**

If the App Group suite is unavailable, log a debug-only diagnostic and return. The main ledger action remains successful. Do not show widget setup errors in expense or settlement flows.

- [ ] **Step 5: Run tests and commit**

```sh
git add Barabari/Barabari/App/LedgerSession.swift Barabari/Barabari/App/BarabariApp.swift \
  Barabari/Barabari/Widgets Barabari/BarabariTests/App/LedgerSessionTests.swift
git commit -m "feat: refresh balance widget snapshot"
```

---

### Task 4: Isolated WidgetKit target and entitlement integration

**Files:**
- Create: `Barabari/BarabariBalanceWidget/BarabariBalanceWidget.swift`
- Create: `Barabari/BarabariBalanceWidget/BalanceWidgetProvider.swift`
- Create: `Barabari/BarabariBalanceWidget/BalanceWidgetView.swift`
- Create: `Barabari/BarabariBalanceWidget/Info.plist`
- Create: `Barabari/Barabari/Barabari.entitlements`
- Create: `Barabari/BarabariBalanceWidget/BarabariBalanceWidget.entitlements`
- Modify: `Barabari/Barabari.xcodeproj/project.pbxproj`
- Modify target membership: `Barabari/Shared/BalanceWidgetSnapshot.swift`
- Modify target membership: `Barabari/Shared/BalanceWidgetSnapshotStore.swift`

**Interfaces:**
- Produces: `BarabariBalanceWidget` for `.systemSmall` and `.systemMedium`.
- Produces: timeline entries from the shared snapshot with placeholder fallback.
- Produces: an injected `now: () -> Date` and prebuilt locale-aware formatters for deterministic freshness tests and cheap view evaluation.

- [ ] **Step 1: Write failing provider tests before target wiring where practical**

Extract pure entry mapping into shared source and test fresh, stale, missing, corrupt, settled, positive, and negative snapshots with an injected clock. A snapshot older than a defined freshness window shows “Open Barabari to update” but keeps the last aggregate value.

- [ ] **Step 2: Implement the provider without repository or network dependencies**

The provider reads one snapshot through the Foundation-only shared store, returns a timeline with a conservative refresh date, and relies on explicit `WidgetCenter.reloadTimelines` after app writes. It never opens SwiftData. Date and currency formatters are cached outside `body`.

- [ ] **Step 3: Implement small and medium layouts**

Small shows Barabari, net state, aggregate amount, and update freshness. Medium adds separate owed and owing totals. Use the same icon-derived black, white, graphite, and mint semantic direction, with no decorative continuous animation.

- [ ] **Step 4: Add the target and App Group capability in Xcode**

Create the Widget Extension target through Xcode so build phases and product references are valid. Add both files under `Barabari/Shared` to the app and extension Sources build phases; do not import or link the app target from the extension. Apply `group.com.nabeegh.Barabari` to both entitlements. Set the extension bundle identifier to `com.nabeegh.Barabari.BalanceWidget` and deployment target to match the main app.

- [ ] **Step 5: Isolate the project-file diff**

Confirm the project file is clean after the program preflight, make the target change, then inspect the full diff. It must contain only the task-owned target, shared-source membership, build phase, configuration, dependency, and entitlement-setting changes. If unrelated changes appear, stop for review instead of committing them.

- [ ] **Step 6: Build both schemes and commit**

```sh
xcodebuild -project Barabari/Barabari.xcodeproj -scheme Barabari \
  -destination 'generic/platform=iOS Simulator' build
xcodebuild -project Barabari/Barabari.xcodeproj -scheme BarabariBalanceWidgetExtension \
  -destination 'generic/platform=iOS Simulator' build
```

Commit only after both succeed:

```sh
git add Barabari/BarabariBalanceWidget Barabari/Barabari/Barabari.entitlements \
  Barabari/BarabariBalanceWidget/BarabariBalanceWidget.entitlements
git add Barabari/Barabari.xcodeproj/project.pbxproj
git commit -m "feat: add Barabari balance widget"
```

---

### Task 5: Widget visual, privacy, and full-suite verification

**Files:**
- Modify: widget files only when verification demonstrates a defect.
- Create: `docs/superpowers/reports/2026-09-23-barabari-widget-verification.md`.

**Produces:** A proof-oriented widget verification report with capability, build, privacy, and visual results.

- [ ] **Step 1: Run all app and widget tests**

```sh
xcodebuild -project Barabari/Barabari.xcodeproj -scheme Barabari \
  -destination "platform=iOS Simulator,id=$BARABARI_SIMULATOR_UDID" test
```

Run widget-target tests separately if Xcode does not include them in the app scheme.

- [ ] **Step 2: Verify snapshots visually**

Capture small and medium widget previews for settled, owed, owing, stale, and placeholder states in Obsidian and Pearl. Check long PKR values, increased contrast, and supported content sizes. No group or member name may appear.

- [ ] **Step 3: Verify refresh behavior**

Create one expense and one settlement in the demo build, verify the shared snapshot changes once per successful ledger revision, and confirm WidgetCenter is asked to reload. Do not wait for nondeterministic SpringBoard refresh timing as the only assertion.

- [ ] **Step 4: Verify physical-device signing**

Install the containing app on the connected iPhone, add the widget, record a ledger change, and confirm the aggregate updates after the system refresh. Physical device success is required before claiming App Group provisioning complete.

- [ ] **Step 5: Record results and commit only task-owned verification work**

```sh
git add docs/superpowers/reports/2026-09-23-barabari-widget-verification.md \
  Barabari/BarabariBalanceWidget Barabari/BarabariTests/Widgets
git commit -m "test: verify Barabari balance widget"
```
