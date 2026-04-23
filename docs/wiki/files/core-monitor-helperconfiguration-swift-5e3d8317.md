# File: Core-Monitor/HelperConfiguration.swift

## Current Role

- Area: Fan control, SMC, or helper.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/HelperConfiguration.swift`](../../../Core-Monitor/HelperConfiguration.swift) |
| Wiki area | Fan control, SMC, or helper |
| Exists in current checkout | True |
| Size | 647 bytes |
| Binary | False |
| Line count | 21 |
| Extension | `.swift` |

## Imports

`Foundation`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| enum | `HelperConfiguration` | 2 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `7185d36` | 2026-04-15 | Improve fan control and alert surfaces |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import Foundation

enum HelperConfiguration {
    private static let infoKey = "CoreMonitorPrivilegedHelperLabel"

    static var label: String {
        if let label = Bundle.main.object(forInfoDictionaryKey: infoKey) as? String,
           !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return label
        }

        if let privilegedExecutables = Bundle.main.object(forInfoDictionaryKey: "SMPrivilegedExecutables") as? [String: Any],
           let label = privilegedExecutables.keys.sorted().first,
           !label.isEmpty {
            return label
        }

        return "ventaphobia.smc-helper"
    }
}
```
