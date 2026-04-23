# File: Core-Monitor/SMCHelperManager.swift

## Current Role

- Owns app-side helper installation, reachability probes, stale-helper repair, and trusted XPC calls.
- Tracks helper state as missing, unknown, checking, reachable, or unreachable instead of a weak installed/not-installed flag.
- Is a security-sensitive boundary because it decides when privileged fan writes are attempted.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/SMCHelperManager.swift`](../../../Core-Monitor/SMCHelperManager.swift) |
| Wiki area | Fan control, SMC, or helper |
| Exists in current checkout | True |
| Size | 30325 bytes |
| Binary | False |
| Line count | 835 |
| Extension | `.swift` |

## Imports

`AppKit`, `Combine`, `Darwin`, `Foundation`, `Security`, `ServiceManagement`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `SMCHelperManager` | 15 |
| struct | `ControlMetadata` | 18 |
| enum | `LegacyServiceManagementBridge` | 25 |
| enum | `ConnectionState` | 83 |
| func | `refreshStatus` | 118 |
| func | `refreshDiagnostics` | 156 |
| func | `ensureInstalledIfNeeded` | 176 |
| func | `execute` | 202 |
| func | `executeIfInstalled` | 205 |
| func | `execute` | 209 |
| func | `readValue` | 237 |
| func | `readControlMetadata` | 272 |
| func | `attemptPrivilegedInstall` | 306 |
| func | `attemptRepairingStaleHelper` | 319 |
| func | `shouldAttemptHelperRepair` | 335 |
| func | `helperInstallationLooksOrphaned` | 360 |
| func | `removeOrphanedHelperInstallInteractively` | 388 |
| func | `readValueViaHelper` | 466 |
| func | `executeViaBlessedXPC` | 474 |
| func | `installBundledHelper` | 538 |
| func | `installFromApp` | 639 |
| enum | `ProbeOutcome` | 662 |
| enum | `ConnectionResult` | 667 |
| func | `applyProbeOutcome` | 672 |
| func | `withHelperConnection` | 689 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `675fabf` | 2026-04-17 | Ship 14.0.5 helper recovery release |
| `bd80f00` | 2026-04-17 | Fix fan helper recovery and weather fallback |
| `b544f6f` | 2026-04-17 | Repair orphaned helper reinstall path |
| `9a8ae54` | 2026-04-17 | Retry stale helper on fan writes |
| `83e001c` | 2026-04-17 | Reinstall stale privileged helper |
| `40e9d5d` | 2026-04-17 | Fix privileged helper connection mismatch |
| `3bc6fbd` | 2026-04-16 | Restore system auto on quit and clarify fan mode behavior |
| `1ff7bdb` | 2026-04-16 | Refine helper health states and service alerts |
| `7185d36` | 2026-04-15 | Improve fan control and alert surfaces |
| `4d78a8f` | 2026-04-15 | e |
| `b09dbec` | 2026-04-14 | Tighten app copy and weather privacy behavior |
| `011232b` | 2026-04-11 | Update website install video |
| `31da3f2` | 2026-04-06 | ui update |
| `0fa238c` | 2026-04-02 | commits. |
| `3651f98` | 2026-03-29 | Remove CoreVisor and virtualization support |
| `b20fd3e` | 2026-03-29 | Refresh README media and system monitor branding |
| `3252194` | 2026-03-27 | Clean repo and keep only active Core-Monitor project |
| `61a73aa` | 2026-03-15 | Commit ig |
| `81e0938` | 2026-03-13 | Add auto fan aggressiveness slider and fix QEMU boot/display defaults |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import AppKit
import Foundation
import Combine
import Security
import ServiceManagement
import Darwin

// MARK: - SMC Helper Manager
//
// Manages execution of the privileged smc-helper binary that writes fan
// target speeds to the Apple System Management Controller (SMC).
//
// Preferred execution path:
//   1. Connect to a privileged Mach service installed via SMJobBless.

@MainActor
final class SMCHelperManager: ObservableObject {
    struct ControlMetadata: Equatable {
        let modeKeyFormat: String
        let forceTestAvailable: Bool
    }

    private static let missingInstallMessage = "Fan write access unavailable: privileged helper not installed."
    private static let incompleteInstallMessage = "Fan write access unavailable: the privileged helper install is incomplete or stale. Repair it from this app build."

    private enum LegacyServiceManagementBridge {
        typealias JobRemoveFunction = @convention(c) (
            CFString,
            CFString,
            AuthorizationRef,
            Bool,
            UnsafeMutablePointer<Unmanaged<CFError>?>?
        ) -> Bool

        typealias JobBlessFunction = @convention(c) (
            CFString,
            CFString,
            AuthorizationRef,
            UnsafeMutablePointer<Unmanaged<CFError>?>?
        ) -> Bool
```
