# File: Core-Monitor/PillView.swift

## Current Role

- Area: Core app.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/PillView.swift`](../../../Core-Monitor/PillView.swift) |
| Wiki area | Core app |
| Exists in current checkout | True |
| Size | 1589 bytes |
| Binary | False |
| Line count | 52 |
| Extension | `.swift` |

## Imports

`AppKit`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `PillView` | 4 |
| func | `setup` | 24 |
| func | `applyTheme` | 41 |

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
// yeah i dont paid enough for thisssssssssssssss

import AppKit

final class PillView: NSView {

    // Content is placed inside `contentView`; auto-sized to fit.
    let contentView = NSView()

    // Explicit fixed width override (pass 0 to auto-size)
    var fixedWidth: CGFloat = 0 {
        didSet { invalidateIntrinsicContentSize() }
    }

    var theme: TouchBarTheme = .dark {
        didSet { applyTheme() }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = TB.pillRadius
        layer?.borderWidth = 1
        applyTheme()

        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor,  constant: TB.hPad),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -TB.hPad),
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
```
