# File: Core-Monitor/BatteryDetailFormatter.swift

## Current Role

- Area: Core app.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/BatteryDetailFormatter.swift`](../../../Core-Monitor/BatteryDetailFormatter.swift) |
| Wiki area | Core app |
| Exists in current checkout | True |
| Size | 2289 bytes |
| Binary | False |
| Line count | 72 |
| Extension | `.swift` |

## Imports

`Foundation`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| enum | `BatteryDetailFormatter` | 2 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `16df8e4` | 2026-04-16 | Refine battery diagnostics and dashboard state flow |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import Foundation

enum BatteryDetailFormatter {
    static func powerStateDescription(for info: BatteryInfo) -> String {
        if info.isCharging {
            return "Charging"
        }
        if info.isPluggedIn {
            return "AC Power"
        }
        return "Battery Power"
    }

    static func sourceDescription(for info: BatteryInfo) -> String? {
        if let source = info.source?.trimmingCharacters(in: .whitespacesAndNewlines), !source.isEmpty {
            switch source {
            case "AC Power":
                return "Power Adapter"
            case "Battery Power":
                return "Internal Battery"
            default:
                return source
            }
        }

        guard info.hasBattery else { return nil }
        return info.isPluggedIn ? "Power Adapter" : "Internal Battery"
    }

    static func runtimeDescription(for info: BatteryInfo) -> String? {
        guard let minutes = info.timeRemainingMinutes, minutes >= 0 else { return nil }
        if minutes == 0 {
            return info.isCharging ? "Finishing soon" : "Less than 1m remaining"
        }

        let formattedDuration = durationDescription(minutes: minutes)
        if info.isCharging {
            return "\(formattedDuration) until full"
        }
        return "\(formattedDuration) remaining"
```
