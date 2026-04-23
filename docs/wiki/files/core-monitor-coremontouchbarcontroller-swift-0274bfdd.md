# File: Core-Monitor/CoreMonTouchBarController.swift

## Current Role

- Area: Touch Bar and Pock widget runtime.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/CoreMonTouchBarController.swift`](../../../Core-Monitor/CoreMonTouchBarController.swift) |
| Wiki area | Touch Bar and Pock widget runtime |
| Exists in current checkout | True |
| Size | 16223 bytes |
| Binary | False |
| Line count | 465 |
| Extension | `.swift` |

## Imports

`AppKit`, `Combine`, `CoreWLAN`, `Foundation`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `CoreMonTouchBarController` | 5 |
| func | `start` | 69 |
| func | `stop` | 84 |
| func | `install` | 96 |
| func | `reloadCustomization` | 100 |
| func | `bindWeather` | 111 |
| func | `bindSystem` | 120 |
| func | `applyCustomization` | 131 |
| func | `startRefreshTimer` | 154 |
| func | `updateWeatherMonitoring` | 166 |
| func | `refreshViews` | 178 |
| func | `makeSnapshot` | 206 |
| func | `clamp` | 229 |
| func | `detailedClockStrings` | 234 |
| func | `formattedTime` | 242 |
| func | `formattedTime` | 246 |
| func | `formattedMonthDay` | 252 |
| func | `currentFPS` | 258 |
| func | `currentWiFiName` | 262 |
| func | `storageUsagePercent` | 266 |
| func | `currentTheme` | 278 |
| func | `configure` | 282 |
| func | `loadCustomization` | 298 |
| extension | `CoreMonTouchBarController` | 306 |
| func | `touchBar` | 308 |
| class | `TouchBarShortcutButton` | 328 |
| func | `openShortcut` | 352 |
| func | `configureIconStyle` | 357 |
| enum | `TouchBarCommandRunner` | 374 |
| class | `TouchBarCustomCommandButton` | 418 |
| func | `runCommand` | 451 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `29afd92` | 2026-04-18 | Ship 14.0.7 localization update |
| `44eb999` | 2026-04-16 | Harden touch bar customization and weather fallback |
| `0ef6575` | 2026-04-16 | Unify monitor refresh delivery paths |
| `4db7203` | 2026-04-16 | Reduce redundant Touch Bar and menu refresh work |
| `4d78a8f` | 2026-04-15 | e |
| `b09dbec` | 2026-04-14 | Tighten app copy and weather privacy behavior |
| `6675114` | 2026-04-13 | e |
| `679aae6` | 2026-04-12 | changes. |
| `2664fd1` | 2026-04-11 | Update Core Monitor |
| `011232b` | 2026-04-11 | Update website install video |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import AppKit
import Combine
import CoreWLAN
import Foundation

@MainActor
final class CoreMonTouchBarController: NSObject {
    private static let customizationIdentifier = NSTouchBar.CustomizationIdentifier("com.coremonitor.touchbar.main")

    private(set) var touchBar: NSTouchBar
    let weatherViewModel: WeatherViewModel

    private let systemMonitor: SystemMonitor
    private let ownsSystemMonitor: Bool
    private let customizationSettings: TouchBarCustomizationSettings

    private var cancellables = Set<AnyCancellable>()
    private var widgets: [NSTouchBarItem.Identifier: PKWidgetInfo] = [:]
    private var configuredItems: [NSTouchBarItem.Identifier: TouchBarItemConfiguration] = [:]
    private var cachedItems: [NSTouchBarItem.Identifier: NSTouchBarItem] = [:]
    private var isStarted = false
    private var isWeatherRunning = false
    private var refreshTimer: Timer?
    private var lastRefreshDate = Date.distantPast
    private lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("Hm")
        return formatter
    }()
    private lazy var monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter
    }()

    init(
        weatherProvider: WeatherProviding? = nil,
        monitor: SystemMonitor? = nil,
        customizationSettings: TouchBarCustomizationSettings? = nil
    ) {
```
