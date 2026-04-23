# File: Core-Monitor/PockWidgetSources/Status/Items/SLangItem.swift

## Current Role

- Area: Touch Bar and Pock widget runtime.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/PockWidgetSources/Status/Items/SLangItem.swift`](../../../Core-Monitor/PockWidgetSources/Status/Items/SLangItem.swift) |
| Wiki area | Touch Bar and Pock widget runtime |
| Exists in current checkout | True |
| Size | 6247 bytes |
| Binary | False |
| Line count | 201 |
| Extension | `.swift` |

## Imports

`AppKit`, `Carbon`, `Foundation`, `UniformTypeIdentifiers`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `SLangItem` | 12 |
| func | `didLoad` | 27 |
| func | `didUnload` | 40 |
| func | `apply` | 48 |
| func | `reload` | 53 |
| func | `shouldTintInputSource` | 93 |
| func | `selectedKeyboardInputSourceChanged` | 120 |
| extension | `TISInputSource` | 125 |
| func | `value` | 127 |
| extension | `URL` | 146 |
| extension | `NSImage` | 160 |
| func | `tint` | 164 |
| func | `copy` | 174 |
| func | `resizeWhileMaintainingAspectRatioToSize` | 186 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `05e3328` | 2026-04-13 | commit |
| `2664fd1` | 2026-04-11 | Update Core Monitor |
| `011232b` | 2026-04-11 | Update website install video |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
//
//  SLangItem.swift
//  Status
//
//  Status widget item for Core Monitor.
//

import AppKit
import Carbon
import Foundation
import UniformTypeIdentifiers

final class SLangItem: StatusItem {
    private var tisInputSource: TISInputSource?
    private let iconView = NSImageView(frame: NSRect(x: 0, y: 0, width: 26, height: 26))
    private var currentTheme: TouchBarTheme = .dark

    init() {
        didLoad()
    }

    deinit {
        didUnload()
    }

    var view: NSView { iconView }

    func didLoad() {
        iconView.imageAlignment = .alignCenter
        iconView.frame.size = NSSize(width: 18, height: 18)
        reload()
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(selectedKeyboardInputSourceChanged),
            name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
    }

```
