# File: Core-Monitor/MenuBarStatusSummary.swift

## Current Role

- Area: Menu bar.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/MenuBarStatusSummary.swift`](../../../Core-Monitor/MenuBarStatusSummary.swift) |
| Wiki area | Menu bar |
| Exists in current checkout | True |
| Size | 1858 bytes |
| Binary | False |
| Line count | 54 |
| Extension | `.swift` |

## Imports

`Foundation`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| enum | `MenuBarStatusPillTone` | 2 |
| struct | `MenuBarStatusPillSummary` | 10 |
| enum | `MenuBarStatusSummary` | 15 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `675fabf` | 2026-04-17 | Ship 14.0.5 helper recovery release |
| `cea99a5` | 2026-04-16 | Finish silent mode cleanup |
| `a116902` | 2026-04-16 | Refine menu bar helper status context |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import Foundation

enum MenuBarStatusPillTone: Equatable {
    case neutral
    case accent
    case good
    case warning
    case critical
}

struct MenuBarStatusPillSummary: Equatable {
    let label: String
    let tone: MenuBarStatusPillTone
}

enum MenuBarStatusSummary {
    static func fanModeSummary(for mode: FanControlMode) -> MenuBarStatusPillSummary {
        let resolvedMode = mode.canonicalMode

        if resolvedMode == .automatic {
            return MenuBarStatusPillSummary(label: "System Cooling", tone: .good)
        }

        let tone: MenuBarStatusPillTone = resolvedMode.guidance.ownership == .system ? .good : .accent
        return MenuBarStatusPillSummary(label: "Mode \(resolvedMode.title)", tone: tone)
    }

    static func helperSummary(
        for mode: FanControlMode,
        connectionState: SMCHelperManager.ConnectionState,
        isInstalled: Bool
    ) -> MenuBarStatusPillSummary {
        guard mode.requiresPrivilegedHelper else {
            if connectionState == .unreachable {
                return MenuBarStatusPillSummary(label: "Helper Attention", tone: .critical)
            }
            return MenuBarStatusPillSummary(label: "Helper Optional", tone: .neutral)
        }

        switch connectionState {
```
