# File: Core-Monitor/PockWidgetSources/Status/StatusWidget.swift

## Current Role

- Area: Touch Bar and Pock widget runtime.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/PockWidgetSources/Status/StatusWidget.swift`](../../../Core-Monitor/PockWidgetSources/Status/StatusWidget.swift) |
| Wiki area | Touch Bar and Pock widget runtime |
| Exists in current checkout | True |
| Size | 1701 bytes |
| Binary | False |
| Line count | 84 |
| Extension | `.swift` |

## Imports

`AppKit`, `Foundation`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `StatusWidget` | 10 |
| func | `setup` | 31 |
| func | `reload` | 40 |
| func | `clearItems` | 46 |
| func | `loadStatusElements` | 59 |
| func | `applyTheme` | 77 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `2664fd1` | 2026-04-11 | Update Core Monitor |
| `011232b` | 2026-04-11 | Update website install video |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
//
//  StatusWidget.swift
//  Status
//
//  Status widget source for Core Monitor.
//

import AppKit
import Foundation

final class StatusWidget: NSStackView, TouchBarThemable {
    var theme: TouchBarTheme = .dark {
        didSet { applyTheme() }
    }

    private var loadedItems: [StatusItem] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    deinit {
        clearItems()
    }

    private func setup() {
        orientation = .horizontal
        alignment = .centerY
        distribution = .fill
        spacing = 12
        translatesAutoresizingMaskIntoConstraints = false
        loadStatusElements()
    }

```
