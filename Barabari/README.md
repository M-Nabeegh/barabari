# Barabari

**Split fairly. Settle simply.**

Barabari is a Pakistan-first, local-first expense-sharing app for iPhone. V1 records shared expenses in PKR and helps groups track settlements without holding or moving money.

## Run on an iPhone

1. Open `Barabari.xcodeproj` in Xcode 26 or later.
2. Select the `Barabari` scheme and your iPhone.
3. In Signing & Capabilities, choose your Apple Developer team if Xcode asks.
4. Press Run.

The app starts in local mode and does not require a backend URL, credentials, contacts, or payment account.

## Demo flows

- The first screen opens in the obsidian dark theme. Settings can switch the appearance back to system or light mode.
- Create a group, open it, and choose Invite to generate a QR code and a shareable `barabari://join` link.
- On the Groups screen, choose Join group to paste a link or scan a QR code. In this MVP, joining updates only the local ledger on the current iPhone.
- The Liquid Glass navigation bar keeps Home, Groups, Add, Activity, and Settings reachable with a single tap.

## Development configuration

`Barabari/Config/Debug.xcconfig` contains non-secret development defaults. If a remote backend is introduced, place machine-local provider values in `Barabari/Config/Local.xcconfig`. That optional file is included only when present and is ignored by Git, so a clean checkout always builds without secrets.

## Architecture

- SwiftUI presentation layer
- SwiftData local persistence
- In-memory seeded data for SwiftUI previews and demo development
- Domain, data, and feature boundaries to keep future backend adapters independent

See `docs/superpowers/specs/2026-09-19-barabari-design.md` for the approved V1 product design.

## Verification

Run the full local test suite from the repository root:

```sh
xcodebuild -project Barabari/Barabari.xcodeproj -scheme Barabari \
  -destination 'platform=iOS Simulator,id=3A10C54D-4D4B-4BEC-B196-68EE205462B0' test
```

The QR scanner requests camera access only after Scan QR is selected. No camera, contacts, notification, payment, or cloud-sync service runs in the MVP.
