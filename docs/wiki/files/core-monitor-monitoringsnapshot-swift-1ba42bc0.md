# File: Core-Monitor/MonitoringSnapshot.swift

## Current Role

- Area: Core app.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/MonitoringSnapshot.swift`](../../../Core-Monitor/MonitoringSnapshot.swift) |
| Wiki area | Core app |
| Exists in current checkout | True |
| Size | 6462 bytes |
| Binary | False |
| Line count | 224 |
| Extension | `.swift` |

## Imports

`Foundation`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| enum | `MonitoringTrendRange` | 2 |
| enum | `MonitoringFreshness` | 26 |
| struct | `MonitoringSnapshotHealth` | 33 |
| struct | `MonitoringTrendPoint` | 102 |
| struct | `MonitoringTrendSummary` | 107 |
| struct | `MonitoringTrendSeries` | 115 |
| func | `values` | 129 |
| func | `summary` | 133 |
| func | `relevantPoints` | 156 |
| struct | `ProcessActivity` | 166 |
| struct | `TopProcessSnapshot` | 176 |
| struct | `SystemMonitorSnapshot` | 184 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `f259317` | 2026-04-16 | Finish Xcode 16.2 CI repair |
| `ce9e812` | 2026-04-16 | Fix Xcode 16.2 CI compatibility |
| `5b96f6f` | 2026-04-16 | Fix Xcode 16.2 CI compatibility |
| `7bd13ba` | 2026-04-16 | Mark monitoring models nonisolated |
| `728674a` | 2026-04-16 | Surface live monitoring freshness across the UI |
| `c39e966` | 2026-04-16 | Add recent thermal trend history to dashboard |
| `7185d36` | 2026-04-15 | Improve fan control and alert surfaces |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import Foundation

enum MonitoringTrendRange: String, CaseIterable, Identifiable {
    case oneMinute
    case fiveMinutes
    case fifteenMinutes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oneMinute: return "1m"
        case .fiveMinutes: return "5m"
        case .fifteenMinutes: return "15m"
        }
    }

    var duration: TimeInterval {
        switch self {
        case .oneMinute: return 60
        case .fiveMinutes: return 5 * 60
        case .fifteenMinutes: return 15 * 60
        }
    }
}

enum MonitoringFreshness: Equatable {
    case waiting
    case live
    case delayed
    case stale
}

struct MonitoringSnapshotHealth: Equatable {
    let freshness: MonitoringFreshness
    let sampledAt: Date?
    let age: TimeInterval?
    let expectedInterval: TimeInterval

    init(sampledAt: Date, expectedInterval: TimeInterval, now: Date = Date()) {
```
