# File: Core-Monitor/PKWidgetViewController.swift

## Current Role

- Area: Touch Bar and Pock widget runtime.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/PKWidgetViewController.swift`](../../../Core-Monitor/PKWidgetViewController.swift) |
| Wiki area | Touch Bar and Pock widget runtime |
| Exists in current checkout | True |
| Size | 859 bytes |
| Binary | False |
| Line count | 34 |
| Extension | `.swift` |

## Imports

`AppKit`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `PKWidgetViewController` | 2 |

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

internal final class PKWidgetViewController: NSViewController {
    private weak var widgetItem: PKWidgetTouchBarItem!
    private var widgetIdentifier: String!

    convenience init(item: PKWidgetTouchBarItem) {
        self.init()
        widgetIdentifier = item.identifier.rawValue
        widgetItem = item
        view = item.widget!.view
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        widgetItem?.widget?.viewWillAppear()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        widgetItem?.widget?.viewDidAppear()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        widgetItem?.widget?.viewWillDisappear()
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        widgetItem?.widget?.viewDidDisappear()
    }
}
```
