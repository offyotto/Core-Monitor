# Commit 81e0938: Add auto fan aggressiveness slider and fix QEMU boot/display defaults

## Metadata

| Field | Value |
| --- | --- |
| Full SHA | `81e0938af1295c399a9ab48c65fd7742e6c50a56` |
| Author | ventaphobia <nazishamin65@gmail.com> |
| Date | 2026-03-13 |
| ISO date | `2026-03-13T23:24:05+05:00` |
| Parents | `6165f4fcb737` |
| Direct refs | No direct branch/tag ref |
| Files changed | 33 |
| Insertions | 4221 |
| Deletions | 293 |

## Commit Message

No extended commit message body.

## Area Summary

- App assets: 14 file(s)
- Core app: 6 file(s)
- Repository support: 4 file(s)
- Startup and onboarding: 3 file(s)
- Fan control, SMC, or helper: 2 file(s)
- Dashboard: 1 file(s)
- Menu bar: 1 file(s)
- Touch Bar and Pock widget runtime: 1 file(s)
- Privileged helper target: 1 file(s)

## Changed Files

| Status | Path | Added | Deleted |
| --- | --- | ---: | ---: |
| Added | `App-Info.plist` | 15 | 0 |
| Modified | `Core-Monitor.xcodeproj/project.pbxproj` | 71 | 182 |
| Added | `Core-Monitor.xcodeproj/xcshareddata/xcschemes/Core-Monitor.xcscheme` | 85 | 0 |
| Modified | `Core-Monitor.xcodeproj/xcuserdata/bookme.xcuserdatad/xcschemes/xcschememanagement.plist` | 13 | 0 |
| Added | `Core-Monitor/AppCoordinator.swift` | 104 | 0 |
| Modified | `Core-Monitor/Assets.xcassets/AppIcon.appiconset/Contents.json` | 11 | 54 |
| Added | `Core-Monitor/Assets.xcassets/AppIcon.appiconset/icon-128.png` |  |  |
| Added | `Core-Monitor/Assets.xcassets/AppIcon.appiconset/icon-128@2x.png` |  |  |
| Added | `Core-Monitor/Assets.xcassets/AppIcon.appiconset/icon-16.png` |  |  |
| Added | `Core-Monitor/Assets.xcassets/AppIcon.appiconset/icon-16@2x.png` |  |  |
| Added | `Core-Monitor/Assets.xcassets/AppIcon.appiconset/icon-256.png` |  |  |
| Added | `Core-Monitor/Assets.xcassets/AppIcon.appiconset/icon-256@2x.png` |  |  |
| Added | `Core-Monitor/Assets.xcassets/AppIcon.appiconset/icon-32.png` |  |  |
| Added | `Core-Monitor/Assets.xcassets/AppIcon.appiconset/icon-32@2x.png` |  |  |
| Added | `Core-Monitor/Assets.xcassets/AppIcon.appiconset/icon-512.png` |  |  |
| Added | `Core-Monitor/Assets.xcassets/AppIcon.appiconset/icon-512@2x.png` |  |  |
| Added | `Core-Monitor/Assets.xcassets/CoreVisorIcon.imageset/Contents.json` | 22 | 0 |
| Added | `Core-Monitor/Assets.xcassets/CoreVisorIcon.imageset/corevisor-1024.png` |  |  |
| Added | `Core-Monitor/Assets.xcassets/CoreVisorIcon.imageset/corevisor-512.png` |  |  |
| Added | `Core-Monitor/CompanionLaunchpadManager.swift` | 62 | 0 |
| Modified | `Core-Monitor/ContentView.swift` | 496 | 35 |
| Added | `Core-Monitor/CoreVisorManager.swift` | 724 | 0 |
| Added | `Core-Monitor/CoreVisorSetupView.swift` | 601 | 0 |
| Modified | `Core-Monitor/Core_MonitorApp.swift` | 13 | 22 |
| Added | `Core-Monitor/FanController.swift` | 139 | 0 |
| Added | `Core-Monitor/LaunchpadGlassView.swift` | 531 | 0 |
| Added | `Core-Monitor/MenuBarExtraView.swift` | 102 | 0 |
| Added | `Core-Monitor/MotionEffects.swift` | 25 | 0 |
| Added | `Core-Monitor/SMCHelperManager.swift` | 186 | 0 |
| Added | `Core-Monitor/StartupManager.swift` | 48 | 0 |
| Added | `Core-Monitor/SystemMonitor.swift` | 579 | 0 |
| Added | `Core-Monitor/TouchBarPrivatePresenter.swift` | 85 | 0 |
| Added | `smc-helper/main.swift` | 309 | 0 |

## Reading Notes

- This page is generated from local git metadata so it is best used with the exact repository clone that produced the wiki.
- Merge commits may show little or no direct diff even though they pull a full branch of work into the reachable history.
- Deleted paths are also cross-linked from the removed-parts index when the status is `Deleted`.
