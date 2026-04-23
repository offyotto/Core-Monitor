# File: Core-Monitor/PockWidgetSources/Status/StatusItem.swift

## Current Role

- Area: Touch Bar and Pock widget runtime.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/PockWidgetSources/Status/StatusItem.swift`](../../../Core-Monitor/PockWidgetSources/Status/StatusItem.swift) |
| Wiki area | Touch Bar and Pock widget runtime |
| Exists in current checkout | True |
| Size | 1306 bytes |
| Binary | False |
| Line count | 57 |
| Extension | `.swift` |

## Imports

`AppKit`, `Foundation`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| protocol | `StatusItem` | 10 |
| func | `reload` | 13 |
| func | `didLoad` | 14 |
| func | `didUnload` | 15 |
| func | `apply` | 16 |
| extension | `Timer` | 18 |
| class | `TempWrapper` | 20 |
| func | `_timeAction` | 44 |

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
//  StatusItem.swift
//  Status
//
//  Status widget source for Core Monitor.
//

import AppKit
import Foundation

protocol StatusItem: AnyObject {
    var view: NSView { get }
    func reload()
    func didLoad()
    func didUnload()
    func apply(theme: TouchBarTheme)
}

extension Timer {
    private class TempWrapper {
        var timerAction: () -> Void
        weak var target: AnyObject?

        init(timerAction: @escaping () -> Void, target: AnyObject) {
            self.timerAction = timerAction
            self.target = target
        }
    }

    static func scheduledTimer(
        timeInterval: TimeInterval,
        target: AnyObject,
        repeats: Bool = false,
        action: @escaping () -> Void
    ) -> Timer {
        scheduledTimer(
            timeInterval: timeInterval,
            target: self,
            selector: #selector(_timeAction(timer:)),
            userInfo: TempWrapper(timerAction: action, target: target),
```
