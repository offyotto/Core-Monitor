# File: Core-Monitor/TouchBarConfiguration.swift

## Current Role

- Area: Touch Bar and Pock widget runtime.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/TouchBarConfiguration.swift`](../../../Core-Monitor/TouchBarConfiguration.swift) |
| Wiki area | Touch Bar and Pock widget runtime |
| Exists in current checkout | True |
| Size | 2303 bytes |
| Binary | False |
| Line count | 71 |
| Extension | `.swift` |

## Imports

`AppKit`, `CoreGraphics`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| enum | `TouchBarWidgetKind` | 3 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `44eb999` | 2026-04-16 | Harden touch bar customization and weather fallback |
| `8bfc685` | 2026-04-16 | Stabilize signing and WeatherKit release packaging |
| `b09dbec` | 2026-04-14 | Tighten app copy and weather privacy behavior |
| `6675114` | 2026-04-13 | e |
| `05e3328` | 2026-04-13 | commit |
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
import CoreGraphics

enum TouchBarWidgetKind: String, CaseIterable, Codable, Identifiable {
    case worldClocks
    case weather
    case controlCenter
    case dock
    case cpu
    case stats
    case detailedStats
    case combined
    case hardware
    case network
    case ramPressure

    var id: String { rawValue }

    var title: String {
        switch self {
        case .worldClocks: return "Status"
        case .weather: return "Weather"
        case .controlCenter: return "Brightness and Volume"
        case .dock: return "Dock"
        case .cpu: return "CPU"
        case .stats: return "Stats"
        case .detailedStats: return "Stats and Clock"
        case .combined: return "Combined"
        case .hardware: return "Hardware"
        case .network: return "Network"
        case .ramPressure: return "Memory Pressure"
        }
    }

    var subtitle: String {
        switch self {
        case .worldClocks: return "Wi-Fi, battery, and clock"
        case .weather: return "Local weather. Requires a WeatherKit-enabled build; location access enables local conditions."
        case .controlCenter: return "Brightness and volume controls"
        case .dock: return "Running apps and pinned items"
```
