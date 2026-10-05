# Barabari

**Split fairly. Settle simply.**

Barabari is a Pakistan-first, local-first expense-sharing app for iPhone. V1 records shared expenses in PKR and helps groups track settlements without holding or moving money.

## Run on an iPhone

1. Open `Barabari.xcodeproj` in Xcode 26 or later. The app targets iOS 26 for native Liquid Glass.
2. Select the `Barabari` scheme and your iPhone.
3. In Signing & Capabilities, choose your Apple Developer team if Xcode asks.
4. Press Run.

The app starts in local mode and does not require a backend URL, credentials, contacts, or payment account.

## Demo flows

- First launch plays an animated splash and a four-page intro that asks for your name. Settings can replay it.
- Home leads with an animated emerald balance card, glass quick actions, and a "where your money went" category chart.
- Add expense is a two-step flow: a custom keypad with live `Rs 2,450` formatting, then details with auto-detected categories.
- Group pages let you add and rename people, and share a WhatsApp reminder card for any balance.
- Settings switches appearance and can lock the app with Face ID.
- A home screen widget shows your net balance (small, medium, and Lock Screen sizes).
- Create a group, open it, and choose Invite to generate a QR code and a shareable `barabari://join` link.
- On the Groups screen, choose Join group to paste a link or scan a QR code. In this MVP, joining updates only the local ledger on the current iPhone.
- The native Liquid Glass tab bar keeps Home, Groups, Activity, and Settings one tap away, with Add as a detached glass button. It minimizes while scrolling.

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
