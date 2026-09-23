# Barabari Obsidian UI and Local Invites Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the purple-heavy Barabari presentation with a polished obsidian/graphite/pearl/mint system and add a tested local QR/link invite and join flow without introducing a backend.

**Architecture:** Keep the current native SwiftUI and SwiftData modular monolith. Add a small Codable invite payload and URL codec at the domain boundary, implement idempotent local joining in `LocalGroupRepository`, and keep invite/join presentation in focused Groups feature views coordinated by `AppRouter`. The native `TabView` remains the primary Liquid Glass navigation surface; custom glass is limited to small interactive controls.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, Core Image QR generation, VisionKit `DataScannerViewController` for optional QR scanning, UIKit pasteboard/share integration, XCTest, and XCUITest.

**Spec:** `docs/superpowers/specs/2026-09-22-barabari-obsidian-invites-design.md`

## Global Constraints

- Support iOS 17 minimum and use Liquid Glass only where available on iOS 26+.
- Keep all ledger amounts as existing `Int64` minor units; the invite payload never includes amounts or balances.
- This is a local-first demo. Do not add authentication, a network client, a server, push notifications, or microservices.
- The UI must state that a copied invite works only when the referenced group already exists in this local demo store.
- The primary UI must not use purple or indigo accents.
- Use semantic color roles, minimum 44 by 44 point hit targets, stable accessibility identifiers, and native safe-area/keyboard behavior.
- Preserve the existing dirty `Barabari/Barabari.xcodeproj/project.pbxproj`; never reset it or replace it wholesale. Do not commit a personal `DEVELOPMENT_TEAM` value.
- Do not log raw invite URLs, QR contents, or member identifiers.

## Review Focus

- Malformed, hostile, or unsupported QR/link input must fail closed with a useful error. The codec tests invalid scheme, host, version, UUID, name, and revision in Task 1.
- A valid invite whose group is absent from this local store must show `This group is not available on this iPhone` and never create a phantom group. The repository and join view-model tests cover this in Tasks 2 and 5.
- Repeated join taps or a second join of the same user must not create duplicate members or duplicate activity. The idempotency test belongs to Task 2.
- Camera denial, unsupported scanning hardware, and scanner cancellation must leave the paste-link path usable. The scanner fallback UI test belongs to Task 5.
- Dark mode, large text, Reduce Motion, and home-indicator/keyboard safe areas must keep controls legible and tappable. The accessibility UI test and device checklist belong to Tasks 3 and 7.

## File Map

### Domain and persistence

- Create `Barabari/Barabari/Domain/Models/GroupInvite.swift` for the payload, join outcome, and typed errors.
- Create `Barabari/Barabari/Domain/Services/GroupInviteCodec.swift` for the versioned `barabari://join` URL contract.
- Modify `Barabari/Barabari/Domain/Repositories/GroupRepository.swift` with invite and idempotent join methods.
- Modify `Barabari/Barabari/Data/LocalRepositories/LocalGroupRepository.swift` to create payloads, add local members, and record `memberJoined` events.
- Modify `Barabari/Barabari/Data/SwiftData/SwiftDataModels.swift` only if a typed repository error is needed; no new SwiftData model or migration is expected.

### Design system and app shell

- Modify `Barabari/Barabari/DesignSystem/BarabariColors.swift` to use obsidian/graphite/pearl/soft-mint semantic roles.
- Modify `Barabari/Barabari/DesignSystem/Components/PrimaryActionButton.swift` and `Barabari/Barabari/DesignSystem/Components/BarabariCard.swift` for the black primary hierarchy and stable hit areas.
- Create `Barabari/Barabari/DesignSystem/Components/InviteQRCode.swift` for Core Image QR rendering.
- Modify `Barabari/Barabari/App/AppRouter.swift`, `Barabari/Barabari/App/BarabariApp.swift`, and `Barabari/Barabari/Features/Root/RootView.swift` for invite presentation and deep-link routing.
- Modify `Barabari/Barabari.xcodeproj/project.pbxproj` minimally for generated Info.plist camera usage and URL scheme settings, preserving unrelated user changes.
- Refresh `Barabari/Barabari/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` and keep `Contents.json` pointed at `AppIcon`.

### Groups feature

- Create `Barabari/Barabari/Features/Groups/GroupInviteViewModel.swift` for loading a group invite.
- Create `Barabari/Barabari/Features/Groups/GroupInviteView.swift` for QR, copy, share, and the local-only disclosure.
- Create `Barabari/Barabari/Features/Groups/JoinGroupViewModel.swift` for parse, local availability, and join state.
- Create `Barabari/Barabari/Features/Groups/JoinGroupView.swift` for paste/scan/preview/join UI.
- Create `Barabari/Barabari/Features/Groups/QRCodeScannerView.swift` for the optional VisionKit camera surface and paste fallback.
- Modify `Barabari/Barabari/Features/Groups/GroupsView.swift`, `GroupsViewModel.swift`, and `GroupDetailView.swift` to expose Join and Invite.

### Tests

- Create `Barabari/BarabariTests/Domain/GroupInviteTests.swift`.
- Create `Barabari/BarabariTests/Features/GroupInviteViewModelTests.swift`.
- Modify `Barabari/BarabariTests/Data/SwiftDataRepositoryTests.swift` and `DesignSystemTests.swift`.
- Modify `Barabari/BarabariUITests/NavigationUITests.swift` and create `Barabari/BarabariUITests/InviteFlowUITests.swift`.

---

### Task 1: Define and test the versioned invite contract

**Files:**
- Create: `Barabari/Barabari/Domain/Models/GroupInvite.swift`
- Create: `Barabari/Barabari/Domain/Services/GroupInviteCodec.swift`
- Modify: `Barabari/Barabari/Domain/Repositories/GroupRepository.swift`
- Create: `Barabari/BarabariTests/Domain/GroupInviteTests.swift`
- Modify: `Barabari/Barabari.xcodeproj/project.pbxproj` only to register the three new app files and one test file if Xcode does not auto-register them

**Interfaces:**
- `GroupInvitePayload: Codable, Equatable, Hashable, Sendable` with `version`, `groupID`, `groupName`, and `groupRevision`.
- `GroupInviteCodec.makeURL(for:) throws -> URL` and `GroupInviteCodec.payload(from:) throws -> GroupInvitePayload`.
- `GroupJoinOutcome: Equatable, Sendable` with `.joined(Group)`, `.alreadyMember(Group)`, and `.unavailable(GroupInvitePayload)`.
- `GroupRepository.invitePayload(groupID:) async throws -> GroupInvitePayload` and `GroupRepository.joinGroup(invite:userID:) async throws -> GroupJoinOutcome`.

- [ ] **Step 1: Write failing codec tests.** Add tests that use a fixed UUID and assert a valid URL round-trips, keeps `barabari` as its scheme and `join` as its host, and preserves the display name containing spaces and Urdu/emoji characters. Add separate assertions that `http://join`, `barabari://other`, missing `v`, `v=99`, an invalid UUID, an empty name, and `revision=0` throw the matching typed error.

```swift
func testInviteURLRoundTripsAndPercentEncodesDisplayName() throws {
    let payload = GroupInvitePayload(
        version: 1,
        groupID: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
        groupName: "Lahore 🥘 & Flat 404",
        groupRevision: 3
    )

    let url = try GroupInviteCodec.makeURL(for: payload)

    XCTAssertEqual(url.scheme, "barabari")
    XCTAssertEqual(url.host, "join")
    XCTAssertFalse(url.absoluteString.contains("Lahore 🥘"))
    XCTAssertEqual(try GroupInviteCodec.payload(from: url), payload)
}

func testUnsupportedInviteInputFailsClosed() {
    XCTAssertThrowsError(try GroupInviteCodec.payload(from: URL(string: "https://example.com")!)) { error in
        XCTAssertEqual(error as? GroupInviteError, .invalidScheme)
    }
    XCTAssertThrowsError(try GroupInviteCodec.payload(from: URL(string: "barabari://other?v=1&group=00000000-0000-0000-0000-000000000123&name=Trip&revision=1")!)) { error in
        XCTAssertEqual(error as? GroupInviteError, .invalidHost)
    }
}
```

- [ ] **Step 2: Run the focused test to prove it fails.**

Run: `xcodebuild -project Barabari/Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' test -only-testing:BarabariTests/GroupInviteTests`

Expected: compilation or test failure because the payload and codec do not exist yet.

- [ ] **Step 3: Implement the smallest safe URL contract.** Encode `v`, `group`, `name`, and `revision` through `URLComponents`; require exactly the `barabari` scheme and `join` host; reject unsupported versions, malformed UUIDs, empty names, names longer than 80 Unicode scalars, and non-positive revisions. Keep the URL payload free of expenses, balances, and member identifiers.

```swift
enum GroupInviteCodec {
    static let scheme = "barabari"
    static let host = "join"

    static func makeURL(for payload: GroupInvitePayload) throws -> URL {
        guard payload.version == GroupInvitePayload.currentVersion else {
            throw GroupInviteError.unsupportedVersion(payload.version)
        }
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [
            URLQueryItem(name: "v", value: String(payload.version)),
            URLQueryItem(name: "group", value: payload.groupID.uuidString.lowercased()),
            URLQueryItem(name: "name", value: payload.groupName),
            URLQueryItem(name: "revision", value: String(payload.groupRevision))
        ]
        guard let url = components.url else { throw GroupInviteError.invalidURL }
        return url
    }
}
```

- [ ] **Step 4: Run the focused test to prove it passes.**

Run the same `xcodebuild` command from Step 2.

Expected: all `GroupInviteTests` pass.

- [ ] **Step 5: Commit the domain contract.**

```bash
git add Barabari/Barabari/Domain/Models/GroupInvite.swift Barabari/Barabari/Domain/Services/GroupInviteCodec.swift Barabari/Barabari/Domain/Repositories/GroupRepository.swift Barabari/BarabariTests/Domain/GroupInviteTests.swift Barabari/Barabari.xcodeproj/project.pbxproj
git commit -m "feat: define local group invite contract"
```

### Task 2: Implement idempotent local joining

**Files:**
- Modify: `Barabari/Barabari/Data/LocalRepositories/LocalGroupRepository.swift`
- Modify: `Barabari/Barabari/Data/SwiftData/SwiftDataModels.swift` if the repository error is added there
- Modify: `Barabari/BarabariTests/Data/SwiftDataRepositoryTests.swift`
- Modify: `Barabari/BarabariTests/Domain/LedgerUseCaseTests.swift` only if the protocol addition requires the existing in-memory test repository to implement the two new methods

**Interfaces:**
- `LocalGroupRepository.invitePayload(groupID:)` returns the current local group name and revision.
- `LocalGroupRepository.joinGroup(invite:userID:)` checks group identity and active membership, then returns `GroupJoinOutcome`.

- [ ] **Step 1: Write failing persistence tests.** Create an in-memory group owned by a fixed owner, create its payload, join as a second user, assert exactly two active members and one `.memberJoined` activity event, then call join again and assert `.alreadyMember` with no new member or activity. Add an unavailable-group assertion using a payload with a random UUID.

```swift
func testLocalInviteJoinIsIdempotentAndRecordsActivity() async throws {
    let container = try BarabariModelContainer.make(inMemory: true)
    let repository = LocalGroupRepository(container: container)
    let ownerID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let memberID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let group = try await repository.createGroup(name: "Trip", description: nil, ownerID: ownerID)
    let invite = try await repository.invitePayload(groupID: group.id)

    let first = try await repository.joinGroup(invite: invite, userID: memberID)
    let second = try await repository.joinGroup(invite: invite, userID: memberID)

    XCTAssertEqual(first, .joined(group))
    XCTAssertEqual(second, .alreadyMember(group))
    XCTAssertEqual(try await repository.members(groupID: group.id).filter(\.isActive).count, 2)
    XCTAssertEqual(try await repository.activities(groupID: group.id).filter { $0.kind == .memberJoined }.count, 1)
}
```

- [ ] **Step 2: Run the focused repository test and observe the missing-method failure.**

Run: `xcodebuild -project Barabari/Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' test -only-testing:BarabariTests/SwiftDataRepositoryTests/testLocalInviteJoinIsIdempotentAndRecordsActivity`

Expected: compilation failure because `GroupRepository` and `LocalGroupRepository` do not implement invite creation or joining.

- [ ] **Step 3: Implement the repository methods without a schema migration.** Fetch the local `StoredGroup`, return its domain values in the payload, find an active `StoredGroupMember` by `groupID` and `userID`, return `.alreadyMember` when present, otherwise insert a `.member` `StoredGroupMember` and a `StoredActivityEvent` with `.memberJoined`, save once, and return `.joined(group)`. For a missing local group return `.unavailable(invite)` instead of inserting anything. Do not trust the invite display name or revision over the stored group.

- [ ] **Step 4: Update all in-memory `GroupRepository` test doubles with deterministic stubs.** Their new invite method should build a payload from the stored group, and their join method should return `.unavailable` for unknown groups and `.alreadyMember` or `.joined` for known groups so existing use-case tests continue to compile without changing their behavior.

- [ ] **Step 5: Run all repository and domain tests.**

Run: `xcodebuild -project Barabari/Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' test -only-testing:BarabariTests/SwiftDataRepositoryTests -only-testing:BarabariTests/LedgerUseCaseTests`

Expected: existing persistence, balance, idempotency, and new invite tests pass.

- [ ] **Step 6: Commit the local join implementation.**

```bash
git add Barabari/Barabari/Data/LocalRepositories/LocalGroupRepository.swift Barabari/Barabari/Data/SwiftData/SwiftDataModels.swift Barabari/BarabariTests/Data/SwiftDataRepositoryTests.swift Barabari/BarabariTests/Domain/LedgerUseCaseTests.swift
git commit -m "feat: add idempotent local group joining"
```

### Task 3: Apply the obsidian design system and touch contract

**Files:**
- Modify: `Barabari/Barabari/DesignSystem/BarabariColors.swift`
- Modify: `Barabari/Barabari/DesignSystem/Components/PrimaryActionButton.swift`
- Modify: `Barabari/Barabari/DesignSystem/Components/BarabariCard.swift`
- Modify: `Barabari/Barabari/Features/Root/RootView.swift` only for native tab tint/background behavior
- Modify: `Barabari/BarabariTests/DesignSystemTests.swift`

**Interfaces:**
- Keep call sites using `BarabariColors.background`, `.surface`, `.raised`, `.accent`, `.onAccent`, `.success`, `.warning`, and `.danger`.
- Keep `BarabariInteraction.minimumHitSize == 44` and make all new controls use it.

- [ ] **Step 1: Add a color-role test that resolves light and dark accent colors.** Resolve `BarabariColors.accent` with `UITraitCollection(userInterfaceStyle:)` and assert the light color is near-black ink, the dark color is pearl, and neither resolves to the old indigo values. Keep this test about semantic roles rather than screen snapshots.

- [ ] **Step 2: Run the design-system test before changing tokens.**

Run: `xcodebuild -project Barabari/Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' test -only-testing:BarabariTests/DesignSystemTests`

Expected: the new role test fails against the current indigo palette.

- [ ] **Step 3: Replace the token values and comments.** Use obsidian `#090A0C`/`#0F1114`, graphite `#15171A`/`#22252A`, pearl `#F5F6F7`/`#FFFFFF`, ink `#111315`, pearl-on-accent `#F2F4F5`, soft mint `#92E6BE` dark and `#16724D` light, plus the existing amber/coral warning and danger roles. Remove the stale indigo wording and any unused `brandIndigo` token.

- [ ] **Step 4: Make primary actions and cards feel deliberate without applying glass everywhere.** Keep `PrimaryActionButton` filled with the semantic accent and a minimum 52-point height, add a subtle pressed state through the existing interaction helper, and keep `BarabariCard` solid with a low-contrast border. Ensure the root uses the system `TabView` and only applies `.tint(BarabariColors.accent)` and the background, leaving Liquid Glass ownership to iOS 26.

- [ ] **Step 5: Run design-system tests and a generic build.**

Run: `xcodebuild -project Barabari/Barabari.xcodeproj -scheme Barabari -destination 'generic/platform=iOS' build && xcodebuild -project Barabari/Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' test -only-testing:BarabariTests/DesignSystemTests`

Expected: the build and color/touch tests pass.

- [ ] **Step 6: Commit the visual foundation.**

```bash
git add Barabari/Barabari/DesignSystem/BarabariColors.swift Barabari/Barabari/DesignSystem/Components/PrimaryActionButton.swift Barabari/Barabari/DesignSystem/Components/BarabariCard.swift Barabari/Barabari/Features/Root/RootView.swift Barabari/BarabariTests/DesignSystemTests.swift
git commit -m "refactor: adopt obsidian Barabari visual system"
```

### Task 4: Add invite loading, QR generation, copy, and share

**Files:**
- Create: `Barabari/Barabari/DesignSystem/Components/InviteQRCode.swift`
- Create: `Barabari/Barabari/Features/Groups/GroupInviteViewModel.swift`
- Create: `Barabari/Barabari/Features/Groups/GroupInviteView.swift`
- Create: `Barabari/BarabariTests/Features/GroupInviteViewModelTests.swift`

**Interfaces:**
- `GroupInviteViewModel` publishes `.loading`, `.loaded(payload:link:)`, and `.failed(message:)`.
- `InviteQRCodeImage` accepts a `URL` and returns a rendered `UIImage?` using `CIFilter.qrCodeGenerator()` and a shared `CIContext`.

- [ ] **Step 1: Write failing view-model and QR tests.** Test that a valid local group loads a payload and URL, a missing group yields a user-facing failure, and the QR renderer returns a non-empty image for a valid link. Do not compare pixel snapshots.

- [ ] **Step 2: Run the focused test to prove it fails.**

Run: `xcodebuild -project Barabari/Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' test -only-testing:BarabariTests/GroupInviteViewModelTests`

Expected: compilation failure because the view model and QR component do not exist.

- [ ] **Step 3: Implement loading and QR rendering.** Build the URL through `GroupInviteCodec`, create a high-contrast `UIImage` from the QR filter output, and keep repository errors on the view-model state rather than exposing SwiftData to the view.

```swift
struct InviteQRCodeImage: View {
    let url: URL

    var body: some View {
        Group {
            if let image = Self.render(url: url) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel("QR code for (url.host ?? "Barabari") group invite")
            } else {
                Image(systemName: "qrcode")
                    .font(.system(size: 96))
                    .foregroundStyle(BarabariColors.textSecondary)
            }
        }
        .padding(20)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
```

- [ ] **Step 4: Build the invite sheet.** Show the group name, QR image, selectable link, `Copy link`, `Share link` through `ShareLink(item:)`, success feedback, and the exact local-only disclosure. Give controls the identifiers `invite-qr`, `copy-invite-link`, and `share-invite-link`. Share and clipboard operations must not log or mutate the ledger.

- [ ] **Step 5: Run view-model tests and the generic build.**

Run the focused test command from Step 2 followed by `xcodebuild -project Barabari/Barabari.xcodeproj -scheme Barabari -destination 'generic/platform=iOS' build`.

Expected: all invite view-model tests pass and the app builds.

- [ ] **Step 6: Commit the invite presentation.**

```bash
git add Barabari/Barabari/DesignSystem/Components/InviteQRCode.swift Barabari/Barabari/Features/Groups/GroupInviteViewModel.swift Barabari/Barabari/Features/Groups/GroupInviteView.swift Barabari/BarabariTests/Features/GroupInviteViewModelTests.swift
git commit -m "feat: add local group invite presentation"
```

### Task 5: Add join preview, paste-link validation, and optional QR scanning

**Files:**
- Create: `Barabari/Barabari/Features/Groups/JoinGroupViewModel.swift`
- Create: `Barabari/Barabari/Features/Groups/JoinGroupView.swift`
- Create: `Barabari/Barabari/Features/Groups/QRCodeScannerView.swift`
- Modify: `Barabari/BarabariTests/Features/GroupInviteViewModelTests.swift`
- Create: `Barabari/BarabariUITests/InviteFlowUITests.swift`

**Interfaces:**
- `JoinGroupViewModel` has `@Published var linkText`, `@Published private(set) var state`, `parse(_:)`, and `join() async -> Group?`.
- `JoinGroupState` includes `.idle`, `.preview(payload:localGroup:)`, `.joining`, `.joined(GroupJoinOutcome)`, and `.failed(String)`.
- `QRCodeScannerView` reports either a scanned string, cancellation, or scanner unavailability; it never owns the join operation.

- [ ] **Step 1: Write failing view-model tests for the five review-focus cases.** Test a valid pasted link with a local group produces `.preview` with that group, an absent local group produces an unavailable preview, malformed input produces `.failed`, joining calls the repository once while duplicate calls are ignored, and a successful outcome returns the group.

```swift
func testJoinViewModelShowsUnavailableLocalGroupWithoutCreatingOne() async throws {
    let environment = AppEnvironment(inMemory: true)
    let missingPayload = GroupInvitePayload(
        version: 1,
        groupID: UUID(uuidString: "00000000-0000-0000-0000-000000009999")!,
        groupName: "Shared trip",
        groupRevision: 1
    )
    let url = try GroupInviteCodec.makeURL(for: missingPayload)
    let viewModel = JoinGroupViewModel(environment: environment, initialURL: url)

    await viewModel.parseAndLoad()

    XCTAssertEqual(viewModel.state, .preview(payload: missingPayload, localGroup: nil))
}
```

- [ ] **Step 2: Run the focused test to prove it fails.**

Run: `xcodebuild -project Barabari/Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' test -only-testing:BarabariTests/GroupInviteViewModelTests`

Expected: compilation failure because the join view model and state do not exist.

- [ ] **Step 3: Implement the join view model.** Parse through `GroupInviteCodec`, look up the local group by UUID for preview, keep the user-facing unavailable state separate from malformed input, guard `isJoining`, call the repository once, and map `.joined` and `.alreadyMember` to a group-opening result. Do not create a group when local lookup fails.

- [ ] **Step 4: Implement the paste and scan UI.** Use a `TextField` with a `Paste` button, a `Scan QR` button, a preview card that states either `Available on this iPhone` or `This group is not available on this iPhone`, and a `Join group` button only when a valid payload has been parsed. Show the local-only disclosure directly below the preview. Keep `Paste invite link`, `scan-qr`, and `join-group-confirm` identifiers stable.

- [ ] **Step 5: Implement the scanner as an optional sheet.** Wrap VisionKit `DataScannerViewController` with `recognizedDataTypes: [.barcode(symbologies: [.qr])]`; check `DataScannerViewController.isSupported` and `.isAvailable` before presenting. On permission denial, unavailable hardware, or cancellation, dismiss the scanner and keep the paste field focused. The scanner callback passes the raw string to `JoinGroupViewModel` and then stops scanning.

- [ ] **Step 6: Add the UI flow test and run it.** Launch the empty state, open Join group, assert the paste and scan controls exist, paste an invalid link through the text field, and assert the actionable invalid-link message. Launch demo state, open Join group, paste a valid invite generated by the test fixture, assert the local preview, tap Join, and assert the group detail opens without a duplicate member on a second attempt. Do not make the test depend on live camera hardware.

Run: `xcodebuild -project Barabari/Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' test -only-testing:BarabariUITests/InviteFlowUITests`

Expected: the paste-link path passes on the simulator; scanner availability is reported as a fallback instead of failing the test.

- [ ] **Step 7: Commit the join flow.**

```bash
git add Barabari/Barabari/Features/Groups/JoinGroupViewModel.swift Barabari/Barabari/Features/Groups/JoinGroupView.swift Barabari/Barabari/Features/Groups/QRCodeScannerView.swift Barabari/BarabariTests/Features/GroupInviteViewModelTests.swift Barabari/BarabariUITests/InviteFlowUITests.swift
git commit -m "feat: add local QR and link group joining"
```

### Task 6: Wire navigation, deep links, group actions, and app metadata

**Files:**
- Modify: `Barabari/Barabari/App/AppRouter.swift`
- Modify: `Barabari/Barabari/App/BarabariApp.swift`
- Modify: `Barabari/Barabari/Features/Root/RootView.swift`
- Modify: `Barabari/Barabari/Features/Groups/GroupsView.swift`
- Modify: `Barabari/Barabari/Features/Groups/GroupsViewModel.swift` if a join callback or refresh method is needed
- Modify: `Barabari/Barabari/Features/Groups/GroupDetailView.swift`
- Modify: `Barabari/Barabari.xcodeproj/project.pbxproj` minimally for `NSCameraUsageDescription` and the `barabari` URL scheme
- Modify: `Barabari/BarabariUITests/NavigationUITests.swift`

**Interfaces:**
- `AppRouter.InvitePresentation: Identifiable, Equatable` with `.invite(groupID:)` and `.join(URL?)`.
- `AppRouter.presentInvite(groupID:)`, `presentJoin(url:)`, and `dismissInvitePresentation()`.
- `RootView` owns one `.sheet(item:)` for invite/join presentation and one `.onOpenURL` handler.

- [ ] **Step 1: Add failing navigation assertions.** Extend navigation UI tests so empty Groups exposes both `Create group` and `Join group`, seeded Group Detail exposes `Invite`, and the invite sheet exposes QR, copy, and share controls. Keep the existing repeated-tab-switch test.

- [ ] **Step 2: Run the navigation tests to capture the missing controls.**

Run: `xcodebuild -project Barabari/Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' test -only-testing:BarabariUITests/NavigationUITests`

Expected: the new assertions fail until routing and controls are wired.

- [ ] **Step 3: Add router presentation state and deep-link handling.** Use `sheet(item:)` from `RootView`; when a join succeeds, call `session.markChanged()`, dismiss the sheet, select Groups, and append the joined group's detail route. When the app receives a `barabari://join` URL, route it to Join with the URL prefilled rather than attempting a repository write in the app delegate.

```swift
enum InvitePresentation: Identifiable, Equatable {
    case invite(groupID: UUID)
    case join(URL?)

    var id: String {
        switch self {
        case let .invite(groupID): "invite-\(groupID.uuidString)"
        case let .join(url): "join-\(url?.absoluteString ?? "empty")"
        }
    }
}
```

- [ ] **Step 4: Add Groups and Group Detail entry points.** Add a 44-point `Join group` control in both empty and loaded Groups states. Add an `Invite` toolbar button to Group Detail. Use the router callbacks rather than constructing sheets inside the feature views. After a successful join, refresh Groups and Activity through `LedgerSession` revision.

- [ ] **Step 5: Register metadata without reserializing the project.** Add `INFOPLIST_KEY_NSCameraUsageDescription = "Barabari uses the camera only when you choose Scan QR."` and a `barabari` URL scheme to the app target's generated Info.plist settings in both Debug and Release. Preserve the existing local `DEVELOPMENT_TEAM` line and unrelated dirty project changes. Verify with `plutil -p` on the built app's Info.plist rather than trusting the project text alone.

- [ ] **Step 6: Refresh the app icon.** Produce the approved Barabari Balance Mark as a square, text-free, near-black icon with soft-mint equal/balance forms, export it to `Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`, and verify `Contents.json` still names the asset `AppIcon`. Do not introduce purple or a rupee glyph.

- [ ] **Step 7: Run navigation tests and a generic device build.**

Run: `xcodebuild -project Barabari/Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' test -only-testing:BarabariUITests/NavigationUITests -only-testing:BarabariUITests/InviteFlowUITests && xcodebuild -project Barabari/Barabari.xcodeproj -scheme Barabari -destination 'generic/platform=iOS' build`

Expected: navigation and invite flows pass, and the generic iOS build succeeds with the camera usage and URL scheme metadata present.

- [ ] **Step 8: Commit integration and app metadata.**

```bash
git add Barabari/Barabari/App/AppRouter.swift Barabari/Barabari/App/BarabariApp.swift Barabari/Barabari/Features/Root/RootView.swift Barabari/Barabari/Features/Groups/GroupsView.swift Barabari/Barabari/Features/Groups/GroupsViewModel.swift Barabari/Barabari/Features/Groups/GroupDetailView.swift Barabari/BarabariUITests/NavigationUITests.swift Barabari/Barabari.xcodeproj/project.pbxproj Barabari/Barabari/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
git commit -m "feat: wire Barabari invite navigation and identity"
```

### Task 7: Full verification and physical iPhone smoke test

**Files:**
- Modify: `Barabari/BarabariUITests/InviteFlowUITests.swift` only if a deterministic accessibility identifier needs correction
- Modify: `Barabari/README.md` with the local-demo invite limitation and the build/run instructions
- Create: `docs/superpowers/verification/2026-09-22-barabari-obsidian-invites.md`

- [ ] **Step 1: Run the full unit and UI suites.**

Run: `xcodebuild -project Barabari/Barabari.xcodeproj -scheme Barabari -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' test`

Expected: all existing tests plus the new domain, persistence, invite, navigation, and join tests pass.

- [ ] **Step 2: Run a clean generic build without touching the working-tree project state.**

Run: `xcodebuild -project Barabari/Barabari.xcodeproj -scheme Barabari -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO`

Expected: the app target compiles for iOS without signing changes.

- [ ] **Step 3: Install and smoke-test on the connected iPhone.** Verify cold launch, tab switching, Create group, Group Detail Invite, QR display, Copy, Share cancellation, Join paste preview, invalid link error, camera denial recovery, duplicate join behavior, keyboard dismissal, dark mode, large text, Reduce Motion, and the home-indicator area. Record the exact device/build result in the verification file.

- [ ] **Step 4: Inspect the built Info.plist and app icon.** Confirm `NSCameraUsageDescription`, `CFBundleURLTypes`, `CFBundleURLSchemes = barabari`, `CFBundleIcons`, and the `AppIcon` asset are present in the built app. Open the app icon in the simulator home screen and verify the near-black/mint mark is crisp.

- [ ] **Step 5: Update README and verification evidence.** Document that invites are local-demo links, list the paste fallback for camera denial, and include the exact test/build commands and pass results. Do not claim cross-device sync.

- [ ] **Step 6: Commit verification documentation only after all checks pass.**

```bash
git add Barabari/README.md docs/superpowers/verification/2026-09-22-barabari-obsidian-invites.md
git commit -m "docs: record Barabari invite verification"
```

## Self-Review

- Spec coverage: the obsidian palette and no-purple rule are Task 3; Liquid Glass and touch rules are Tasks 3 and 7; QR/copy/share are Task 4; paste/scan/join and local-only disclosure are Task 5; deep links and navigation are Task 6; privacy, tests, and device checks are Tasks 1, 2, 5, and 7; deferred backend work is intentionally absent from every implementation task.
- Placeholder scan: all steps name concrete files, APIs, test commands, expected outcomes, and commit messages. No step relies on `TODO`, `TBD`, or unspecified edge-case work.
- Type consistency: `GroupInvitePayload`, `GroupInviteCodec`, `GroupJoinOutcome`, `InvitePresentation`, `JoinGroupViewModel`, and `JoinGroupState` are introduced before the tasks that consume them.
- Review focus coverage: hostile input is tested in Task 1; absent local groups in Tasks 2 and 5; duplicate joins in Task 2; camera denial/unavailable hardware in Task 5; accessibility and appearance conditions in Tasks 3 and 7.
