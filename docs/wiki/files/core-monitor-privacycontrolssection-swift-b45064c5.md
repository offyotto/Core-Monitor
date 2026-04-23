# File: Core-Monitor/PrivacyControlsSection.swift

## Current Role

- Area: Privacy controls.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/PrivacyControlsSection.swift`](../../../Core-Monitor/PrivacyControlsSection.swift) |
| Wiki area | Privacy controls |
| Exists in current checkout | True |
| Size | 1342 bytes |
| Binary | False |
| Line count | 38 |
| Extension | `.swift` |

## Imports

`SwiftUI`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| struct | `PrivacyControlsSectionContent` | 2 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `133d9ad` | 2026-04-16 | Replace alert surfaces with monitoring status |
| `0690966` | 2026-04-16 | Surface privacy controls in system settings |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import SwiftUI

struct PrivacyControlsSectionContent: View {
    @ObservedObject private var privacySettings = PrivacySettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Privacy Controls")
                .font(.system(size: 16, weight: .bold))

            Toggle(
                "Include top app context in memory views",
                isOn: $privacySettings.processInsightsEnabled
            )
            .toggleStyle(.switch)

            Text(description)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if privacySettings.processInsightsEnabled == false {
                Text("Private mode is on.")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.bdAccent)
            }
        }
    }

    private var description: String {
        if privacySettings.processInsightsEnabled {
            return "Top app context stays on-device and helps explain CPU and memory spikes in the dashboard and menu bar."
        }

        return "Core Monitor still tracks memory pressure and top-process usage locally, but app names stay hidden from memory views while private mode is on."
    }
}
```
