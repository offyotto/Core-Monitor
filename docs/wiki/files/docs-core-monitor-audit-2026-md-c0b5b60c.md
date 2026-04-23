# File: docs/CORE_MONITOR_AUDIT_2026.md

## Current Role

- Area: Website and documentation.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`docs/CORE_MONITOR_AUDIT_2026.md`](../../../docs/CORE_MONITOR_AUDIT_2026.md) |
| Wiki area | Website and documentation |
| Exists in current checkout | True |
| Size | 8066 bytes |
| Binary | False |
| Line count | 136 |
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
| `ef6fa04` | 2026-04-16 | Fix Homebrew install docs |
| `5dc29ed` | 2026-04-16 | Add privacy controls and refine Core Monitor presentation |
| `1ff7bdb` | 2026-04-16 | Refine helper health states and service alerts |
| `7afc598` | 2026-04-15 | Automate releases and sharpen product positioning |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
# Core-Monitor Audit and Reinvention Plan

## Verdict

Core-Monitor has real strengths: native SwiftUI UI, direct Apple SMC access, a privileged helper path for actual fan control, open-source trust, and a menu bar footprint that can become a serious daily utility. It is not yet category-dominating.

The main blocker is not raw feature count. It is trust and focus. Users trust TG Pro and Macs Fan Control when they need fan control. Users trust iStat Menus and Stats when they need at-a-glance monitoring. Core-Monitor currently sits in the middle with good ingredients, but too many rough edges in release rigor, architecture, and product framing.

## Brutally honest audit

### Critical

- Release trust gap: the repository did not previously contain a source-controlled CI or notarized release pipeline, even though the product story depends on signed helper-backed distribution.
- Monolithic UI files: `ContentView.swift`, `MenuBarExtraView.swift`, `SystemMonitor.swift`, and `FanController.swift` are still oversized enough to slow iteration and increase regression risk.
- Fan-control persistence risk: saved custom curve data previously did not restore the in-memory preset correctly after launch, making custom mode unreliable after restart.
- Hardware detection fragility: fan discovery depended too heavily on `FNum`, which is not robust across every Apple Silicon machine and SMC variant.

### High

- Helper identity and signing assumptions were too hard-coded. That creates friction when preparing a clean Developer ID release flow.
- Product positioning was blurred. Weather, Touch Bar, and broad stats collection diluted the sharper story users actually buy into: thermal awareness, fan control, alerts, and readable menu bar status.
- Website and release copy over-promised a smooth install path without repository evidence for how that path is produced.
- There is still not enough narrow test coverage around helper-adjacent behavior, fan curves, and monitoring edge cases.

### Medium

- The website is duplicated across `index.html` and `docs/index.html`, which increases drift risk.
- Xcode Cloud documentation was stale and still described a pre-test-target world.
- There is a lot of product surface area for a utility this size. Touch Bar, weather, launcher widgets, and menu bar customization all add maintenance cost.

### Low

- GitHub topics and discovery copy were too noisy and too close to competitor-keyword stuffing.
- Release channel guidance was scattered instead of codified.

## Competitor intelligence

### iStat Menus

- Strengths: broadest monitoring surface, polished multi-menu experience, mature history/graphing, strong perception of reliability, direct sales plus Setapp.
```
