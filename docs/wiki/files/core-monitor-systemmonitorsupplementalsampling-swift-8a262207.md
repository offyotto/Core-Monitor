# File: Core-Monitor/SystemMonitorSupplementalSampling.swift

## Current Role

- Area: Core app.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/SystemMonitorSupplementalSampling.swift`](../../../Core-Monitor/SystemMonitorSupplementalSampling.swift) |
| Wiki area | Core app |
| Exists in current checkout | True |
| Size | 1546 bytes |
| Binary | False |
| Line count | 49 |
| Extension | `.swift` |

## Imports

`Foundation`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| struct | `SystemMonitorRefreshGate` | 2 |
| struct | `SystemMonitorSupplementalSamplingState` | 31 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `bd91092` | 2026-04-16 | Fix merged disk refresh regression |
| `6fcd312` | 2026-04-16 | Throttle slow-moving system monitor reads |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import Foundation

struct SystemMonitorRefreshGate {
    let minimumInterval: TimeInterval
    private(set) var lastRefreshAt: Date?

    init(minimumInterval: TimeInterval, lastRefreshAt: Date? = nil) {
        self.minimumInterval = minimumInterval
        self.lastRefreshAt = lastRefreshAt
    }

    mutating func shouldRefresh(now: Date, monitoringInterval: TimeInterval) -> Bool {
        let requiredInterval = max(minimumInterval, monitoringInterval)
        guard let lastRefreshAt else {
            self.lastRefreshAt = now
            return true
        }

        guard now.timeIntervalSince(lastRefreshAt) >= requiredInterval else {
            return false
        }

        self.lastRefreshAt = now
        return true
    }

    mutating func reset() {
        lastRefreshAt = nil
    }
}

struct SystemMonitorSupplementalSamplingState {
    private var batteryRefreshGate = SystemMonitorRefreshGate(minimumInterval: 10.0)
    private var systemControlsRefreshGate = SystemMonitorRefreshGate(minimumInterval: 5.0)

    mutating func shouldRefreshBattery(now: Date, monitoringInterval: TimeInterval) -> Bool {
        batteryRefreshGate.shouldRefresh(now: now, monitoringInterval: monitoringInterval)
    }

    mutating func shouldRefreshSystemControls(now: Date, monitoringInterval: TimeInterval) -> Bool {
```
