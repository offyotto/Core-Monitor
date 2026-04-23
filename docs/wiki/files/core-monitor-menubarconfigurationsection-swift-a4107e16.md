# File: Core-Monitor/MenuBarConfigurationSection.swift

## Current Role

- Area: Menu bar.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/MenuBarConfigurationSection.swift`](../../../Core-Monitor/MenuBarConfigurationSection.swift) |
| Wiki area | Menu bar |
| Exists in current checkout | True |
| Size | 9189 bytes |
| Binary | False |
| Line count | 257 |
| Extension | `.swift` |

## Imports

`SwiftUI`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| struct | `MenuBarSettingsCard` | 2 |
| struct | `Snapshot` | 4 |
| func | `detail` | 125 |
| func | `preview` | 142 |
| func | `binding` | 169 |
| struct | `MenuBarPresetChip` | 177 |
| struct | `MenuBarToggleRow` | 223 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `f2db2d4` | 2026-04-16 | Show live network rates in menu bar settings preview |
| `58feb7a` | 2026-04-16 | Add network menu bar item and popover |
| `4709cd6` | 2026-04-16 | Add live fan RPM to the balanced menu bar |
| `4334e21` | 2026-04-16 | Refine menu bar default density and preset guidance |
| `25fb436` | 2026-04-15 | Improve dashboard controls and menu bar configuration |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import SwiftUI

struct MenuBarSettingsCard: View {
    struct Snapshot {
        var cpuUsagePercent: Double
        var fanSpeeds: [Int]
        var memoryUsagePercent: Double
        var networkDownloadBytesPerSecond: Double
        var networkUploadBytesPerSecond: Double
        var diskUsagePercent: Double
        var cpuTemperature: Double?
    }

    @ObservedObject private var menuBarSettings = MenuBarSettings.shared

    let snapshot: Snapshot

    var body: some View {
        CoreMonGlassPanel(
            cornerRadius: 18,
            tintOpacity: 0.12,
            strokeOpacity: 0.14,
            shadowRadius: 10,
            contentPadding: 16
        ) {
            VStack(alignment: .leading, spacing: 14) {
                header
                presetSection
                toggleSection

                if let warning = menuBarSettings.lastWarning, !warning.isEmpty {
                    Text(warning)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var header: some View {
```
