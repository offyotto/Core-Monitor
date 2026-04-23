# Commit 61a73aa: Commit ig

## Metadata

| Field | Value |
| --- | --- |
| Full SHA | `61a73aa9d73aee9e9c105e87b8317a8121164343` |
| Author | ventaphobia <nazishamin65@gmail.com> |
| Date | 2026-03-15 |
| ISO date | `2026-03-15T14:54:26+05:00` |
| Parents | `81e0938af129` |
| Direct refs | `v6`, `v6.1`, `v7` |
| Files changed | 85 |
| Insertions | 6071 |
| Deletions | 1865 |

## Commit Message

No extended commit message body.

## Area Summary

- Repository support: 66 file(s)
- Core app: 8 file(s)
- Startup and onboarding: 3 file(s)
- Fan control, SMC, or helper: 3 file(s)
- Dashboard: 1 file(s)
- Menu bar: 1 file(s)
- Touch Bar and Pock widget runtime: 1 file(s)
- Tests: 1 file(s)
- Privileged helper target: 1 file(s)

## Changed Files

| Status | Path | Added | Deleted |
| --- | --- | ---: | ---: |
| Modified | `App-Info.plist` | 16 | 0 |
| Modified | `Core Monitor.xcodeproj/project.pbxproj` | 2 | 0 |
| Added | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/Info.plist` | 57 | 0 |
| Added | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/MacOS/Core-Monitor` |  |  |
| Added | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/PkgInfo` | 1 | 0 |
| Added | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/Resources/AppIcon.icns` |  |  |
| Added | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/Resources/Assets.car` |  |  |
| Added | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/Resources/EmbeddedQEMU/lib/libepoxy.0.dylib` |  |  |
| Added | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/Resources/EmbeddedQEMU/lib/libgio-2.0.0.dylib` |  |  |
| Added | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/Resources/EmbeddedQEMU/lib/libglib-2.0.0.dylib` |  |  |
| Added | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/Resources/EmbeddedQEMU/lib/libgmodule-2.0.0.dylib` |  |  |
| Added | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/Resources/EmbeddedQEMU/lib/libgobject-2.0.0.dylib` |  |  |
| Added | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/Resources/EmbeddedQEMU/lib/libintl.8.dylib` |  |  |
| Added | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/Resources/EmbeddedQEMU/lib/libpcre2-8.0.dylib` |  |  |
| Added | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/Resources/EmbeddedQEMU/lib/libpixman-1.0.dylib` |  |  |
| Added | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/Resources/EmbeddedQEMU/lib/libslirp.0.dylib` |  |  |
| Added | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/Resources/EmbeddedQEMU/lib/libvirglrenderer.1.dylib` |  |  |
| Added | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/Resources/EmbeddedQEMU/lib/libvirglrenderer.dylib` |  |  |
| Added | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/Resources/EmbeddedQEMU/lib/libzstd.1.5.7.dylib` |  |  |
| Added | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/Resources/EmbeddedQEMU/qemu-img` |  |  |
| Added | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/Resources/EmbeddedQEMU/qemu-system-aarch64` |  |  |
| Added | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/_CodeSignature/CodeResources` | 377 | 0 |
| Added | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/libs/libepoxy.0.dylib` |  |  |
| Added | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/libs/libgio-2.0.0.dylib` |  |  |
| Added | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/libs/libglib-2.0.0.dylib` |  |  |
| Added | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/libs/libgmodule-2.0.0.dylib` |  |  |
| Added | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/libs/libgobject-2.0.0.dylib` |  |  |
| Added | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/libs/libintl.8.dylib` |  |  |
| Added | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/libs/libpcre2-8.0.dylib` |  |  |
| Added | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/libs/libpixman-1.0.dylib` |  |  |
| Added | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/libs/libslirp.0.dylib` |  |  |
| Added | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/libs/libvirglrenderer.1.dylib` |  |  |
| Added | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/libs/libvirglrenderer.dylib` |  |  |
| Added | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/libs/libzstd.1.5.7.dylib` |  |  |
| Added | `Core-Monitor.entitlements` | 8 | 0 |
| Modified | `Core-Monitor.xcodeproj/project.pbxproj` | 56 | 34 |
| Added | `Core-Monitor.xcodeproj/xcuserdata/bookme.xcuserdatad/xcdebugger/Breakpoints_v2.xcbkptlist` | 24 | 0 |
| Modified | `Core-Monitor/AppCoordinator.swift` | 11 | 8 |
| Deleted | `Core-Monitor/CompanionLaunchpadManager.swift` | 0 | 62 |
| Modified | `Core-Monitor/ContentView.swift` | 814 | 421 |
| Modified | `Core-Monitor/CoreVisorManager.swift` | 1302 | 109 |
| Modified | `Core-Monitor/CoreVisorSetupView.swift` | 1401 | 441 |
| Modified | `Core-Monitor/Core_MonitorApp.swift` | 13 | 2 |
| Modified | `Core-Monitor/FanController.swift` | 5 | 5 |
| Deleted | `Core-Monitor/Item.swift` | 0 | 18 |
| Deleted | `Core-Monitor/LaunchpadGlassView.swift` | 0 | 531 |
| Modified | `Core-Monitor/MenuBarExtraView.swift` | 195 | 41 |
| Deleted | `Core-Monitor/MotionEffects.swift` | 0 | 25 |
| Modified | `Core-Monitor/SMCHelperManager.swift` | 42 | 23 |
| Modified | `Core-Monitor/StartupManager.swift` | 21 | 1 |
| Modified | `Core-Monitor/SystemMonitor.swift` | 13 | 13 |
| Modified | `Core-Monitor/TouchBarPrivatePresenter.swift` | 36 | 13 |
| Added | `Core-Monitor/diff/FanController_vs_solo.diff` | 501 | 0 |
| Added | `Core-Monitor/diff/SystemMonitor_vs_solo.diff` | 1143 | 0 |
| Deleted | `Core-MonitorTests/Core_MonitorTests.swift` | 0 | 36 |
| Deleted | `Core-MonitorUITests/Core_MonitorUITests.swift` | 0 | 41 |
| Deleted | `Core-MonitorUITests/Core_MonitorUITestsLaunchTests.swift` | 0 | 33 |
| Added | `EmbeddedQEMU/README.md` | 16 | 0 |
| Added | `EmbeddedQEMU/lib/libepoxy.0.dylib` |  |  |
| Added | `EmbeddedQEMU/lib/libgio-2.0.0.dylib` |  |  |
| Added | `EmbeddedQEMU/lib/libglib-2.0.0.dylib` |  |  |
| Added | `EmbeddedQEMU/lib/libgmodule-2.0.0.dylib` |  |  |
| Added | `EmbeddedQEMU/lib/libgobject-2.0.0.dylib` |  |  |
| Added | `EmbeddedQEMU/lib/libintl.8.dylib` |  |  |
| Added | `EmbeddedQEMU/lib/libpcre2-8.0.dylib` |  |  |
| Added | `EmbeddedQEMU/lib/libpixman-1.0.dylib` |  |  |
| Added | `EmbeddedQEMU/lib/libslirp.0.dylib` |  |  |
| Added | `EmbeddedQEMU/lib/libvirglrenderer.1.dylib` |  |  |
| Added | `EmbeddedQEMU/lib/libvirglrenderer.dylib` |  |  |
| Added | `EmbeddedQEMU/lib/libzstd.1.5.7.dylib` |  |  |
| Added | `EmbeddedQEMU/qemu-img` |  |  |
| Added | `EmbeddedQEMU/qemu-system-aarch64` |  |  |
| Added | `libs/libepoxy.0.dylib` |  |  |
| Added | `libs/libgio-2.0.0.dylib` |  |  |
| Added | `libs/libglib-2.0.0.dylib` |  |  |
| Added | `libs/libgmodule-2.0.0.dylib` |  |  |
| Added | `libs/libgobject-2.0.0.dylib` |  |  |
| Added | `libs/libintl.8.dylib` |  |  |
| Added | `libs/libpcre2-8.0.dylib` |  |  |
| Added | `libs/libpixman-1.0.dylib` |  |  |
| Added | `libs/libslirp.0.dylib` |  |  |
| Added | `libs/libvirglrenderer.1.dylib` |  |  |
| Added | `libs/libvirglrenderer.dylib` |  |  |
| Added | `libs/libzstd.1.5.7.dylib` |  |  |
| Modified | `smc-helper/main.swift` | 17 | 8 |

## Reading Notes

- This page is generated from local git metadata so it is best used with the exact repository clone that produced the wiki.
- Merge commits may show little or no direct diff even though they pull a full branch of work into the reachable history.
- Deleted paths are also cross-linked from the removed-parts index when the status is `Deleted`.
