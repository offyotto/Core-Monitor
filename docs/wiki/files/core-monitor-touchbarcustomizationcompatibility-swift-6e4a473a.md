# File: Core-Monitor/TouchBarCustomizationCompatibility.swift

## Current Role

- Owns persisted Touch Bar layouts, pinned apps, pinned folders, custom commands, themes, presentation mode, and legacy migration.
- The versioned persisted structs are the compatibility boundary for old user layouts.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/TouchBarCustomizationCompatibility.swift`](../../../Core-Monitor/TouchBarCustomizationCompatibility.swift) |
| Wiki area | Touch Bar and Pock widget runtime |
| Exists in current checkout | True |
| Size | 21732 bytes |
| Binary | False |
| Line count | 634 |
| Extension | `.swift` |

## Imports

`AppKit`, `Combine`, `Foundation`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| extension | `Notification.Name` | 4 |
| enum | `TouchBarPresentationMode` | 8 |
| enum | `StoredTouchBarTheme` | 29 |
| extension | `TouchBarTheme` | 45 |
| struct | `TouchBarPinnedApp` | 91 |
| struct | `TouchBarPinnedFolder` | 98 |
| struct | `TouchBarCustomWidget` | 104 |
| enum | `TouchBarItemConfiguration` | 112 |
| enum | `CodingKeys` | 186 |
| enum | `Discriminator` | 194 |
| func | `encode` | 217 |
| struct | `TouchBarPreset` | 237 |
| struct | `PersistedTouchBarConfigurationV6` | 290 |
| struct | `LegacyPersistedTouchBarConfigurationV5` | 296 |
| struct | `LegacyPersistedTouchBarConfigurationV4` | 301 |
| class | `TouchBarCustomizationSettings` | 306 |
| func | `applyPreset` | 398 |
| func | `restoreDefaults` | 402 |
| func | `contains` | 410 |
| func | `toggle` | 414 |
| func | `moveUp` | 425 |
| func | `moveDown` | 432 |
| func | `remove` | 439 |
| func | `addPinnedApps` | 446 |
| func | `addPinnedFolders` | 464 |
| func | `addCustomWidget` | 481 |
| func | `persistAndNotify` | 503 |
| func | `applyConfiguration` | 517 |
| extension | `TouchBarItemConfiguration` | 608 |
| extension | `MeterControl` | 620 |
| func | `update` | 622 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `65e3e0a` | 2026-04-17 | Fix release CI compatibility for 14.0.3 |
| `7c1b882` | 2026-04-17 | Keep Touch Bar HUD always on |
| `44eb999` | 2026-04-16 | Harden touch bar customization and weather fallback |
| `c408c06` | 2026-04-16 | Default fresh installs to system Touch Bar |
| `b09dbec` | 2026-04-14 | Tighten app copy and weather privacy behavior |
| `6675114` | 2026-04-13 | e |
| `05e3328` | 2026-04-13 | commit |
| `679aae6` | 2026-04-12 | changes. |
| `2664fd1` | 2026-04-11 | Update Core Monitor |
| `011232b` | 2026-04-11 | Update website install video |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import AppKit
import Combine
import Foundation

extension Notification.Name {
    static let touchBarCustomizationDidChange = Notification.Name("TouchBarCustomizationDidChange")
}

enum TouchBarPresentationMode: String, Codable, CaseIterable, Identifiable {
    case app
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .app: return "Core-Monitor"
        case .system: return "System"
        }
    }

    var subtitle: String {
        switch self {
        case .app: return "Show the Core-Monitor Touch Bar layout on the hardware Touch Bar"
        case .system: return "Keep editing the Core-Monitor layout, but show the standard macOS Touch Bar on the hardware until you press Command-Shift-6 or switch back to Core-Monitor"
        }
    }
}

private enum StoredTouchBarTheme: String, Codable {
    case dark
    case light

    init(theme: TouchBarTheme) {
        self = theme == .light ? .light : .dark
    }

    var theme: TouchBarTheme {
        switch self {
        case .dark: return .dark
```
