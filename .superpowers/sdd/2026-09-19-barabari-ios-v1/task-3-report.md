# Task 3 Report: Precise PKR Split Calculator

## Scope completed

Implemented the isolated Domain value types and calculator required for expense splitting:

- `Money` uses `Int64` minor units plus an explicit currency code.
- `PercentageBasisPoints` defines 10,000 basis points as 100 percent.
- `ExpenseSplit` and `SplitMethod` are `Equatable`, `Codable`, and `Sendable`.
- `SplitCalculator` supports equal, exact, percentage, and shares methods.
- `SplitError` covers every required invalid input branch.

## Calculation contract

- Barabari V1 accepts PKR only. Any other total currency is rejected with `currencyMismatch`.
- A valid total must be greater than zero.
- Participants are de-duplicated and then ordered by their raw UUID bytes.
- Output order is the canonical UUID-byte order, independent of UI input ordering.
- Equal split remainders go one paisa at a time to the earliest UUID-byte ordered participants.
- Percentage and shares splits use integer floor allocation, followed by deterministic largest-remainder allocation. Tied fractional remainders use UUID-byte ordering.
- Exact totals must reconcile exactly to the total. Negative exact values are rejected.
- Percentage values must be non-negative and total exactly 10,000 basis points.
- Shares must be positive for each participant.
- Supplied split keys must be members of the participant set.
- Proportional multiplication uses `multipliedFullWidth` plus `dividingFullWidth`, avoiding `Double` and ordinary `Int64` multiplication overflow.

## TDD evidence

1. Added `SplitCalculatorTests` before production Domain types.
2. Ran the focused test target against the available iPhone 17 Pro simulator. It failed as expected because `Money`, `SplitMethod`, `ExpenseSplit`, `SplitError`, and `SplitCalculator` did not exist.
3. Implemented the smallest complete Domain calculator.
4. Re-ran focused tests successfully.

The planned iPhone 15 destination was not installed. The available booted destination was `iPhone 17 Pro, iOS 26.5`.

## Test coverage

- Equal split with a UUID-order remainder.
- Equal split conservation of the full total.
- Valid exact split and invalid exact total.
- Valid 100-percent basis-point split and invalid percentage total.
- Shares split with proportional allocation and invalid zero shares.
- Unknown participant.
- Empty participant list.
- Non-positive total.
- Non-PKR currency.
- Exact conservation assertions in every successful calculation case.

## Verification

Passed focused test run:

```text
xcodebuild -project Barabari.xcodeproj -scheme Barabari \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test -only-testing:BarabariTests/SplitCalculatorTests

12 tests, 0 failures
```

Passed full unit test run:

```text
xcodebuild -project Barabari.xcodeproj -scheme Barabari \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test -only-testing:BarabariTests

19 tests, 0 failures
```

Passed simulator build:

```text
xcodebuild -project Barabari.xcodeproj -scheme Barabari \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

BUILD SUCCEEDED
```

## Concerns and follow-up

- The app is intentionally PKR-only in V1. Multi-currency should be introduced as a dedicated product and migration decision, not by silently relaxing the split calculator.
- A later ledger task should preserve the canonical split result returned by this calculator rather than recomputing amounts from UI inputs.
- Participants are de-duplicated defensively. The future Group domain should still prevent duplicate group-member records at the model and persistence layers.

## Review follow-up: deterministic weighted remainder coverage

Added regression tests for the review findings without changing production behavior:

- Percentage split with a one-paisa total and equal 5,000-basis-point fractions. The first UUID-byte ordered participant receives the paisa even when provided second in UI order.
- Shares split with a one-paisa total and equal shares. The first UUID-byte ordered participant receives the paisa even when provided second in UI order.
- Negative exact amount, negative percentage basis points, and negative share weights.
- Duplicate participant input normalization, proving a duplicate ID cannot become a second debtor.

Focused verification after the follow-up:

```text
xcodebuild -project Barabari.xcodeproj -scheme Barabari \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test -only-testing:BarabariTests/SplitCalculatorTests

18 tests, 0 failures
TEST SUCCEEDED
```

Full unit verification after the follow-up:

```text
xcodebuild -project Barabari.xcodeproj -scheme Barabari \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test -only-testing:BarabariTests

25 tests, 0 failures
TEST SUCCEEDED
```
