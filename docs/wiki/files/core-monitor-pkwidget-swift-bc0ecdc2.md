# File: Core-Monitor/PKWidget.swift

## Current Role

- Area: Touch Bar and Pock widget runtime.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/PKWidget.swift`](../../../Core-Monitor/PKWidget.swift) |
| Wiki area | Touch Bar and Pock widget runtime |
| Exists in current checkout | True |
| Size | 745 bytes |
| Binary | False |
| Line count | 33 |
| Extension | `.swift` |

## Imports

`AppKit`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `PKWidget` | 2 |
| func | `viewWillAppear` | 14 |
| func | `viewDidAppear` | 16 |
| func | `viewWillDisappear` | 17 |
| func | `viewDidDisappear` | 18 |
| func | `prepareForCustomization` | 19 |
| struct | `PKWidgetInfo` | 23 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `011232b` | 2026-04-11 | Update website install video |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import AppKit

class PKWidget: NSObject {
    var customizationLabel: String = "Widget"

    var view: NSView {
        assertionFailure("PKWidget subclasses must override `view`.")
        return NSView(frame: .zero)
    }

    required override init() {
        super.init()
    }

    func viewWillAppear() {}
    func viewDidAppear() {}
    func viewWillDisappear() {}
    func viewDidDisappear() {}
    func prepareForCustomization() {}

    var imageForCustomization: NSImage? { nil }
}

struct PKWidgetInfo: Equatable {
    let bundleIdentifier: String
    let principalClass: AnyClass?
    let name: String

    static func == (lhs: PKWidgetInfo, rhs: PKWidgetInfo) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier
    }
}
```
