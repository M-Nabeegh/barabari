# Task 1 Report: Xcode foundation and development configuration

## Status

Completed. Barabari is now a native SwiftUI iOS 17 project with app, unit-test, and UI-test targets. It launches without backend credentials and persists live app data locally with SwiftData.

## Files changed

- `Barabari/.gitignore`
- `Barabari/README.md`
- `Barabari/Barabari.xcodeproj/project.pbxproj`
- `Barabari/Barabari.xcodeproj/xcshareddata/xcschemes/Barabari.xcscheme`
- `Barabari/Barabari/App/AppEnvironment.swift`
- `Barabari/Barabari/App/BarabariApp.swift`
- `Barabari/Barabari/App/ContentView.swift`
- `Barabari/Barabari/Config/Debug.xcconfig`
- `Barabari/Barabari/Domain/DemoModels.swift`
- `Barabari/BarabariTests/BarabariLaunchTests.swift`
- `Barabari/BarabariUITests/BarabariUITests.swift`

## Implementation notes

- `AppEnvironment.live` creates the persistent on-device SwiftData store.
- `AppEnvironment.demo` creates an in-memory container and seeds groups and activity records for previews and demo development.
- The real app target uses `AppEnvironment.live`, so it does not need backend credentials to launch.
- `Debug.xcconfig` holds empty provider-base-URL and local-auth defaults. It contains no credentials.
- The initial TabView has Home, Groups, Add, Activity, and Settings. iOS 26 automatically applies native Liquid Glass styling to system tab bars; the deployment target remains iOS 17 for compatible fallback behavior.
- The app target has `CFBundleDisplayName = Barabari`, a stable bundle identifier, iPhone-only deployment, and generated launch screen configuration.

## Verification

### Red phase

Attempted the requested launch test before the project existed:

```sh
xcodebuild -project Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,name=iPhone 15' test -only-testing:BarabariTests/BarabariLaunchTests
```

Result: unable to start because `Barabari/` did not yet exist, which confirmed the expected unconfigured-project state.

### Project discovery and build

```sh
xcodebuild -list -project Barabari.xcodeproj
xcodebuild -project Barabari.xcodeproj -scheme Barabari -sdk iphonesimulator -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

Result: project discovery listed `Barabari`, `BarabariTests`, `BarabariUITests`, and scheme `Barabari`. The first build exposed one invalid preview-assets setting. I removed that configuration reference and rebuilt through the test commands below.

### Unit test

```sh
xcodebuild -project Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,id=3A10C54D-4D4B-4BEC-B196-68EE205462B0' test -only-testing:BarabariTests/BarabariLaunchTests
```

Result: `TEST SUCCEEDED`. `BarabariLaunchTests.testLaunchConfigurationHasBarabariDisplayName` passed, 1 test and 0 failures.

### UI launch test

```sh
xcodebuild -project Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,id=3A10C54D-4D4B-4BEC-B196-68EE205462B0' test -only-testing:BarabariUITests/BarabariUITests/testAppLaunches
```

Result: `TEST SUCCEEDED`. `BarabariUITests.testAppLaunches` passed, 1 test and 0 failures. It launched `com.nabeegh.Barabari` and found the `Barabari` navigation bar.

### Static checks

```sh
git diff --check
rg -n "BarabariAccent|TODO|FIXME" Barabari || true
```

Result: no whitespace errors and no unresolved accent-resource or placeholder markers.

## Self-review

- Kept UI, model, configuration, and environment code separate rather than wiring storage directly into SwiftUI views.
- Used integer `Int64` paisa for the demo monetary values.
- Avoided third-party packages and backend coupling.
- Confirmed the app and test targets are present and the app launches in a simulator.
- Kept the root UI intentionally lightweight. Feature implementation and polished design-system work belong to subsequent tasks.

## Concerns

- The installed simulator is iPhone 17 Pro on iOS 26.5, not the brief's iPhone 15 destination. Verification used the available simulator UUID.
- Simulator launch logs contain known CoreData recovery/noise about an initially missing Application Support directory, plus Xcode simulator debugger warnings. Both tests still passed. This should be rechecked on a clean simulator and a physical iPhone during final acceptance.
- A physical-device run still needs the user's Apple Developer signing team selected in Xcode. No signing identity was changed by this task.

## Review-fix addendum

### Findings fixed

1. Added `ActivityRecord.currencyCode` with a `"PKR"` default. This keeps demo financial records explicitly PKR-denominated instead of relying on presentation or future feature state.
2. Added an optional, Git-ignored `Barabari/Config/Local.xcconfig` override path. `Debug.xcconfig` now supplies buildable non-secret defaults first and uses `#include? "Local.xcconfig"` afterward, so a clean checkout builds while a developer may safely override provider values locally.

### Added test

- `AppEnvironmentTests.testDemoActivityRecordsUsePKR` creates the seeded in-memory demo environment, fetches activity records, and verifies every record has `currencyCode == "PKR"`.

### Red phase

```sh
xcodebuild -project Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,id=3A10C54D-4D4B-4BEC-B196-68EE205462B0' test -only-testing:BarabariTests/AppEnvironmentTests/testDemoActivityRecordsUsePKR
```

Expected failing output observed before implementation:

```text
Value of type 'ActivityRecord' has no member 'currencyCode'
** TEST FAILED **
```

### Focused test after fix

```sh
xcodebuild -project Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,id=3A10C54D-4D4B-4BEC-B196-68EE205462B0' test -only-testing:BarabariTests/AppEnvironmentTests/testDemoActivityRecordsUsePKR
```

Output: `TEST SUCCEEDED`; `testDemoActivityRecordsUsePKR` passed, 1 test and 0 failures.

### Full unit target and build after fix

```sh
xcodebuild -project Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,id=3A10C54D-4D4B-4BEC-B196-68EE205462B0' test -only-testing:BarabariTests
xcodebuild -project Barabari.xcodeproj -scheme Barabari -sdk iphonesimulator -configuration Debug build CODE_SIGNING_ALLOWED=NO
git check-ignore -v Barabari/Config/Local.xcconfig
git diff --check
```

Outputs:

- Unit target: `TEST SUCCEEDED`; 2 tests and 0 failures.
- Simulator build: `BUILD SUCCEEDED`.
- Git ignore check: `Barabari/.gitignore:7:Barabari/Config/Local.xcconfig Barabari/Config/Local.xcconfig`.
- Whitespace check: no output, therefore clean.

### Transient verification note

One initial full-unit retry failed because the shared simulator reported `Application failed preflight checks` with `Busy`. I terminated the existing simulator app process, reran the same unit command, and it passed. This was simulator contention, not an app assertion or compile failure.

### Post-fix self-review

- The PKR property is stored on the model and covered by an in-memory SwiftData test.
- Local configuration is opt-in, ignored, and does not add a required source-controlled secret file.
- No feature behavior or backend coupling was added.
