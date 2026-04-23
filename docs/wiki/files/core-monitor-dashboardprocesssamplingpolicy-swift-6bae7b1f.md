# File: Core-Monitor/DashboardProcessSamplingPolicy.swift

## Current Role

- Area: Dashboard.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/DashboardProcessSamplingPolicy.swift`](../../../Core-Monitor/DashboardProcessSamplingPolicy.swift) |
| Wiki area | Dashboard |
| Exists in current checkout | True |
| Size | 434 bytes |
| Binary | False |
| Line count | 18 |
| Extension | `.swift` |

## Imports

`Foundation`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| enum | `DashboardProcessSamplingPolicy` | 2 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `a570f09` | 2026-04-16 | Scope detailed sampling to active monitoring views |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import Foundation

enum DashboardProcessSamplingPolicy {
    static func requiresDetailedSampling(
        isBasicMode: Bool,
        selection: SidebarItem
    ) -> Bool {
        guard isBasicMode == false else { return false }

        switch selection {
        case .memory:
            return true
        case .overview, .thermals, .fans, .battery, .system, .touchBar, .help, .about:
            return false
        }
    }
}
```
