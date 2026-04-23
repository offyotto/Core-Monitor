# File: Core-Monitor/FanModeGuidanceCard.swift

## Current Role

- Area: Fan control, SMC, or helper.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/FanModeGuidanceCard.swift`](../../../Core-Monitor/FanModeGuidanceCard.swift) |
| Wiki area | Fan control, SMC, or helper |
| Exists in current checkout | True |
| Size | 8423 bytes |
| Binary | False |
| Line count | 218 |
| Extension | `.swift` |

## Imports

`SwiftUI`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| struct | `FanModeGuidanceCard` | 2 |
| func | `guidancePill` | 188 |
| enum | `FanModeGuidanceCopy` | 199 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `b8fd8a6` | 2026-04-16 | Clarify silent mode helper handoff semantics |
| `006d70b` | 2026-04-16 | Refresh Mac model registry and fan guidance |
| `3bc6fbd` | 2026-04-16 | Restore system auto on quit and clarify fan mode behavior |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import SwiftUI

struct FanModeGuidanceCard: View {
    let mode: FanControlMode
    let hasFans: Bool

    @ObservedObject private var helperManager = SMCHelperManager.shared

    var body: some View {
        let guidance = mode.guidance

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Selected Mode")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(mode.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(primaryColor)
                    Text(guidance.summary)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Text(ownershipLabel)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(primaryColor.opacity(0.14))
                    .clipShape(Capsule())
            }

            HStack(spacing: 8) {
                guidancePill(helperRequirementLabel, color: helperRequirementColor)
                if guidance.restoresSystemAutomaticOnExit {
```
