# File: Core-Monitor/PKWidgetTouchBarItem.swift

## Current Role

- Area: Touch Bar and Pock widget runtime.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/PKWidgetTouchBarItem.swift`](../../../Core-Monitor/PKWidgetTouchBarItem.swift) |
| Wiki area | Touch Bar and Pock widget runtime |
| Exists in current checkout | True |
| Size | 3867 bytes |
| Binary | False |
| Line count | 108 |
| Extension | `.swift` |

## Imports

`AppKit`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `PKWidgetTouchBarItem` | 2 |
| extension | `NSView` | 81 |
| func | `touchBarSnapshotImage` | 83 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `679aae6` | 2026-04-12 | changes. |
| `011232b` | 2026-04-11 | Update website install video |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import AppKit

internal final class PKWidgetTouchBarItem: NSCustomTouchBarItem {
    internal private(set) var widget: PKWidget?

    override var customizationLabel: String! {
        get { widget?.customizationLabel }
        set { widget?.customizationLabel = newValue ?? "Widget" }
    }

    convenience init?(widget: PKWidgetInfo) {
        self.init(widget: widget, identifier: NSTouchBarItem.Identifier(widget.bundleIdentifier))
    }

    convenience init?(widget: PKWidgetInfo, identifier: NSTouchBarItem.Identifier) {
        guard let clss = widget.principalClass as? PKWidget.Type else {
            return nil
        }

        self.init(identifier: identifier)
        self.widget = clss.init()
        self.widget?.customizationLabel = widget.name
        viewController = PKWidgetViewController(item: self)
    }

    private var defaultSnapshotView: NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 140, height: TB.stripH))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(calibratedWhite: 0.18, alpha: 1).cgColor
        container.layer?.cornerRadius = TB.pillRadius
        container.layer?.masksToBounds = true

        let imageView = NSImageView(frame: NSRect(x: 12, y: 6, width: 18, height: 18))
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 14, weight: .medium))
        imageView.contentTintColor = .white

        let label = NSTextField(labelWithString: widget?.customizationLabel ?? "Widget")
        label.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
```
