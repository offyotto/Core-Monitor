// TouchBarConstants.swift
// CoreMonitor — single source of truth for every visual token.
// All values tuned from reference screenshots.

import AppKit
import Foundation

enum TB {
    static let refreshInterval: TimeInterval = 10

    // ── Physical Touch Bar geometry ───────────────────────────────────────
    /// Physical height of the Touch Bar strip in points.
    static let stripH: CGFloat = 30

    // ── Group pill ────────────────────────────────────────────────────────
    /// Vertical inset so the pill is shorter than the strip.
    static let pillVInset:  CGFloat = 2
    static let pillH:       CGFloat = stripH - pillVInset * 2   // = 24
    static let pillRadius:  CGFloat = 7.5

    // ── Inter-group gap ───────────────────────────────────────────────────
    static let groupGap:    CGFloat = 8

    // ── Horizontal padding inside a pill ─────────────────────────────────
    static let hPad:        CGFloat = 12
    static let innerGap:    CGFloat = 8

    // ── Typography — SF Pro across the board ─────────────────────────────
    /// Tiny uppercase label above a bar or beside a value (MEM / SSD / CPU / FPS / BAT)
    static let fontKey   = NSFont.systemFont(ofSize: 8,  weight: .semibold)
    /// Value text (13%, 45°, 12, Way Out)
    static let fontVal   = NSFont.systemFont(ofSize: 11, weight: .semibold)
    /// Large time / date (10:38 / Mon 3:03 / Apr 30th)
    static let fontBig   = NSFont.monospacedDigitSystemFont(ofSize: 16, weight: .bold)
    /// Network speed lines (↑ 13 KB/s)
    static let fontNet   = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
    /// Flag + time zone lines
    static let fontTZ    = NSFont.systemFont(ofSize: 11, weight: .semibold)
    /// Weather condition tiny label
    static let fontCond  = NSFont.systemFont(ofSize: 9,  weight: .regular)

    // ── Color ─────────────────────────────────────────────────────────────
    static let cyan          = NSColor(red: 0.25, green: 0.67, blue: 0.97, alpha: 1)
    static let purple        = NSColor(red: 0.43, green: 0.30, blue: 0.89, alpha: 1)

    // ── Usage bar geometry ────────────────────────────────────────────────
    static let barW:     CGFloat = 42
    static let barH:     CGFloat = 8
    static let barRadius: CGFloat = 3

    // ── SF Symbol sizes ───────────────────────────────────────────────────
    static let iconSizeLg:  CGFloat = 18
    static let iconSizeMd:  CGFloat = 14
    static let iconSizeSm:  CGFloat = 11    // small inline

    // ── Network graph ─────────────────────────────────────────────────────
    static let graphW:   CGFloat = 52
    static let graphH:   CGFloat = 16
    static let graphBarCount = 16

    // ── Helpers ───────────────────────────────────────────────────────────

    static func label(_ string: String, font: NSFont, color: NSColor) -> NSTextField {
        let f = NSTextField(labelWithString: string)
        f.font            = font
        f.textColor       = color
        f.isBezeled       = false
        f.isEditable      = false
        f.drawsBackground = false
        f.lineBreakMode   = .byClipping
        f.sizeToFit()
        return f
    }

    static func label(_ string: String, font: NSFont, theme: TouchBarTheme, emphasis: Bool = true) -> NSTextField {
        label(string, font: font, color: emphasis ? theme.primaryTextColor : theme.secondaryTextColor)
    }

    static func symbol(_ name: String, size: CGFloat, color: NSColor = .white) -> NSImage {
        let cfg = NSImage.SymbolConfiguration(pointSize: size, weight: .medium)
        let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg) ?? NSImage()
        // Tint monochrome symbols
        if let tinted = img.copy() as? NSImage {
            tinted.lockFocus()
            color.set()
            NSRect(origin: .zero, size: tinted.size).fill(using: .sourceAtop)
            tinted.unlockFocus()
            return tinted
        }
        return img
    }

    /// Multicolor SF Symbol (for weather icons — respects palette)
    static func symbolMulticolor(_ name: String, size: CGFloat) -> NSImage {
        let cfg = NSImage.SymbolConfiguration(pointSize: size, weight: .medium)
            .applying(NSImage.SymbolConfiguration(paletteColors: [
                NSColor.systemYellow,
                NSColor.white,
                NSColor(red: 0.3, green: 0.6, blue: 1, alpha: 1)
            ]))
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg) ?? NSImage()
    }
}
