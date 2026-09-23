# Barabari Local App Lock Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Every implementation and review agent must use `model="gpt-5.6-luna"` with `reasoning_effort="max"`. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an optional Face ID app lock that protects the local ledger without creating an account, uploading data, or trapping users whose biometric hardware is unavailable.

**Architecture:** Put LocalAuthentication behind a small injected protocol. A main-actor `AppLockController` owns preference, lifecycle, and unlock state. SwiftUI renders either the existing `RootView` or a dedicated lock screen, while tests inject deterministic evaluators instead of invoking system biometric UI.

**Tech Stack:** Swift 5 language mode in the current Xcode toolchain, SwiftUI, LocalAuthentication, UserDefaults, XCTest, XCUITest.

**Depends on:** `docs/superpowers/plans/2026-09-23-barabari-premium-core-ui.md`

**Spec:** `docs/superpowers/specs/2026-09-23-barabari-premium-ui-design.md`

## Global Constraints

- Face ID remains off by default and is described as an on-device privacy lock, not encryption.
- The ledger, group invites, exports, and financial calculations remain unchanged.
- Enabling requires enrolled Face ID, checked with `deviceOwnerAuthenticationWithBiometrics` and `LABiometryType.faceID`.
- Normal unlock attempts Face ID. If Face ID later becomes unavailable or locked out, the dedicated lock screen offers an explicit device-passcode recovery action using `deviceOwnerAuthentication` so the user is never trapped.
- Cancellation keeps the app locked and provides a clear Retry action.
- Authentication failure never erases data, disables the preference, or loops automatically.
- If device-owner authentication is unavailable, the setting stays off and explains why.
- The app locks after leaving the active state only when the preference is enabled and the app has previously unlocked in this process.
- UI tests never depend on the Simulator's real biometric enrollment or prompt timing.
- No third-party dependency and no network call.
- The program preflight must commit the approved user-owned Xcode project baseline before this plan begins. Every new source or test file then receives a normal, reviewable project registration.
- Use the preflight-selected `$BARABARI_SIMULATOR_UDID` in every test command.

## Review Focus

- Success, user cancellation, authentication failure, unavailable hardware, and thrown LocalAuthentication errors map to distinct typed outcomes.
- Turning the setting on requires a successful authentication before persistence.
- Turning the setting off requires a successful authentication while the app is unlocked.
- Background and inactive transitions cannot expose ledger content in the app switcher.
- Relaunch with the saved preference enabled starts locked.
- Accessibility identifies the lock state, Retry action, and unavailable explanation without exposing financial data.

---

## File Structure

### Create

- `Barabari/Barabari/Security/BiometricEvaluating.swift`: authentication protocol, typed outcomes, and production LocalAuthentication adapter.
- `Barabari/Barabari/Security/AppLockController.swift`: preference, scene lifecycle, and unlock state machine.
- `Barabari/Barabari/Features/Security/LockedView.swift`: privacy-safe locked surface.
- `Barabari/BarabariTests/Security/AppLockControllerTests.swift`: deterministic state-machine tests.
- `Barabari/BarabariUITests/AppLockUITests.swift`: launch, lifecycle, and settings coverage.

### Modify

- `Barabari/Barabari/App/BarabariApp.swift`
- `Barabari/Barabari/App/ContentView.swift`
- `Barabari/Barabari/Features/Root/RootView.swift`
- `Barabari/Barabari/Features/Settings/SettingsViewModel.swift`
- `Barabari/Barabari/Features/Settings/SettingsView.swift`
- `Barabari/Barabari/Info.plist`
- `Barabari/Barabari.xcodeproj/project.pbxproj` only for explicit registration of files created by the active task.

---

### Task 1: Injected authentication boundary and state machine

**Files:**
- Create: `Barabari/Barabari/Security/BiometricEvaluating.swift`
- Create: `Barabari/Barabari/Security/AppLockController.swift`
- Create: `Barabari/BarabariTests/Security/AppLockControllerTests.swift`
- Modify: `Barabari/Barabari.xcodeproj/project.pbxproj` only to register the three new files.

**Interfaces:**
- Produces: `AppAuthenticationOutcome` with `.authenticated`, `.cancelled`, `.failed(message:)`, and `.unavailable(message:)`.
- Produces: `BiometricEvaluating.faceIDAvailability`, `authenticateWithFaceID(reason:)`, and `authenticateWithDeviceOwner(reason:)`.
- Produces: `AppLockController.isEnabled`, `state`, `enable()`, `disable()`, `unlockWithFaceID()`, `unlockWithDeviceOwner()`, and `handleScenePhase(_:)`.

- [ ] **Step 1: Write failing evaluator and controller tests**

Use a scripted fake evaluator. Cover initial state with preference off, enabled relaunch starting locked, enable success, enable cancellation, non-Face-ID device, unenrolled Face ID, unlock success, Face ID lockout, device-passcode recovery success, recovery cancellation, disable success, and background relocking.

```swift
func testEnabledRelaunchStartsLocked() {
    let defaults = makeIsolatedDefaults(enabled: true)
    let controller = AppLockController(
        evaluator: FakeBiometricEvaluator(outcomes: []),
        defaults: defaults
    )

    XCTAssertTrue(controller.isEnabled)
    XCTAssertEqual(controller.state, .locked)
}

func testCancelledUnlockRemainsLockedWithoutAutomaticRetry() async {
    let fake = FakeBiometricEvaluator(outcomes: [.cancelled])
    let controller = makeEnabledController(evaluator: fake)

    await controller.unlockWithFaceID()

    XCTAssertEqual(controller.state, .locked)
    XCTAssertEqual(fake.authenticationCallCount, 1)
}
```

- [ ] **Step 2: Run the focused suite and verify RED**

```sh
xcodebuild -project Barabari/Barabari.xcodeproj -scheme Barabari \
  -destination "platform=iOS Simulator,id=$BARABARI_SIMULATOR_UDID" \
  -only-testing:BarabariTests/AppLockControllerTests test
```

Expected: missing authentication and controller symbols.

- [ ] **Step 3: Implement the production evaluator**

Create a fresh `LAContext` for each request. To enable and normally unlock, require `biometryType == .faceID`, check `canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error:)`, then evaluate that policy. For the separately labelled recovery action only, evaluate `.deviceOwnerAuthentication`. Map `LAError.userCancel`, `.appCancel`, and `.systemCancel` to `.cancelled`; map enrollment, availability, and lockout errors to typed unavailability that can expose recovery; map other failures to a short privacy-safe message. Never retain `LAContext` across attempts.

- [ ] **Step 4: Implement the controller as an explicit state machine**

```swift
enum AppLockState: Equatable {
    case unlocked
    case locked
    case authenticating
    case error(String)
}

@MainActor
final class AppLockController: ObservableObject {
    @Published private(set) var isEnabled: Bool
    @Published private(set) var state: AppLockState

    func enable() async
    func disable() async
    func unlockWithFaceID() async
    func unlockWithDeviceOwner() async
    func handleScenePhase(_ phase: ScenePhase)
}
```

Use an injected UserDefaults key `barabari.appLockEnabled`. Guard concurrent calls so repeated taps cannot show overlapping system prompts. Persist `true` only after successful enable authentication.

- [ ] **Step 5: Run focused tests and commit**

Expected: every AppLockController test passes.

```sh
git add Barabari/Barabari/Security Barabari/BarabariTests/Security
git add Barabari/Barabari.xcodeproj/project.pbxproj
git commit -m "feat: add local app lock state machine"
```

---

### Task 2: Lock screen, lifecycle, and Settings integration

**Files:**
- Create: `Barabari/Barabari/Features/Security/LockedView.swift`
- Modify: `Barabari/Barabari/App/BarabariApp.swift`
- Modify: `Barabari/Barabari/App/ContentView.swift`
- Modify: `Barabari/Barabari/Features/Root/RootView.swift`
- Modify: `Barabari/Barabari/Features/Settings/SettingsViewModel.swift`
- Modify: `Barabari/Barabari/Features/Settings/SettingsView.swift`
- Modify: `Barabari/Barabari/Info.plist`
- Modify: `Barabari/BarabariTests/Features/SettingsViewModelTests.swift`
- Modify: `Barabari/Barabari.xcodeproj/project.pbxproj` only to register `LockedView.swift`.

**Interfaces:**
- Produces: `ContentView(environment:appLockController:)`.
- Produces: Settings toggle intent methods instead of directly mutating the stored lock preference.
- Produces: deterministic UI-test authentication selected from launch arguments at app composition.

- [ ] **Step 1: Write failing Settings tests**

Verify the toggle is off by default, successful enable changes the displayed setting, cancellation restores the off position, unavailable produces explanation text, and successful disable removes the stored preference.

- [ ] **Step 2: Run Settings tests and verify RED**

- [ ] **Step 3: Compose one shared controller at the app boundary**

Create the production controller in `BarabariApp.init()`, inject it into `ContentView`, pass it explicitly through `RootView` to `SettingsView`, and observe `scenePhase` in `ContentView`. On `.inactive` or `.background`, place a privacy-safe opaque cover before content can appear in the app switcher. On `.active`, remain locked until authentication succeeds. Authentication-prompt scene transitions must not launch a second prompt.

Add UI-test launch values such as `-uiTestingAppLock enabled`, `-uiTestingAuthentication success|cancel|failure|unavailable`. Parse them only at the app composition root and inject a fake evaluator. Do not branch inside feature views.

- [ ] **Step 4: Build the locked surface**

Render the Barabari mark, “Barabari is locked,” a short local-privacy explanation, and a `Try Face ID again` action. When the controller reports Face ID unavailable or locked out, additionally show `Use device passcode` as an explicit recovery action. Use the active theme's semantic colours and static final-state feedback under Reduce Motion. Do not render amounts, groups, activity, or blurred ledger content behind it.

- [ ] **Step 5: Integrate the Settings control**

Add a `Privacy` section with a Face ID row, explanatory subcopy, progress state, and typed error text. Show the toggle only when enrolled Face ID is available; otherwise show an unavailable explanation without an interactive switch. Disable the control while authenticating. The toggle calls `enable()` or `disable()` and reflects authoritative controller state.

- [ ] **Step 6: Add Face ID usage copy**

Add `NSFaceIDUsageDescription` to `Info.plist` with user-facing copy that Barabari uses Face ID only to unlock the local ledger on this device.

- [ ] **Step 7: Run unit tests, build, and commit**

```sh
git add Barabari/Barabari/App Barabari/Barabari/Security Barabari/Barabari/Features/Root/RootView.swift \
  Barabari/Barabari/Features/Security Barabari/Barabari/Features/Settings \
  Barabari/Barabari/Info.plist Barabari/BarabariTests/Features/SettingsViewModelTests.swift
git add Barabari/Barabari.xcodeproj/project.pbxproj
git commit -m "feat: integrate Face ID app lock"
```

Before committing, verify that the project-file patch contains only the `LockedView.swift` reference and app Sources entry. The user-owned baseline must already be committed by program preflight.

---

### Task 3: App-lock UX regressions and final verification

**Files:**
- Create: `Barabari/BarabariUITests/AppLockUITests.swift`
- Modify: lock files only when a failing test demonstrates a defect.
- Modify: `Barabari/Barabari.xcodeproj/project.pbxproj` only to register the new UI-test file.

**Interfaces:**
- Consumes the deterministic launch values from Task 2.

- [ ] **Step 1: Add failing end-to-end UI tests**

Cover enabled relaunch, successful Face ID unlock, cancellation plus manual Retry, Face ID lockout plus device-passcode recovery, unavailable setting, and disable success. Assert the locked screen contains no seeded amount or group text.

- [ ] **Step 2: Add a deterministic lifecycle regression**

Launch unlocked with app lock enabled, send the app to the background with `XCUIDevice.shared.press(.home)`, reactivate it, and verify the privacy-safe locked surface appears before any ledger assertion. If Simulator lifecycle automation proves nondeterministic, move the transition assertion to the controller unit suite and keep the UI test to relaunch locking. Do not add sleeps.

- [ ] **Step 3: Add accessibility checks**

At AX-XXXL, verify the lock title, explanation, and Retry action are present and hittable. Verify VoiceOver labels do not announce hidden ledger content.

- [ ] **Step 4: Run the focused UI suite and complete suite**

```sh
xcodebuild -project Barabari/Barabari.xcodeproj -scheme Barabari \
  -destination "platform=iOS Simulator,id=$BARABARI_SIMULATOR_UDID" \
  -only-testing:BarabariUITests/AppLockUITests test

xcodebuild -project Barabari/Barabari.xcodeproj -scheme Barabari \
  -destination "platform=iOS Simulator,id=$BARABARI_SIMULATOR_UDID" test
```

Expected: all discovered tests pass. A Simulator result proves the injected flows, not physical Face ID hardware behavior.

- [ ] **Step 5: Perform a physical-device smoke check before claiming Face ID complete**

Install on the connected iPhone, enable the setting, cancel once, Retry successfully, background and reopen, then disable. Confirm system passcode fallback works when Face ID is temporarily unavailable. This is the only acceptance step requiring the user and real hardware.

- [ ] **Step 6: Commit final app-lock verification changes**

```sh
git add Barabari/BarabariUITests/AppLockUITests.swift Barabari/Barabari/Security \
  Barabari/Barabari/Features/Security Barabari/Barabari/Features/Settings
git add Barabari/Barabari.xcodeproj/project.pbxproj
git commit -m "test: verify local app lock flows"
```
