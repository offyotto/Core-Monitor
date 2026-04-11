// WeatherTouchBarView.swift
// Core-Monitor
//
// Renders the iStat-style weather group:
//
//   ┌─────────────────────────────────────────────┐  h=30pt
//   │  [SF Symbol 18pt]  [22.4°]  [Mon 3:03]      │
//   └─────────────────────────────────────────────┘
//   background: NSColor(white:0.18 alpha:1)  cornerRadius: 5

import AppKit

// MARK: - Layout constants (tweak here to pixel-push)

private enum WeatherTBLayout {
    static let height:          CGFloat = 30
    static let hPad:            CGFloat = 8      // left/right inset inside pill
    static let spacing:         CGFloat = 5      // gap between elements
    static let iconSize:        CGFloat = 16     // SF Symbol pt size
    static let cornerRadius:    CGFloat = 5
    static let pillColor        = NSColor(white: 0.18, alpha: 1.0)
    static let primaryFont      = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
    static let secondaryFont    = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
    static let dimFont          = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
}

// MARK: - View

final class WeatherTouchBarView: NSView {

    // ── Public state ───────────────────────────────────────────────────────

    var state: WeatherState = .idle {
        didSet { needsLayout = true; needsDisplay = true }
    }

    /// Whether to show °C or °F
    var useCelsius: Bool = true {
        didSet { needsDisplay = true }
    }

    // ── Sub-views ──────────────────────────────────────────────────────────

    private let pillLayer = CALayer()
    private let iconView  = NSImageView()
    private let tempLabel = NSTextField(labelWithString: "")
    private let timeLabel = NSTextField(labelWithString: "")
    private let condLabel = NSTextField(labelWithString: "")

    // ── Init ───────────────────────────────────────────────────────────────

    override init(frame: NSRect) {
        super.init(frame: frame)
        commonInit()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true

        // pill background layer
        pillLayer.backgroundColor = WeatherTBLayout.pillColor.cgColor
        pillLayer.cornerRadius    = WeatherTBLayout.cornerRadius
        layer?.addSublayer(pillLayer)

        // icon
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        // temperature — primary large label
        configureLabel(tempLabel, font: WeatherTBLayout.primaryFont)
        addSubview(tempLabel)

        // condition — tiny dim label below temp
        configureLabel(condLabel, font: WeatherTBLayout.dimFont, alpha: 0.55)
        addSubview(condLabel)

        // time — right-side secondary label
        configureLabel(timeLabel, font: WeatherTBLayout.secondaryFont)
        addSubview(timeLabel)

        // Manual layout in layout() for Touch Bar pixel precision
        [iconView, tempLabel, condLabel, timeLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = true
        }
    }

    private func configureLabel(_ lbl: NSTextField, font: NSFont, alpha: CGFloat = 1.0) {
        lbl.font            = font
        lbl.textColor       = NSColor.white.withAlphaComponent(alpha)
        lbl.isBezeled       = false
        lbl.isEditable      = false
        lbl.drawsBackground = false
        lbl.lineBreakMode   = .byClipping
        lbl.cell?.truncatesLastVisibleLine = false
    }

    // ── Sizing ─────────────────────────────────────────────────────────────

    override var intrinsicContentSize: NSSize {
        NSSize(width: estimatedWidth(), height: WeatherTBLayout.height)
    }

    private func estimatedWidth() -> CGFloat {
        switch state {
        case .idle:
            return 56
        case .loading:
            return 80
        case .loaded(let s):
            let tempStr  = temperatureString(s.temperature)
            let timeStr  = timeString()
            let tempW    = tempStr.size(withAttributes: [.font: WeatherTBLayout.primaryFont]).width
            let timeW    = timeStr.size(withAttributes: [.font: WeatherTBLayout.secondaryFont]).width
            return WeatherTBLayout.hPad * 2 + WeatherTBLayout.iconSize + WeatherTBLayout.spacing
                 + tempW + WeatherTBLayout.spacing + timeW + 4
        case .error:
            return 80
        }
    }

    // ── Layout ─────────────────────────────────────────────────────────────

    override func layout() {
        super.layout()

        let b = bounds
        pillLayer.frame = b

        let cy = b.midY
        var x  = WeatherTBLayout.hPad

        switch state {
        case .idle:
            hideAll()

        case .loading:
            hideAll()
            tempLabel.stringValue = "Loading…"
            tempLabel.isHidden    = false
            tempLabel.sizeToFit()
            tempLabel.frame = NSRect(
                x: x,
                y: cy - tempLabel.frame.height / 2,
                width: tempLabel.frame.width,
                height: tempLabel.frame.height
            )

        case .loaded(let snapshot):
            showAll()

            // 1. Icon
            let icon = symbolImage(snapshot.symbolName, size: WeatherTBLayout.iconSize)
            iconView.image = icon
            iconView.frame = NSRect(x: x, y: cy - WeatherTBLayout.iconSize / 2,
                                    width: WeatherTBLayout.iconSize, height: WeatherTBLayout.iconSize)
            x += WeatherTBLayout.iconSize + WeatherTBLayout.spacing

            // 2. Temperature stacked with condition below
            let tempStr = temperatureString(snapshot.temperature)
            tempLabel.stringValue = tempStr
            tempLabel.sizeToFit()

            condLabel.stringValue = shortCondition(snapshot.condition)
            condLabel.sizeToFit()

            let stackH = tempLabel.frame.height + condLabel.frame.height - 1
            let stackY = cy - stackH / 2

            tempLabel.frame = NSRect(x: x, y: stackY + condLabel.frame.height - 1,
                                     width: tempLabel.frame.width, height: tempLabel.frame.height)
            condLabel.frame = NSRect(x: x, y: stackY,
                                     width: condLabel.frame.width, height: condLabel.frame.height)

            x += max(tempLabel.frame.width, condLabel.frame.width) + WeatherTBLayout.spacing

            // 3. Time right-side
            let timeStr = timeString()
            timeLabel.stringValue = timeStr
            timeLabel.sizeToFit()
            timeLabel.frame = NSRect(
                x: x,
                y: cy - timeLabel.frame.height / 2,
                width: timeLabel.frame.width,
                height: timeLabel.frame.height
            )

        case .error(let msg):
            hideAll()
            tempLabel.isHidden    = false
            tempLabel.stringValue = "⚠ \(msg.prefix(12))"
            tempLabel.sizeToFit()
            tempLabel.frame = NSRect(
                x: x,
                y: cy - tempLabel.frame.height / 2,
                width: tempLabel.frame.width,
                height: tempLabel.frame.height
            )
        }

        invalidateIntrinsicContentSize()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }

    // ── Helpers ────────────────────────────────────────────────────────────

    private func hideAll() {
        [iconView, tempLabel, condLabel, timeLabel].forEach { $0.isHidden = true }
    }

    private func showAll() {
        [iconView, tempLabel, condLabel, timeLabel].forEach { $0.isHidden = false }
    }

    private func temperatureString(_ celsius: Double) -> String {
        if useCelsius {
            return String(format: "%.0f°C", celsius)
        } else {
            let f = celsius * 9 / 5 + 32
            return String(format: "%.0f°F", f)
        }
    }

    private func timeString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE H:mm"
        return fmt.string(from: Date())
    }

    private func shortCondition(_ condition: String) -> String {
        condition.count > 12 ? String(condition.prefix(11)) + "…" : condition
    }

    private func symbolImage(_ name: String, size: CGFloat) -> NSImage {
        let cfg = NSImage.SymbolConfiguration(pointSize: size, weight: .medium)
            .applying(.init(paletteColors: [.systemYellow, .white, .systemBlue]))
        if let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg) {
            return img
        }
        return NSImage(systemSymbolName: "cloud.fill", accessibilityDescription: nil) ?? NSImage()
    }
}
