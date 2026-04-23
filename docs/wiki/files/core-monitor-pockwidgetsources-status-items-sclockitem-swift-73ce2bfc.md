# File: Core-Monitor/PockWidgetSources/Status/Items/SClockItem.swift

## Current Role

- Area: Touch Bar and Pock widget runtime.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/PockWidgetSources/Status/Items/SClockItem.swift`](../../../Core-Monitor/PockWidgetSources/Status/Items/SClockItem.swift) |
| Wiki area | Touch Bar and Pock widget runtime |
| Exists in current checkout | True |
| Size | 985 bytes |
| Binary | False |
| Line count | 45 |
| Extension | `.swift` |

## Imports

`AppKit`, `Foundation`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `SClockItem` | 8 |
| func | `didLoad` | 26 |
| func | `didUnload` | 32 |
| func | `apply` | 34 |
| func | `reload` | 38 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `29afd92` | 2026-04-18 | Ship 14.0.7 localization update |
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
//  SClockItem.swift
//  Status widget item for Core Monitor.
//

import AppKit
import Foundation

final class SClockItem: StatusItem {
    private let clockLabel = NSTextField(labelWithString: "…")
    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("Hm")
        return formatter
    }()

    init() {
        didLoad()
    }

    deinit {
        didUnload()
    }

    var view: NSView { clockLabel }

    func didLoad() {
        clockLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        clockLabel.maximumNumberOfLines = 1
        reload()
    }

    func didUnload() {}

    func apply(theme: TouchBarTheme) {
        clockLabel.textColor = theme.primaryTextColor
    }

    @objc func reload() {
        formatter.locale = AppLocaleStore.currentLocale
```
