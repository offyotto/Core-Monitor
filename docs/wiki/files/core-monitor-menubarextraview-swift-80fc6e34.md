# File: Core-Monitor/MenuBarExtraView.swift

## Current Role

- Builds the rich menu bar popovers for CPU, memory, disk, network, temperature, and combined menu actions.
- Uses the shared snapshot and trend histories so menu bar status does not invent a parallel telemetry model.
- Regression risk is layout-driven: small visual changes can hide actions or stale-state messaging.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/MenuBarExtraView.swift`](../../../Core-Monitor/MenuBarExtraView.swift) |
| Wiki area | Menu bar |
| Exists in current checkout | True |
| Size | 69149 bytes |
| Binary | False |
| Line count | 1599 |
| Extension | `.swift` |

## Imports

`AppKit`, `SwiftUI`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| extension | `View` | 3 |
| func | `mbTracking` | 5 |
| extension | `Color` | 12 |
| struct | `MenuPopoverSurface` | 25 |
| struct | `MBRow` | 59 |
| struct | `MBSectionHeader` | 84 |
| struct | `MBDivider` | 102 |
| struct | `MenuBarMonitoringSummarySection` | 106 |
| func | `summaryPill` | 157 |
| func | `statusBadgeColor` | 177 |
| func | `thermalColor` | 181 |
| func | `freshnessColor` | 191 |
| func | `pillColor` | 216 |
| func | `thermalStateLabel` | 231 |
| struct | `MBActionButton` | 247 |
| struct | `MBQuickActionsSection` | 268 |
| struct | `SecondaryAction` | 270 |
| struct | `BigRing` | 299 |
| struct | `MiniSparkline` | 324 |
| struct | `CoreCircle` | 356 |
| struct | `DonutChart` | 373 |
| struct | `CPUMenuPopoverView` | 415 |
| func | `gpuRing` | 560 |
| func | `loadAvgString` | 582 |
| func | `uptimeString` | 588 |
| func | `tempColor` | 595 |
| func | `loadColor` | 597 |
| struct | `MemoryMenuPopoverView` | 603 |
| func | `memProcessRow` | 694 |
| func | `memoryProcessColor` | 761 |
| func | `formatByteCount` | 771 |
| struct | `DiskMenuPopoverView` | 785 |
| func | `diskLegendRow` | 872 |
| func | `diskProcessColor` | 919 |
| func | `diskProcessRow` | 930 |
| func | `syncDiskProcessSampling` | 941 |
| struct | `NetworkMenuPopoverView` | 954 |
| func | `rateBadge` | 1008 |
| func | `historyRow` | 1085 |
| func | `summaryLabel` | 1142 |
| func | `normalizedValues` | 1147 |
| struct | `TemperatureMenuPopoverView` | 1159 |
| func | `tempCircle` | 1233 |
| func | `tempRow` | 1272 |
| func | `tempColor` | 1331 |
| struct | `MenuBarStatusLabel` | 1337 |
| struct | `MenuBarMenuView` | 1380 |
| func | `metricRow` | 1540 |
| func | `actionRow` | 1550 |
| func | `statusPill` | 1558 |
| func | `tempColor` | 1568 |
| func | `loadColor` | 1572 |
| struct | `MBLegacyActionButton` | 1574 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `4e417f6` | 2026-04-17 | Remove Alerts screen surface |
| `3094642` | 2026-04-16 | Cache disk activity away from menu bar renders |
| `133d9ad` | 2026-04-16 | Replace alert surfaces with monitoring status |
| `58feb7a` | 2026-04-16 | Add network menu bar item and popover |
| `d837bc2` | 2026-04-16 | Add menu bar setup and help shortcuts |
| `e486572` | 2026-04-16 | Scope detailed sampling to active monitoring views |
| `0574661` | 2026-04-16 | Sync menu bar guidance with the latest thermal UX |
| `a116902` | 2026-04-16 | Refine menu bar helper status context |
| `b27fd63` | 2026-04-16 | Deep-link menu bar alerts into the dashboard |
| `5dc29ed` | 2026-04-16 | Add privacy controls and refine Core Monitor presentation |
| `728674a` | 2026-04-16 | Surface live monitoring freshness across the UI |
| `3c34251` | 2026-04-16 | Refine helper reachability across alerts and menu bar |
| `4db7203` | 2026-04-16 | Reduce redundant Touch Bar and menu refresh work |
| `7185d36` | 2026-04-15 | Improve fan control and alert surfaces |
| `b09dbec` | 2026-04-14 | Tighten app copy and weather privacy behavior |
| `81ce4d9` | 2026-04-14 | Save current Core-Monitor rescue changes |
| `c0c476d` | 2026-04-14 | e |
| `2da19d9` | 2026-04-13 | er |
| `05e3328` | 2026-04-13 | commit |
| `011232b` | 2026-04-11 | Update website install video |
| `deca3a0` | 2026-04-09 | Publish Sparkle test update 11.2.10 |
| `9aef922` | 2026-04-08 | Publish Sparkle test update 11.2.7 |
| `31da3f2` | 2026-04-06 | ui update |
| `0fa238c` | 2026-04-02 | commits. |
| `3651f98` | 2026-03-29 | Remove CoreVisor and virtualization support |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import SwiftUI
import AppKit

private extension View {
    @ViewBuilder
    func mbTracking(_ value: CGFloat) -> some View {
        self.tracking(value)
    }
}

// MARK: - Shared colours (dark popover palette)
private extension Color {
    static let mbBG     = Color.clear
    static let mbCard   = Color.white.opacity(0.06)
    static let mbDiv    = Color.white.opacity(0.10)
    static let mbAccent = Color.white.opacity(0.92)
    static let mbTint   = Color(red: 0.66, green: 0.72, blue: 0.96)
    static let mbBlue   = Color(red: 0.39, green: 0.66, blue: 1.00)
    static let mbGreen  = Color(red: 0.25, green: 0.90, blue: 0.58)
    static let mbOrange = Color(red: 1.00, green: 0.62, blue: 0.20)
    static let mbPurple = Color(red: 0.72, green: 0.52, blue: 1.00)
}

// MARK: - Shared surface (used by all popovers)
private struct MenuPopoverSurface<Content: View>: View {
    @ObservedObject private var appearanceSettings = AppAppearanceSettings.shared
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            VisualEffectView(material: .underWindowBackground,
                             blendingMode: .behindWindow,
                             opacity: appearanceSettings.surfaceOpacity)

            LinearGradient(
                colors: [
                    Color(red: 0.22, green: 0.24, blue: 0.33).opacity(0.06 * appearanceSettings.surfaceOpacity),
                    Color(red: 0.11, green: 0.12, blue: 0.19).opacity(0.07 * appearanceSettings.surfaceOpacity)
                ],
                startPoint: .topLeading, endPoint: .bottom
```
