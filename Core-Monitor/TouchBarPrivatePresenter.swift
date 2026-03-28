import AppKit
import ObjectiveC.runtime

// MARK: - TouchBarPrivatePresenter

@MainActor
final class TouchBarPrivatePresenter: NSObject {

    private enum ID {
        static let bar   = NSTouchBar.CustomizationIdentifier("com.coremonitor.touchbar")
        static let panel = NSTouchBarItem.Identifier("com.coremonitor.touchbar.panel")
        static let tray  = "com.coremonitor.private.touchbar.tray" as NSString
    }

    private var touchBar: NSTouchBar?
    private weak var panel: CoreMonitorTouchBarView?
    private var isPresented = false

    // MARK: Public

    func present() {
        guard touchBar == nil, !isPresented else { return }
        let bar = NSTouchBar()
        bar.customizationIdentifier = ID.bar
        bar.delegate = self
        bar.defaultItemIdentifiers = [ID.panel]
        touchBar = bar
        isPresented = true
        presentModal(bar)
    }

    func dismiss() {
        guard let touchBar else { return }
        let barToDismiss = touchBar
        self.touchBar = nil
        panel = nil
        isPresented = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.dismissModal(barToDismiss)
        }
    }

    /// Legacy text-based update (kept for compatibility).
    func update(topText: String, graphText: String) {
        guard isPresented else { return }
        panel?.applyLegacyText(top: topText, graph: graphText)
    }

    /// Preferred structured update called from AppCoordinator.
    func updateMetrics(
        cpuPercent: Double,
        cpuTempC: Double?,
        memPercent: Double,
        memPressure: MemoryPressureLevel,
        fanRPM: Int,
        fanFrac: Double,
        vmCount: Int,
        cpuHistory: [Double],
        memHistory: [Double],
        fanHistory: [Double],
        customWidget: TouchBarCustomWidget,
        volume: Float,
        brightness: Float
    ) {
        guard isPresented else { return }
        panel?.updateMetrics(
            cpuPercent: cpuPercent, cpuTempC: cpuTempC,
            memPercent: memPercent, memPressure: memPressure,
            fanRPM: fanRPM, fanFrac: fanFrac,
            vmCount: vmCount,
            cpuHistory: cpuHistory, memHistory: memHistory, fanHistory: fanHistory,
            customWidget: customWidget,
            volume: volume, brightness: brightness
        )
    }

    // MARK: Private

    private func presentModal(_ bar: NSTouchBar) {
        let cls: AnyObject = NSTouchBar.self
        let selA = NSSelectorFromString("presentSystemModalTouchBar:placement:systemTrayItemIdentifier:")
        if let m = class_getClassMethod(NSTouchBar.self, selA) {
            typealias F = @convention(c) (AnyObject, Selector, NSTouchBar, Int, NSString) -> Void
            unsafeBitCast(method_getImplementation(m), to: F.self)(cls, selA, bar, 1, ID.tray)
            return
        }
        let selB = NSSelectorFromString("presentSystemModalTouchBar:systemTrayItemIdentifier:")
        guard let m = class_getClassMethod(NSTouchBar.self, selB) else { isPresented = false; return }
        typealias G = @convention(c) (AnyObject, Selector, NSTouchBar, NSString) -> Void
        unsafeBitCast(method_getImplementation(m), to: G.self)(cls, selB, bar, ID.tray)
    }

    private func dismissModal(_ bar: NSTouchBar) {
        let sel = NSSelectorFromString("dismissSystemModalTouchBar:")
        guard let m = class_getClassMethod(NSTouchBar.self, sel) else { isPresented = false; return }
        typealias F = @convention(c) (AnyObject, Selector, NSTouchBar) -> Void
        unsafeBitCast(method_getImplementation(m), to: F.self)(NSTouchBar.self, sel, bar)
    }
}

struct TouchBarCustomWidget {
    let label: String
    let value: String
    let symbolName: String
    let color: NSColor
    let alerting: Bool
}

extension TouchBarPrivatePresenter: NSTouchBarDelegate {
    func touchBar(_ touchBar: NSTouchBar,
                  makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        guard identifier == ID.panel else { return nil }
        let item = NSCustomTouchBarItem(identifier: identifier)
        let view = CoreMonitorTouchBarView()
        panel = view
        item.view = view
        return item
    }
}

// MARK: - CoreMonitorTouchBarView

/// Root view — lays out metric chips in a horizontal stack.
final class CoreMonitorTouchBarView: NSView {

    private let cpuChip = MetricChip(label: "CPU",  color: .systemBlue,   symbolName: "cpu")
    private let memChip = MetricChip(label: "MEM",  color: .systemPurple, symbolName: "memorychip")
    private let fanChip = MetricChip(label: "FAN",  color: .systemTeal,   symbolName: "wind")
    private let customChip = MetricChip(label: "WIDGET", color: .systemOrange, symbolName: "server.rack")

    private lazy var stack: NSStackView = {
        let s = NSStackView(views: [cpuChip, memChip, fanChip, customChip])
        s.orientation  = .horizontal
        s.spacing      = 4
        s.alignment    = .centerY
        s.distribution = .fillProportionally
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    // MARK: Updates

    func applyLegacyText(top: String, graph: String) {
        for segment in top.components(separatedBy: "   ") {
            let s = segment.trimmingCharacters(in: .whitespaces)
            if s.hasPrefix("CPU ") {
                let parts = String(s.dropFirst(4)).components(separatedBy: " ")
                let temp = parts.first ?? "--"
                let pct  = parts.dropFirst().first ?? ""
                cpuChip.set(value: "\(temp) \(pct)", sparkValues: [])
            } else if s.hasPrefix("MEM ") {
                let pct = String(s.dropFirst(4)).components(separatedBy: " ").first ?? "--"
                memChip.set(value: pct, sparkValues: [])
            } else if s.hasPrefix("FAN ") {
                let rpm = s.dropFirst(4).replacingOccurrences(of: "rpm", with: "").trimmingCharacters(in: .whitespaces)
                fanChip.set(value: "\(rpm) rpm", sparkValues: [])
            } else if s.contains("VM") {
                let num = s.filter { $0.isNumber }
                if !num.isEmpty {
                    customChip.configure(label: "VM", color: .systemOrange, symbolName: "server.rack")
                    customChip.set(value: "\(num) running", sparkValues: [])
                }
            }
        }
    }

    func updateMetrics(
        cpuPercent: Double, cpuTempC: Double?,
        memPercent: Double, memPressure: MemoryPressureLevel,
        fanRPM: Int, fanFrac: Double,
        vmCount: Int,
        cpuHistory: [Double], memHistory: [Double], fanHistory: [Double],
        customWidget: TouchBarCustomWidget,
        volume: Float, brightness: Float
    ) {
        let tempStr = cpuTempC.map { String(format: "%.0f°C", $0) } ?? "--"
        cpuChip.set(
            value: "\(tempStr)  \(Int(cpuPercent.rounded()))%",
            sparkValues: cpuHistory,
            alerting: cpuPercent > 85 || (cpuTempC ?? 0) > 95
        )

        let pressureSuffix: String
        switch memPressure {
        case .green:  pressureSuffix = ""
        case .yellow: pressureSuffix = " !"
        case .red:    pressureSuffix = " !!"
        }
        memChip.set(
            value: "\(Int(memPercent.rounded()))%\(pressureSuffix)",
            sparkValues: memHistory,
            alerting: memPressure == .red
        )

        fanChip.set(
            value: "\(fanRPM) rpm",
            sparkValues: fanHistory,
            alerting: fanFrac > 0.9
        )

        customChip.configure(label: customWidget.label, color: customWidget.color, symbolName: customWidget.symbolName)
        customChip.set(value: customWidget.value, sparkValues: [], alerting: customWidget.alerting)
    }
}

// MARK: - MetricChip

/// Single metric chip: SF Symbol icon + name label + value label + mini sparkline.
final class MetricChip: NSView {

    private var accentColor: NSColor
    private var symbolName:  String

    private let iconView   = NSImageView()
    private let topLabel   = NSTextField(labelWithString: "")
    private let valueLabel = NSTextField(labelWithString: "--")
    private let sparkView  = SparklineView()

    private static let chipW:  CGFloat = 158
    private static let chipH:  CGFloat = 30
    private static let iconSz: CGFloat = 10
    private static let sparkW: CGFloat = 36
    private static let padX:   CGFloat = 6

    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.chipW, height: Self.chipH)
    }

    init(label: String, color: NSColor, symbolName: String) {
        self.accentColor = color
        self.symbolName  = symbolName
        super.init(frame: NSRect(x: 0, y: 0, width: Self.chipW, height: Self.chipH))
        build(label: label)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build(label: String) {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor

        // SF Symbol icon
        let cfg = NSImage.SymbolConfiguration(pointSize: Self.iconSz, weight: .medium)
        iconView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg)
        iconView.imageScaling   = .scaleProportionallyUpOrDown
        iconView.contentTintColor = accentColor
        iconView.translatesAutoresizingMaskIntoConstraints = false

        // Top label — metric name, accent colour, small
        topLabel.stringValue = label
        topLabel.font        = .systemFont(ofSize: 8.5, weight: .semibold)
        topLabel.textColor   = accentColor.withAlphaComponent(0.85)
        topLabel.lineBreakMode = .byTruncatingTail
        topLabel.translatesAutoresizingMaskIntoConstraints = false

        // Value label — monospaced, white
        valueLabel.font          = .monospacedSystemFont(ofSize: 10.5, weight: .medium)
        valueLabel.textColor     = .white
        valueLabel.lineBreakMode = .byTruncatingTail
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        // Sparkline
        sparkView.accentColor = accentColor
        sparkView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(topLabel)
        addSubview(valueLabel)
        addSubview(sparkView)

        let p   = Self.padX
        let iSz = Self.iconSz
        let sW  = Self.sparkW

        NSLayoutConstraint.activate([
            // Icon — left, vertically centred
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: p),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: iSz),
            iconView.heightAnchor.constraint(equalToConstant: iSz),

            // Sparkline — right, vertically centred
            sparkView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -p),
            sparkView.centerYAnchor.constraint(equalTo: centerYAnchor),
            sparkView.widthAnchor.constraint(equalToConstant: sW),
            sparkView.heightAnchor.constraint(equalToConstant: Self.chipH - 8),

            // Name label — upper half, between icon and spark
            topLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 4),
            topLabel.trailingAnchor.constraint(equalTo: sparkView.leadingAnchor, constant: -4),
            topLabel.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            topLabel.heightAnchor.constraint(equalToConstant: 11),

            // Value label — lower half, between icon and spark
            valueLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 4),
            valueLabel.trailingAnchor.constraint(equalTo: sparkView.leadingAnchor, constant: -4),
            valueLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
            valueLabel.heightAnchor.constraint(equalToConstant: 14)
        ])
    }

    func configure(label: String, color: NSColor, symbolName: String) {
        accentColor = color
        self.symbolName = symbolName
        topLabel.stringValue = label
        topLabel.textColor = color.withAlphaComponent(0.85)
        iconView.contentTintColor = color
        let cfg = NSImage.SymbolConfiguration(pointSize: Self.iconSz, weight: .medium)
        iconView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg)
        sparkView.accentColor = color
    }

    func set(value: String, sparkValues: [Double], alerting: Bool = false) {
        valueLabel.stringValue = value
        sparkView.values = sparkValues
        sparkView.accentColor = accentColor
        layer?.backgroundColor = alerting
            ? NSColor.systemRed.withAlphaComponent(0.20).cgColor
            : NSColor.white.withAlphaComponent(0.08).cgColor
    }
}

// MARK: - SparklineView

/// Mini sparkline drawn with NSBezierPath — no CALayer, no sublayers.
final class SparklineView: NSView {

    var accentColor: NSColor = .systemBlue { didSet { needsDisplay = true } }
    var values: [Double] = []              { didSet { needsDisplay = true } }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard values.count >= 2 else { return }
        let pts  = Array(values.suffix(20))
        let minV = pts.min() ?? 0
        let maxV = max((pts.max() ?? 1), minV + 1)
        let w = bounds.width
        let h = bounds.height
        let xStep = w / CGFloat(pts.count - 1)

        let path = NSBezierPath()
        path.lineWidth     = 1.2
        path.lineCapStyle  = .round
        path.lineJoinStyle = .round

        for (i, v) in pts.enumerated() {
            let x = CGFloat(i) * xStep
            let y = CGFloat((v - minV) / (maxV - minV)) * (h - 2) + 1
            if i == 0 { path.move(to: NSPoint(x: x, y: y)) }
            else       { path.line(to: NSPoint(x: x, y: y)) }
        }

        accentColor.withAlphaComponent(0.8).setStroke()
        path.stroke()
    }
}
