# File: Core-Monitor/PockWidgetSources/Status/Items/SPowerItem.swift

## Current Role

- Area: Touch Bar and Pock widget runtime.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/PockWidgetSources/Status/Items/SPowerItem.swift`](../../../Core-Monitor/PockWidgetSources/Status/Items/SPowerItem.swift) |
| Wiki area | Touch Bar and Pock widget runtime |
| Exists in current checkout | True |
| Size | 4301 bytes |
| Binary | False |
| Line count | 135 |
| Extension | `.swift` |

## Imports

`AppKit`, `Foundation`, `IOKit`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| struct | `SPowerStatus` | 9 |
| class | `SPowerItem` | 15 |
| func | `didLoad` | 34 |
| func | `didUnload` | 43 |
| func | `apply` | 45 |
| func | `configureValueLabel` | 52 |
| func | `configureStackView` | 57 |
| func | `reload` | 68 |
| func | `updateIcon` | 90 |
| func | `buildBatteryIcon` | 118 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `4db7203` | 2026-04-16 | Reduce redundant Touch Bar and menu refresh work |
| `2664fd1` | 2026-04-11 | Update Core Monitor |
| `011232b` | 2026-04-11 | Update website install video |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
//
//  SPowerItem.swift
//  Status widget item for Core Monitor.
//

import AppKit
import Foundation
import IOKit.ps

private struct SPowerStatus {
    var isCharging: Bool
    var isCharged: Bool
    var currentValue: Int
}

final class SPowerItem: StatusItem {
    private var powerStatus = SPowerStatus(isCharging: false, isCharged: false, currentValue: 0)
    private var currentTheme: TouchBarTheme = .dark

    private let stackView = NSStackView(frame: .zero)
    private let iconView = NSImageView(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
    private let bodyView = NSView(frame: NSRect(x: 2, y: 2, width: 21, height: 8))
    private let valueLabel = NSTextField(labelWithString: "-%")

    init() {
        didLoad()
    }

    deinit {
        didUnload()
    }

    var view: NSView { stackView }

    func didLoad() {
        bodyView.wantsLayer = true
        bodyView.layer?.cornerRadius = 1
        configureValueLabel()
        configureStackView()
        stackView.wantsLayer = false
```
