# File: Core-Monitor/AppCoordinator.swift

## Current Role

- Area: Core app.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/AppCoordinator.swift`](../../../Core-Monitor/AppCoordinator.swift) |
| Wiki area | Core app |
| Exists in current checkout | True |
| Size | 8524 bytes |
| Binary | False |
| Line count | 250 |
| Extension | `.swift` |

## Imports

`AppKit`, `Combine`, `Foundation`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `AppCoordinator` | 6 |
| func | `start` | 38 |
| func | `stop` | 47 |
| func | `revertToSystemTouchBar` | 81 |
| func | `revertToAppTouchBar` | 87 |
| func | `attachTouchBar` | 92 |
| func | `applySavedTouchBarMode` | 104 |
| func | `cancelTouchBarScheduling` | 113 |
| func | `installTouchBarBootstrapObservers` | 120 |
| func | `scheduleTouchBarReassertion` | 202 |
| func | `scheduleTouchBarBootstrap` | 216 |
| func | `startAppTouchBar` | 229 |
| func | `stopAppTouchBar` | 239 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `1ac3a89` | 2026-04-17 | Keep fan control responsive with touch bar |
| `7c1b882` | 2026-04-17 | Keep Touch Bar HUD always on |
| `e24d811` | 2026-04-16 | :)) |
| `44eb999` | 2026-04-16 | Harden touch bar customization and weather fallback |
| `3bc6fbd` | 2026-04-16 | Restore system auto on quit and clarify fan mode behavior |
| `4db7203` | 2026-04-16 | Reduce redundant Touch Bar and menu refresh work |
| `7185d36` | 2026-04-15 | Improve fan control and alert surfaces |
| `c0c476d` | 2026-04-14 | e |
| `6675114` | 2026-04-13 | e |
| `2664fd1` | 2026-04-11 | Update Core Monitor |
| `011232b` | 2026-04-11 | Update website install video |
| `0096e86` | 2026-04-08 | Remove unnecessary AppCoordinator deinit |
| `31da3f2` | 2026-04-06 | ui update |
| `0fa238c` | 2026-04-02 | commits. |
| `3651f98` | 2026-03-29 | Remove CoreVisor and virtualization support |
| `4537bc5` | 2026-03-28 | Detect fan SMC keys and add wake-reapplied fan profiles |
| `ee5d86a` | 2026-03-28 | Add fan profiles, safety override, and wake reapply |
| `b436125` | 2026-03-28 | Improve Touch Bar behavior, CoreVisor UI, and docs |
| `3252194` | 2026-03-27 | Clean repo and keep only active Core-Monitor project |
| `61a73aa` | 2026-03-15 | Commit ig |
| `81e0938` | 2026-03-13 | Add auto fan aggressiveness slider and fix QEMU boot/display defaults |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import AppKit
import Combine
import Foundation

@available(macOS 13.0, *)
@MainActor
final class AppCoordinator: ObservableObject {
    let systemMonitor: SystemMonitor
    let fanController: FanController

    private let touchBarPresenter = TouchBarPrivatePresenter()
    private let customizationSettings = TouchBarCustomizationSettings.shared
    private let touchBarMonitoringReason = "touchbar"

    private lazy var coreMonTouchBarController = CoreMonTouchBarController(
        weatherProvider: nil,
        monitor: systemMonitor
    )

    private var launchObserver: NSObjectProtocol?
    private var activationObserver: NSObjectProtocol?
    private var resignObserver: NSObjectProtocol?
    private var workspaceActivationObserver: NSObjectProtocol?
    private var terminateObserver: NSObjectProtocol?
    private var customizationObserver: NSObjectProtocol?
    private var bootstrapWorkItem: DispatchWorkItem?
    private var touchBarReassertWorkItem: DispatchWorkItem?
    private weak var attachedWindow: NSWindow?

    init() {
        let monitor = SystemMonitor()
        let fanController = FanController(systemMonitor: monitor)
        self.systemMonitor = monitor
        self.fanController = fanController

        start()
    }

    func start() {
        systemMonitor.startMonitoring()
```
