import AppKit

struct TouchBarSystemSnapshot {
    let memPct: Double
    let ssdPct: Double
    let cpuPct: Double
    let cpuTempC: Double
    let batPct: Int
    let batCharging: Bool
    let netUpKBs: Double
    let netDownMBs: Double
    let fps: Int
    let wifiName: String
    let detailedClockTitle: String
    let detailedClockSubtitle: String
}

private func sanitizedUnitCGFloat(_ value: CGFloat, default defaultValue: CGFloat = 0) -> CGFloat {
    guard value.isFinite else { return defaultValue }
    return min(max(value, 0), 1)
}

private func hasDrawableGeometry(_ bounds: CGRect, minimumExtent: CGFloat = 2) -> Bool {
    bounds.width.isFinite &&
    bounds.height.isFinite &&
    bounds.width >= minimumExtent &&
    bounds.height >= minimumExtent
}

protocol TouchBarThemable: AnyObject {
    var theme: TouchBarTheme { get set }
}

private func makeLabel(_ text: String, font: NSFont, color: NSColor) -> NSTextField {
    TB.label(text, font: font, color: color)
}

private final class VerticalMeterGlyphView: NSView, TouchBarThemable {
    var theme: TouchBarTheme = .dark {
        didSet { needsDisplay = true }
    }

    var fillFraction: CGFloat = 0.35 {
        didSet { needsDisplay = true }
    }

    var fillColor: NSColor? {
        didSet { needsDisplay = true }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 12, height: 20)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard hasDrawableGeometry(bounds, minimumExtent: 4) else { return }

        let rect = bounds.insetBy(dx: 1, dy: 1)
        guard hasDrawableGeometry(rect, minimumExtent: 4) else { return }
        let fillFraction = sanitizedUnitCGFloat(fillFraction, default: 0)
        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
        theme.barTrackColor.setFill()
        path.fill()
        theme.barOutlineColor.setStroke()
        path.lineWidth = 1.2
        path.stroke()

        let innerHeight = max((rect.height - 4) * fillFraction, 3)
        let fillRect = NSRect(
            x: rect.minX + 2,
            y: rect.minY + 2,
            width: rect.width - 4,
            height: innerHeight
        )
        let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: 3, yRadius: 3)
        (fillColor ?? theme.primaryTextColor).setFill()
        fillPath.fill()
    }
}

private final class MiniHistogramGlyphView: NSView, TouchBarThemable {
    var theme: TouchBarTheme = .dark {
        didSet { needsDisplay = true }
    }

    var normalizedLevel: CGFloat = 0.48 {
        didSet { needsDisplay = true }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 62, height: 20)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard hasDrawableGeometry(bounds, minimumExtent: 6) else { return }

        let frame = bounds.insetBy(dx: 1, dy: 1)
        guard hasDrawableGeometry(frame, minimumExtent: 6) else { return }
        let normalizedLevel = sanitizedUnitCGFloat(normalizedLevel, default: 0)
        let outline = NSBezierPath(roundedRect: frame, xRadius: 6, yRadius: 6)
        theme.barTrackColor.setFill()
        outline.fill()
        theme.barOutlineColor.setStroke()
        outline.lineWidth = 1.2
        outline.stroke()

        let barArea = frame.insetBy(dx: 6, dy: 4)
        let basePattern: [CGFloat] = [0.28, 0.88, 0.62, 0.16, 0.30, 0.20, 0.10, 0.08, 0.05, 0.04]
        let values = basePattern.map { max(0.08, min(1, $0 * (0.45 + normalizedLevel))) }
        let spacing: CGFloat = 1.8
        let totalSpacing = spacing * CGFloat(values.count - 1)
        let barWidth = max(2, (barArea.width - totalSpacing) / CGFloat(values.count))

        for (index, value) in values.enumerated() {
            let height = max(3, barArea.height * value)
            let rect = NSRect(
                x: barArea.minX + CGFloat(index) * (barWidth + spacing),
                y: barArea.minY,
                width: barWidth,
                height: height
            )
            theme.primaryTextColor.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 1.4, yRadius: 1.4).fill()
        }
    }
}

private final class WaveformGlyphView: NSView, TouchBarThemable {
    var theme: TouchBarTheme = .dark {
        didSet { needsDisplay = true }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 52, height: 18)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard hasDrawableGeometry(bounds, minimumExtent: 6) else { return }

        let frame = bounds.insetBy(dx: 1, dy: 1)
        guard hasDrawableGeometry(frame, minimumExtent: 6) else { return }
        let outline = NSBezierPath(roundedRect: frame, xRadius: 4.5, yRadius: 4.5)
        theme.barTrackColor.setFill()
        outline.fill()
        theme.barOutlineColor.setStroke()
        outline.lineWidth = 1
        outline.stroke()

        let midY = frame.midY
        let waveform = NSBezierPath()
        let points: [CGPoint] = [
            CGPoint(x: frame.minX + 8, y: midY),
            CGPoint(x: frame.minX + 18, y: midY),
            CGPoint(x: frame.minX + 22, y: midY + 6),
            CGPoint(x: frame.minX + 28, y: midY),
            CGPoint(x: frame.minX + 35, y: midY),
            CGPoint(x: frame.minX + 41, y: midY - 9),
            CGPoint(x: frame.minX + 46, y: midY),
            CGPoint(x: frame.minX + 55, y: midY),
            CGPoint(x: frame.minX + 60, y: midY + 4),
            CGPoint(x: frame.maxX - 8, y: midY + 4)
        ]
        waveform.move(to: points[0])
        for point in points.dropFirst() {
            waveform.line(to: point)
        }
        theme.accentBlue.setStroke()
        waveform.lineWidth = 1.8
        waveform.lineCapStyle = .round
        waveform.lineJoinStyle = .round
        waveform.stroke()
    }
}

private final class MiniScreenGraphView: NSView, TouchBarThemable {
    var theme: TouchBarTheme = .dark {
        didSet { needsDisplay = true }
    }

    var level: CGFloat = 0.45 {
        didSet { needsDisplay = true }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 54, height: 20)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard hasDrawableGeometry(bounds, minimumExtent: 6) else { return }

        let frame = bounds.insetBy(dx: 1, dy: 1)
        guard hasDrawableGeometry(frame, minimumExtent: 6) else { return }
        let level = sanitizedUnitCGFloat(level, default: 0)
        let outline = NSBezierPath(roundedRect: frame, xRadius: 5.5, yRadius: 5.5)
        theme.barTrackColor.setFill()
        outline.fill()
        theme.barOutlineColor.setStroke()
        outline.lineWidth = 1
        outline.stroke()

        let inner = frame.insetBy(dx: 6, dy: 5)
        guard hasDrawableGeometry(inner, minimumExtent: 2) else { return }
        let baseY = inner.minY
        let values: [CGFloat] = [0.10, 0.08, 0.12, 0.18, 0.80, 0.78, 0.76, 0.74, 0.72]
        let width = inner.width / CGFloat(values.count)

        let purpleFill = NSBezierPath()
        purpleFill.move(to: CGPoint(x: inner.minX, y: baseY))
        for (index, value) in values.enumerated() {
            purpleFill.line(to: CGPoint(
                x: inner.minX + CGFloat(index) * width,
                y: baseY + inner.height * value * (0.55 + level * 0.45)
            ))
        }
        purpleFill.line(to: CGPoint(x: inner.maxX, y: baseY + inner.height * values.last!))
        purpleFill.line(to: CGPoint(x: inner.maxX, y: baseY))
        purpleFill.close()
        theme.accentPurple.withAlphaComponent(0.85).setFill()
        purpleFill.fill()

        let cyanFill = NSBezierPath()
        cyanFill.move(to: CGPoint(x: inner.minX, y: baseY + inner.height * 0.35))
        let topValues = values.map { min(1, $0 + 0.18) }
        for (index, value) in topValues.enumerated() {
            cyanFill.line(to: CGPoint(
                x: inner.minX + CGFloat(index) * width,
                y: baseY + inner.height * value * (0.55 + level * 0.45)
            ))
        }
        cyanFill.line(to: CGPoint(x: inner.maxX, y: baseY + inner.height * topValues.last!))
        cyanFill.line(to: CGPoint(x: inner.maxX, y: baseY + inner.height * 0.35))
        cyanFill.close()
        theme.accentBlue.withAlphaComponent(0.92).setFill()
        cyanFill.fill()
    }
}

final class TimeZoneGroupView: NSView, TouchBarThemable {
    var theme: TouchBarTheme = .dark {
        didSet { applyTheme() }
    }

    private let titleLabel = NSTextField(labelWithString: "9:20")
    private let subtitleLabel = NSTextField(labelWithString: "Apr 11th")

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = -1
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = TB.fontBig
        subtitleLabel.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        titleLabel.lineBreakMode = .byClipping
        subtitleLabel.lineBreakMode = .byClipping
        titleLabel.alignment = .left
        subtitleLabel.alignment = .left
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        subtitleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        applyTheme()
    }

    func update(title: String, subtitle: String) {
        titleLabel.stringValue = title
        subtitleLabel.stringValue = subtitle
    }

    private func applyTheme() {
        titleLabel.textColor = theme.primaryTextColor
        subtitleLabel.textColor = theme.primaryTextColor
    }
}

final class WeatherGroupView: NSView, TouchBarThemable {
    var theme: TouchBarTheme = .dark {
        didSet { applyTheme() }
    }

    private let iconView = NSImageView()
    private var currentSymbolName = "cloud.bolt.rain.fill"

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconView)

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18)
        ])
        applyTheme()
    }

    func applyState(_ state: WeatherState) {
        switch state {
        case .idle, .loading:
            currentSymbolName = "cloud.bolt.rain.fill"
        case .loaded(let snapshot):
            currentSymbolName = snapshot.symbolName
        case .error:
            currentSymbolName = "cloud.bolt.rain.fill"
        }
        applyTheme()
    }

    private func applyTheme() {
        iconView.image = TB.symbolMulticolor(currentSymbolName, size: 16)
    }
}

enum StatsGroupStyle {
    case compact
    case detailed
}

final class SystemStatsGroupView: NSView, TouchBarThemable {
    var theme: TouchBarTheme = .dark {
        didSet { applyTheme() }
    }

    private let style: StatsGroupStyle
    private let timeLabel = NSTextField(labelWithString: "10:38")
    private let memKey = NSTextField(labelWithString: "MEM")
    private let memBar = UsageBarView()
    private let ssdKey = NSTextField(labelWithString: "SSD")
    private let ssdBar = UsageBarView()
    private let cpuKey = NSTextField(labelWithString: "CPU")
    private let cpuBar = UsageBarView()
    private let detailedTitle = NSTextField(labelWithString: "Mon 12:15")
    private let detailedSubtitle = NSTextField(labelWithString: "Mon 04:15 (Paris)")

    init(style: StatsGroupStyle) {
        self.style = style
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        self.style = .compact
        super.init(coder: coder)
        setup()
    }

    private func metricColumn(key: NSTextField, bar: NSView) -> NSStackView {
        let stack = NSStackView(views: [key, bar])
        stack.orientation = .vertical
        stack.spacing = 2
        stack.alignment = .centerX
        return stack
    }

    private func setup() {
        [timeLabel, memKey, ssdKey, cpuKey, detailedTitle, detailedSubtitle].forEach {
            $0.lineBreakMode = .byClipping
        }
        timeLabel.font = TB.fontBig
        memKey.font = TB.fontKey
        ssdKey.font = TB.fontKey
        cpuKey.font = TB.fontKey
        detailedTitle.font = TB.fontTZ
        detailedSubtitle.font = NSFont.systemFont(ofSize: 10, weight: .semibold)

        [memBar, ssdBar, cpuBar].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                $0.widthAnchor.constraint(equalToConstant: TB.barW),
                $0.heightAnchor.constraint(equalToConstant: TB.barH)
            ])
        }

        let metricsStack = NSStackView(views: [
            metricColumn(key: memKey, bar: memBar),
            metricColumn(key: ssdKey, bar: ssdBar),
            metricColumn(key: cpuKey, bar: cpuBar)
        ])
        metricsStack.orientation = .horizontal
        metricsStack.spacing = 18
        metricsStack.alignment = .centerY

        var rows: [NSView] = [timeLabel, metricsStack]

        if style == .detailed {
            let clockStack = NSStackView(views: [detailedTitle, detailedSubtitle])
            clockStack.orientation = .vertical
            clockStack.spacing = 1
            clockStack.alignment = .leading
            rows.append(clockStack)
        }

        let stack = NSStackView(views: rows)
        stack.orientation = .horizontal
        stack.spacing = 20
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        timeLabel.alignment = .left
        applyTheme()
    }

    func update(snap: TouchBarSystemSnapshot) {
        let formatter = DateFormatter()
        formatter.dateFormat = "H:mm"
        timeLabel.stringValue = formatter.string(from: Date())
        memBar.fraction = CGFloat(snap.memPct / 100)
        memBar.fillColor = theme.accentBlue
        memBar.theme = theme
        ssdBar.fraction = CGFloat(snap.ssdPct / 100)
        ssdBar.fillColor = theme.accentBlue
        ssdBar.theme = theme
        cpuBar.fraction = CGFloat(snap.cpuPct / 100)
        // Show CPU temperature alongside the CPU key when available
        if snap.cpuTempC.isFinite && snap.cpuTempC > 0 {
            cpuKey.stringValue = String(format: "CPU %.0f°", snap.cpuTempC)
        } else {
            cpuKey.stringValue = "CPU"
        }
        cpuBar.fillColor = theme.accentBlue
        cpuBar.theme = theme
        detailedTitle.stringValue = snap.detailedClockTitle
        detailedSubtitle.stringValue = snap.detailedClockSubtitle
    }

    private func applyTheme() {
        let primary = theme.primaryTextColor
        let secondary = theme.secondaryTextColor
        timeLabel.textColor = primary
        [memKey, ssdKey, cpuKey].forEach { $0.textColor = primary }
        [detailedTitle, detailedSubtitle].forEach { $0.textColor = primary }
        detailedSubtitle.textColor = secondary
        [memBar, ssdBar, cpuBar].forEach { $0.theme = theme }
    }
}

final class NetworkGroupView: NSView, TouchBarThemable {
    var theme: TouchBarTheme = .dark {
        didSet { applyTheme() }
    }

    private let upLabel = NSTextField(labelWithString: "↑ 13 KB/s")
    private let downLabel = NSTextField(labelWithString: "↓ 1.6 MB/s")

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        [upLabel, downLabel].forEach {
            $0.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)
            $0.lineBreakMode = .byClipping
        }

        let stack = NSStackView(views: [upLabel, downLabel])
        stack.orientation = .vertical
        stack.spacing = 0
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        applyTheme()
    }

    func update(upKBs: Double, downMBs: Double) {
        upLabel.stringValue = upKBs >= 1000
            ? String(format: "↑ %.1f MB/s", upKBs / 1000)
            : String(format: "↑ %.0f KB/s", upKBs)
        downLabel.stringValue = downMBs >= 1
            ? String(format: "↓ %.1f MB/s", downMBs)
            : String(format: "↓ %.0f KB/s", downMBs * 1000)
    }

    private func applyTheme() {
        upLabel.textColor = theme.primaryTextColor
        downLabel.textColor = theme.primaryTextColor
    }
}

final class CombinedGroupView: NSView, TouchBarThemable {
    var theme: TouchBarTheme = .dark {
        didSet { applyTheme() }
    }

    private let upLabel = NSTextField(labelWithString: "↑ 13 KB/s")
    private let downLabel = NSTextField(labelWithString: "↓ 1.6 MB/s")
    private let memLabel = NSTextField(labelWithString: "MEM\n13%")
    private let cpuLabel = NSTextField(labelWithString: "CPU\n45°")
    private let batLabel = NSTextField(labelWithString: "B\nA\nT")
    private let ssdLabel = NSTextField(labelWithString: "S\nS\nD")
    private let cpuGraphLabel = NSTextField(labelWithString: "C\nP\nU")
    private let batteryGlyph = VerticalMeterGlyphView()
    private let ssdGlyph = VerticalMeterGlyphView()
    private let graphGlyph = MiniHistogramGlyphView()
    private let timeLabel = NSTextField(labelWithString: "Mon 3:03")

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        [upLabel, downLabel].forEach {
            $0.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        }

        [memLabel, cpuLabel].forEach {
            $0.font = TB.fontVal
            $0.usesSingleLineMode = false
            $0.alignment = .center
        }

        [batLabel, ssdLabel, cpuGraphLabel].forEach {
            $0.font = TB.fontKey
            $0.usesSingleLineMode = false
            $0.alignment = .center
        }

        let networkStack = NSStackView(views: [upLabel, downLabel])
        networkStack.orientation = .vertical
        networkStack.spacing = 1
        networkStack.alignment = .leading

        let memStack = NSStackView(views: [memLabel])
        memStack.orientation = .vertical
        memStack.alignment = .centerX

        let cpuStack = NSStackView(views: [cpuLabel])
        cpuStack.orientation = .vertical
        cpuStack.alignment = .centerX

        let batteryStack = NSStackView(views: [batLabel, batteryGlyph])
        batteryStack.orientation = .horizontal
        batteryStack.spacing = 6
        batteryStack.alignment = .centerY

        let ssdStack = NSStackView(views: [ssdLabel, ssdGlyph])
        ssdStack.orientation = .horizontal
        ssdStack.spacing = 6
        ssdStack.alignment = .centerY

        let graphStack = NSStackView(views: [cpuGraphLabel, graphGlyph])
        graphStack.orientation = .horizontal
        graphStack.spacing = 6
        graphStack.alignment = .centerY

        let stack = NSStackView(views: [
            networkStack,
            memStack,
            cpuStack,
            batteryStack,
            ssdStack,
            graphStack,
            timeLabel
        ])
        stack.orientation = .horizontal
        stack.spacing = 18
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        applyTheme()
    }

    func update(snap: TouchBarSystemSnapshot) {
        upLabel.stringValue = snap.netUpKBs >= 1000
            ? String(format: "↑ %.1f MB/s", snap.netUpKBs / 1000)
            : String(format: "↑ %.0f KB/s", snap.netUpKBs)
        downLabel.stringValue = snap.netDownMBs >= 1
            ? String(format: "↓ %.1f MB/s", snap.netDownMBs)
            : String(format: "↓ %.0f KB/s", snap.netDownMBs * 1000)

        memLabel.stringValue = String(format: "MEM\n%.0f%%", snap.memPct)
        cpuLabel.stringValue = String(format: "CPU\n%.0f°", snap.cpuTempC)
        batteryGlyph.fillFraction = CGFloat(Double(snap.batPct) / 100)
        batteryGlyph.fillColor = snap.batCharging ? theme.accentBlue : theme.primaryTextColor
        ssdGlyph.fillFraction = CGFloat(snap.ssdPct / 100)
        ssdGlyph.fillColor = theme.primaryTextColor
        graphGlyph.normalizedLevel = CGFloat(snap.cpuPct / 100)

        let formatter = DateFormatter()
        formatter.dateFormat = "EEE H:mm"
        timeLabel.stringValue = formatter.string(from: Date())
    }

    private func applyTheme() {
        [upLabel, downLabel, memLabel, cpuLabel, batLabel, ssdLabel, cpuGraphLabel, timeLabel].forEach {
            $0.textColor = theme.primaryTextColor
        }
        timeLabel.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        batteryGlyph.theme = theme
        ssdGlyph.theme = theme
        graphGlyph.theme = theme
    }
}

final class HardwareIconsGroupView: NSView, TouchBarThemable {
    var theme: TouchBarTheme = .dark {
        didSet { applyTheme() }
    }

    private let arrowIcon = NSImageView()
    private let waveform = WaveformGlyphView()
    private let boltIcon = NSImageView()
    private let batteryGlyph = VerticalMeterGlyphView()
    private let driveIcon = NSImageView()
    private let miniBatteryGlyph = VerticalMeterGlyphView()
    private let memoryIcon = NSImageView()
    private let cpuIcon = NSImageView()
    private let graph = MiniScreenGraphView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func makeSymbolView(_ symbolName: String, pointSize: CGFloat = 17) -> NSImageView {
        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 20),
            imageView.heightAnchor.constraint(equalToConstant: 20)
        ])
        imageView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium))
        return imageView
    }

    private func setup() {
        let rebuiltArrow = makeSymbolView("arrow.up.right.and.arrow.down.left")
        arrowIcon.image = rebuiltArrow.image
        let rebuiltBolt = makeSymbolView("bolt.fill")
        boltIcon.image = rebuiltBolt.image
        let rebuiltDrive = makeSymbolView("externaldrive.fill")
        driveIcon.image = rebuiltDrive.image
        let rebuiltMemory = makeSymbolView("memorychip.fill")
        memoryIcon.image = rebuiltMemory.image
        let rebuiltCPU = makeSymbolView("cpu.fill")
        cpuIcon.image = rebuiltCPU.image

        let stack = NSStackView(views: [
            arrowIcon,
            waveform,
            boltIcon,
            batteryGlyph,
            driveIcon,
            miniBatteryGlyph,
            memoryIcon,
            cpuIcon,
            graph
        ])
        stack.orientation = .horizontal
        stack.spacing = 12
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        applyTheme()
    }

    func update(snapshot: TouchBarSystemSnapshot) {
        batteryGlyph.fillFraction = CGFloat(Double(snapshot.batPct) / 100)
        batteryGlyph.fillColor = theme.accentBlue
        miniBatteryGlyph.fillFraction = CGFloat(min(snapshot.memPct / 100, 1))
        miniBatteryGlyph.fillColor = theme.accentBlue
        graph.level = CGFloat(max(snapshot.cpuPct / 100, snapshot.memPct / 100))
    }

    private func applyTheme() {
        let glyphViews = [arrowIcon, boltIcon, driveIcon, memoryIcon, cpuIcon]
        glyphViews.forEach { $0.contentTintColor = theme.glyphFillColor }
        waveform.theme = theme
        batteryGlyph.theme = theme
        miniBatteryGlyph.theme = theme
        graph.theme = theme
    }
}

