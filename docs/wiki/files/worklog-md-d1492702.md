# File: WORKLOG.md

## Current Role

- Area: Repository support.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`WORKLOG.md`](../../../WORKLOG.md) |
| Wiki area | Repository support |
| Exists in current checkout | True |
| Size | 50371 bytes |
| Binary | False |
| Line count | 411 |
| Extension | `.md` |

## Imports

None detected.

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| None detected |  |  |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `675fabf` | 2026-04-17 | Ship 14.0.5 helper recovery release |
| `099460c` | 2026-04-16 | Refine overview alert status strip |
| `bd91092` | 2026-04-16 | Fix merged disk refresh regression |
| `cea99a5` | 2026-04-16 | Finish silent mode cleanup |
| `70ef30c` | 2026-04-16 | Refresh competitor supportability notes |
| `423587b` | 2026-04-16 | Stabilize unit test app bootstrap |
| `ebf3e12` | 2026-04-16 | Retire redundant silent fan mode |
| `a5b84af` | 2026-04-16 | Clarify README product stance and install flow |
| `6fcd312` | 2026-04-16 | Throttle slow-moving system monitor reads |
| `0836e11` | 2026-04-16 | Clarify README product positioning |
| `6cabf2c` | 2026-04-16 | Make onboarding copy platform-aware |
| `3094642` | 2026-04-16 | Cache disk activity away from menu bar renders |
| `2dae7aa` | 2026-04-16 | Prevent duplicate Core Monitor launches |
| `133d9ad` | 2026-04-16 | Replace alert surfaces with monitoring status |
| `a570f09` | 2026-04-16 | Scope detailed sampling to active monitoring views |
| `cfea009` | 2026-04-16 | Polish launch-at-login recovery flow |
| `767668c` | 2026-04-16 | Throttle disk stats refresh cadence |
| `f2db2d4` | 2026-04-16 | Show live network rates in menu bar settings preview |
| `58feb7a` | 2026-04-16 | Add network menu bar item and popover |
| `d837bc2` | 2026-04-16 | Add menu bar setup and help shortcuts |
| `3672312` | 2026-04-16 | Promote dashboard shortcut in onboarding |
| `5fe6a4c` | 2026-04-16 | Harden first-launch startup and onboarding state |
| `7c0c8d6` | 2026-04-16 | Add dashboard shortcut and app menu access |
| `be75b81` | 2026-04-16 | Add dashboard network throughput visibility |
| `b8fd8a6` | 2026-04-16 | Clarify silent mode helper handoff semantics |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
# WORKLOG

## 2026-04-17

### Completed batch
- Reworked the privileged fan-control backend around the Apple-Silicon-first `agoodkind/macos-smc-fan` research model instead of leaving Core Monitor on a purely local ad hoc implementation.
- Kept Core Monitor's stricter helper boundary checks, but aligned the low-level control path with runtime mode-key probing (`F%dMd` vs `F%dmd`), direct-write-first behavior, and `Ftst`-only fallback semantics.
- Fixed a helper reset edge case so returning one fan to auto no longer clears `Ftst` while other fans are still in manual mode.
- Expanded helper diagnostics exports to record the upstream backend reference plus detected mode-key and `Ftst` availability, then added regression coverage for those new report fields.
- Corrected the `SMPrivilegedExecutables` and `SMAuthorizedClients` requirement strings back to the Team ID check after proving the sample-style Apple Development certificate OIDs broke `SMJobBless` for local signed builds.
- Corrected the raw helper `Info.plist` metadata after proving the `-sectcreate` path was embedding literal `$(PRODUCT_...)` placeholders into the blessed helper binary instead of concrete executable and bundle identifiers.

## 2026-04-15

### Reviewed
- Repository structure, app bootstrap, menu bar controller, dashboard window flow, `SystemMonitor`, fan control, helper/XPC path, and current docs.
- Current build and test health with `xcodebuild` on macOS.
- Runtime behavior far enough to confirm the app launches as menu bar items and relies on menu bar access by default.

### Baseline
- `xcodebuild -project Core-Monitor.xcodeproj -scheme Core-Monitor -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build` succeeded.
- `xcodebuild -project Core-Monitor.xcodeproj -scheme Core-Monitor -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test` succeeded.
- The worktree already contained significant local changes, so all edits in this session are layered on top without reverting in-progress work.

### Prioritized action list
- Improve menu bar configuration UX and reduce menu bar clutter friction with presets and clearer live-item controls.
- Keep chipping away at the oversized SwiftUI surfaces, starting with `ContentView.swift`.
- Continue runtime/menu bar polish, then convert competitor findings into product and documentation improvements.

### In progress
- Extracted the menu bar configuration card into its own SwiftUI file.
- Added menu bar presets and live preview values to make density choices faster and more obvious.

### Completed batch
- Verified the menu bar settings refactor and preset flow with a fresh macOS build and test pass.
- Confirmed the debug app still launches and publishes the expected live menu bar item titles after the change.

### Next batch
- Added a sourced competitor matrix covering Stats, iStat Menus 7, TG Pro, and Macs Fan Control.
- Captured the product and trust implications so roadmap and README changes can point to concrete public evidence instead of vague claims.
```
