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
        }
    }
}
