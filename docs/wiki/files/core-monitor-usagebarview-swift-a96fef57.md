# File: Core-Monitor/UsageBarView.swift

## Current Role

- Area: Core app.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/UsageBarView.swift`](../../../Core-Monitor/UsageBarView.swift) |
| Wiki area | Core app |
| Exists in current checkout | True |
| Size | 1506 bytes |
| Binary | False |
| Line count | 44 |
| Extension | `.swift` |

## Imports

`AppKit`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `UsageBarView` | 9 |

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
// UsageBarView.swift
// CoreMonitor — the thin cyan fill bar seen under MEM / SSD / CPU values.
//
//  ┌────────────────────────┐  3pt tall, 28pt wide
//  │████████████░░░░░░░░░░░░│  cyan fill on gray track
//  └────────────────────────┘

import AppKit

final class UsageBarView: NSView {
    var theme: TouchBarTheme = .dark {
        didSet { needsDisplay = true }
    }

    var fraction: CGFloat = 0.5 {  // 0.0 – 1.0
        didSet { needsDisplay = true }
    }

    var fillColor: NSColor = TouchBarTheme.dark.accentBlue {
        didSet { needsDisplay = true }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: TB.barW, height: TB.barH)
    }

    override func draw(_ dirtyRect: NSRect) {
        let outline = NSBezierPath(roundedRect: bounds, xRadius: TB.barRadius, yRadius: TB.barRadius)
        theme.barTrackColor.setFill()
        outline.fill()
        theme.barOutlineColor.setStroke()
        outline.lineWidth = 1
        outline.stroke()

        // Fill
        let fillW = max(0, min((bounds.width - 4) * fraction, bounds.width - 4))
        if fillW > 0.5 {
            let fillRect = NSRect(x: 2, y: 2, width: fillW, height: bounds.height - 4)
            fillColor.setFill()
            NSBezierPath(roundedRect: fillRect, xRadius: TB.barRadius, yRadius: TB.barRadius).fill()
```
