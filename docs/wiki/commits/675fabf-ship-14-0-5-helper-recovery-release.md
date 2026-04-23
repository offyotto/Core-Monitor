# Commit 675fabf: Ship 14.0.5 helper recovery release

## Metadata

| Field | Value |
| --- | --- |
| Full SHA | `675fabf0789fa403f79d3a0df889e2e24f63a690` |
| Author | ventaphobia <nazishamin65@gmail.com> |
| Date | 2026-04-17 |
| ISO date | `2026-04-17T23:56:00+05:00` |
| Parents | `49e36e2e8c2a` |
| Direct refs | No direct branch/tag ref |
| Files changed | 23 |
| Insertions | 546 |
| Deletions | 62 |

## Commit Message

No extended commit message body.

## Area Summary

- Repository support: 5 file(s)
- Fan control, SMC, or helper: 4 file(s)
- Privileged helper target: 4 file(s)
- Tests: 3 file(s)
- Dashboard: 2 file(s)
- Developer and release scripts: 2 file(s)
- GitHub automation: 1 file(s)
- Menu bar: 1 file(s)
- Website and documentation: 1 file(s)

## Changed Files

| Status | Path | Added | Deleted |
| --- | --- | ---: | ---: |
| Modified | `.github/workflows/release.yml` | 28 | 0 |
| Modified | `App-Info.plist` | 1 | 1 |
| Modified | `Core-Monitor.xcodeproj/project.pbxproj` | 9 | 9 |
| Modified | `Core-Monitor/ContentView.swift` | 22 | 12 |
| Modified | `Core-Monitor/FanController.swift` | 13 | 4 |
| Modified | `Core-Monitor/HelperDiagnosticsExporter.swift` | 21 | 2 |
| Modified | `Core-Monitor/MenuBarStatusSummary.swift` | 3 | 0 |
| Modified | `Core-Monitor/MonitoringDashboardViews.swift` | 8 | 8 |
| Modified | `Core-Monitor/SMCHelperManager.swift` | 75 | 9 |
| Modified | `Core-Monitor/SMCHelperXPC.swift` | 1 | 0 |
| Modified | `Core-MonitorTests/CustomFanPresetTests.swift` | 13 | 0 |
| Modified | `Core-MonitorTests/HelperDiagnosticsReportTests.swift` | 96 | 0 |
| Added | `Core-MonitorTests/PrivilegedHelperRequirementStringsTests.swift` | 86 | 0 |
| Modified | `README.md` | 3 | 1 |
| Modified | `RELEASING.md` | 10 | 4 |
| Modified | `WORKLOG.md` | 10 | 0 |
| Modified | `docs/HELPER_DIAGNOSTICS.md` | 3 | 0 |
| Modified | `scripts/release/build_release.sh` | 30 | 3 |
| Modified | `scripts/release/notarize_release.sh` | 27 | 3 |
| Modified | `smc-helper/Info.plist` | 9 | 4 |
| Modified | `smc-helper/Launchd.plist` | 4 | 0 |
| Modified | `smc-helper/SMCHelperXPC.swift` | 1 | 0 |
| Modified | `smc-helper/main.swift` | 73 | 2 |

## Reading Notes

- This page is generated from local git metadata so it is best used with the exact repository clone that produced the wiki.
- Merge commits may show little or no direct diff even though they pull a full branch of work into the reachable history.
- Deleted paths are also cross-linked from the removed-parts index when the status is `Deleted`.
