# Commit 3651f98: Remove CoreVisor and virtualization support

## Metadata

| Field | Value |
| --- | --- |
| Full SHA | `3651f9830e4269c16c622fae0ff398397a4f4576` |
| Author | ventaphobia <nazishamin65@gmail.com> |
| Date | 2026-03-29 |
| ISO date | `2026-03-29T16:41:25+05:00` |
| Parents | `b20fd3e9534b` |
| Direct refs | No direct branch/tag ref |
| Files changed | 36 |
| Insertions | 235 |
| Deletions | 473 |

## Commit Message

No extended commit message body.

## Area Summary

- Repository support: 17 file(s)
- Core app: 4 file(s)
- Website and documentation: 4 file(s)
- App assets: 3 file(s)
- Fan control, SMC, or helper: 2 file(s)
- Menu bar: 2 file(s)
- Dashboard: 1 file(s)
- Touch Bar and Pock widget runtime: 1 file(s)
- Startup and onboarding: 1 file(s)
- Privileged helper target: 1 file(s)

## Changed Files

| Status | Path | Added | Deleted |
| --- | --- | ---: | ---: |
| Modified | `Core-Monitor.entitlements` | 0 | 2 |
| Modified | `Core-Monitor.xcodeproj/project.pbxproj` | 4 | 32 |
| Modified | `Core-Monitor/AppCoordinator.swift` | 3 | 29 |
| Modified | `Core-Monitor/AppUpdater.swift` | 69 | 18 |
| Modified | `Core-Monitor/AppVersion.swift` | 1 | 1 |
| Deleted | `Core-Monitor/Assets.xcassets/CoreVisorIcon.imageset/Contents.json` | 0 | 22 |
| Deleted | `Core-Monitor/Assets.xcassets/CoreVisorIcon.imageset/corevisor-1024.png` |  |  |
| Deleted | `Core-Monitor/Assets.xcassets/CoreVisorIcon.imageset/corevisor-512.png` |  |  |
| Modified | `Core-Monitor/ContentView.swift` | 0 | 57 |
| Modified | `Core-Monitor/Core_MonitorApp.swift` | 0 | 10 |
| Modified | `Core-Monitor/FanController.swift` | 2 | 21 |
| Modified | `Core-Monitor/MenuBarExtraView.swift` | 0 | 98 |
| Modified | `Core-Monitor/MenubarController.swift` | 0 | 11 |
| Modified | `Core-Monitor/SMCHelperManager.swift` | 81 | 6 |
| Modified | `Core-Monitor/TouchBarPrivatePresenter.swift` | 1 | 10 |
| Modified | `Core-Monitor/WelcomeGuide.swift` | 15 | 15 |
| Deleted | `EmbeddedQEMU/README.md` | 0 | 16 |
| Deleted | `EmbeddedQEMU/lib/libepoxy.0.dylib` |  |  |
| Deleted | `EmbeddedQEMU/lib/libgio-2.0.0.dylib` |  |  |
| Deleted | `EmbeddedQEMU/lib/libglib-2.0.0.dylib` |  |  |
| Deleted | `EmbeddedQEMU/lib/libgmodule-2.0.0.dylib` |  |  |
| Deleted | `EmbeddedQEMU/lib/libgobject-2.0.0.dylib` |  |  |
| Deleted | `EmbeddedQEMU/lib/libintl.8.dylib` |  |  |
| Deleted | `EmbeddedQEMU/lib/libpcre2-8.0.dylib` |  |  |
| Deleted | `EmbeddedQEMU/lib/libpixman-1.0.dylib` |  |  |
| Deleted | `EmbeddedQEMU/lib/libslirp.0.dylib` |  |  |
| Deleted | `EmbeddedQEMU/lib/libvirglrenderer.1.dylib` |  |  |
| Deleted | `EmbeddedQEMU/lib/libvirglrenderer.dylib` |  |  |
| Deleted | `EmbeddedQEMU/lib/libzstd.1.5.7.dylib` |  |  |
| Deleted | `EmbeddedQEMU/qemu-img` |  |  |
| Deleted | `EmbeddedQEMU/qemu-system-aarch64` |  |  |
| Modified | `docs/index.html` | 11 | 47 |
| Modified | `docs/styles.css` | 4 | 14 |
| Modified | `index.html` | 11 | 47 |
| Modified | `smc-helper/main.swift` | 29 | 3 |
| Modified | `styles.css` | 4 | 14 |

## Reading Notes

- This page is generated from local git metadata so it is best used with the exact repository clone that produced the wiki.
- Merge commits may show little or no direct diff even though they pull a full branch of work into the reachable history.
- Deleted paths are also cross-linked from the removed-parts index when the status is `Deleted`.
