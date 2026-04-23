# File: Core-Monitor/DashboardShortcutManager.swift

## Current Role

- Area: Dashboard.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/DashboardShortcutManager.swift`](../../../Core-Monitor/DashboardShortcutManager.swift) |
| Wiki area | Dashboard |
| Exists in current checkout | True |
| Size | 4975 bytes |
| Binary | False |
| Line count | 158 |
| Extension | `.swift` |

## Imports

`AppKit`, `Carbon`, `Combine`, `Foundation`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| extension | `Notification.Name` | 5 |
| enum | `DashboardShortcutConfiguration` | 9 |
| class | `DashboardShortcutManager` | 44 |
| func | `setEnabled` | 63 |
| func | `updateRegistration` | 69 |
| func | `installEventHandlerIfNeeded` | 99 |
| func | `unregisterHotKey` | 145 |
| func | `removeEventHandler` | 151 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `7c0c8d6` | 2026-04-16 | Add dashboard shortcut and app menu access |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import AppKit
import Carbon
import Combine
import Foundation

extension Notification.Name {
    static let dashboardShortcutDidActivate = Notification.Name("CoreMonitor.DashboardShortcutDidActivate")
}

enum DashboardShortcutConfiguration {
    static let enabledDefaultsKey = "coremonitor.dashboardShortcut.enabled"
    static let keyEquivalent = "m"
    static let modifierFlags: NSEvent.ModifierFlags = [.command, .option]
    static let displayLabel = "Option-Command-M"

    fileprivate static let keyCode = UInt32(kVK_ANSI_M)
    fileprivate static let hotKeyID = EventHotKeyID(signature: fourCharCode("CMON"), id: 1)

    static func carbonModifiers(for flags: NSEvent.ModifierFlags = modifierFlags) -> UInt32 {
        var carbonFlags: UInt32 = 0

        if flags.contains(.command) {
            carbonFlags |= UInt32(cmdKey)
        }
        if flags.contains(.option) {
            carbonFlags |= UInt32(optionKey)
        }
        if flags.contains(.control) {
            carbonFlags |= UInt32(controlKey)
        }
        if flags.contains(.shift) {
            carbonFlags |= UInt32(shiftKey)
        }

        return carbonFlags
    }

    private static func fourCharCode(_ string: String) -> OSType {
        string.utf8.prefix(4).reduce(0) { partialResult, character in
            (partialResult << 8) | OSType(character)
```
