# File: Core-Monitor/FanController.swift

## Current Role

- Owns user-facing fan modes, Smart/Manual/Custom behavior, custom preset persistence, and shutdown restoration semantics.
- Separates system-owned automatic control from Core-Monitor-owned managed profiles so UI copy can explain helper requirements accurately.
- Transforms temperature, wattage, fan ranges, and preset settings into helper write targets.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/FanController.swift`](../../../Core-Monitor/FanController.swift) |
| Wiki area | Fan control, SMC, or helper |
| Exists in current checkout | True |
| Size | 42882 bytes |
| Binary | False |
| Line count | 1172 |
| Extension | `.swift` |

## Imports

`AppKit`, `Combine`, `Foundation`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| enum | `FanControlMode` | 6 |
| enum | `FanControlOwnership` | 136 |
| enum | `FanModeHelperRequirement` | 141 |
| struct | `FanModeGuidance` | 151 |
| struct | `CustomFanPreset` | 166 |
| enum | `Sensor` | 168 |
| struct | `CurvePoint` | 183 |
| enum | `CodingKeys` | 188 |
| func | `encode` | 207 |
| struct | `PowerBoost` | 214 |
| func | `validationErrors` | 264 |
| func | `interpolatedSpeedPercent` | 332 |
| enum | `CustomPresetSaveOutcome` | 366 |
| class | `FanController` | 373 |
| func | `restoreSystemAutomaticOnTermination` | 438 |
| func | `setMode` | 451 |
| func | `setManualSpeed` | 463 |
| func | `setAutoAggressiveness` | 470 |
| func | `setAutoMaxSpeed` | 479 |
| func | `validateCustomPresetSource` | 488 |
| func | `currentCustomPresetDraft` | 497 |
| func | `validateCustomPreset` | 507 |
| func | `saveCustomPreset` | 511 |
| func | `prettyPrintedPresetSource` | 524 |
| func | `saveCustomPresetSource` | 528 |
| func | `restartAppToApplyCustomPreset` | 574 |
| func | `resetToSystemAutomatic` | 624 |
| func | `calibrateFanControl` | 642 |
| func | `startControlLoop` | 680 |
| func | `stopControlLoop` | 697 |
| func | `controlLoopInterval` | 702 |
| func | `applyCurrentMode` | 707 |
| func | `updateManagedControl` | 728 |
| func | `updateSmartProfile` | 766 |
| func | `updateCustomProfile` | 808 |
| func | `resolvedPowerBoost` | 884 |
| func | `applyFixedPercentProfile` | 893 |
| func | `applyFanSpeed` | 912 |
| func | `applyPerFanSpeeds` | 918 |
| func | `canActivatePrivilegedMode` | 948 |
| func | `runSmcHelper` | 959 |
| func | `ensureHelperInstalledIfNeeded` | 967 |
| func | `resolvedFanCount` | 975 |
| func | `helperUnavailableMessage` | 998 |
| func | `passiveStatusMessage` | 1005 |
| func | `fanCalibrationCandidateKeys` | 1024 |
| func | `registerForWakeNotifications` | 1046 |
| func | `customPresetFileURL` | 1069 |
| func | `loadCustomPresetFromDisk` | 1077 |
| func | `decodeCustomPreset` | 1117 |
| func | `prettyPrintedJSONString` | 1128 |
| func | `loadSettings` | 1137 |
| func | `saveSettings` | 1163 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `675fabf` | 2026-04-17 | Ship 14.0.5 helper recovery release |
| `cea99a5` | 2026-04-16 | Finish silent mode cleanup |
| `ebf3e12` | 2026-04-16 | Retire redundant silent fan mode |
| `b8fd8a6` | 2026-04-16 | Clarify silent mode helper handoff semantics |
| `77dcc07` | 2026-04-16 | Make silent fan mode truly system-owned |
| `ce9e812` | 2026-04-16 | Fix Xcode 16.2 CI compatibility |
| `3fff2ff` | 2026-04-16 | Fix Xcode 16.2 CI compatibility |
| `5b96f6f` | 2026-04-16 | Fix Xcode 16.2 CI compatibility |
| `3dbf6ac` | 2026-04-16 | Default fan control to system mode |
| `3bc6fbd` | 2026-04-16 | Restore system auto on quit and clarify fan mode behavior |
| `5691635` | 2026-04-16 | Improve custom fan curve editing |
| `7185d36` | 2026-04-15 | Improve fan control and alert surfaces |
| `4d78a8f` | 2026-04-15 | e |
| `b09dbec` | 2026-04-14 | Tighten app copy and weather privacy behavior |
| `81ce4d9` | 2026-04-14 | Save current Core-Monitor rescue changes |
| `c0c476d` | 2026-04-14 | e |
| `011232b` | 2026-04-11 | Update website install video |
| `0fa238c` | 2026-04-02 | commits. |
| `3651f98` | 2026-03-29 | Remove CoreVisor and virtualization support |
| `4537bc5` | 2026-03-28 | Detect fan SMC keys and add wake-reapplied fan profiles |
| `ee5d86a` | 2026-03-28 | Add fan profiles, safety override, and wake reapply |
| `3252194` | 2026-03-27 | Clean repo and keep only active Core-Monitor project |
| `61a73aa` | 2026-03-15 | Commit ig |
| `81e0938` | 2026-03-13 | Add auto fan aggressiveness slider and fix QEMU boot/display defaults |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import Foundation
import Combine
import AppKit

// MARK: - Fan Control Modes

enum FanControlMode: String, CaseIterable {
    case smart
    case silent
    case balanced
    case performance
    case max
    case manual
    case custom
    case automatic

    static var quickModes: [FanControlMode] {
        [.smart, .balanced, .performance, .max, .manual, .custom, .automatic]
    }

    var canonicalMode: FanControlMode {
        switch self {
        case .silent:
            return .automatic
        default:
            return self
        }
    }
    var title: String {
        switch self {
        case .smart:       return "SMART"
        case .silent:      return "SYSTEM"
        case .balanced:    return "BALANCED"
        case .performance: return "PERFORMANCE"
        case .max:         return "MAX"
        case .manual:      return "MANUAL"
        case .custom:      return "CUSTOM"
        case .automatic:   return "SYSTEM"
        }
    }
```
