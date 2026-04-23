# Commit 7185d36: Improve fan control and alert surfaces

## Metadata

| Field | Value |
| --- | --- |
| Full SHA | `7185d36d764a3b9b52fd721683b8eec43ec9f180` |
| Author | ventaphobia <nazishamin65@gmail.com> |
| Date | 2026-04-15 |
| ISO date | `2026-04-15T13:19:17+05:00` |
| Parents | `4d78a8fbc787` |
| Direct refs | No direct branch/tag ref |
| Files changed | 26 |
| Insertions | 4088 |
| Deletions | 354 |

## Commit Message

No extended commit message body.

## Area Summary

- Core app: 6 file(s)
- Fan control, SMC, or helper: 5 file(s)
- Legacy alert system: 4 file(s)
- Repository support: 3 file(s)
- Menu bar: 2 file(s)
- Tests: 2 file(s)
- Privileged helper target: 2 file(s)
- Dashboard: 1 file(s)
- Startup and onboarding: 1 file(s)

## Changed Files

| Status | Path | Added | Deleted |
| --- | --- | ---: | ---: |
| Modified | `App-Info.plist` | 3 | 1 |
| Modified | `Core-Monitor.xcodeproj/project.pbxproj` | 167 | 18 |
| Modified | `Core-Monitor.xcodeproj/xcshareddata/xcschemes/Core-Monitor.xcscheme` | 23 | 1 |
| Added | `Core-Monitor/AlertEngine.swift` | 691 | 0 |
| Added | `Core-Monitor/AlertManager.swift` | 369 | 0 |
| Added | `Core-Monitor/AlertModels.swift` | 415 | 0 |
| Added | `Core-Monitor/AlertsView.swift` | 696 | 0 |
| Modified | `Core-Monitor/AppCoordinator.swift` | 4 | 2 |
| Modified | `Core-Monitor/ContentView.swift` | 84 | 148 |
| Modified | `Core-Monitor/Core_MonitorApp.swift` | 2 | 0 |
| Modified | `Core-Monitor/FanController.swift` | 124 | 46 |
| Added | `Core-Monitor/FanCurveEditorView.swift` | 722 | 0 |
| Modified | `Core-Monitor/HelpView.swift` | 14 | 2 |
| Added | `Core-Monitor/HelperConfiguration.swift` | 20 | 0 |
| Modified | `Core-Monitor/MenuBarExtraView.swift` | 92 | 77 |
| Modified | `Core-Monitor/MenubarController.swift` | 28 | 4 |
| Added | `Core-Monitor/MonitoringSnapshot.swift` | 59 | 0 |
| Modified | `Core-Monitor/SMCHelperManager.swift` | 1 | 1 |
| Modified | `Core-Monitor/SMCTamperDetector.swift` | 8 | 5 |
| Modified | `Core-Monitor/SystemMonitor.swift` | 51 | 39 |
| Added | `Core-Monitor/TopProcessSampler.swift` | 212 | 0 |
| Modified | `Core-Monitor/WelcomeGuide.swift` | 3 | 2 |
| Added | `Core-MonitorTests/AlertEngineTests.swift` | 224 | 0 |
| Added | `Core-MonitorTests/CustomFanPresetTests.swift` | 68 | 0 |
| Modified | `smc-helper-Info.plist` | 4 | 4 |
| Modified | `smc-helper/Info.plist` | 4 | 4 |

## Reading Notes

- This page is generated from local git metadata so it is best used with the exact repository clone that produced the wiki.
- Merge commits may show little or no direct diff even though they pull a full branch of work into the reachable history.
- Deleted paths are also cross-linked from the removed-parts index when the status is `Deleted`.
