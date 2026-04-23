# File: Core-Monitor/NetworkThroughputFormatter.swift

## Current Role

- Area: Core app.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/NetworkThroughputFormatter.swift`](../../../Core-Monitor/NetworkThroughputFormatter.swift) |
| Wiki area | Core app |
| Exists in current checkout | True |
| Size | 1111 bytes |
| Binary | False |
| Line count | 36 |
| Extension | `.swift` |

## Imports

`Foundation`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| enum | `NetworkThroughputFormatter` | 2 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `e24d811` | 2026-04-16 | :)) |
| `58feb7a` | 2026-04-16 | Add network menu bar item and popover |
| `be75b81` | 2026-04-16 | Add dashboard network throughput visibility |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import Foundation

enum NetworkThroughputFormatter {
    private static let rateUnits = ["B/s", "KB/s", "MB/s", "GB/s", "TB/s"]
    private static let abbreviatedUnits = ["B", "K", "M", "G", "T"]

    static func compactRate(bytesPerSecond: Double) -> String {
        formattedValue(bytesPerSecond, units: rateUnits)
    }

    static func abbreviatedRate(bytesPerSecond: Double) -> String {
        formattedValue(bytesPerSecond, units: abbreviatedUnits)
    }

    private static func formattedValue(_ bytesPerSecond: Double, units: [String]) -> String {
        let normalized = max(abs(bytesPerSecond), 0)
        guard normalized.isFinite else { return "0 \(units[0])" }

        var value = normalized
        var unitIndex = 0
        while value >= 1_000, unitIndex < units.count - 1 {
            value /= 1_000
            unitIndex += 1
        }
        let decimals: Int
        switch value {
        case 0..<10 where unitIndex > 0:
            decimals = 1
        default:
            decimals = 0
        }

        return String(format: "%.\(decimals)f %@", value, units[unitIndex])
    }
}
```
