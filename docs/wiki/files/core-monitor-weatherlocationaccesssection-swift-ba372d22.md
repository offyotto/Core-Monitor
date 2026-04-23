# File: Core-Monitor/WeatherLocationAccessSection.swift

## Current Role

- Area: Weather and location.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/WeatherLocationAccessSection.swift`](../../../Core-Monitor/WeatherLocationAccessSection.swift) |
| Wiki area | Weather and location |
| Exists in current checkout | True |
| Size | 5413 bytes |
| Binary | False |
| Line count | 152 |
| Extension | `.swift` |

## Imports

`CoreLocation`, `SwiftUI`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| struct | `WeatherLocationAccessSection` | 3 |
| struct | `WeatherLocationActionButtonStyle` | 134 |
| func | `makeBody` | 136 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `44eb999` | 2026-04-16 | Harden touch bar customization and weather fallback |
| `311dc52` | 2026-04-15 | Refine first-run onboarding and weather permissions |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import SwiftUI
import CoreLocation

struct WeatherLocationAccessSection: View {
    @ObservedObject var controller: WeatherLocationAccessController
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: symbolName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .frame(width: 18, height: 18)

                Text("Location Access")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(badgeTitle.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(accentColor.opacity(0.14))
                    .clipShape(Capsule())
            }

            Text(detailText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineSpacing(3)

            HStack(spacing: 8) {
                if let requestTitle {
                    Button(requestTitle) {
                        controller.requestAccess()
                    }
                    .buttonStyle(WeatherLocationActionButtonStyle())
                }
```
