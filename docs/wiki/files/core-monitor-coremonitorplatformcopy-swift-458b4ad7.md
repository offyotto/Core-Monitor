# File: Core-Monitor/CoreMonitorPlatformCopy.swift

## Current Role

- Area: Core app.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/CoreMonitorPlatformCopy.swift`](../../../Core-Monitor/CoreMonitorPlatformCopy.swift) |
| Wiki area | Core app |
| Exists in current checkout | True |
| Size | 1264 bytes |
| Binary | False |
| Line count | 30 |
| Extension | `.swift` |

## Imports

`Foundation`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| enum | `CoreMonitorPlatformCopy` | 2 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `6cabf2c` | 2026-04-16 | Make onboarding copy platform-aware |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import Foundation

enum CoreMonitorPlatformCopy {
    static func welcomeIntroSubheadline(isAppleSilicon: Bool = SystemMonitor.isAppleSilicon) -> String {
        isAppleSilicon ? "Your M-series Mac, fully visible." : "Your Mac, fully visible."
    }

    static func welcomeIntroBody(isAppleSilicon: Bool = SystemMonitor.isAppleSilicon) -> String {
        if isAppleSilicon {
            return "Core Monitor gives you deep, real-time insight into your Apple Silicon Mac: thermals, memory pressure, fan behavior, power draw, and a customizable Touch Bar surface."
        }

        return "Core Monitor gives you deep, real-time insight into your Mac: thermals, memory pressure, fan behavior, power draw, and a customizable Touch Bar surface."
    }

    static func thermalMetricsBullet(isAppleSilicon: Bool = SystemMonitor.isAppleSilicon) -> String {
        isAppleSilicon
            ? "P-core and E-core usage, plus CPU temperature"
            : "CPU usage and temperature"
    }

    static func thermalStatusDetail(isAppleSilicon: Bool = SystemMonitor.isAppleSilicon) -> String {
        if isAppleSilicon {
            return "macOS thermal pressure on Apple Silicon."
        }

        return "macOS thermal pressure reported by the system."
    }
}
```
