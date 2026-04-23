# File: Core-Monitor/PKCoreMonWidgets.swift

## Current Role

- Area: Core app.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/PKCoreMonWidgets.swift`](../../../Core-Monitor/PKCoreMonWidgets.swift) |
| Wiki area | Core app |
| Exists in current checkout | True |
| Size | 11748 bytes |
| Binary | False |
| Line count | 340 |
| Extension | `.swift` |

## Imports

`AppKit`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `PKPillWidget` | 2 |
| func | `setup` | 29 |
| func | `applyTheme` | 55 |
| class | `PKBareWidget` | 61 |
| func | `setup` | 79 |
| class | `PKWorldClockWidget` | 89 |
| class | `PKStatusStripWidget` | 99 |
| class | `PKControlCenterWidget` | 110 |
| class | `PKDockWidget` | 121 |
| class | `PKCPUWidget` | 132 |
| class | `PKWeatherWidget` | 143 |
| class | `PKWeatherStripWidget` | 153 |
| class | `PKStatsWidget` | 164 |
| class | `PKDetailedStatsWidget` | 174 |
| class | `PKCombinedWidget` | 184 |
| class | `PKHardwareWidget` | 194 |
| class | `PKNetworkWidget` | 204 |
| class | `PKRAMPressureWidget` | 214 |
| extension | `TouchBarWidgetKind` | 225 |
| enum | `PKCoreMonWidgetCatalog` | 254 |
| enum | `TouchBarItemFactory` | 260 |
| enum | `PKCoreMonWidgetState` | 291 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `6675114` | 2026-04-13 | e |
| `05e3328` | 2026-04-13 | commit |
| `2664fd1` | 2026-04-11 | Update Core Monitor |
| `011232b` | 2026-04-11 | Update website install video |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import AppKit

class PKPillWidget: PKWidget {
    let kind: TouchBarWidgetKind
    let contentView: NSView
    private let themableContent: any TouchBarThemable
    private let containerView: NSView
    private let pillView = PillView()

    var theme: TouchBarTheme = .dark {
        didSet { applyTheme() }
    }

    init(kind: TouchBarWidgetKind, contentView: NSView & TouchBarThemable) {
        self.kind = kind
        self.contentView = contentView
        self.themableContent = contentView
        self.containerView = NSView(frame: NSRect(x: 0, y: 0, width: kind.estimatedWidth, height: TB.stripH))
        super.init()
        customizationLabel = kind.title
        setup()
    }

    required init() {
        fatalError("PKPillWidget subclasses must override init().")
    }

    override var view: NSView { containerView }

    private func setup() {
        containerView.translatesAutoresizingMaskIntoConstraints = false

        pillView.fixedWidth = kind.estimatedWidth
        pillView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(pillView)

        NSLayoutConstraint.activate([
            pillView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            pillView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            pillView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: TB.pillVInset),
```
