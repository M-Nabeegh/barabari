# Barabari Premium Experience Program

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement these plans task-by-task. Every implementation task, including small fixes, must use `model="gpt-5.6-luna"` with `reasoning_effort="max"`. Use a fresh Luna Max reviewer after every task and a final Luna Max whole-branch reviewer.

**Goal:** Deliver the approved quiet-luxury Barabari experience without coupling visual polish, local app locking, and widget signing work into one risky change.

**Architecture:** Execute three independently testable plans in order. The core premium UI plan changes only the existing app target. Local app lock follows behind an injected authentication boundary. Widget support is last because it requires a separate target and an Apple App Group entitlement.

**Tech Stack:** Swift 5 language mode in the current Xcode toolchain, SwiftUI, SwiftData, XCTest/XCUITest, LocalAuthentication, WidgetKit, native iOS 26 Liquid Glass with the existing pre-iOS-26 fallback.

**Spec:** `docs/superpowers/specs/2026-09-23-barabari-premium-ui-design.md`

## Execution order

0. Preserve and isolate the current user-owned Xcode project-file baseline.
1. `docs/superpowers/plans/2026-09-23-barabari-premium-core-ui.md`
2. `docs/superpowers/plans/2026-09-23-barabari-local-app-lock.md`
3. `docs/superpowers/plans/2026-09-23-barabari-widget.md`

Each plan must finish with a passing complete suite and a runnable simulator build before the next begins.

## Required preflight: Xcode project baseline

`Barabari/Barabari.xcodeproj/project.pbxproj` currently contains a large user-owned Xcode reserialization and signing change relative to `HEAD`. Hunk staging is not a safe way to mix new source registration into that uncommitted rewrite.

Before any implementation agent creates a file:

1. Capture `git diff -- Barabari/Barabari.xcodeproj/project.pbxproj` and validate the current project with `xcodebuild -list` plus a simulator build.
2. Present the exact project-file-only diff summary to the user and obtain confirmation that it represents the Xcode/signing state they want preserved.
3. Commit that one file alone as `chore: preserve Xcode project settings`.
4. Confirm the worktree is otherwise unchanged and subsequent project-file diffs are task-owned and reviewable.

If the user does not approve baselining that file, stop before implementation and restructure the plan with them. Do not use `git add -p`, stash, reset, or a generated replacement project to work around the unresolved ownership boundary.

At the same preflight, run `xcodebuild -showdestinations -project Barabari/Barabari.xcodeproj -scheme Barabari`, select one currently available iPhone Simulator, and use its UDID for every command in the execution session. Plan commands refer to it as `$BARABARI_SIMULATOR_UDID`.

## Agent policy

- Use one fresh Luna Max implementation agent per numbered task.
- Use one fresh Luna Max specification reviewer and one fresh Luna Max code-quality reviewer per task.
- Do not run two implementation agents concurrently when their file lists overlap.
- Review agent output locally and run the task's verification commands before committing or accepting completion.
- Never start source registration until the required project-file baseline above is approved and committed.
- Stop and report if an agent requests a product-scope decision not settled by the approved specification.

## Program completion gate

- Core premium UI passes the complete unit and UI suite.
- Local app lock passes injected success, cancellation, failure, unavailable, and lifecycle tests.
- Widget work either passes its entitlement gate and builds both targets, or is documented as deferred without changing the main app's buildability.
- Final simulator build is launched for user testing.
- Physical-device smoothness remains unclaimed until the user tries the build on the connected iPhone.
