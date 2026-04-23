# File: Core-Monitor/SystemMonitor.swift

## Current Role

- Owns the live sampling loop for CPU, memory, battery, disk, network, thermal, SMC, and supplemental control data.
- Publishes `SystemMonitorSnapshot` as the shared point-in-time model used by dashboard, menu bar, trends, and support surfaces.
- Keeps expensive process sampling adaptive so detailed process enumeration is hot only while detailed UI asks for it.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/SystemMonitor.swift`](../../../Core-Monitor/SystemMonitor.swift) |
| Wiki area | Core app |
| Exists in current checkout | True |
| Size | 49612 bytes |
| Binary | False |
| Line count | 1311 |
| Extension | `.swift` |

## Imports

`Combine`, `CoreAudio`, `Darwin`, `Foundation`, `IOKit`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| struct | `CPUStats` | 7 |
| enum | `MemoryPressureLevel` | 13 |
| struct | `MemoryStats` | 19 |
| struct | `BatteryInfo` | 34 |
| struct | `DiskStats` | 54 |
| struct | `SMCKeyData_vers_t` | 68 |
| struct | `SMCKeyData_pLimitData_t` | 76 |
| struct | `SMCKeyData_keyInfo_t` | 84 |
| struct | `SMCParamStruct` | 90 |
| class | `SystemMonitor` | 103 |
| enum | `ActivitySamplingMode` | 105 |
| struct | `NetworkStats` | 157 |
| func | `setBasicMode` | 246 |
| func | `startMonitoring` | 298 |
| func | `stopMonitoring` | 317 |
| func | `setDetailedSamplingEnabled` | 324 |
| func | `setInteractiveMonitoringEnabled` | 336 |
| func | `setMonitoringIntervalOverride` | 348 |
| func | `snapshotHealth` | 360 |
| func | `openSMCConnection` | 368 |
| func | `closeSMCConnection` | 396 |
| func | `detectFans` | 403 |
| func | `updateReadings` | 423 |
| func | `readBatteryInfoIfNeeded` | 511 |
| func | `readSystemControlsIfNeeded` | 518 |
| func | `updateTopProcesses` | 525 |
| func | `applyMonitoringIntervalIfNeeded` | 531 |
| func | `updateActivitySamplingMode` | 551 |
| func | `handleProcessInsightsChange` | 567 |
| func | `clearTopProcesses` | 574 |
| func | `readCPUTemperature` | 581 |
| func | `readGPUTemperature` | 590 |
| func | `readSSDTemperature` | 599 |
| func | `readNetworkStats` | 610 |
| func | `readDiskStats` | 656 |
| func | `readFanReadings` | 692 |
| func | `readCPUUsage` | 718 |
| func | `readCPUClusterUsage` | 771 |
| func | `usageForProcessorRange` | 824 |
| func | `readMemoryStats` | 848 |
| func | `readBatteryInfo` | 932 |
| func | `readSMCValue` | 1023 |
| func | `parseSMCBytes` | 1084 |
| func | `decodeSMCFloat` | 1143 |
| func | `isValid` | 1158 |
| func | `isSubnormalLike` | 1184 |
| func | `isCommonSensorMagnitude` | 1194 |
| func | `preferredFloatRange` | 1207 |
| func | `readSystemControls` | 1217 |
| func | `readOutputVolume` | 1251 |
| func | `readVolumeScalar` | 1271 |
| func | `fourCharCodeFrom` | 1288 |
| func | `sysctlString` | 1296 |
| func | `sysctlInt` | 1304 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `daa972c` | 2026-04-17 | Fix fan SMC float decoding |
| `bd91092` | 2026-04-16 | Fix merged disk refresh regression |
| `6fcd312` | 2026-04-16 | Throttle slow-moving system monitor reads |
| `767668c` | 2026-04-16 | Throttle disk stats refresh cadence |
| `be75b81` | 2026-04-16 | Add dashboard network throughput visibility |
| `108166d` | 2026-04-16 | Throttle disk stats refresh cadence |
| `e486572` | 2026-04-16 | Scope detailed sampling to active monitoring views |
| `f259317` | 2026-04-16 | Finish Xcode 16.2 CI repair |
| `7bd13ba` | 2026-04-16 | Mark monitoring models nonisolated |
| `0ef6575` | 2026-04-16 | Unify monitor refresh delivery paths |
| `5dc29ed` | 2026-04-16 | Add privacy controls and refine Core Monitor presentation |
| `728674a` | 2026-04-16 | Surface live monitoring freshness across the UI |
| `2a9a96b` | 2026-04-16 | Add memory and swap history to overview trends |
| `c7b6bac` | 2026-04-16 | Reduce duplicate monitor state and dashboard churn |
| `c39e966` | 2026-04-16 | Add recent thermal trend history to dashboard |
| `4db7203` | 2026-04-16 | Reduce redundant Touch Bar and menu refresh work |
| `7185d36` | 2026-04-15 | Improve fan control and alert surfaces |
| `81ce4d9` | 2026-04-14 | Save current Core-Monitor rescue changes |
| `c0c476d` | 2026-04-14 | e |
| `05e3328` | 2026-04-13 | commit |
| `011232b` | 2026-04-11 | Update website install video |
| `0fa238c` | 2026-04-02 | commits. |
| `34b59ac` | 2026-03-29 | Update app UI and website branding |
| `b436125` | 2026-03-28 | Improve Touch Bar behavior, CoreVisor UI, and docs |
| `3ddebed` | 2026-03-27 | add benchmark |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import Foundation
import Combine
import IOKit
import IOKit.ps
import Darwin
import CoreAudio

struct CPUStats {
    let usagePercent: Double
    let performanceCoreUsagePercent: Double?
    let efficiencyCoreUsagePercent: Double?
}

enum MemoryPressureLevel {
    case green
    case yellow
    case red
}

struct MemoryStats {
    let usagePercent: Double
    let usedGB: Double
    let totalGB: Double
    let pressure: MemoryPressureLevel
    let appGB: Double
    let wiredGB: Double
    let compressedGB: Double
    let freeGB: Double
    let pageInsBytes: UInt64
    let pageOutsBytes: UInt64
    let swapUsedBytes: UInt64
    let swapTotalBytes: UInt64
}

struct BatteryInfo {
    var hasBattery: Bool = false
    var chargePercent: Int?
    var isCharging: Bool = false
    var isPluggedIn: Bool = false
    var powerWatts: Double?
```
