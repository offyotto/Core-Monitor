# File: Core-Monitor/ContentView.swift

## Current Role

- Large SwiftUI dashboard shell containing the main sidebar, overview surfaces, system cards, fan panel, Touch Bar settings, and about/help-adjacent UI.
- A high-risk file because visual refactors can cross monitoring, fan control, helper diagnostics, and onboarding behavior.
- Current architecture docs flag this as a pressure point that should keep shrinking into dedicated subviews.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/ContentView.swift`](../../../Core-Monitor/ContentView.swift) |
| Wiki area | Dashboard |
| Exists in current checkout | True |
| Size | 125603 bytes |
| Binary | False |
| Line count | 2866 |
| Extension | `.swift` |

## Imports

`AVFoundation`, `AppKit`, `Combine`, `Darwin`, `SwiftUI`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `AppModeState` | 8 |
| class | `AppAppearanceSettings` | 14 |
| extension | `Color` | 38 |
| struct | `CoreMonBackdrop` | 49 |
| struct | `CoreMonWindowShell` | 65 |
| struct | `CoreMonGlassBackground` | 116 |
| struct | `SidebarShellBackground` | 142 |
| struct | `CoreMonGlassPanel` | 166 |
| struct | `CopyOnTap` | 191 |
| func | `body` | 193 |
| extension | `View` | 211 |
| func | `copyOnTap` | 212 |
| struct | `SoftPressButtonStyle` | 214 |
| func | `makeBody` | 216 |
| struct | `DarkCard` | 229 |
| struct | `GaugeRing` | 247 |
| struct | `Sparkline` | 275 |
| struct | `MetricTile` | 307 |
| struct | `MonitoringTrendSection` | 383 |
| struct | `MonitoringTrendCard` | 485 |
| func | `deltaLabel` | 567 |
| struct | `MonitoringTrendMiniStat` | 573 |
| struct | `MonitoringTrendChart` | 590 |
| func | `yPosition` | 650 |
| struct | `MonitoringStatusCard` | 656 |
| func | `detailText` | 701 |
| func | `statusColor` | 714 |
| func | `statusMeta` | 727 |
| struct | `CompactRow` | 743 |
| struct | `FanBar` | 763 |
| struct | `BatteryBar` | 799 |
| func | `pill` | 845 |
| struct | `FanHelperStatusCard` | 851 |
| struct | `HelperDiagnosticsSupportCard` | 997 |
| func | `performPrimaryAction` | 1127 |
| func | `exportReport` | 1142 |
| struct | `DashboardShortcutCard` | 1162 |
| struct | `FanControlPanel` | 1241 |
| struct | `Snapshot` | 1242 |
| func | `modeIcon` | 1421 |
| func | `fanSummaryPill` | 1434 |
| enum | `SidebarItem` | 1447 |
| struct | `SidebarRow` | 1478 |
| struct | `Sidebar` | 1524 |
| struct | `DetailPane` | 1610 |
| func | `header` | 1878 |
| func | `emptyState` | 1886 |
| func | `levelRow` | 1899 |
| func | `loadColor` | 1932 |
| func | `tempColor` | 1933 |
| func | `hostModelName` | 1934 |
| struct | `AboutDetailsPanel` | 1938 |
| func | `aboutPill` | 1987 |
| struct | `TouchBarPreviewStrip` | 1998 |
| struct | `TouchBarWidgetPreview` | 2019 |
| func | `renderPreview` | 2030 |
| enum | `TouchBarPreviewFixture` | 2072 |
| struct | `TouchBarWidgetRow` | 2107 |
| struct | `TouchBarConfiguredItemRow` | 2142 |
| struct | `TouchBarCustomizationPanel` | 2220 |
| struct | `BetterDisplayInspiredHero` | 2554 |
| struct | `BasicModeView` | 2621 |
| func | `basicCell` | 2695 |
| func | `basicFanBtn` | 2726 |
| struct | `VisualEffectView` | 2748 |
| func | `makeNSView` | 2752 |
| func | `updateNSView` | 2760 |
| struct | `ContentView` | 2769 |
| func | `applyPendingDashboardRouteIfNeeded` | 2843 |
| func | `syncDashboardSampling` | 2855 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `29afd92` | 2026-04-18 | Ship 14.0.7 localization update |
| `32f6f43` | 2026-04-18 | Ship 14.0.6 Cupertino Touch Bar fix |
| `675fabf` | 2026-04-17 | Ship 14.0.5 helper recovery release |
| `83e001c` | 2026-04-17 | Reinstall stale privileged helper |
| `40e9d5d` | 2026-04-17 | Fix privileged helper connection mismatch |
| `7c1b882` | 2026-04-17 | Keep Touch Bar HUD always on |
| `e24d811` | 2026-04-16 | :)) |
| `cea99a5` | 2026-04-16 | Finish silent mode cleanup |
| `ebf3e12` | 2026-04-16 | Retire redundant silent fan mode |
| `133d9ad` | 2026-04-16 | Replace alert surfaces with monitoring status |
| `a570f09` | 2026-04-16 | Scope detailed sampling to active monitoring views |
| `cfea009` | 2026-04-16 | Polish launch-at-login recovery flow |
| `f2db2d4` | 2026-04-16 | Show live network rates in menu bar settings preview |
| `7c0c8d6` | 2026-04-16 | Add dashboard shortcut and app menu access |
| `be75b81` | 2026-04-16 | Add dashboard network throughput visibility |
| `44eb999` | 2026-04-16 | Harden touch bar customization and weather fallback |
| `1cc987e` | 2026-04-16 | Scope dashboard process sampling by surface |
| `e486572` | 2026-04-16 | Scope detailed sampling to active monitoring views |
| `4709cd6` | 2026-04-16 | Add live fan RPM to the balanced menu bar |
| `8bfc685` | 2026-04-16 | Stabilize signing and WeatherKit release packaging |
| `4d587ef` | 2026-04-16 | Restore standard quit controls in the accessory app |
| `b27fd63` | 2026-04-16 | Deep-link menu bar alerts into the dashboard |
| `0690966` | 2026-04-16 | Surface privacy controls in system settings |
| `5dc29ed` | 2026-04-16 | Add privacy controls and refine Core Monitor presentation |
| `3dbf6ac` | 2026-04-16 | Default fan control to system mode |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import SwiftUI
import Darwin
import AVFoundation
import Combine
import AppKit

// MARK: - App-wide mode state
final class AppModeState: ObservableObject {
    @Published var isBasicMode: Bool {
        didSet { UserDefaults.standard.set(isBasicMode, forKey: "basicMode") }
    }
    init() { isBasicMode = UserDefaults.standard.bool(forKey: "basicMode") }
}

@MainActor
final class AppAppearanceSettings: ObservableObject {
    static let shared = AppAppearanceSettings()
    private static let defaultSurfaceOpacity = 1.0

    @Published var surfaceOpacity: Double {
        didSet {
            UserDefaults.standard.set(surfaceOpacity, forKey: Self.surfaceOpacityKey)
        }
    }

    private static let surfaceOpacityKey = "coremonitor.surfaceOpacity"

    private init() {
        if let stored = UserDefaults.standard.object(forKey: Self.surfaceOpacityKey) as? Double {
            surfaceOpacity = min(max(stored, 0.0), 1.0)
        } else {
            surfaceOpacity = Self.defaultSurfaceOpacity
        }
    }
}

// MARK: - Colours (BetterDisplay-matched dark palette)
extension Color {
    static let bdSidebar = Color(red: 0.16, green: 0.17, blue: 0.22).opacity(0.90)
    static let bdContent = Color.clear
```
