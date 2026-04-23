# File: Core-Monitor/GroupViews.swift

## Current Role

- Area: Core app.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/GroupViews.swift`](../../../Core-Monitor/GroupViews.swift) |
| Wiki area | Core app |
| Exists in current checkout | True |
| Size | 28663 bytes |
| Binary | False |
| Line count | 841 |
| Extension | `.swift` |

## Imports

`AppKit`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| struct | `TouchBarSystemSnapshot` | 2 |
| func | `sanitizedUnitCGFloat` | 19 |
| func | `hasDrawableGeometry` | 24 |
| class | `VerticalMeterGlyphView` | 31 |
| class | `MiniHistogramGlyphView` | 77 |
| class | `WaveformGlyphView` | 127 |
| class | `MiniScreenGraphView` | 177 |
| class | `TimeZoneGroupView` | 244 |
| func | `setup` | 262 |
| func | `update` | 287 |
| func | `applyTheme` | 292 |
| class | `WeatherGroupView` | 298 |
| func | `setup` | 316 |
| func | `applyState` | 331 |
| func | `applyTheme` | 343 |
| class | `SystemStatsGroupView` | 348 |
| enum | `Style` | 350 |
| func | `metricColumn` | 381 |
| func | `setup` | 389 |
| func | `update` | 444 |
| func | `applyTheme` | 470 |
| class | `CPUGroupView` | 481 |
| func | `setup` | 502 |
| func | `update` | 550 |
| func | `barColor` | 560 |
| func | `applyTheme` | 566 |
| class | `NetworkGroupView` | 575 |
| func | `setup` | 593 |
| func | `update` | 615 |
| func | `applyTheme` | 624 |
| class | `CombinedGroupView` | 630 |
| func | `setup` | 656 |
| func | `update` | 724 |
| func | `applyTheme` | 741 |
| class | `HardwareIconsGroupView` | 751 |
| func | `makeSymbolView` | 776 |
| func | `setup` | 789 |
| func | `update` | 822 |
| func | `applyTheme` | 830 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `29afd92` | 2026-04-18 | Ship 14.0.7 localization update |
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

struct TouchBarSystemSnapshot {
    let memPct: Double
    let ssdPct: Double
    let cpuPct: Double
    let cpuTempC: Double
    let brightness: Float
    let batPct: Int
    let batCharging: Bool
    let netUpKBs: Double
    let netDownMBs: Double
    let fps: Int
    let wifiName: String
    let detailedClockTitle: String
    let detailedClockSubtitle: String
    let memoryPressure: MemoryPressureLevel
}

private func sanitizedUnitCGFloat(_ value: CGFloat, default defaultValue: CGFloat = 0) -> CGFloat {
    guard value.isFinite else { return defaultValue }
    return min(max(value, 0), 1)
}

private func hasDrawableGeometry(_ bounds: CGRect, minimumExtent: CGFloat = 2) -> Bool {
    bounds.width.isFinite &&
    bounds.height.isFinite &&
    bounds.width >= minimumExtent &&
    bounds.height >= minimumExtent
}

private final class VerticalMeterGlyphView: NSView, TouchBarThemable {
    var theme: TouchBarTheme = .dark {
        didSet { needsDisplay = true }
    }

    var fillFraction: CGFloat = 0.35 {
        didSet { needsDisplay = true }
    }

```
