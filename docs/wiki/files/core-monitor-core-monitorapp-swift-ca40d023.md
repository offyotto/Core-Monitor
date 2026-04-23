# File: Core-Monitor/Core_MonitorApp.swift

## Current Role

- Contains the NSApplicationDelegate, single-instance policy, dashboard window controller, activation policy, startup routing, and shutdown hooks.
- Keeps a menu bar utility alive while still opening a visible dashboard for onboarding and explicit dashboard requests.
- Runs best-effort cleanup when the app terminates, including returning fan control to automatic where applicable.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/Core_MonitorApp.swift`](../../../Core-Monitor/Core_MonitorApp.swift) |
| Wiki area | Core app |
| Exists in current checkout | True |
| Size | 21890 bytes |
| Binary | False |
| Line count | 554 |
| Extension | `.swift` |

## Imports

`AppKit`, `Carbon`, `OSLog`, `SwiftUI`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| struct | `CoreMonitorRunningInstance` | 5 |
| enum | `CoreMonitorSingleInstancePolicy` | 12 |
| struct | `CoreMonitorLaunchEnvironment` | 35 |
| func | `debugLaunch` | 41 |
| class | `DashboardWindowController` | 48 |
| func | `showDashboard` | 87 |
| func | `windowWillClose` | 106 |
| func | `windowDidBecomeKey` | 111 |
| func | `windowDidBecomeMain` | 115 |
| func | `configure` | 119 |
| func | `promoteVisibility` | 140 |
| class | `CoreMonitorApplicationDelegate` | 159 |
| func | `applicationDidFinishLaunching` | 178 |
| func | `applicationWillTerminate` | 205 |
| func | `applicationSupportsSecureRestorableState` | 229 |
| func | `applicationShouldRestoreApplicationState` | 233 |
| func | `applicationShouldSaveApplicationState` | 237 |
| func | `applicationShouldTerminateAfterLastWindowClosed` | 241 |
| func | `applicationShouldHandleReopen` | 245 |
| func | `openDashboardFromMenu` | 252 |
| func | `openHelpFromMenu` | 257 |
| func | `reopenWelcomeGuideFromMenu` | 263 |
| func | `quitApplication` | 269 |
| func | `openDashboard` | 274 |
| func | `installMenuBarIfNeeded` | 289 |
| func | `installApplicationMenuIfNeeded` | 308 |
| func | `installDistributedDashboardRequestObserverIfNeeded` | 359 |
| func | `installQuitShortcutMonitorIfNeeded` | 380 |
| func | `installTouchBarShortcutMonitorIfNeeded` | 390 |
| func | `installDashboardShortcutObserverIfNeeded` | 400 |
| func | `isQuitShortcut` | 414 |
| func | `isSystemTouchBarShortcut` | 419 |
| func | `dashboardControllerIfNeeded` | 424 |
| func | `presentInitialDashboardIfNeeded` | 443 |
| func | `handOffToRunningInstanceIfNeeded` | 455 |
| func | `scheduleInitialDashboardAttempts` | 491 |
| func | `attemptInitialDashboardPresentation` | 508 |
| func | `cancelInitialDashboardAttempts` | 524 |
| func | `setDashboardActivationPolicy` | 529 |
| func | `applyInitialActivationPolicy` | 536 |
| func | `restoreAccessoryActivationPolicyIfNeeded` | 545 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `29afd92` | 2026-04-18 | Ship 14.0.7 localization update |
| `7c1b882` | 2026-04-17 | Keep Touch Bar HUD always on |
| `e24d811` | 2026-04-16 | :)) |
| `423587b` | 2026-04-16 | Stabilize unit test app bootstrap |
| `2dae7aa` | 2026-04-16 | Prevent duplicate Core Monitor launches |
| `133d9ad` | 2026-04-16 | Replace alert surfaces with monitoring status |
| `5fe6a4c` | 2026-04-16 | Harden first-launch startup and onboarding state |
| `7c0c8d6` | 2026-04-16 | Add dashboard shortcut and app menu access |
| `a62ded6` | 2026-04-16 | Prevent duplicate Core Monitor launches |
| `34c671f` | 2026-04-16 | Add accessory app menu shortcuts |
| `001a339` | 2026-04-16 | Purge deprecated launch diagnostics defaults |
| `4d587ef` | 2026-04-16 | Restore standard quit controls in the accessory app |
| `78d0fd2` | 2026-04-16 | Stabilize onboarding launch and menu bar defaults |
| `5dc29ed` | 2026-04-16 | Add privacy controls and refine Core Monitor presentation |
| `6a63f7e` | 2026-04-16 | Name dashboard window for macOS |
| `9d4d7d1` | 2026-04-16 | Capture dashboard launch state in support diagnostics |
| `844ce69` | 2026-04-16 | Fix first-launch dashboard discoverability |
| `7185d36` | 2026-04-15 | Improve fan control and alert surfaces |
| `2664fd1` | 2026-04-11 | Update Core Monitor |
| `011232b` | 2026-04-11 | Update website install video |
| `31da3f2` | 2026-04-06 | ui update |
| `0fa238c` | 2026-04-02 | commits. |
| `3651f98` | 2026-03-29 | Remove CoreVisor and virtualization support |
| `b436125` | 2026-03-28 | Improve Touch Bar behavior, CoreVisor UI, and docs |
| `3252194` | 2026-03-27 | Clean repo and keep only active Core-Monitor project |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import AppKit
import Carbon
import OSLog
import SwiftUI

struct CoreMonitorRunningInstance: Equatable {
    let processIdentifier: pid_t
    let launchDate: Date?
    let isFinishedLaunching: Bool
    let isTerminated: Bool
}

enum CoreMonitorSingleInstancePolicy {
    static func handoffTarget(
        from runningInstances: [CoreMonitorRunningInstance],
        currentPID: pid_t
    ) -> CoreMonitorRunningInstance? {
        runningInstances
            .filter { instance in
                instance.processIdentifier != currentPID &&
                instance.isFinishedLaunching &&
                instance.isTerminated == false
            }
            .sorted { lhs, rhs in
                let lhsLaunchDate = lhs.launchDate ?? .distantPast
                let rhsLaunchDate = rhs.launchDate ?? .distantPast
                if lhsLaunchDate != rhsLaunchDate {
                    return lhsLaunchDate < rhsLaunchDate
                }
                return lhs.processIdentifier < rhs.processIdentifier
            }
            .first
    }
}

struct CoreMonitorLaunchEnvironment {
    static func shouldHandleDuplicateLaunch(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        environment["XCTestConfigurationFilePath"] == nil
    }
}
```
