# Commit 011232b: Update website install video

## Metadata

| Field | Value |
| --- | --- |
| Full SHA | `011232ba11688f0f913abda0e37ffb98420a079d` |
| Author | ventaphobia <nazishamin65@gmail.com> |
| Date | 2026-04-11 |
| ISO date | `2026-04-11T13:11:36+05:00` |
| Parents | `6decaf7e3eab` |
| Direct refs | No direct branch/tag ref |
| Files changed | 156 |
| Insertions | 11985 |
| Deletions | 5653 |

## Commit Message

No extended commit message body.

## Area Summary

- Touch Bar and Pock widget runtime: 87 file(s)
- Repository support: 39 file(s)
- Core app: 16 file(s)
- Website and documentation: 4 file(s)
- Fan control, SMC, or helper: 3 file(s)
- Menu bar: 2 file(s)
- Privileged helper target: 2 file(s)
- Dashboard: 1 file(s)
- Weather and location: 1 file(s)
- Startup and onboarding: 1 file(s)

## Changed Files

| Status | Path | Added | Deleted |
| --- | --- | ---: | ---: |
| Added | `.codex-recovery/broken-working-tree-20260410-194115.patch` | 6873 | 0 |
| Added | `.codex-recovery/untracked-20260410-194115.txt` | 5 | 0 |
| Modified | `App-Info.plist` | 2 | 6 |
| Modified | `Core-Monitor.entitlements` | 2 | 0 |
| Copied | `Core-Monitor.entitlements -> Core-Monitor.xcodeproj/CoreMonitor-Info.plist` |  |  |
| Modified | `Core-Monitor.xcodeproj/project.pbxproj` | 24 | 33 |
| Modified | `Core-Monitor.xcodeproj/project.xcworkspace/contents.xcworkspacedata` | 3 | 0 |
| Modified | `Core-Monitor.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` | 0 | 10 |
| Modified | `Core-Monitor.xcodeproj/xcshareddata/xcschemes/Core-Monitor.xcscheme` | 1 | 1 |
| Modified | `Core-Monitor/AppCoordinator.swift` | 37 | 222 |
| Deleted | `Core-Monitor/AppUpdater.swift` | 0 | 237 |
| Modified | `Core-Monitor/AppVersion.swift` | 1 | 1 |
| Deleted | `Core-Monitor/BenchmarkEngine.swift` | 0 | 271 |
| Deleted | `Core-Monitor/BenchmarkResult.swift` | 0 | 104 |
| Deleted | `Core-Monitor/BenchmarkView.swift` | 0 | 301 |
| Modified | `Core-Monitor/ContentView.swift` | 395 | 361 |
| Added | `Core-Monitor/CoreMonTouchBarController.swift` | 343 | 0 |
| Modified | `Core-Monitor/Core_MonitorApp.swift` | 2 | 3 |
| Modified | `Core-Monitor/FanController.swift` | 58 | 0 |
| Added | `Core-Monitor/GroupViews.swift` | 755 | 0 |
| Deleted | `Core-Monitor/LeaderboardView.swift` | 0 | 208 |
| Modified | `Core-Monitor/MenuBarExtraView.swift` | 13 | 33 |
| Modified | `Core-Monitor/MenubarController.swift` | 0 | 4 |
| Added | `Core-Monitor/NetworkGraphView.swift` | 54 | 0 |
| Added | `Core-Monitor/PKCoreMonWidgets.swift` | 191 | 0 |
| Added | `Core-Monitor/PKWidget.swift` | 32 | 0 |
| Added | `Core-Monitor/PKWidgetTouchBarItem.swift` | 103 | 0 |
| Added | `Core-Monitor/PKWidgetViewController.swift` | 33 | 0 |
| Added | `Core-Monitor/PillView.swift` | 58 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Status/Items/SClockItem.swift` | 50 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Status/Items/SLangItem.swift` | 192 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Status/Items/SPowerItem.swift` | 142 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Status/Items/SWifiItem.swift` | 94 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Status/Media.xcassets/Contents.json` | 6 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Status/Media.xcassets/powerEmpty.imageset/BatteryEmpty.pdf` | 98 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Status/Media.xcassets/powerEmpty.imageset/Contents.json` | 15 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Status/Media.xcassets/powerIsCharged.imageset/BatteryCharged.pdf` |  |  |
| Added | `Core-Monitor/PockWidgetSources/Status/Media.xcassets/powerIsCharged.imageset/Contents.json` | 15 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Status/Media.xcassets/powerIsCharging.imageset/BatteryCharging-1.pdf` |  |  |
| Added | `Core-Monitor/PockWidgetSources/Status/Media.xcassets/powerIsCharging.imageset/Contents.json` | 15 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Status/Media.xcassets/powerLeft.imageset/BatteryLevelCapB-L.pdf` | 118 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Status/Media.xcassets/powerLeft.imageset/Contents.json` | 15 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Status/Media.xcassets/powerMiddle.imageset/BatteryLevelCapB-M.pdf` | 118 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Status/Media.xcassets/powerMiddle.imageset/Contents.json` | 15 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Status/Media.xcassets/powerRight.imageset/BatteryLevelCapB-R.pdf` | 137 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Status/Media.xcassets/powerRight.imageset/Contents.json` | 15 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Status/Media.xcassets/wifi0.imageset/AirPort0.png` |  |  |
| Added | `Core-Monitor/PockWidgetSources/Status/Media.xcassets/wifi0.imageset/AirPort0@2x.png` |  |  |
| Added | `Core-Monitor/PockWidgetSources/Status/Media.xcassets/wifi0.imageset/Contents.json` | 21 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Status/Media.xcassets/wifi1.imageset/AirPort1.png` |  |  |
| Added | `Core-Monitor/PockWidgetSources/Status/Media.xcassets/wifi1.imageset/AirPort1@2x.png` |  |  |
| Added | `Core-Monitor/PockWidgetSources/Status/Media.xcassets/wifi1.imageset/Contents.json` | 21 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Status/Media.xcassets/wifi2.imageset/AirPort2.png` |  |  |
| Added | `Core-Monitor/PockWidgetSources/Status/Media.xcassets/wifi2.imageset/AirPort2@2x.png` |  |  |
| Added | `Core-Monitor/PockWidgetSources/Status/Media.xcassets/wifi2.imageset/Contents.json` | 21 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Status/Media.xcassets/wifi3.imageset/AirPort3.png` |  |  |
| Added | `Core-Monitor/PockWidgetSources/Status/Media.xcassets/wifi3.imageset/AirPort3@2x.png` |  |  |
| Added | `Core-Monitor/PockWidgetSources/Status/Media.xcassets/wifi3.imageset/Contents.json` | 21 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Status/Media.xcassets/wifi4.imageset/AirPort4.png` |  |  |
| Added | `Core-Monitor/PockWidgetSources/Status/Media.xcassets/wifi4.imageset/AirPort4@2x.png` |  |  |
| Added | `Core-Monitor/PockWidgetSources/Status/Media.xcassets/wifi4.imageset/Contents.json` | 21 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Status/Media.xcassets/wifiOff.imageset/AirPortOff.png` |  |  |
| Added | `Core-Monitor/PockWidgetSources/Status/Media.xcassets/wifiOff.imageset/AirPortOff@2x.png` |  |  |
| Added | `Core-Monitor/PockWidgetSources/Status/Media.xcassets/wifiOff.imageset/Contents.json` | 21 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Status/StatusItem.swift` | 56 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Status/StatusWidget.swift` | 82 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/01d.imageset/01d.png` |  |  |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/01d.imageset/Contents.json` | 15 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/01n.imageset/01n.png` |  |  |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/01n.imageset/Contents.json` | 15 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/02d.imageset/02d.png` |  |  |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/02d.imageset/Contents.json` | 15 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/02n.imageset/02n.png` |  |  |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/02n.imageset/Contents.json` | 15 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/03d.imageset/03d.png` |  |  |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/03d.imageset/Contents.json` | 15 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/03n.imageset/03n.png` |  |  |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/03n.imageset/Contents.json` | 15 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/04d.imageset/04d.png` |  |  |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/04d.imageset/Contents.json` | 15 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/04n.imageset/04n.png` |  |  |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/04n.imageset/Contents.json` | 15 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/09d.imageset/09d.png` |  |  |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/09d.imageset/Contents.json` | 15 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/09n.imageset/09n.png` |  |  |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/09n.imageset/Contents.json` | 15 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/10d.imageset/10d.png` |  |  |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/10d.imageset/Contents.json` | 15 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/10n.imageset/10n.png` |  |  |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/10n.imageset/Contents.json` | 15 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/11d.imageset/11d.png` |  |  |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/11d.imageset/Contents.json` | 15 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/11n.imageset/11n.png` |  |  |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/11n.imageset/Contents.json` | 15 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/13d.imageset/13d.png` |  |  |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/13d.imageset/Contents.json` | 15 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/13n.imageset/13n.png` |  |  |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/13n.imageset/Contents.json` | 15 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/50d.imageset/50d.png` |  |  |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/50d.imageset/Contents.json` | 15 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/50n.imageset/50n.png` |  |  |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/50n.imageset/Contents.json` | 15 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Weather/Icons.xcassets/Contents.json` | 6 | 0 |
| Added | `Core-Monitor/PockWidgetSources/Weather/WeatherWidget.swift` | 155 | 0 |
| Deleted | `Core-Monitor/QualityRatingEngine.swift` | 0 | 73 |
| Modified | `Core-Monitor/SMCHelperManager.swift` | 18 | 75 |
| Modified | `Core-Monitor/SystemMonitor.swift` | 121 | 154 |
| Added | `Core-Monitor/TouchBarConfiguration.swift` | 273 | 0 |
| Added | `Core-Monitor/TouchBarConstants.swift` | 103 | 0 |
| Added | `Core-Monitor/TouchBarIdentifiers.swift` | 15 | 0 |
| Added | `Core-Monitor/TouchBarPrivateBridge.h` | 10 | 0 |
| Added | `Core-Monitor/TouchBarPrivateBridge.m` | 45 | 0 |
| Modified | `Core-Monitor/TouchBarPrivatePresenter.swift` | 20 | 1827 |
| Added | `Core-Monitor/UsageBarView.swift` | 43 | 0 |
| Added | `Core-Monitor/WeatherService.swift` | 184 | 0 |
| Added | `Core-Monitor/WeatherTouchBarItem.swift` | 61 | 0 |
| Added | `Core-Monitor/WeatherTouchBarView.swift` | 250 | 0 |
| Modified | `Core-Monitor/WelcomeGuide.swift` | 12 | 12 |
| Deleted | `Core-Monitor/diff/FanController_vs_solo.diff` | 0 | 501 |
| Deleted | `Core-Monitor/diff/SystemMonitor_vs_solo.diff` | 0 | 1143 |
| Modified | `README.md` | 4 | 8 |
| Added | `XCODE_CLOUD.md` | 78 | 0 |
| Deleted | `appcast.xml` | 0 | 47 |
| Modified | `docs/index.html` | 5 | 5 |
| Deleted | `docs/videos/install-walkthrough.mov` |  |  |
| Added | `docs/videos/install-walkthrough.mp4` |  |  |
| Deleted | `downloads/Core-Monitor112100-11250.delta` |  |  |
| Deleted | `downloads/Core-Monitor112100-11260.delta` |  |  |
| Deleted | `downloads/Core-Monitor112100-11270.delta` |  |  |
| Deleted | `downloads/Core-Monitor112100-11280.delta` |  |  |
| Deleted | `downloads/Core-Monitor112100-11290.delta` |  |  |
| Deleted | `downloads/Core-Monitor11220-11201.delta` |  |  |
| Deleted | `downloads/Core-Monitor11230-11201.delta` |  |  |
| Deleted | `downloads/Core-Monitor11230-11220.delta` |  |  |
| Deleted | `downloads/Core-Monitor11250-11201.delta` |  |  |
| Deleted | `downloads/Core-Monitor11250-11220.delta` |  |  |
| Deleted | `downloads/Core-Monitor11250-11230.delta` |  |  |
| Deleted | `downloads/Core-Monitor11250-11240.delta` |  |  |
| Deleted | `downloads/Core-Monitor11260-11201.delta` |  |  |
| Deleted | `downloads/Core-Monitor11260-11220.delta` |  |  |
| Deleted | `downloads/Core-Monitor11260-11230.delta` |  |  |
| Deleted | `downloads/Core-Monitor11260-11240.delta` |  |  |
| Deleted | `downloads/Core-Monitor11260-11250.delta` |  |  |
| Deleted | `downloads/Core-Monitor11270-11220.delta` |  |  |
| Deleted | `downloads/Core-Monitor11270-11230.delta` |  |  |
| Deleted | `downloads/Core-Monitor11270-11240.delta` |  |  |
| Deleted | `downloads/Core-Monitor11270-11250.delta` |  |  |
| Deleted | `downloads/Core-Monitor11270-11260.delta` |  |  |
| Deleted | `downloads/Core-Monitor11280-11230.delta` |  |  |
| Deleted | `downloads/Core-Monitor11280-11240.delta` |  |  |
| Deleted | `downloads/Core-Monitor11280-11250.delta` |  |  |
| Deleted | `downloads/Core-Monitor11280-11260.delta` |  |  |
| Deleted | `downloads/Core-Monitor11280-11270.delta` |  |  |
| Modified | `index.html` | 5 | 5 |
| Modified | `smc-helper-Info.plist` | 11 | 1 |
| Modified | `smc-helper/Info.plist` | 0 | 7 |

## Reading Notes

- This page is generated from local git metadata so it is best used with the exact repository clone that produced the wiki.
- Merge commits may show little or no direct diff even though they pull a full branch of work into the reachable history.
- Deleted paths are also cross-linked from the removed-parts index when the status is `Deleted`.
