# File: Core-Monitor/MenubarController.swift

## Current Role

- Area: Menu bar.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/MenubarController.swift`](../../../Core-Monitor/MenubarController.swift) |
| Wiki area | Menu bar |
| Exists in current checkout | True |
| Size | 16923 bytes |
| Binary | False |
| Line count | 479 |
| Extension | `.swift` |

## Imports

`AppKit`, `Combine`, `SwiftUI`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| enum | `MenuBarItemKind` | 6 |
| class | `MenuBarController` | 56 |
| func | `refreshAllItems` | 111 |
| class | `SingleMenuBarItemController` | 118 |
| enum | `StatusTone` | 120 |
| struct | `StatusButtonState` | 139 |
| func | `setupStatusItem` | 182 |
| func | `refresh` | 192 |
| func | `updateStatusButton` | 196 |
| func | `statusButtonState` | 228 |
| func | `statusLabel` | 238 |
| func | `statusBarIcon` | 290 |
| func | `makeStatusBarIconAttachment` | 298 |
| func | `setupPopover` | 314 |
| func | `makePopoverView` | 331 |
| func | `openSelectionFromPopover` | 426 |
| func | `ensurePopover` | 431 |
| func | `togglePopover` | 438 |
| func | `popoverWillShow` | 456 |
| func | `popoverDidClose` | 469 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `4e417f6` | 2026-04-17 | Remove Alerts screen surface |
| `133d9ad` | 2026-04-16 | Replace alert surfaces with monitoring status |
| `58feb7a` | 2026-04-16 | Add network menu bar item and popover |
| `d837bc2` | 2026-04-16 | Add menu bar setup and help shortcuts |
| `4709cd6` | 2026-04-16 | Add live fan RPM to the balanced menu bar |
| `a116902` | 2026-04-16 | Refine menu bar helper status context |
| `b27fd63` | 2026-04-16 | Deep-link menu bar alerts into the dashboard |
| `adede3f` | 2026-04-16 | Clean up warning baseline for menu bar and weather |
| `ccc5d2c` | 2026-04-16 | Pin menu bar controllers to main actor |
| `0ef6575` | 2026-04-16 | Unify monitor refresh delivery paths |
| `4db7203` | 2026-04-16 | Reduce redundant Touch Bar and menu refresh work |
| `7185d36` | 2026-04-15 | Improve fan control and alert surfaces |
| `81ce4d9` | 2026-04-14 | Save current Core-Monitor rescue changes |
| `c0c476d` | 2026-04-14 | e |
| `05e3328` | 2026-04-13 | commit |
| `011232b` | 2026-04-11 | Update website install video |
| `48553d4` | 2026-04-06 | Refine landing page hero and top bar icon |
| `31da3f2` | 2026-04-06 | ui update |
| `3651f98` | 2026-03-29 | Remove CoreVisor and virtualization support |
| `3252194` | 2026-03-27 | Clean repo and keep only active Core-Monitor project |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import AppKit
import Combine
import SwiftUI

// MARK: - MenuBarItemKind
enum MenuBarItemKind: CaseIterable {
    case cpu, fan, memory, network, disk, temperature

    var systemImageName: String {
        switch self {
        case .cpu:
            return "cpu"
        case .fan:
            return "fanblades"
        case .memory:
            return "memorychip"
        case .network:
            return "arrow.down.arrow.up"
        case .disk:
            return "internaldrive"
        case .temperature:
            return "thermometer.medium"
        }
    }

    var title: String {
        switch self {
        case .cpu:
            return "CPU"
        case .fan:
            return "Fan"
        case .memory:
            return "Memory"
        case .network:
            return "Network"
        case .disk:
            return "Disk"
        case .temperature:
            return "Temperature"
        }
```
