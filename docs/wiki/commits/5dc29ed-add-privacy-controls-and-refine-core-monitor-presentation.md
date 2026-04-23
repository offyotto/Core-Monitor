# Commit 5dc29ed: Add privacy controls and refine Core Monitor presentation

## Metadata

| Field | Value |
| --- | --- |
| Full SHA | `5dc29edcc20cb7a45289c46cfbedd901b302cd1a` |
| Author | ventaphobia <nazishamin65@gmail.com> |
| Date | 2026-04-16 |
| ISO date | `2026-04-16T07:39:39+05:00` |
| Parents | `6a63f7e4936e` |
| Direct refs | No direct branch/tag ref |
| Files changed | 23 |
| Insertions | 1027 |
| Deletions | 1446 |

## Commit Message

No extended commit message body.

## Area Summary

- Website and documentation: 7 file(s)
- Legacy alert system: 3 file(s)
- Core app: 3 file(s)
- Dashboard: 2 file(s)
- Tests: 2 file(s)
- Repository support: 2 file(s)
- Fan control, SMC, or helper: 1 file(s)
- Menu bar: 1 file(s)
- Privacy controls: 1 file(s)
- Startup and onboarding: 1 file(s)

## Changed Files

| Status | Path | Added | Deleted |
| --- | --- | ---: | ---: |
| Modified | `Core-Monitor/AlertEngine.swift` | 12 | 8 |
| Modified | `Core-Monitor/AlertManager.swift` | 68 | 0 |
| Modified | `Core-Monitor/AlertsView.swift` | 51 | 1 |
| Modified | `Core-Monitor/ContentView.swift` | 1 | 1 |
| Modified | `Core-Monitor/Core_MonitorApp.swift` | 4 | 29 |
| Deleted | `Core-Monitor/DashboardLaunchDiagnostics.swift` | 0 | 75 |
| Modified | `Core-Monitor/HelpView.swift` | 9 | 8 |
| Modified | `Core-Monitor/HelperDiagnosticsExporter.swift` | 0 | 30 |
| Modified | `Core-Monitor/MenuBarExtraView.swift` | 41 | 5 |
| Added | `Core-Monitor/PrivacySettings.swift` | 29 | 0 |
| Modified | `Core-Monitor/SystemMonitor.swift` | 31 | 1 |
| Modified | `Core-Monitor/WelcomeGuide.swift` | 3 | 2 |
| Modified | `Core-MonitorTests/AlertEngineTests.swift` | 31 | 0 |
| Modified | `Core-MonitorTests/HelperDiagnosticsReportTests.swift` | 0 | 61 |
| Modified | `README.md` | 29 | 37 |
| Modified | `WORKLOG.md` | 10 | 0 |
| Modified | `docs/CORE_MONITOR_AUDIT_2026.md` | 2 | 2 |
| Modified | `docs/HELPER_DIAGNOSTICS.md` | 2 | 4 |
| Modified | `docs/SECURITY_COMPETITIVE_AUDIT_2026-04-15.md` | 2 | 2 |
| Modified | `docs/index.html` | 82 | 148 |
| Modified | `docs/styles.css` | 269 | 442 |
| Modified | `index.html` | 82 | 148 |
| Modified | `styles.css` | 269 | 442 |

## Reading Notes

- This page is generated from local git metadata so it is best used with the exact repository clone that produced the wiki.
- Merge commits may show little or no direct diff even though they pull a full branch of work into the reachable history.
- Deleted paths are also cross-linked from the removed-parts index when the status is `Deleted`.
