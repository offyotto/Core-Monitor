# File: Core-Monitor/AlertModels.swift

## Current Role

- Area: Legacy alert system.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/AlertModels.swift`](../../../Core-Monitor/AlertModels.swift) |
| Wiki area | Legacy alert system |
| Exists in current checkout | True |
| Size | 21098 bytes |
| Binary | False |
| Line count | 409 |
| Extension | `.swift` |

## Imports

`Foundation`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| enum | `AlertCategory` | 2 |
| enum | `AlertSeverity` | 22 |
| enum | `AlertRuleKind` | 44 |
| struct | `AlertThreshold` | 166 |
| struct | `AlertRuleConfig` | 174 |
| enum | `AlertPreset` | 185 |
| enum | `AlertNotificationPolicy` | 212 |
| struct | `AlertEvent` | 228 |
| struct | `AlertRuleRuntime` | 239 |
| struct | `AlertActiveState` | 265 |
| struct | `AlertStore` | 278 |
| extension | `AlertPreset` | 303 |
| func | `configurations` | 305 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `ce9e812` | 2026-04-16 | Fix Xcode 16.2 CI compatibility |
| `5b96f6f` | 2026-04-16 | Fix Xcode 16.2 CI compatibility |
| `1ff7bdb` | 2026-04-16 | Refine helper health states and service alerts |
| `7185d36` | 2026-04-15 | Improve fan control and alert surfaces |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import Foundation

enum AlertCategory: String, Codable, CaseIterable, Identifiable {
    case thermal
    case performance
    case fanSafety
    case battery
    case services

    var id: String { rawValue }

    var title: String {
        switch self {
        case .thermal: return "Thermal"
        case .performance: return "Performance"
        case .fanSafety: return "Fan Safety"
        case .battery: return "Battery"
        case .services: return "Services"
        }
    }
}

enum AlertSeverity: Int, Codable, CaseIterable, Comparable, Identifiable {
    case none = 0
    case info = 1
    case warning = 2
    case critical = 3

    var id: Int { rawValue }

    static func < (lhs: AlertSeverity, rhs: AlertSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .none: return "Stable"
        case .info: return "Info"
        case .warning: return "Warning"
        case .critical: return "Critical"
```
