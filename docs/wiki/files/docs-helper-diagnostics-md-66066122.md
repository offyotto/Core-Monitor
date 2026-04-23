# File: docs/HELPER_DIAGNOSTICS.md

## Current Role

- Area: Website and documentation.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`docs/HELPER_DIAGNOSTICS.md`](../../../docs/HELPER_DIAGNOSTICS.md) |
| Wiki area | Website and documentation |
| Exists in current checkout | True |
| Size | 3107 bytes |
| Binary | False |
| Line count | 66 |
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
| `133d9ad` | 2026-04-16 | Replace alert surfaces with monitoring status |
| `5dc29ed` | 2026-04-16 | Add privacy controls and refine Core Monitor presentation |
| `80000af` | 2026-04-16 | Add friendly host model names to diagnostics |
| `9d4d7d1` | 2026-04-16 | Capture dashboard launch state in support diagnostics |
| `f7b2ac8` | 2026-04-16 | Clarify menu bar visibility recovery in support docs |
| `3ce51de` | 2026-04-16 | Improve helper diagnostics discoverability |
| `d7d5269` | 2026-04-16 | Add helper diagnostics support docs |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
# Helper Diagnostics

Core Monitor now includes an exportable helper diagnostics report for support and bug triage.

Use it when:

- the app says the privileged helper is unavailable
- fan writes fail or do nothing
- helper installation succeeds but connection checks still fail
- launch-at-login or menu bar reachability might be part of the support issue

## How to export it

1. Open `System`
2. Use the `Helper Diagnostics` card
3. Click `Export Report`
4. Save the JSON file and attach it to your issue or support thread

You can still reach the same export flow from `Help` → `Reopen Welcome Guide` → final readiness step if you want the onboarding checklist at the same time.

The app reveals the saved file in Finder after export.

## What the report includes

- Core Monitor bundle identifier, version, build, and macOS version
- Mac model identifier, friendly name, and chip name
- app signing identity details relevant to helper trust
- bundled helper path and installed helper path
- helper install state and current connectivity state
- the Apple Silicon fan-control backend currently wired into the helper
- detected mode-key format (`F%dMd` vs `F%dmd`) when the helper can report it
- whether the `Ftst` unlock path exists on the current Mac
- current helper status message, if one exists
- launch-at-login state and approval errors
- menu bar preset title and enabled-item count
- recommended recovery actions based on the captured state

## What it does not include

- analytics or network activity
```
