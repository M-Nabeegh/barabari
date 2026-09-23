# Barabari Obsidian UI and Local Invite Design

**Status:** Awaiting user review

**Date:** 2026-09-22

**Product:** Barabari

**Platform:** Native iPhone app, SwiftUI, iOS 17 minimum, Liquid Glass on iOS 26+

**Related design:** `docs/superpowers/specs/2026-09-20-barabari-smooth-demo-design.md`

## 1. Intent

Make the current Barabari demo feel calm, premium, and dependable on a real iPhone. The visual pass removes the purple and indigo emphasis, improves touch reliability, and gives the product a restrained black, graphite, pearl, and soft-mint identity. The feature pass adds a usable local invite flow with a QR code, copyable link, share sheet, and join preview.

This remains a local-first demo. There is no account service, backend, cross-device synchronization, or remote membership authority in this change. The UI must say that clearly so a copied link is not mistaken for a production invite.

## 2. Success criteria

- The app has no purple or indigo accent in its primary UI.
- Primary actions look intentional in light and dark mode and retain accessible contrast.
- The system tab bar remains the main Liquid Glass navigation surface on iOS 26+, with a native fallback on earlier iOS versions.
- Every invite action is reachable, has a visible result, and handles cancellation or invalid input without a dead end.
- A user can open Invite from a group, view the group name and invite link, show a generated QR code, copy the link, and use the system share sheet.
- A user can paste or scan a Barabari invite, see a join preview, and join when the referenced group exists in the local store and the user is not already a member.
- Duplicate joins are idempotent. Invalid, expired-format, or unsupported links show an actionable error.
- A successful local join refreshes the group people view and activity without relaunching the app.
- Unit and UI tests cover palette roles, payload round-tripping, invalid links, duplicate joins, invite navigation, and the primary touch path.

## 3. Visual language

### 3.1 Color roles

Use semantic roles, not feature-specific hard-coded colors:

- `background`: near-black obsidian in dark mode and pearl gray in light mode.
- `surface`: graphite in dark mode and white in light mode.
- `raised`: elevated graphite in dark mode and cool gray in light mode.
- `accent`: near-black ink in light mode and pearl in dark mode. This is the primary action color, not purple.
- `onAccent`: white in light mode and near-black in dark mode.
- `success`: soft mint for positive balances and completed joins.
- `warning`: amber for caution and pending work.
- `danger`: coral for destructive or invalid states.

The existing color API may keep its stable names to limit call-site churn, but its values and preview labels must express these roles. Do not introduce a new indigo alias or use purple as a fallback.

### 3.2 Surfaces and hierarchy

Cards use solid semantic surfaces with a low-contrast border and restrained shadow. Glass is reserved for interactive chrome. The bottom navigation uses the native `TabView` Liquid Glass treatment on iOS 26+, and a system material fallback on iOS 17 through 25. A compact invite/share control may use custom glass only when it improves affordance and remains readable in Reduce Transparency mode.

Do not make every card translucent. The hierarchy is: ink primary action, mint status, solid content surface, then glass navigation.

### 3.3 Touch and motion

- Every button and row has at least a 44 by 44 point hit target.
- The entire visible row is the hit region, not only its label or icon.
- Saving and joining disable duplicate taps and show local progress.
- Use short native transitions. Respect Reduce Motion and Reduce Transparency.
- Keep content above the home indicator and keyboard without fixed bottom offsets.

## 4. Invite and join experience

### 4.1 Entry points

- Group detail includes an `Invite` action in the navigation bar or header.
- Groups includes `Join group` beside `Create group` when space allows, otherwise in the toolbar menu.
- A shared or opened `barabari://join?...` URL routes into the join preview when the app is running or launched.

### 4.2 Invite sheet

The invite sheet contains:

1. Group name and a short statement that this is a local demo invite.
2. A high-contrast QR image generated on-device with Core Image.
3. The compact invite link in a selectable, copyable field.
4. `Copy link` and `Share link` actions with confirmation feedback.
5. A note that a recipient needs the group data on this same local demo store; cross-device sharing is deferred until a backend exists.

The payload is versioned and contains only the group identifier, a display name for preview, and a non-secret local token/version. It must not contain expense amounts, member balances, or personal data.

### 4.3 Join sheet

Join presents two equal paths:

- `Scan QR`, using the camera only after the user requests it and explaining denial recovery.
- `Paste invite link`, which validates the Barabari URL and payload.

After parsing, show a preview with group name, local availability, and the exact reason if joining cannot proceed. The primary action is `Join group`. On success, dismiss to Groups, select the joined group, and refresh members and activity. If the user is already a member, show the existing group and offer `Open group` rather than creating a duplicate.

Camera scanning should use a small scanner surface and a paste-link fallback. Camera permission is optional to the rest of the app; denial must not block Groups or Add Expense.

### 4.4 Local-only boundary

The join use case checks the local repository. A valid link from another phone cannot create a remote group in V1 because no server exists. The copy, share, and scan UI still demonstrates the complete product shape, while the disclosure prevents a false promise. The data and repository interfaces should leave a narrow seam for a future server-backed invite exchange without adding a service layer now.

## 5. Data and architecture

Add a small domain payload, for example `GroupInvitePayload`, with:

- schema version
- group UUID
- group display name
- local token or revision

Keep the payload `Codable`, URL-safe, and independently testable. Add focused repository/use-case seams:

- create an invite for an existing group
- parse and validate an invite
- join a locally available group idempotently
- return a domain result that distinguishes joined, already a member, unavailable locally, and invalid

The SwiftData repository remains the local implementation. Do not add microservices or a network client for this demo. `AppRouter` owns invite presentation/deep-link routing, while feature views receive explicit callbacks and do not import persistence details. A successful join increments the existing ledger session revision so Groups and Activity refresh predictably.

## 6. Error and privacy rules

- Do not log raw invite URLs, QR contents, or member identifiers.
- Treat arbitrary QR data as untrusted input. Accept only the Barabari scheme and expected versioned payload.
- Keep camera access lazy and scoped to scanning.
- Use clear errors for malformed links, unsupported versions, unavailable local groups, duplicate joins, and camera denial.
- Keep the current local-only privacy copy accurate. No notifications, payment APIs, or cloud sync are introduced.

## 7. Verification plan

### Unit tests

- Semantic palette values have no purple/indigo primary role.
- Payload encode/decode round-trip preserves fields.
- Unsupported scheme, missing fields, bad UUID, and unsupported version fail safely.
- Join adds one member, is idempotent on retry, and reports unavailable local groups.
- QR generator returns a non-empty image for a valid payload.

### UI tests

- Groups shows Create and Join actions and both have stable accessibility identifiers.
- Group detail opens Invite.
- Invite shows QR, Copy, and Share controls.
- Join accepts a pasted valid link and shows a preview/error state.
- Repeated taps do not create duplicate members.
- Light/dark mode and large text preserve action labels and hit targets.

### Build and device checks

- Run focused unit and UI tests plus a generic iOS build.
- Smoke-test on the connected iPhone, including camera denial, copy/share cancellation, keyboard dismissal, tab switching, and the home-indicator area.
- Preserve any existing user-local Xcode project settings. Do not commit a personal development team or replace a dirty `project.pbxproj` wholesale.

## 8. Deferred work

- Real cross-device membership and invite revocation.
- Authentication, server-issued secrets, expiry, and remote notifications.
- Conflict resolution when multiple devices edit the same group.
- Production analytics and crash reporting.

