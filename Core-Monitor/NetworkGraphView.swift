// NetworkGraphView.swift
// CoreMonitor — scrolling bar-graph of network throughput, iStat style.
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
            let barH = max(1, maxH * val)
            let rect = NSRect(
                x: insetBounds.minX + CGFloat(i) * barW,
                y: insetBounds.minY,
                width: max(barW - 1, 1),
                height: barH
            )
            // Slightly brighter for recent bars
            let alpha = 0.55 + 0.45 * (CGFloat(i) / CGFloat(count))
            theme.accentBlue.withAlphaComponent(alpha).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 1.2, yRadius: 1.2).fill()
        }
    }
}
