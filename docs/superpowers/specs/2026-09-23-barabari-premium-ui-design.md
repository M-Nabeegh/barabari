# Barabari Premium UI Design

**Status:** Awaiting written-spec approval

**Date:** 2026-09-23

**Product:** Barabari native iPhone app

**Parent specification:** `docs/superpowers/specs/2026-09-19-barabari-design.md`

## 1. Objective

Make the existing local Barabari demo feel like a premium native financial product while keeping it fast, calm, accessible, and recognisably Barabari.

The approved direction is **quiet luxury**:

- spacious layouts with strong information hierarchy;
- black, pearl, graphite, and restrained mint;
- one obvious primary action per screen;
- tactile controls and restrained motion;
- useful detail instead of decorative dashboards;
- native SwiftUI and Apple frameworks only;
- no change to the ledger-only product boundary.

The result should feel polished on a real iPhone in both supported themes without introducing heavy rendering, broad view invalidation, or fragile navigation behavior.

## 2. Selected visual direction

Three directions were considered:

1. **Quiet luxury, selected.** Monochrome foundations, restrained mint, excellent typography, subtle depth, and meaningful motion.
2. **Expressive fintech, rejected.** Brighter group colours, illustrations, and more visible animation would add personality but weaken the calm financial tone.
3. **Dense utility, rejected.** More controls and data per screen would improve power-user density but make the first-use experience feel like accounting software.

Quiet luxury is the only direction to implement in this pass.

## 3. Scope

### 3.1 Premium application experience

The implementation covers:

- a smarter contextual Home hero;
- premium group cards with deterministic identities and useful summaries;
- a faster amount-first Add Expense flow with a sticky action;
- a complete digital-receipt expense detail screen;
- a day-grouped Activity timeline;
- a restrained settlement-completion success moment;
- exactly two named themes, Obsidian and Pearl;
- optional local Face ID app lock;
- polished skeleton, empty, error, offline, and success states;
- a small home-screen widget surface, gated by App Group signing availability;
- accessibility and performance verification for all new presentation work.

### 3.2 Product boundaries

This remains a local-first ledger demo. The work must not:

- transfer or hold money;
- imply that Raast, Easypaisa, JazzCash, cash, or bank settlements were executed by Barabari;
- add authentication, cloud sync, contacts access, analytics, advertising, or tracking;
- add receipt OCR, bank linking, lending, or payment credentials;
- add charts merely to fill space;
- add a third-party design, animation, biometric, or widget dependency.

## 4. Theme system

### 4.1 Supported themes

Settings will expose exactly two choices:

#### Obsidian

- Default on first install.
- Background: `#090A0C`.
- Surface: `#15171A`.
- Raised surface: `#22252A`.
- Primary text and primary actions: pearl white.
- Secondary text: cool neutral grey.
- Success and identity accent: `#92E6BE` mint.
- Warning and danger remain semantic and accessible.

#### Pearl

- Warm off-white background rather than stark system white.
- White primary surfaces with warm neutral raised surfaces.
- Ink-black primary text and primary actions.
- Deep green semantic success derived from the Barabari mint.
- Identical spacing, typography, information hierarchy, and component shapes to Obsidian.

### 4.2 Theme architecture

`BarabariAppearance` becomes `.obsidian` and `.pearl`. Existing stored values for `dark`, `light`, or `system` must migrate safely:

- `dark` maps to Obsidian;
- `light` maps to Pearl;
- `system` maps to Obsidian to preserve the app's intended default identity.

The selected appearance remains in `@AppStorage`. Feature views continue to consume semantic design-system values rather than hard-coded theme colours.

The theme implementation must support increased contrast, Dynamic Type, VoiceOver, and Reduce Motion. Colour must never be the sole carrier of debt, credit, success, or error meaning.

## 5. Motion and tactile language

Motion must make state changes easier to understand, not slow the user down.

### 5.1 Motion rules

- Control press feedback: 120 to 180ms.
- Small state transitions: 180 to 240ms.
- Success moment: no more than 700ms before the interface is fully usable.
- Tab switching remains immediate. Only the selected Liquid Glass capsule and its icon state animate.
- List entrance animation is limited to the first visible items and must not replay after every refresh.
- No continuous animation, decorative background motion, or full-screen particle systems.
- Reduce Motion replaces scale, bounce, and movement with a short opacity transition or no transition.

### 5.2 Haptics

- Selection haptic for split method, group, payer, and settlement method changes.
- Light impact for card presses only when it communicates navigation or selection.
- Success haptic after a confirmed expense or settlement write.
- Error haptic only after actionable validation failure.
- Respect the existing Haptics setting.

### 5.3 Performance constraints

- No expensive sorting, filtering, formatting, image generation, or persistence fetches in a SwiftUI `body`.
- Derived presentation data is prepared by view models or small pure presentation helpers.
- Collections use stable domain IDs.
- No custom blur implementation.
- No broad animation around root navigation or complete feature hierarchies.
- No glass effect on ordinary cards, rows, receipt sections, or screen backgrounds.

## 6. Screen designs

### 6.1 Home

The Home hero becomes contextual rather than merely showing a net number.

The hero displays:

- the current net position;
- a human sentence such as “You owe Member 2 PKR 1,000,” “Member 2 owes you PKR 1,000,” or “Everything is settled”;
- a small deterministic member or group identity badge when a single most-relevant debt can be identified;
- one contextual action: `Settle up`, `Open group`, or `Add expense`;
- the existing owed and owing breakdown beneath the primary message.

Recent activity remains compact and shows no more than the bounded Home limit. It should use the same timeline language as the full Activity screen without duplicating the full screen.

Loading uses lightweight skeleton shapes matching the final hero and activity rows. Failure keeps a short explanation and one retry action. Offline state remains explicit.

### 6.2 Groups

Each group card displays:

- a deterministic monogram identity derived from the group name;
- the group name and optional description;
- member count;
- most recent activity date or “No activity yet”;
- the current user's group status: settled, owed, or owing;
- a chevron and full-card hit target.

Group identity colour comes from a tiny theme-aware palette and remains subordinate to the monochrome application palette. It is not user-configurable in this pass and must maintain readable contrast.

Cards use the existing single card treatment, subtle pressed scale, and no static decorative gradient. The Join Group callout remains distinct from actual group cards.

### 6.3 Add Expense

The default equal-split path must feel fast and should not require the user to hunt for the save action.

The screen keeps amount first, followed by title. It adds:

- optional quick amount chips for `PKR 500`, `PKR 1,000`, and `PKR 2,500` when the amount is empty;
- smart reuse of the most recently selected group and payer during the current app session;
- a compact summary for the default equal split;
- progressive disclosure for exact and future advanced split controls;
- a sticky `Save expense` action immediately above the custom tab bar or keyboard safe area;
- an always-visible validation summary near the sticky action when saving is unavailable;
- a short local confirmation state after persistence succeeds.

The sticky action must not overlap the keyboard, content, or Liquid Glass tab bar. Switching tabs while a field is focused must continue to dismiss the keyboard in one tap.

### 6.4 Expense detail

Expense detail becomes a digital receipt rather than a title and amount placeholder.

It displays:

- amount, title, date, and group;
- payer identity;
- participant list with each person's exact share;
- split method;
- local-only status copy;
- notes when present;
- actions to duplicate and share the receipt representation;
- edit and soft-delete only if the existing domain and repository interfaces support them safely in this implementation pass.

The view obtains group and member presentation data through a dedicated `ExpenseDetailViewModel`. The view must not perform repository scans or member-name joins in `body`.

Sharing produces a concise text receipt in this local demo. It must not imply a payment receipt or provider confirmation.

### 6.5 Activity

Activity is grouped into deterministic calendar sections:

- Today;
- Yesterday;
- a formatted date for older entries.

Each row has a semantic symbol, primary description, supporting group or member information, time, and a clear detail destination. Timeline lines are visual decoration only and are hidden from accessibility.

Pagination retains loaded rows when a later page fails and presents a compact retry footer. Initial failure remains a full-screen recoverable state. The known failed-to-empty state overwrite must be corrected as part of this work.

### 6.6 Settlement success

After a settlement is recorded:

- balances update immediately;
- a checkmark success state appears;
- one success haptic fires when enabled;
- if the group is now settled, the copy reads “All settled” and a restrained mint sparkle ring appears for no more than 700ms;
- Reduce Motion shows the final checkmark without bounce or sparkles.

This is a confirmation that a ledger entry was recorded, not proof that an external payment was transferred.

### 6.7 Loading, empty, error, and offline states

Every primary feature receives a consistent state treatment:

- skeletons for short predictable local loads;
- meaningful icon, sentence, and one action for empty states;
- action-specific error copy and retry;
- explicit offline or local-only status where relevant;
- no spinner-only full screen unless the destination cannot yet render any useful structure.

## 7. Local Face ID lock

Settings adds an optional `Require Face ID` control when biometry is available.

Behavior:

- Off by default.
- Enabling requires a successful biometric evaluation.
- The app locks after entering the background and requires evaluation when active again.
- A cancel or failed evaluation leaves a dedicated locked screen with `Try Face ID again`.
- If biometry becomes unavailable, Settings explains the state and does not trap the user behind an impossible prompt.
- Simulator and tests use an injected evaluator rather than invoking real biometric UI.

The feature is a local presentation gate. It does not replace iOS file protection, encrypt the SwiftData store independently, or claim banking-grade account security.

`NSFaceIDUsageDescription` must clearly explain that Face ID protects the local Barabari ledger on the device.

## 8. Home-screen widgets

The widget surface is intentionally small:

- small widget: current net position and local status;
- medium widget: net position, owed, owing, and an `Open Barabari` action;
- no sensitive member names on the lock screen or widget by default;
- no background network work.

The app writes a minimal `WidgetSnapshot` to an App Group `UserDefaults` suite after ledger changes. The widget reads only this snapshot and never opens the SwiftData store directly.

Widget implementation is gated by App Group entitlement availability for the selected Apple Developer team. The main app must remain buildable and runnable if this entitlement is unavailable. If signing cannot support App Groups, the widget target is deferred without blocking the premium application update.

## 9. Component architecture

New presentation components should remain small and independently testable:

- `BarabariTheme` or equivalent semantic theme token provider;
- `BarabariSkeleton`;
- `GroupIdentityBadge`;
- `ContextualBalanceHero`;
- `StickyActionBar`;
- `ReceiptSection` and `ReceiptParticipantRow`;
- `ActivityDaySection` and `ActivityTimelineRow`;
- `SettlementSuccessMoment`;
- `AppLockController` with a biometric-evaluator protocol;
- `WidgetSnapshot` and `WidgetSnapshotWriter`.

Feature-specific business logic remains in feature view models. Reusable presentation rules belong in DesignSystem or a pure presentation helper. Financial domain models, split calculations, and repositories must not depend on SwiftUI theme or animation types.

## 10. Data flow

### 10.1 Existing ledger data

Home, group summaries, expense details, activity, and settlements continue to use repositories composed by `AppEnvironment`. New view models transform domain values into bounded, stable presentation models.

### 10.2 Theme

Settings writes the selected named appearance. Root applies its colour scheme. Semantic design-system colours resolve consistently for that scheme.

### 10.3 App lock

Settings writes only the enabled preference. The lock controller observes app lifecycle changes and requests biometric evaluation through an injected interface.

### 10.4 Widget

After `LedgerSession.markChanged()`, the application produces a privacy-minimised widget snapshot and asks WidgetKit to refresh the relevant timeline.

## 11. Accessibility

- All interactive targets remain at least 44 by 44 points.
- The sticky save action is reachable with VoiceOver and does not reorder focus unexpectedly.
- Group monograms have meaningful group labels, not spoken colour names.
- Receipt participant rows combine name and share into one useful accessibility element.
- Timeline decoration is hidden from VoiceOver.
- Dynamic Type is tested at accessibility sizes for Home hero, group cards, sticky action, receipt rows, Activity headings, Settings, and biometric lock copy.
- Reduce Motion is tested for entrance, selected-tab, and settlement-success behavior.
- Increased contrast is tested in both themes.

## 12. Testing and verification

### 12.1 Unit tests

- appearance migration and Obsidian/Pearl mapping;
- contextual Home hero presentation for owing, owed, and settled states;
- deterministic group monogram and palette selection;
- activity day grouping across Today, Yesterday, and older dates;
- Activity initial and pagination failure behavior;
- expense-detail member and share presentation;
- biometric lock lifecycle through a fake evaluator;
- widget snapshot privacy and encoding.

### 12.2 UI tests

- switch between Obsidian and Pearl and verify persistence after relaunch;
- add an equal expense using the sticky action;
- keyboard dismissal and one-tap tab switching remain stable;
- open a complete digital receipt;
- view grouped Activity and open a row;
- record a settlement and observe the final success state;
- biometric unavailable, cancelled, and successful flows through launch arguments;
- representative Dynamic Type and Reduce Motion configurations.

UI fixtures must be deterministic and isolated from persistent preferences. Standard test launch controls should include:

- reset defaults and appearance;
- select Obsidian or Pearl explicitly;
- inject a fixed clock and `Asia/Karachi` timezone for Activity grouping;
- select owing, owed, settled, error, offline, and pagination-failure states;
- select biometric success, cancellation, failure, and unavailable states;
- select a complete receipt and full-debt fixture.

Tests must wait for stable identifiers and enabled states rather than sleeping or tapping a primary action twice. Decimal-pad dismissal uses the explicit keyboard Done control. Camera scanning, system share sheets, and real biometric prompts are replaced by deterministic boundary tests in the automated suite.

### 12.3 Performance verification

- Run the complete existing test suite plus new tests.
- Build and run on the current simulator configuration.
- Stress repeated tab switching and keyboard transitions.
- Verify that the custom tab selection and press animations respect Reduce Motion.
- Verify the sticky expense action remains hittable above both the keyboard and Liquid Glass navigation.
- Perform a code-first SwiftUI performance audit after implementation.
- Capture one focused performance trace if physical-device interaction still feels slow.
- Do not claim physical-device smoothness until it is tried on the user's iPhone.

## 13. Implementation order

1. Theme tokens and Obsidian/Pearl migration.
2. Shared premium components and state treatments.
3. Home hero and group cards.
4. Add Expense sticky action and progressive disclosure.
5. Expense digital receipt.
6. Activity grouping and error-state correction.
7. Settlement success moment.
8. Local Face ID lock.
9. Widget snapshot contract and optional widget target after signing-capability verification.
10. Accessibility, performance, regression, simulator, and physical-device handoff verification.

This sequence keeps each slice independently testable and preserves a runnable app throughout the work.

## 14. Acceptance criteria

The premium UI pass is accepted when:

- Obsidian and Pearl are the only user-facing appearance choices and persist correctly;
- the five main tabs remain instant and stable;
- the common equal-expense path has a visible sticky save action;
- expense details show payer, participants, shares, date, group, and split method;
- Activity is grouped by day and retains loaded rows after a pagination failure;
- settlement confirmation clearly distinguishes ledger recording from payment execution;
- optional Face ID lock behaves safely across background and foreground transitions;
- the app remains fully usable with Reduce Motion and large Dynamic Type;
- no new app-level runtime warnings, navigation crashes, or dropped-tab regressions are introduced;
- the complete automated test suite passes;
- the main app remains buildable when widget signing requirements are not available.
