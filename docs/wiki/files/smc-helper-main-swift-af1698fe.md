# File: smc-helper/main.swift

## Current Role

- Implements the privileged helper process, AppleSMC reads/writes, fan manual/auto commands, and XPC service mode.
- Validates clients, fan IDs, RPM values, and four-character SMC keys inside the privileged process.
- Includes Apple Silicon fan-control mode-key probing and `Ftst` fallback behavior based on agoodkind/macos-smc-fan research.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`smc-helper/main.swift`](../../../smc-helper/main.swift) |
| Wiki area | Privileged helper target |
| Exists in current checkout | True |
| Size | 22496 bytes |
| Binary | False |
| Line count | 686 |
| Extension | `.swift` |

## Imports

`Foundation`, `IOKit`, `Security`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| struct | `SMCKeyData_vers_t` | 14 |
| struct | `SMCKeyData_pLimitData_t` | 22 |
| struct | `SMCKeyData_keyInfo_t` | 30 |
| struct | `SMCParamStruct` | 36 |
| struct | `SMCControlMetadata` | 52 |
| class | `SMCController` | 57 |
| func | `open` | 77 |
| func | `close` | 94 |
| func | `setFanManual` | 103 |
| func | `setFanAuto` | 112 |
| func | `controlMetadata` | 122 |
| func | `readValue` | 130 |
| func | `writeValue` | 162 |
| func | `getKeyInfo` | 191 |
| func | `detectHardwareCapabilities` | 220 |
| func | `keyExists` | 238 |
| func | `modeKey` | 243 |
| func | `hasForceTest` | 249 |
| func | `isForceTestEnabled` | 254 |
| func | `manualFanCount` | 260 |
| func | `resolvedFanCount` | 276 |
| func | `unlockFansIfNeeded` | 294 |
| func | `encode` | 318 |
| func | `parseSMCBytes` | 349 |
| func | `decodeSMCFloat` | 384 |
| func | `isValid` | 399 |
| func | `isSubnormalLike` | 425 |
| func | `isCommonSensorMagnitude` | 435 |
| func | `preferredFloatRange` | 448 |
| struct | `HelperError` | 459 |
| func | `fourCharCodeFrom` | 465 |
| func | `printUsageAndExit` | 473 |
| func | `validatedFanID` | 478 |
| func | `validatedFanID` | 485 |
| func | `validatedRPM` | 492 |
| func | `validatedRPM` | 499 |
| func | `validatedSMCKey` | 506 |
| class | `HelperClientValidator` | 514 |
| func | `authorize` | 534 |
| func | `validateProcess` | 546 |
| class | `SMCHelperXPCService` | 560 |
| func | `listener` | 569 |
| func | `setFanManual` | 581 |
| func | `setFanAuto` | 593 |
| func | `readValue` | 604 |
| func | `readControlMetadata` | 615 |
| func | `runCommandLineMode` | 630 |
| func | `runXPCServiceMode` | 670 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `675fabf` | 2026-04-17 | Ship 14.0.5 helper recovery release |
| `daa972c` | 2026-04-17 | Fix fan SMC float decoding |
| `40e9d5d` | 2026-04-17 | Fix privileged helper connection mismatch |
| `c54c313` | 2026-04-16 | Harden helper client authorization and XPC validation |
| `0fa238c` | 2026-04-02 | commits. |
| `3651f98` | 2026-03-29 | Remove CoreVisor and virtualization support |
| `4537bc5` | 2026-03-28 | Detect fan SMC keys and add wake-reapplied fan profiles |
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
import IOKit
import Security

// Apple Silicon fan-control mode detection and Ftst unlock behavior are based on
// the MIT-licensed research implementation from agoodkind/macos-smc-fan.

private typealias SMCBytes = (
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
)

private struct SMCKeyData_vers_t {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

private struct SMCKeyData_pLimitData_t {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

private struct SMCKeyData_keyInfo_t {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

private struct SMCParamStruct {
    var key: UInt32 = 0
    var vers = SMCKeyData_vers_t()
    var pLimitData = SMCKeyData_pLimitData_t()
```
