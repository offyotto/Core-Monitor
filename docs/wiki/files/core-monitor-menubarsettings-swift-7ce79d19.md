# File: Core-Monitor/MenuBarSettings.swift

## Current Role

- Defines menu bar visibility presets and validates item enablement so the app remains reachable.
- Persists user menu bar density choices and broadcasts configuration changes to controllers.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/MenuBarSettings.swift`](../../../Core-Monitor/MenuBarSettings.swift) |
| Wiki area | Menu bar |
| Exists in current checkout | True |
| Size | 5540 bytes |
| Binary | False |
| Line count | 174 |
| Extension | `.swift` |

## Imports

`Combine`, `Foundation`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| extension | `Notification.Name` | 3 |
| enum | `MenuBarVisibilityPreset` | 7 |
| class | `MenuBarSettings` | 52 |
| func | `isEnabled` | 78 |
| func | `setEnabled` | 95 |
| func | `restoreDefaults` | 110 |
| func | `applyPreset` | 114 |
| func | `applyPreset` | 118 |
| func | `assign` | 143 |
| func | `ensureAccessibleConfiguration` | 160 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `58feb7a` | 2026-04-16 | Add network menu bar item and popover |
| `4709cd6` | 2026-04-16 | Add live fan RPM to the balanced menu bar |
| `4334e21` | 2026-04-16 | Refine menu bar default density and preset guidance |
| `25fb436` | 2026-04-15 | Improve dashboard controls and menu bar configuration |
| `b09dbec` | 2026-04-14 | Tighten app copy and weather privacy behavior |
| `81ce4d9` | 2026-04-14 | Save current Core-Monitor rescue changes |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import Foundation
import Combine

extension Notification.Name {
    static let menuBarSettingsDidChange = Notification.Name("CoreMonitor.MenuBarSettingsDidChange")
}

enum MenuBarVisibilityPreset: CaseIterable, Identifiable {
    case thermalFocus
    case balanced
    case full

    var id: Self { self }

    var title: String {
        switch self {
        case .thermalFocus:
            return "Compact"
        case .balanced:
            return "Balanced"
        case .full:
            return "Full"
        }
    }

    var detail: String {
        switch self {
        case .thermalFocus:
            return "Keep the menu bar heat-first with CPU load and temperature only."
        case .balanced:
            return "Show CPU load, live fan RPM, and temperature without turning the menu bar into noise."
        case .full:
            return "Expose CPU, fan, memory, network, storage, and temperature all at once."
        }
    }

    var isRecommended: Bool {
        self == .balanced
    }

```
