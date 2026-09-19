# Barabari

**Split fairly. Settle simply.**

Barabari is a Pakistan-first, local-first expense-sharing app for iPhone. V1 records shared expenses in PKR and helps groups track settlements without holding or moving money.

## Run on an iPhone

1. Open `Barabari.xcodeproj` in Xcode 26 or later.
2. Select the `Barabari` scheme and your iPhone.
3. In Signing & Capabilities, choose your Apple Developer team if Xcode asks.
4. Press Run.

The app starts in local mode and does not require a backend URL, credentials, contacts, or payment account.

## Development configuration

`Barabari/Config/Debug.xcconfig` contains non-secret development defaults. If a remote backend is introduced, place machine-local provider values in `Barabari/Config/Local.xcconfig`. That optional file is included only when present and is ignored by Git, so a clean checkout always builds without secrets.

## Architecture

- SwiftUI presentation layer
- SwiftData local persistence
- In-memory seeded data for SwiftUI previews and demo development
- Domain, data, and feature boundaries to keep future backend adapters independent

See `docs/superpowers/specs/2026-09-19-barabari-design.md` for the approved V1 product design.
