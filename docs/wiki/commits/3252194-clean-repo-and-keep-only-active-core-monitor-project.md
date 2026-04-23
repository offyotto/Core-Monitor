# Commit 3252194: Clean repo and keep only active Core-Monitor project

## Metadata

| Field | Value |
| --- | --- |
| Full SHA | `3252194a519f3613bcccae5c4ec43f8e690711d8` |
| Author | ventaphobia <nazishamin65@gmail.com> |
| Date | 2026-03-27 |
| ISO date | `2026-03-27T13:34:38+05:00` |
| Parents | `9f92da4b82d9` |
| Direct refs | No direct branch/tag ref |
| Files changed | 87 |
| Insertions | 6411 |
| Deletions | 3464 |

## Commit Message

No extended commit message body.

## Area Summary

- Repository support: 68 file(s)
- Core app: 10 file(s)
- Fan control, SMC, or helper: 2 file(s)
- Menu bar: 2 file(s)
- Startup and onboarding: 2 file(s)
- Dashboard: 1 file(s)
- Touch Bar and Pock widget runtime: 1 file(s)
- Privileged helper target: 1 file(s)

## Changed Files

| Status | Path | Added | Deleted |
| --- | --- | ---: | ---: |
| Added | `.gitignore` | 17 | 0 |
| Deleted | `Core Monitor.xcodeproj/project.pbxproj` | 0 | 364 |
| Deleted | `Core Monitor.xcodeproj/project.xcworkspace/contents.xcworkspacedata` | 0 | 7 |
| Deleted | `Core Monitor.xcodeproj/xcshareddata/xcschemes/Core Monitor.xcscheme` | 0 | 78 |
| Deleted | `Core Monitor.xcodeproj/xcshareddata/xcschemes/topbarExtension.xcscheme` | 0 | 114 |
| Deleted | `Core Monitor.xcodeproj/xcuserdata/bookme.xcuserdatad/xcschemes/xcschememanagement.plist` | 0 | 29 |
| Deleted | `Core Monitor/Assets.xcassets/AccentColor.colorset/Contents.json` | 0 | 11 |
| Deleted | `Core Monitor/Assets.xcassets/AppIcon.appiconset/Contents.json` | 0 | 58 |
| Deleted | `Core Monitor/Assets.xcassets/Contents.json` | 0 | 6 |
| Deleted | `Core Monitor/ContentView.swift` | 0 | 98 |
| Deleted | `Core Monitor/Core_MonitorApp.swift` | 0 | 23 |
| Deleted | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/Info.plist` | 0 | 57 |
| Deleted | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/MacOS/Core-Monitor` |  |  |
| Deleted | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/PkgInfo` | 0 | 1 |
| Deleted | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/Resources/AppIcon.icns` |  |  |
| Deleted | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/Resources/Assets.car` |  |  |
| Deleted | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/Resources/EmbeddedQEMU/lib/libepoxy.0.dylib` |  |  |
| Deleted | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/Resources/EmbeddedQEMU/lib/libgio-2.0.0.dylib` |  |  |
| Deleted | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/Resources/EmbeddedQEMU/lib/libglib-2.0.0.dylib` |  |  |
| Deleted | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/Resources/EmbeddedQEMU/lib/libgmodule-2.0.0.dylib` |  |  |
| Deleted | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/Resources/EmbeddedQEMU/lib/libgobject-2.0.0.dylib` |  |  |
| Deleted | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/Resources/EmbeddedQEMU/lib/libintl.8.dylib` |  |  |
| Deleted | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/Resources/EmbeddedQEMU/lib/libpcre2-8.0.dylib` |  |  |
| Deleted | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/Resources/EmbeddedQEMU/lib/libpixman-1.0.dylib` |  |  |
| Deleted | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/Resources/EmbeddedQEMU/lib/libslirp.0.dylib` |  |  |
| Deleted | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/Resources/EmbeddedQEMU/lib/libvirglrenderer.1.dylib` |  |  |
| Deleted | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/Resources/EmbeddedQEMU/lib/libvirglrenderer.dylib` |  |  |
| Deleted | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/Resources/EmbeddedQEMU/lib/libzstd.1.5.7.dylib` |  |  |
| Deleted | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/Resources/EmbeddedQEMU/qemu-img` |  |  |
| Deleted | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/Resources/EmbeddedQEMU/qemu-system-aarch64` |  |  |
| Deleted | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/_CodeSignature/CodeResources` | 0 | 377 |
| Deleted | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/libs/libepoxy.0.dylib` |  |  |
| Deleted | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/libs/libgio-2.0.0.dylib` |  |  |
| Deleted | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/libs/libglib-2.0.0.dylib` |  |  |
| Deleted | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/libs/libgmodule-2.0.0.dylib` |  |  |
| Deleted | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/libs/libgobject-2.0.0.dylib` |  |  |
| Deleted | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/libs/libintl.8.dylib` |  |  |
| Deleted | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/libs/libpcre2-8.0.dylib` |  |  |
| Deleted | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/libs/libpixman-1.0.dylib` |  |  |
| Deleted | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/libs/libslirp.0.dylib` |  |  |
| Deleted | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/libs/libvirglrenderer.1.dylib` |  |  |
| Deleted | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/libs/libvirglrenderer.dylib` |  |  |
| Deleted | `Core-Monitor 2026-03-14 14-48-54/Core-Monitor.app/Contents/libs/libzstd.1.5.7.dylib` |  |  |
| Modified | `Core-Monitor.xcodeproj/project.pbxproj` | 2 | 2 |
| Modified | `Core-Monitor.xcodeproj/xcshareddata/xcschemes/Core-Monitor.xcscheme` | 12 | 8 |
| Deleted | `Core-Monitor.xcodeproj/xcuserdata/bookme.xcuserdatad/xcdebugger/Breakpoints_v2.xcbkptlist` | 0 | 24 |
| Deleted | `Core-Monitor.xcodeproj/xcuserdata/bookme.xcuserdatad/xcschemes/xcschememanagement.plist` | 0 | 27 |
| Modified | `Core-Monitor/AppCoordinator.swift` | 104 | 62 |
| Added | `Core-Monitor/AppUpdater.swift` | 431 | 0 |
| Added | `Core-Monitor/AppVersion.swift` | 6 | 0 |
| Added | `Core-Monitor/Compatibility.swift` | 51 | 0 |
| Modified | `Core-Monitor/ContentView.swift` | 732 | 519 |
| Modified | `Core-Monitor/CoreVisorManager.swift` | 1312 | 1078 |
| Modified | `Core-Monitor/CoreVisorSetupView.swift` | 722 | 35 |
| Modified | `Core-Monitor/Core_MonitorApp.swift` | 74 | 17 |
| Added | `Core-Monitor/DoitformeView.swift` | 661 | 0 |
| Added | `Core-Monitor/Doitformemanger.swift` | 858 | 0 |
| Modified | `Core-Monitor/FanController.swift` | 40 | 5 |
| Modified | `Core-Monitor/MenuBarExtraView.swift` | 247 | 118 |
| Added | `Core-Monitor/MenubarController.swift` | 214 | 0 |
| Modified | `Core-Monitor/SMCHelperManager.swift` | 2 | 0 |
| Modified | `Core-Monitor/StartupManager.swift` | 6 | 5 |
| Modified | `Core-Monitor/SystemMonitor.swift` | 152 | 2 |
| Modified | `Core-Monitor/TouchBarPrivatePresenter.swift` | 309 | 63 |
| Added | `Core-Monitor/WelcomeGuide.swift` | 452 | 0 |
| Deleted | `libs/libepoxy.0.dylib` |  |  |
| Deleted | `libs/libgio-2.0.0.dylib` |  |  |
| Deleted | `libs/libglib-2.0.0.dylib` |  |  |
| Deleted | `libs/libgmodule-2.0.0.dylib` |  |  |
| Deleted | `libs/libgobject-2.0.0.dylib` |  |  |
| Deleted | `libs/libintl.8.dylib` |  |  |
| Deleted | `libs/libpcre2-8.0.dylib` |  |  |
| Deleted | `libs/libpixman-1.0.dylib` |  |  |
| Deleted | `libs/libslirp.0.dylib` |  |  |
| Deleted | `libs/libvirglrenderer.1.dylib` |  |  |
| Deleted | `libs/libvirglrenderer.dylib` |  |  |
| Deleted | `libs/libzstd.1.5.7.dylib` |  |  |
| Modified | `smc-helper/main.swift` | 7 | 0 |
| Deleted | `topbar/AppIntent.swift` | 0 | 18 |
| Deleted | `topbar/Assets.xcassets/AccentColor.colorset/Contents.json` | 0 | 11 |
| Deleted | `topbar/Assets.xcassets/AppIcon.appiconset/Contents.json` | 0 | 58 |
| Deleted | `topbar/Assets.xcassets/Contents.json` | 0 | 6 |
| Deleted | `topbar/Assets.xcassets/WidgetBackground.colorset/Contents.json` | 0 | 11 |
| Deleted | `topbar/Info.plist` | 0 | 11 |
| Deleted | `topbar/topbar.swift` | 0 | 67 |
| Deleted | `topbar/topbarBundle.swift` | 0 | 17 |
| Deleted | `topbar/topbarControl.swift` | 0 | 77 |

## Reading Notes

- This page is generated from local git metadata so it is best used with the exact repository clone that produced the wiki.
- Merge commits may show little or no direct diff even though they pull a full branch of work into the reachable history.
- Deleted paths are also cross-linked from the removed-parts index when the status is `Deleted`.
