# File: Core-Monitor/HelperDiagnosticsExporter.swift

## Current Role

- Builds exportable JSON reports for helper signing, helper installation, launch-at-login, menu bar reachability, and recovery recommendations.
- This is the preferred support artifact when fan control or helper trust fails.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/HelperDiagnosticsExporter.swift`](../../../Core-Monitor/HelperDiagnosticsExporter.swift) |
| Wiki area | Fan control, SMC, or helper |
| Exists in current checkout | True |
| Size | 14023 bytes |
| Binary | False |
| Line count | 346 |
| Extension | `.swift` |

## Imports

`AppKit`, `Foundation`, `Security`, `UniformTypeIdentifiers`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| enum | `HelperDiagnosticsConnectionState` | 5 |
| struct | `HelperDiagnosticsSigningInfo` | 13 |
| struct | `HelperDiagnosticsContext` | 20 |
| struct | `HelperDiagnosticsReport` | 46 |
| struct | `AppDetails` | 48 |
| struct | `HelperDetails` | 58 |
| struct | `LaunchAtLoginDetails` | 73 |
| struct | `MenuBarDetails` | 78 |
| enum | `HelperDiagnosticsExporter` | 92 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `675fabf` | 2026-04-17 | Ship 14.0.5 helper recovery release |
| `5dc29ed` | 2026-04-16 | Add privacy controls and refine Core Monitor presentation |
| `80000af` | 2026-04-16 | Add friendly host model names to diagnostics |
| `9d4d7d1` | 2026-04-16 | Capture dashboard launch state in support diagnostics |
| `3668c50` | 2026-04-16 | Add exportable helper diagnostics reports |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import AppKit
import Foundation
import Security
import UniformTypeIdentifiers

enum HelperDiagnosticsConnectionState: String, Codable, Equatable {
    case missing
    case unknown
    case checking
    case reachable
    case unreachable
}

struct HelperDiagnosticsSigningInfo: Codable, Equatable {
    let signedIdentifier: String?
    let teamIdentifier: String?
    let isAdHocOrUnsigned: Bool
    let issue: String?
}

struct HelperDiagnosticsContext: Equatable {
    let generatedAt: Date
    let appBundleIdentifier: String
    let appVersion: String
    let appBuild: String
    let macOSVersion: String
    let hostModelIdentifier: String
    let hostModelName: String
    let chipName: String
    let helperLabel: String
    let bundledHelperPath: String
    let bundledHelperExists: Bool
    let installedHelperPath: String
    let installedHelperExists: Bool
    let connectionState: HelperDiagnosticsConnectionState
    let helperStatusMessage: String?
    let fanBackendRepository: String
    let fanModeKeyFormat: String?
    let fanForceTestAvailable: Bool?
    let launchAtLoginEnabled: Bool
```
