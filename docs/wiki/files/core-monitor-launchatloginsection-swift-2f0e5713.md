# File: Core-Monitor/LaunchAtLoginSection.swift

## Current Role

- Area: Startup and onboarding.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/LaunchAtLoginSection.swift`](../../../Core-Monitor/LaunchAtLoginSection.swift) |
| Wiki area | Startup and onboarding |
| Exists in current checkout | True |
| Size | 3984 bytes |
| Binary | False |
| Line count | 109 |
| Extension | `.swift` |

## Imports

`SwiftUI`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| struct | `LaunchAtLoginSection` | 2 |
| func | `iconColor` | 86 |
| func | `primaryDetail` | 97 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `cfea009` | 2026-04-16 | Polish launch-at-login recovery flow |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import SwiftUI

struct LaunchAtLoginSection: View {
    @ObservedObject var startupManager: StartupManager

    var body: some View {
        let summary = startupManager.statusSummary

        VStack(alignment: .leading, spacing: 10) {
            CoreMonGlassPanel(
                cornerRadius: 18,
                tintOpacity: 0.12,
                strokeOpacity: 0.14,
                shadowRadius: 10,
                contentPadding: 16
            ) {
                HStack(spacing: 14) {
                    Image(systemName: "power")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(iconColor(for: summary.tone))
                        .frame(width: 32, height: 32)
                        .background(iconColor(for: summary.tone).opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Launch at Login")
                            .font(.system(size: 13, weight: .semibold))
                        Text(primaryDetail(for: summary))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle(
                        "",
                        isOn: Binding(
                            get: { startupManager.isEnabled },
                            set: { startupManager.setEnabled($0) }
                        )
```
