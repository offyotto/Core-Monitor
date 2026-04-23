# File: Core-Monitor/NetworkGraphView.swift

## Current Role

- Area: Core app.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/NetworkGraphView.swift`](../../../Core-Monitor/NetworkGraphView.swift) |
| Wiki area | Core app |
| Exists in current checkout | True |
| Size | 1832 bytes |
| Binary | False |
| Line count | 55 |
| Extension | `.swift` |

## Imports

`AppKit`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `NetworkGraphView` | 8 |
| func | `push` | 16 |

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
// NetworkGraphView.swift
// CoreMonitor — scrolling bar-graph of network throughput.
//
//  60×20pt view containing ~20 vertical bars.
//  Bars are cyan (#00D0FF) on black, newest bar on the right.

import AppKit

final class NetworkGraphView: NSView {
    var theme: TouchBarTheme = .dark {
        didSet { needsDisplay = true }
    }

    /// Ring buffer of normalised values [0.0 – 1.0], newest last.
    private var samples: [CGFloat] = Array(repeating: 0, count: TB.graphBarCount)

    func push(_ normalised: CGFloat) {
        samples.removeFirst()
        samples.append(min(max(normalised, 0), 1))
        needsDisplay = true
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: TB.graphW, height: TB.graphH)
    }

    override func draw(_ dirtyRect: NSRect) {
        let background = NSBezierPath(roundedRect: bounds, xRadius: 5, yRadius: 5)
        theme.graphBackgroundColor.setFill()
        background.fill()
        theme.barOutlineColor.setStroke()
        background.lineWidth = 1
        background.stroke()

        let count  = samples.count
        let insetBounds = bounds.insetBy(dx: 4, dy: 4)
        let barW   = insetBounds.width / CGFloat(max(count, 1))
        let maxH   = insetBounds.height

        for (i, val) in samples.enumerated() {
```
