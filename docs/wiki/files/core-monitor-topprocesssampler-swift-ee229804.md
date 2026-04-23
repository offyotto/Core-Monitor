# File: Core-Monitor/TopProcessSampler.swift

## Current Role

- Area: Core app.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/TopProcessSampler.swift`](../../../Core-Monitor/TopProcessSampler.swift) |
| Wiki area | Core app |
| Exists in current checkout | True |
| Size | 8603 bytes |
| Binary | False |
| Line count | 241 |
| Extension | `.swift` |

## Imports

`AppKit`, `Darwin`, `Foundation`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `TopProcessSampler` | 4 |
| struct | `SampledProcess` | 6 |
| struct | `AggregatedProcess` | 12 |
| func | `start` | 35 |
| func | `updateInterval` | 63 |
| func | `stop` | 68 |
| func | `sample` | 83 |
| func | `collectProcesses` | 126 |
| func | `aggregateProcesses` | 166 |
| func | `taskInfo` | 186 |
| func | `cpuTime` | 198 |
| func | `displayName` | 210 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `a2e946d` | 2026-04-16 | Avoid redundant top process sampling restarts |
| `ce9e812` | 2026-04-16 | Fix Xcode 16.2 CI compatibility |
| `3fff2ff` | 2026-04-16 | Fix Xcode 16.2 CI compatibility |
| `5b96f6f` | 2026-04-16 | Fix Xcode 16.2 CI compatibility |
| `4db7203` | 2026-04-16 | Reduce redundant Touch Bar and menu refresh work |
| `7185d36` | 2026-04-15 | Improve fan control and alert surfaces |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import AppKit
import Darwin
import Foundation

final class TopProcessSampler {
    private struct SampledProcess {
        let pid: pid_t
        let name: String
        let cpuPercent: Double
        let memoryBytes: UInt64
    }

    private struct AggregatedProcess {
        let pid: pid_t
        let name: String
        var cpuPercent: Double
        var memoryBytes: UInt64
    }

    var onUpdate: ((TopProcessSnapshot) -> Void)?

    private let samplingQueue = DispatchQueue(label: "CoreMonitor.TopProcessSampler", qos: .utility)
    private var interval: TimeInterval
    private let limit: Int
    private var timer: Timer?
    private var isRunning = false
    private var previousCPUTimeByPID: [pid_t: UInt64] = [:]
    private var previousSampleDate = Date()
    private var isSampling = false

    init(interval: TimeInterval = 5.0, limit: Int = 4) {
        self.interval = interval
        self.limit = limit
    }

    func start(interval: TimeInterval? = nil) {
        let requestedInterval = interval ?? self.interval
        guard Self.shouldRestartTimer(
            isRunning: isRunning,
            currentInterval: self.interval,
```
