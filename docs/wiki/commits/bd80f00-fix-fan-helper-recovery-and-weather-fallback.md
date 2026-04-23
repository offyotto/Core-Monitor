# Commit bd80f00: Fix fan helper recovery and weather fallback

## Metadata

| Field | Value |
| --- | --- |
| Full SHA | `bd80f00445bc17c7acc581dfdc2f0284085feb12` |
| Author | ventaphobia <nazishamin65@gmail.com> |
| Date | 2026-04-17 |
| ISO date | `2026-04-17T21:25:41+05:00` |
| Parents | `712cda33cdd4` |
| Direct refs | No direct branch/tag ref |
| Files changed | 6 |
| Insertions | 165 |
| Deletions | 32 |

## Commit Message

No extended commit message body.

## Area Summary

- Fan control, SMC, or helper: 2 file(s)
- Tests: 2 file(s)
- Repository support: 1 file(s)
- Weather and location: 1 file(s)

## Changed Files

| Status | Path | Added | Deleted |
| --- | --- | ---: | ---: |
| Modified | `Core-Monitor.xcodeproj/project.pbxproj` | 4 | 4 |
| Modified | `Core-Monitor/SMCHelperManager.swift` | 83 | 10 |
| Modified | `Core-Monitor/SMCHelperXPC.swift` | 3 | 3 |
| Modified | `Core-Monitor/WeatherService.swift` | 43 | 7 |
| Modified | `Core-MonitorTests/HelperDiagnosticsReportTests.swift` | 16 | 0 |
| Modified | `Core-MonitorTests/WeatherViewModelTests.swift` | 16 | 8 |

## Reading Notes

- This page is generated from local git metadata so it is best used with the exact repository clone that produced the wiki.
- Merge commits may show little or no direct diff even though they pull a full branch of work into the reachable history.
- Deleted paths are also cross-linked from the removed-parts index when the status is `Deleted`.
