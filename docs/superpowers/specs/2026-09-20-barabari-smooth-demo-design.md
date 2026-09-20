# Barabari Smooth Demo Polish Design

**Status:** Approved for implementation planning

**Date:** 2026-09-20

**Product:** Barabari

**Platform:** Native iPhone app, SwiftUI, iOS 17 minimum, Liquid Glass on iOS 26+

**Related canonical design:** `docs/superpowers/specs/2026-09-19-barabari-design.md`

## 1. Purpose

This design upgrades the existing local Barabari demo into a reliable, polished, and convincing iPhone experience. The pass focuses on touch reliability, persistent navigation state, responsive rendering, complete demo actions, native Liquid Glass composition, and a real app icon. It does not add backend authentication, cloud sync, payment initiation, or production account management.

The existing domain model, integer PKR arithmetic, SwiftData persistence, expense splitting, balances, and settlement validation remain the foundation. The redesign changes the app shell and feature presentation around those boundaries rather than rewriting the ledger.

## 2. Goals

- Make every visible interactive control respond reliably on a physical iPhone.
- Preserve drafts and navigation state when switching tabs.
- Use native iOS navigation and safe-area behavior wherever possible.
- Use Liquid Glass for navigation and primary actions without turning every card into glass.
- Keep all demo-visible features either functional locally or removed from the surface.
- Make Home, Groups, Add Expense, Activity, and Settings feel like one coherent product.
- Reduce avoidable main-actor work and prove responsiveness with tests and Instruments.
- Add a distinctive Barabari app icon using an equal/balance visual language.

## 3. Non-goals

- Backend deployment or authentication.
- Network sync, invite links, QR codes, push notifications, or payment-provider APIs.
- Wallet functionality, payment custody, bank linking, SMS parsing, OCR, lending, or multi-currency support.
- A chart-heavy analytics dashboard.
- A custom design system that replaces native controls without a measured need.

## 4. Evidence from the current demo

### 4.1 Touch and state risks

- `RootView` overlays a custom tab bar in a `ZStack` and reserves a hard-coded 78 points for it. The bar can compete with scroll content and keyboard-safe areas.
- `RootView.selectedContent` switches the entire feature tree. Add Expense, Activity, and Settings can be recreated when tabs change, losing local state or starting another load.
- The custom tab bar applies one interactive glass surface to the whole HStack instead of using the system tab container.
- The Groups create button is 40 by 40 points. Balance settlement rows do not define a 44-point minimum hit area.
- Add Expense and Settlement reserve different fixed bottom paddings, so the visual and interactive safe area is not owned by one component.

### 4.2 Performance risks

- `AmountFormatter.string` creates a `NumberFormatter` every time an amount view renders.
- Activity loads all pages, joins detail records, sorts, and maps rows during one view task, then renders all rows.
- Group selection starts an unstructured task for member loading, so rapid selection can race and publish stale members.
- Root-level tab replacement restarts screen tasks and creates avoidable loading transitions.

### 4.3 Demo completeness risks

- Join Group and several Settings rows only display future-work messages.
- Activity rows do not navigate to details.
- Expense detail is not reachable from the main Activity experience.
- Screen refresh after a local expense or settlement is implicit rather than driven by an explicit ledger revision.
- The target has no configured app icon asset or Icon Composer file.

## 5. Design decisions

### 5.1 Navigation shell

Use a persistent native `TabView(selection:)` as the root shell. Each tab owns a `NavigationStack` and stable route state. The `AppTab` enum remains the single source of truth for tab identity, labels, and symbols.

The native tab bar is the Liquid Glass surface on iOS 26 and the system material tab bar on earlier supported releases. A custom glass overlay is not used for primary navigation. This gives the system responsibility for hit testing, home-indicator spacing, Dynamic Type, VoiceOver, keyboard movement, and tab selection animation.

The Add tab is a real tab in V1, with a visually prominent symbol and one primary action. It does not intercept selection or open an unrelated modal.

### 5.2 Feature state and refresh

Root owns a small `LedgerSession` observable object:

```swift
@MainActor
final class LedgerSession: ObservableObject {
    @Published private(set) var revision = 0

    func markChanged() {
        revision &+= 1
    }
}
```

Feature views receive the revision and explicit save callbacks. Home, Groups, Activity, and Group Detail use `.task(id: revision)` or an equivalent view-model method to refresh after a local write. Add Expense and Settlement call `markChanged()` only after a repository write succeeds. This keeps synchronization explicit without putting SwiftData into view code or making every feature observe a broad global model.

Draft state belongs to the Add Expense view model and is retained while the tab remains in the shell. Loading tasks must be cancellable and keyed by the selected group.

### 5.3 Touch contract

- Every tappable control has a minimum 44 by 44 point hit area.
- A row button applies `.contentShape(Rectangle())` to its complete visible row.
- The button remains enabled until an action starts, then shows a local saving state and ignores duplicate taps.
- Keyboard dismissal uses focus state and does not move the navigation bar over form controls.
- UI tests exercise repeated tab switches, repeated save taps, and controls near the bottom safe area.

### 5.4 Liquid Glass contract

- Native `TabView` provides the primary glass navigation on iOS 26+.
- Custom glass is limited to small, meaningful interactive surfaces such as a prominent Add action or a compact confirmation control.
- Multiple custom glass shapes are grouped in one `GlassEffectContainer`.
- `.glassEffect` is applied after layout and appearance modifiers.
- Non-glass material and solid-color fallbacks remain available for iOS 17 through 25.
- Glass is not applied to every card, list row, or background because excessive material reduces hierarchy and increases rendering work.

### 5.5 Feature surface

The demo surface contains only actions that work locally:

- Home: current-user balance, recent activity, and a working route to Groups.
- Groups: list, create group, open detail, and a clear empty state. Join Group is hidden until a local join flow exists.
- Add Expense: amount-first entry, equal and exact split, payer, participants, preview, save, confirmation, and draft retention.
- Group Detail: balance transfers, people, latest activity, settlement navigation, and refresh after settlement.
- Activity: incremental list, expense and settlement detail navigation, empty/loading/error states.
- Settings: working appearance preference, haptics preference, privacy explanation, local export, and truthful local-demo status. Account deletion and remote notifications are not shown in this local build.

### 5.6 Performance contract

- Cache the PKR formatter and avoid constructing formatters in `body`.
- Move activity joining, sorting, and formatting into an `@MainActor` view model task that publishes a value-semantic row model.
- Render activity with `LazyVStack` and load additional pages as the last visible row appears.
- Keep `ForEach` identity based on stable UUIDs.
- Avoid broad observation of repository objects from leaf views.
- Use Instruments on a Release build of the physical iPhone to validate hitches and hangs after code-level fixes.

### 5.7 Icon direction

The recommended mark is the **Barabari Balance Mark**: two mirrored rounded forms that suggest an equal sign and a subtle B. It uses a deep ink base with restrained teal/cyan foreground layers, no text, no rupee glyph, and no generic wallet imagery. Three visual candidates will be generated and reviewed before one is finalized.

The final production asset uses Icon Composer where available, with vector or high-resolution layers and an asset-catalog fallback for older targets. The target's app-icon build setting will point at the intentional asset name.

### 5.8 Xcode project hygiene

The screenshot's recommendations are accepted selectively:

- Recommended warnings: enabled.
- Build Active Architecture Only: enabled for Debug and left disabled for Release.
- User Script Sandboxing: enabled.
- String Catalog symbol generation: enabled when the localizable catalog is added.
- Generated asset symbol extensions: enabled after the asset catalog exists.

The existing user-specific `DEVELOPMENT_TEAM` value stays local and is not added to shared source-control settings. Xcode's large automatic project reserialization is normalized before implementation commits. Generated workspace metadata is committed only if the project requires it.

## 6. Module boundaries

### App

- `RootView` owns the persistent tab shell, tab selection, per-tab routes, `LedgerSession`, and app-level haptic preference.
- `AppRouter` defines stable tab and route identity.

### Design system

- Design tokens and reusable cards/buttons remain value-oriented and do not own navigation.
- `BarabariTabBar` becomes a fallback-only component if native `TabView` handles the primary navigation.
- Amount formatting is cached behind a small formatter type.

### Features

- View models own asynchronous loading and form validation.
- Views own only focus, presentation, and ephemeral selection state.
- Feature views receive explicit environment, revision, and callbacks instead of importing persistence implementation details.

### Data and domain

- Domain models, split calculation, balance calculation, and use cases remain unchanged unless a focused interface is needed for activity pagination or local export.
- SwiftData repositories remain actors and continue to return domain values.

## 7. Definition of done

- No visible demo control is a dead end.
- Every interactive target is at least 44 by 44 points.
- Switching tabs does not lose an unfinished expense draft.
- A successful expense or settlement updates relevant balances and Activity without relaunching.
- Activity uses stable identity and incremental rendering.
- Light mode, dark mode, large text, VoiceOver labels, Reduce Motion, keyboard use, and home-indicator spacing are validated.
- The app icon appears on a real device and in the simulator.
- Generic iOS build, focused unit tests, UI tests, and a signed physical-device smoke test pass.
- A Release Instruments run shows no interaction-blocking hang and no reproducible missed tap.

