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
