import AppKit
import CoreAudio
import CoreFoundation
import IOKit.graphics
import ObjectiveC.runtime
import Darwin

@MainActor
final class TouchBarPrivatePresenter: NSResponder {

    private enum ID {
        static let bar = NSTouchBar.CustomizationIdentifier("com.coremonitor.touchbar.v2")
        static let panel = NSTouchBarItem.Identifier("com.coremonitor.touchbar.v2.panel")
    }

    private struct MetricsSnapshot {
        let cpuPercent: Double
        let cpuTempC: Double?
        let memPercent: Double
        let memPressure: MemoryPressureLevel
        let fanRPM: Int
        let fanFrac: Double
        let cpuHistory: [Double]
        let memHistory: [Double]
        let fanHistory: [Double]
        let customWidget: TouchBarCustomWidget
        let volume: Float
        let brightness: Float
        let netBytesIn: Double
        let netBytesOut: Double
        let diskReadBPS: Double
        let diskWriteBPS: Double
    }

    private weak var window: NSWindow?
    private var activeTouchBar: NSTouchBar?
    private weak var panel: IStatsTouchBarView?
    private var latestMetrics: MetricsSnapshot?
    private var isEnabled = true
    private var windowObserverTokens: [NSObjectProtocol] = []
    private var appObserverTokens: [NSObjectProtocol] = []

    func attach(to window: NSWindow) {
        removeObservers()
        self.window = window
        installObservers(for: window)
        refreshWindowTouchBar()
    }

    func present() {
        isEnabled = true
        activeTouchBar = nil
        panel = nil
        refreshWindowTouchBar()
    }

    func dismiss() {
        isEnabled = false
        activeTouchBar = nil
        panel = nil
        refreshWindowTouchBar()
    }

    func dismissToSystemTouchBar() {
        dismiss()
    }

    func updateMetrics(
        cpuPercent: Double,
        cpuTempC: Double?,
        memPercent: Double,
        memPressure: MemoryPressureLevel,
        fanRPM: Int,
        fanFrac: Double,
        cpuHistory: [Double],
        memHistory: [Double],
        fanHistory: [Double],
        customWidget: TouchBarCustomWidget,
        volume: Float,
        brightness: Float,
        netBytesIn: Double,
        netBytesOut: Double,
        diskReadBPS: Double,
        diskWriteBPS: Double
    ) {
        let snapshot = MetricsSnapshot(
            cpuPercent: cpuPercent,
            cpuTempC: cpuTempC,
            memPercent: memPercent,
            memPressure: memPressure,
            fanRPM: fanRPM,
            fanFrac: fanFrac,
            cpuHistory: cpuHistory,
            memHistory: memHistory,
            fanHistory: fanHistory,
            customWidget: customWidget,
            volume: volume,
            brightness: brightness,
            netBytesIn: netBytesIn,
            netBytesOut: netBytesOut,
            diskReadBPS: diskReadBPS,
            diskWriteBPS: diskWriteBPS
        )
        latestMetrics = snapshot
        if let panel {
            apply(snapshot, to: panel)
        } else if isEnabled {
            activeTouchBar = nil
            refreshWindowTouchBar()
        }
    }

    func update(topText: String, graphText: String) {}

    override func makeTouchBar() -> NSTouchBar? {
        guard isEnabled else { return nil }
        if let activeTouchBar { return activeTouchBar }
        let bar = NSTouchBar()
        bar.customizationIdentifier = ID.bar
        bar.delegate = self
        bar.defaultItemIdentifiers = [.flexibleSpace, ID.panel]
        bar.customizationAllowedItemIdentifiers = [ID.panel]
        bar.customizationRequiredItemIdentifiers = [ID.panel]
        activeTouchBar = bar
        return bar
    }

    private func apply(_ snapshot: MetricsSnapshot, to panel: IStatsTouchBarView) {
        panel.updateMetrics(
            cpuPercent: snapshot.cpuPercent,
            cpuTempC: snapshot.cpuTempC,
            memPercent: snapshot.memPercent,
            memPressure: snapshot.memPressure,
            fanRPM: snapshot.fanRPM,
            fanFrac: snapshot.fanFrac,
            cpuHistory: snapshot.cpuHistory,
            memHistory: snapshot.memHistory,
            fanHistory: snapshot.fanHistory,
            customWidget: snapshot.customWidget,
            volume: snapshot.volume,
            brightness: snapshot.brightness,
            netBytesIn: snapshot.netBytesIn,
            netBytesOut: snapshot.netBytesOut,
            diskReadBPS: snapshot.diskReadBPS,
            diskWriteBPS: snapshot.diskWriteBPS
        )
    }

    private func refreshWindowTouchBar() {
        guard let window else { return }
        touchBar = nil
        window.touchBar = nil
        guard shouldExposeTouchBar(on: window) else { return }
        window.touchBar = makeTouchBar()
        window.update()
    }

    private func shouldExposeTouchBar(on window: NSWindow) -> Bool {
        isEnabled && NSApp.isActive && (window.isKeyWindow || window.isMainWindow)
    }

    private func installObservers(for window: NSWindow) {
        let center = NotificationCenter.default
        windowObserverTokens = [
            center.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshWindowTouchBar()
                }
            },
            center.addObserver(
                forName: NSWindow.didBecomeMainNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshWindowTouchBar()
                }
            },
            center.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshWindowTouchBar()
                }
            },
            center.addObserver(
                forName: NSWindow.didResignMainNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshWindowTouchBar()
                }
            }
        ]
        appObserverTokens = [
            center.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: NSApp,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshWindowTouchBar()
                }
            },
            center.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: NSApp,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshWindowTouchBar()
                }
            }
        ]
    }

    private func removeObservers() {
        let center = NotificationCenter.default
        windowObserverTokens.forEach(center.removeObserver)
        appObserverTokens.forEach(center.removeObserver)
        windowObserverTokens.removeAll()
        appObserverTokens.removeAll()
    }
}

extension TouchBarPrivatePresenter: NSTouchBarDelegate {
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        guard identifier == ID.panel else { return nil }
        let item = NSCustomTouchBarItem(identifier: identifier)
        let view = IStatsTouchBarView()
        view.frame = NSRect(origin: .zero, size: view.intrinsicContentSize)
        panel = view
        item.view = view
        if let latestMetrics {
            apply(latestMetrics, to: view)
        }
        return item
    }
}

struct TouchBarCustomWidget {
    enum Style {
        case symbol
        case volumeSlider
        case nowPlaying
    }

    let label: String
    let value: String
    let secondaryValue: String?
    let symbolName: String
    let color: NSColor
    let alerting: Bool
    let style: Style
    let artwork: NSImage?
}

final class IStatsTouchBarView: NSView {
    private enum CustomModuleKind {
        case symbol
        case sliders
        case nowPlaying
    }

    private let moduleStack = NSStackView()

    private let primaryGroup = TBModuleView(style: .dark)
    private let symbolGroup = TBModuleView(style: .light)
    private let nowPlayingGroup = TBModuleView(style: .dark)
    private let sliderGroup = NSStackView()
    private let nowPlayingSliderGroup = NSStackView()
    private let brightnessWidget = TBBrightnessSliderWidgetView()
    private let volumeWidget = TBVolumeSliderWidgetView()
    private let nowPlayingWidget = TBNowPlayingWidgetView()

    private let memoryStat = TBStatTextView(width: 92, style: .dark, alignment: .center)
    private let cpuStat = TBStatTextView(width: 86, style: .dark, alignment: .center)
    private let memoryMeter = TBBoardMeterView(title: "MEM")
    private let cpuMeter = TBBoardMeterView(title: "CPU")
    private let cpuGraph = TBGraphMetricView(label: "CPU", appearanceMode: .dark)
    private let timeDisplay = TBLargeClockView(width: 176, appearanceMode: .dark)
    private let symbolTile = TBSymbolTileView(symbolName: "cloud.sun.rain.fill", accent: .systemYellow, appearanceMode: .light)
    private var currentCustomModule: CustomModuleKind = .symbol

    override init(frame: NSRect) {
        super.init(frame: frame)
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        let fitting = moduleStack.fittingSize
        return NSSize(width: fitting.width + 8, height: 34)
    }

    private func build() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        moduleStack.orientation = .horizontal
        moduleStack.spacing = 6
        moduleStack.alignment = .centerY
        moduleStack.distribution = .gravityAreas
        moduleStack.translatesAutoresizingMaskIntoConstraints = false

        sliderGroup.orientation = .horizontal
        sliderGroup.spacing = 6
        sliderGroup.alignment = .centerY
        sliderGroup.distribution = .gravityAreas
        sliderGroup.translatesAutoresizingMaskIntoConstraints = false

        nowPlayingSliderGroup.orientation = .horizontal
        nowPlayingSliderGroup.spacing = 6
        nowPlayingSliderGroup.alignment = .centerY
        nowPlayingSliderGroup.distribution = .gravityAreas
        nowPlayingSliderGroup.translatesAutoresizingMaskIntoConstraints = false

        [memoryStat, cpuStat, memoryMeter, cpuMeter, cpuGraph, timeDisplay].forEach {
            primaryGroup.addMetric($0)
        }
        symbolGroup.addMetric(symbolTile)
        nowPlayingGroup.addMetric(nowPlayingWidget)
        [brightnessWidget, volumeWidget].forEach {
            sliderGroup.addArrangedSubview($0)
        }
        [nowPlayingGroup, sliderGroup].forEach {
            nowPlayingSliderGroup.addArrangedSubview($0)
        }

        [primaryGroup, symbolGroup].forEach {
            moduleStack.addArrangedSubview($0)
        }

        addSubview(moduleStack)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 34),
            moduleStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            moduleStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4),
            moduleStack.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 1.5)
        ])
    }

    func updateMetrics(
        cpuPercent: Double,
        cpuTempC: Double?,
        memPercent: Double,
        memPressure: MemoryPressureLevel,
        fanRPM: Int,
        fanFrac: Double,
        cpuHistory: [Double],
        memHistory: [Double],
        fanHistory: [Double],
        customWidget: TouchBarCustomWidget,
        volume: Float,
        brightness: Float,
        netBytesIn: Double,
        netBytesOut: Double,
        diskReadBPS: Double,
        diskWriteBPS: Double
    ) {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "EEE H:mm"

        let cpuColor: NSColor = cpuPercent > 85 ? .systemRed : cpuPercent > 60 ? .systemOrange : .white
        let memoryColor: NSColor = memPressure == .red ? .systemRed : memPressure == .yellow ? .systemOrange : .white
        let thermalColor: NSColor = {
            guard let cpuTempC else { return .white }
            if cpuTempC > 95 { return .systemRed }
            if cpuTempC > 80 { return .systemOrange }
            return .white
        }()
        memoryStat.configure(
            title: "MEM",
            value: "\(Int(memPercent.rounded()))%",
            accent: memoryColor
        )
        cpuStat.configure(
            title: "CPU",
            value: cpuTempC.map { "\(Int($0.rounded()))°" } ?? "--",
            accent: thermalColor
        )
        memoryMeter.configure(fraction: memPercent / 100.0)
        cpuMeter.configure(fraction: cpuPercent / 100.0)
        cpuGraph.configure(values: cpuHistory, tintColor: cpuColor)
        timeDisplay.configure(timeFormatter.string(from: Date()))
        updateCustomWidget(customWidget, volume: volume, brightness: brightness)
    }

    private func updateCustomWidget(_ customWidget: TouchBarCustomWidget, volume: Float, brightness: Float) {
        switch customWidget.style {
        case .symbol:
            switchCustomModule(to: .symbol)
            symbolTile.configure(symbolName: customWidget.symbolName, accent: customWidget.color)
        case .volumeSlider:
            switchCustomModule(to: .sliders)
            brightnessWidget.configure(fraction: CGFloat(max(0, min(1, brightness))))
            volumeWidget.configure(fraction: CGFloat(max(0, min(1, volume))))
        case .nowPlaying:
            switchCustomModule(to: .nowPlaying)
            nowPlayingWidget.configure(
                title: customWidget.value,
                subtitle: customWidget.secondaryValue,
                artwork: customWidget.artwork
            )
        }
    }

    private func switchCustomModule(to kind: CustomModuleKind) {
        guard currentCustomModule != kind else { return }

        switch currentCustomModule {
        case .symbol:
            moduleStack.removeArrangedSubview(symbolGroup)
            symbolGroup.removeFromSuperview()
        case .sliders:
            moduleStack.removeArrangedSubview(sliderGroup)
            sliderGroup.removeFromSuperview()
        case .nowPlaying:
            moduleStack.removeArrangedSubview(nowPlayingSliderGroup)
            nowPlayingSliderGroup.removeFromSuperview()
        }

        let nextView: NSView
        switch kind {
        case .symbol:
            nextView = symbolGroup
        case .sliders:
            nextView = sliderGroup
        case .nowPlaying:
            nextView = nowPlayingSliderGroup
        }
        moduleStack.addArrangedSubview(nextView)
        currentCustomModule = kind
        invalidateIntrinsicContentSize()
    }
}

final class TBStatTextView: NSView {
    private let width: CGFloat
    private let style: TBModuleView.Style
    private let alignment: NSTextAlignment
    private let titleLabel = TBLabel(size: 6.5, weight: .bold, mono: true)
    private let valueLabel = TBLabel(size: 9.2, weight: .semibold, mono: true)

    init(width: CGFloat, style: TBModuleView.Style, alignment: NSTextAlignment) {
        self.width = width
        self.style = style
        self.alignment = alignment
        super.init(frame: .zero)
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        NSSize(width: width, height: 22)
    }

    private func build() {
        translatesAutoresizingMaskIntoConstraints = false
        titleLabel.alignment = alignment
        valueLabel.alignment = alignment
        valueLabel.maximumNumberOfLines = 1
        valueLabel.cell?.wraps = false
        valueLabel.lineBreakMode = .byClipping
        titleLabel.textColor = secondaryColor
        valueLabel.textColor = primaryColor

        [titleLabel, valueLabel].forEach(addSubview)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            valueLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1)
        ])
    }

    func configure(title: String?, value: String, accent: NSColor) {
        titleLabel.stringValue = title ?? ""
        titleLabel.isHidden = title == nil
        valueLabel.stringValue = value
        valueLabel.textColor = accent
    }

    private var primaryColor: NSColor {
        switch style {
        case .dark:
            return .white
        case .light:
            return NSColor(white: 0.08, alpha: 1)
        }
    }

    private var secondaryColor: NSColor {
        switch style {
        case .dark:
            return NSColor(white: 0.76, alpha: 1)
        case .light:
            return NSColor(white: 0.28, alpha: 1)
        }
    }
}

final class TBVerticalMeterView: NSView {
    private let labelStack = NSStackView()
    private let meterView = TBProgressBar(color: .white, trackColor: NSColor(white: 0.18, alpha: 1))
    private let appearanceMode: TBMetricCardView.Appearance

    init(label: String, appearanceMode: TBMetricCardView.Appearance) {
        self.appearanceMode = appearanceMode
        super.init(frame: .zero)
        build(label: label)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 32, height: 18)
    }

    private func build(label: String) {
        translatesAutoresizingMaskIntoConstraints = false
        labelStack.orientation = .vertical
        labelStack.spacing = -2
        labelStack.alignment = .centerX
        labelStack.translatesAutoresizingMaskIntoConstraints = false

        label.uppercased().forEach { character in
            let labelView = TBLabel(size: 5.8, weight: .bold, mono: true)
            labelView.stringValue = String(character)
            labelView.textColor = textColor
            labelStack.addArrangedSubview(labelView)
        }

        meterView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(labelStack)
        addSubview(meterView)

        NSLayoutConstraint.activate([
            labelStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            labelStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            meterView.leadingAnchor.constraint(equalTo: labelStack.trailingAnchor, constant: 4),
            meterView.centerYAnchor.constraint(equalTo: centerYAnchor),
            meterView.widthAnchor.constraint(equalToConstant: 8),
            meterView.heightAnchor.constraint(equalToConstant: 18)
        ])
    }

    override func layout() {
        super.layout()
        meterView.rotation = .pi / 2
    }

    func configure(label: String, fraction: Double, fillColor: NSColor) {
        if labelStack.arrangedSubviews.count != label.count {
            labelStack.arrangedSubviews.forEach { view in
                labelStack.removeArrangedSubview(view)
                view.removeFromSuperview()
            }
            label.uppercased().forEach { character in
                let labelView = TBLabel(size: 5.8, weight: .bold, mono: true)
                labelView.stringValue = String(character)
                labelView.textColor = textColor
                labelStack.addArrangedSubview(labelView)
            }
        }
        meterView.tintColor = fillColor
        meterView.trackColorOverride = trackColor
        meterView.fraction = fraction
    }

    private var textColor: NSColor {
        switch appearanceMode {
        case .dark:
            return .white
        case .light:
            return NSColor(white: 0.08, alpha: 1)
        }
    }

    private var trackColor: NSColor {
        switch appearanceMode {
        case .dark:
            return NSColor(white: 0.28, alpha: 1)
        case .light:
            return NSColor(white: 0.72, alpha: 1)
        }
    }
}

final class TBGraphMetricView: NSView {
    private let labelStack = NSStackView()
    private let graphView = TBBarGraphView()
    private let appearanceMode: TBMetricCardView.Appearance

    init(label: String, appearanceMode: TBMetricCardView.Appearance) {
        self.appearanceMode = appearanceMode
        super.init(frame: .zero)
        build(label: label)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 112, height: 20)
    }

    private func build(label: String) {
        translatesAutoresizingMaskIntoConstraints = false
        labelStack.orientation = .vertical
        labelStack.spacing = -2
        labelStack.alignment = .centerX
        labelStack.translatesAutoresizingMaskIntoConstraints = false

        label.uppercased().forEach { character in
            let labelView = TBLabel(size: 5.8, weight: .bold, mono: true)
            labelView.stringValue = String(character)
            labelView.textColor = textColor
            labelStack.addArrangedSubview(labelView)
        }

        graphView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(labelStack)
        addSubview(graphView)

        NSLayoutConstraint.activate([
            labelStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            labelStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            graphView.leadingAnchor.constraint(equalTo: labelStack.trailingAnchor, constant: 8),
            graphView.trailingAnchor.constraint(equalTo: trailingAnchor),
            graphView.centerYAnchor.constraint(equalTo: centerYAnchor),
            graphView.heightAnchor.constraint(equalToConstant: 15)
        ])
    }

    func configure(values: [Double], tintColor: NSColor) {
        graphView.values = values
        graphView.barColor = tintColor
        graphView.trackColor = appearanceMode == .dark ? NSColor(white: 0.22, alpha: 1) : NSColor(white: 0.82, alpha: 1)
    }

    private var textColor: NSColor {
        switch appearanceMode {
        case .dark:
            return .white
        case .light:
            return NSColor(white: 0.08, alpha: 1)
        }
    }
}

final class TBLargeClockView: NSView {
    private let width: CGFloat
    private let appearanceMode: TBMetricCardView.Appearance
    private let label = TBLabel(size: 10.6, weight: .regular, mono: false)

    init(width: CGFloat, appearanceMode: TBMetricCardView.Appearance) {
        self.width = width
        self.appearanceMode = appearanceMode
        super.init(frame: .zero)
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        NSSize(width: width, height: 22)
    }

    private func build() {
        translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 10.4, weight: .regular)
        label.alignment = .center
        label.textColor = appearanceMode == .dark ? .white : NSColor(white: 0.08, alpha: 1)
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    func configure(_ value: String) {
        label.stringValue = value
    }
}

final class TBSymbolTileView: NSView {
    private let iconView: TBSymbol
    private let appearanceMode: TBMetricCardView.Appearance

    init(symbolName: String, accent: NSColor, appearanceMode: TBMetricCardView.Appearance) {
        self.iconView = TBSymbol(name: symbolName, size: 18, color: accent)
        self.appearanceMode = appearanceMode
        super.init(frame: .zero)
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 52, height: 20)
    }

    private func build() {
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    func configure(symbolName: String, accent: NSColor) {
        let configuration = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        iconView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
        iconView.contentTintColor = accent
    }
}

final class TBNowPlayingWidgetView: NSView {
    private let artworkView = NSImageView()
    private let artworkFallback = NSView()
    private let titleLabel = TBLabel(size: 10.4, weight: .semibold, mono: false, color: .white)
    private let subtitleLabel = TBLabel(size: 8.2, weight: .regular, mono: false, color: NSColor(white: 0.72, alpha: 1))
    private let textStack = NSStackView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 240, height: 24)
    }

    private func build() {
        translatesAutoresizingMaskIntoConstraints = false

        artworkView.wantsLayer = true
        artworkView.layer?.cornerRadius = 5
        artworkView.layer?.masksToBounds = true
        artworkView.imageScaling = .scaleAxesIndependently
        artworkView.translatesAutoresizingMaskIntoConstraints = false

        artworkFallback.wantsLayer = true
        artworkFallback.layer?.cornerRadius = 5
        artworkFallback.layer?.backgroundColor = NSColor(white: 0.82, alpha: 1).cgColor
        artworkFallback.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.maximumNumberOfLines = 1

        textStack.orientation = .vertical
        textStack.spacing = 0
        textStack.alignment = .leading
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)

        addSubview(artworkFallback)
        addSubview(artworkView)
        addSubview(textStack)

        NSLayoutConstraint.activate([
            artworkFallback.leadingAnchor.constraint(equalTo: leadingAnchor),
            artworkFallback.centerYAnchor.constraint(equalTo: centerYAnchor),
            artworkFallback.widthAnchor.constraint(equalToConstant: 22),
            artworkFallback.heightAnchor.constraint(equalToConstant: 22),

            artworkView.leadingAnchor.constraint(equalTo: leadingAnchor),
            artworkView.centerYAnchor.constraint(equalTo: centerYAnchor),
            artworkView.widthAnchor.constraint(equalToConstant: 22),
            artworkView.heightAnchor.constraint(equalToConstant: 22),

            textStack.leadingAnchor.constraint(equalTo: artworkView.trailingAnchor, constant: 10),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    func configure(title: String, subtitle: String?, artwork: NSImage?) {
        titleLabel.stringValue = title
        subtitleLabel.stringValue = subtitle ?? ""
        subtitleLabel.isHidden = (subtitle?.isEmpty ?? true)
        artworkView.image = artwork
        artworkView.isHidden = artwork == nil
        artworkFallback.isHidden = artwork != nil
    }
}

final class TBBoardMeterView: NSView {
    private let titleLabel = TBLabel(size: 6.6, weight: .bold, mono: false, color: .white)
    private let meterView = TBRoundedCapsuleMeterView()
    private let stack = NSStackView()

    init(title: String) {
        super.init(frame: .zero)
        titleLabel.stringValue = title
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 42, height: 22)
    }

    private func build() {
        translatesAutoresizingMaskIntoConstraints = false

        stack.orientation = .vertical
        stack.spacing = 3
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(meterView)

        addSubview(stack)
        NSLayoutConstraint.activate([
            meterView.widthAnchor.constraint(equalToConstant: 40),
            meterView.heightAnchor.constraint(equalToConstant: 10),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    func configure(fraction: Double) {
        meterView.fraction = fraction
    }
}

final class TBRoundedCapsuleMeterView: NSView {
    var fraction: Double = 0 { didSet { needsDisplay = true } }

    override init(frame: NSRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 40, height: 10)
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds
        NSColor(white: 0.16, alpha: 1).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 3.5, yRadius: 3.5).fill()

        NSColor(white: 0.62, alpha: 1).setStroke()
        let outline = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 3.5, yRadius: 3.5)
        outline.lineWidth = 1
        outline.stroke()

        let inset = rect.insetBy(dx: 3, dy: 2)
        let fillWidth = max(3, inset.width * CGFloat(max(0, min(1, fraction))))
        let fillRect = NSRect(x: inset.minX, y: inset.minY, width: fillWidth, height: inset.height)
        NSColor(calibratedRed: 0.10, green: 0.64, blue: 0.98, alpha: 1).setFill()
        NSBezierPath(roundedRect: fillRect, xRadius: 2, yRadius: 2).fill()
    }
}

final class TBVolumeSliderWidgetView: NSView {
    private let minIcon = TBSymbol(name: "speaker.fill", size: 15, color: NSColor(white: 0.7, alpha: 1))
    private let maxIcon = TBSymbol(name: "speaker.wave.3.fill", size: 24, color: NSColor(white: 0.7, alpha: 1))
    private let slider = TBVolumeSliderControl()
    private var pendingSystemValue: Double?
    private var pendingSystemValueDeadline: Date?

    override init(frame: NSRect) {
        super.init(frame: frame)
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 188, height: 28)
    }

    private func build() {
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.backgroundColor = NSColor.black.cgColor
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(minIcon)
        addSubview(slider)
        addSubview(maxIcon)

        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.target = self
        slider.action = #selector(handleSliderChanged(_:))
        slider.isContinuous = true

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 28),
            minIcon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            minIcon.centerYAnchor.constraint(equalTo: centerYAnchor),
            slider.leadingAnchor.constraint(equalTo: minIcon.trailingAnchor, constant: 10),
            slider.centerYAnchor.constraint(equalTo: centerYAnchor),
            slider.heightAnchor.constraint(equalToConstant: 22),
            maxIcon.leadingAnchor.constraint(equalTo: slider.trailingAnchor, constant: 10),
            maxIcon.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            maxIcon.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    func configure(fraction: CGFloat) {
        let normalized = max(0, min(1, Double(fraction)))

        if slider.isInteracting {
            return
        }

        if let pendingSystemValue {
            let isCaughtUp = abs(normalized - pendingSystemValue) < 0.035
            let isExpired = (pendingSystemValueDeadline.map { Date() >= $0 }) ?? true

            if isCaughtUp || isExpired {
                self.pendingSystemValue = nil
                pendingSystemValueDeadline = nil
            } else {
                slider.doubleValue = pendingSystemValue
                return
            }
        }

        slider.doubleValue = normalized
    }

    @objc
    private func handleSliderChanged(_ sender: NSSlider) {
        let value = max(0, min(1, sender.doubleValue))
        pendingSystemValue = value
        pendingSystemValueDeadline = Date().addingTimeInterval(1.25)
        TBSystemAudioController.setSystemVolume(Float(value))
    }
}

final class TBBrightnessSliderWidgetView: NSView {
    private let minIcon = TBSymbol(name: "sun.min.fill", size: 15, color: NSColor(white: 0.7, alpha: 1))
    private let maxIcon = TBSymbol(name: "sun.max.fill", size: 15, color: NSColor(white: 0.7, alpha: 1))
    private let slider = TBVolumeSliderControl()
    private var pendingSystemValue: Double?
    private var pendingSystemValueDeadline: Date?

    override init(frame: NSRect) {
        super.init(frame: frame)
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 188, height: 28)
    }

    private func build() {
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.backgroundColor = NSColor.black.cgColor
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(minIcon)
        addSubview(slider)
        addSubview(maxIcon)

        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.target = self
        slider.action = #selector(handleSliderChanged(_:))
        slider.isContinuous = true

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 28),
            minIcon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            minIcon.centerYAnchor.constraint(equalTo: centerYAnchor),
            slider.leadingAnchor.constraint(equalTo: minIcon.trailingAnchor, constant: 10),
            slider.centerYAnchor.constraint(equalTo: centerYAnchor),
            slider.heightAnchor.constraint(equalToConstant: 22),
            maxIcon.leadingAnchor.constraint(equalTo: slider.trailingAnchor, constant: 10),
            maxIcon.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            maxIcon.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    func configure(fraction: CGFloat) {
        let normalized = max(0, min(1, Double(fraction)))

        if slider.isInteracting {
            return
        }

        if let pendingSystemValue {
            let isCaughtUp = abs(normalized - pendingSystemValue) < 0.035
            let isExpired = (pendingSystemValueDeadline.map { Date() >= $0 }) ?? true

            if isCaughtUp || isExpired {
                self.pendingSystemValue = nil
                pendingSystemValueDeadline = nil
            } else {
                slider.doubleValue = pendingSystemValue
                return
            }
        }

        slider.doubleValue = normalized
    }

    @objc
    private func handleSliderChanged(_ sender: NSSlider) {
        let value = max(0, min(1, sender.doubleValue))
        pendingSystemValue = value
        pendingSystemValueDeadline = Date().addingTimeInterval(1.25)
        TBDisplayBrightnessController.setBrightness(Float(value))
    }
}

final class TBVolumeSliderControl: NSSlider {
    private(set) var isInteracting = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        minValue = 0
        maxValue = 1
        isContinuous = true
        controlSize = .small
        sliderType = .linear
        cell = TBVolumeSliderCell()
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 102, height: 20)
    }

    override func mouseDown(with event: NSEvent) {
        isInteracting = true
        super.mouseDown(with: event)
        isInteracting = false
    }
}

final class TBVolumeSliderCell: NSSliderCell {
    override init() {
        super.init()
        controlSize = .small
        sliderType = .linear
    }

    required init(coder: NSCoder) {
        fatalError()
    }

    override func drawBar(inside aRect: NSRect, flipped: Bool) {
        let trackRect = NSRect(x: aRect.minX, y: aRect.midY - 3, width: aRect.width, height: 6)
        NSColor(white: 0.18, alpha: 1).setFill()
        NSBezierPath(roundedRect: trackRect, xRadius: 3, yRadius: 3).fill()

        let dotY = aRect.midY
        let dotInset: CGFloat = 18
        let dotSpan = max(aRect.width - (dotInset * 2), 1)
        NSColor(white: 0.08, alpha: 1).setFill()
        for index in 0..<4 {
            let x = aRect.minX + dotInset + (dotSpan * CGFloat(index) / 3.0)
            let dotRect = NSRect(x: x - 1.75, y: dotY - 1.75, width: 3.5, height: 3.5)
            NSBezierPath(ovalIn: dotRect).fill()
        }
    }

    override func drawKnob(_ knobRect: NSRect) {
        let rect = NSRect(x: knobRect.midX - 8.5, y: knobRect.midY - 8, width: 17, height: 16)
        NSColor.white.setFill()
        NSBezierPath(roundedRect: rect, xRadius: 7.5, yRadius: 7.5).fill()
    }

    override func knobRect(flipped: Bool) -> NSRect {
        let base = super.knobRect(flipped: flipped)
        return NSRect(x: base.origin.x, y: base.midY - 8, width: 17, height: 16)
    }

    override func barRect(flipped: Bool) -> NSRect {
        guard let controlView else { return super.barRect(flipped: flipped) }
        return NSRect(x: 0, y: controlView.bounds.midY - 8, width: controlView.bounds.width, height: 16)
    }
}

enum DisplayServicesBrightnessBridge {
    private typealias SetBrightnessFn = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private typealias GetBrightnessFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32

    private static let frameworkHandle: UnsafeMutableRawPointer? = {
        dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)
    }()

    private static let setBrightnessFn: SetBrightnessFn? = {
        guard let frameworkHandle,
              let symbol = dlsym(frameworkHandle, "DisplayServicesSetBrightness") else {
            return nil
        }
        return unsafeBitCast(symbol, to: SetBrightnessFn.self)
    }()

    private static let getBrightnessFn: GetBrightnessFn? = {
        guard let frameworkHandle,
              let symbol = dlsym(frameworkHandle, "DisplayServicesGetBrightness") else {
            return nil
        }
        return unsafeBitCast(symbol, to: GetBrightnessFn.self)
    }()

    static func getBrightness() -> Float? {
        guard let getBrightnessFn else { return nil }

        for displayID in preferredDisplayIDs() {
            var value: Float = 0
            if getBrightnessFn(displayID, &value) == 0 {
                return value
            }
        }
        return nil
    }

    @discardableResult
    static func setBrightness(_ value: Float) -> Bool {
        guard let setBrightnessFn else { return false }

        let clamped = max(0, min(1, value))
        var didSetBrightness = false
        for displayID in preferredDisplayIDs() {
            if setBrightnessFn(displayID, clamped) == 0 {
                didSetBrightness = true
            }
        }
        return didSetBrightness
    }

    private static func preferredDisplayIDs() -> [CGDirectDisplayID] {
        var activeCount: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &activeCount) == .success, activeCount > 0 else {
            return [CGMainDisplayID()]
        }

        var displays = Array(repeating: CGDirectDisplayID(), count: Int(activeCount))
        guard CGGetOnlineDisplayList(activeCount, &displays, &activeCount) == .success else {
            return [CGMainDisplayID()]
        }

        return displays.sorted { lhs, rhs in
            let lhsBuiltin = CGDisplayIsBuiltin(lhs) != 0
            let rhsBuiltin = CGDisplayIsBuiltin(rhs) != 0
            if lhsBuiltin != rhsBuiltin {
                return lhsBuiltin && !rhsBuiltin
            }
            if lhs == CGMainDisplayID() { return true }
            if rhs == CGMainDisplayID() { return false }
            return lhs < rhs
        }
    }
}

private enum TBSystemAudioController {
    static func setSystemVolume(_ value: Float) {
        let clamped = max(0, min(1, value))
        guard let deviceID = defaultOutputDevice() else {
            setVolumeViaAppleScript(clamped)
            return
        }
        if setVolume(clamped, deviceID: deviceID, element: kAudioObjectPropertyElementMain) {
            return
        }

        let leftOK = setVolume(clamped, deviceID: deviceID, element: 1)
        let rightOK = setVolume(clamped, deviceID: deviceID, element: 2)
        if leftOK || rightOK {
            return
        }

        setVolumeViaAppleScript(clamped)
    }

    private static func defaultOutputDevice() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }

    private static func setVolume(_ value: Float, deviceID: AudioDeviceID, element: AudioObjectPropertyElement) -> Bool {
        var mutableValue = value
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )

        guard AudioObjectHasProperty(deviceID, &address) else { return false }

        var isSettable: DarwinBoolean = false
        let settableStatus = AudioObjectIsPropertySettable(deviceID, &address, &isSettable)
        guard settableStatus == noErr, isSettable.boolValue else { return false }

        let status = AudioObjectSetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<Float32>.size),
            &mutableValue
        )
        return status == noErr
    }

    private static func setVolumeViaAppleScript(_ value: Float) {
        let percent = Int((max(0, min(1, value)) * 100).rounded())
        let script = "set volume output volume \(percent)"
        guard let appleScript = NSAppleScript(source: script) else { return }
        appleScript.executeAndReturnError(nil)
    }
}

struct SystemNowPlayingSnapshot {
    let title: String
    let subtitle: String?
    let artwork: NSImage?
}

enum SystemNowPlayingBridge {
    private typealias GetNowPlayingInfoFn = @convention(c) (DispatchQueue, @escaping @convention(block) (CFDictionary?) -> Void) -> Void
    private typealias GetNowPlayingPlayingFn = @convention(c) (DispatchQueue, @escaping @convention(block) (Bool) -> Void) -> Void

    private static let frameworkBundle: Bundle? = {
        Bundle(path: "/System/Library/PrivateFrameworks/MediaRemote.framework")
    }()

    private static let frameworkHandle: UnsafeMutableRawPointer? = {
        frameworkBundle?.load()
        return dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY)
    }()

    private static let nowPlayingInfoFn: GetNowPlayingInfoFn? = {
        guard let frameworkHandle,
              let symbol = dlsym(frameworkHandle, "MRMediaRemoteGetNowPlayingInfo") else {
            return nil
        }
        return unsafeBitCast(symbol, to: GetNowPlayingInfoFn.self)
    }()

    private static let isPlayingFn: GetNowPlayingPlayingFn? = {
        guard let frameworkHandle,
              let symbol = dlsym(frameworkHandle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying") else {
            return nil
        }
        return unsafeBitCast(symbol, to: GetNowPlayingPlayingFn.self)
    }()

    private static let queue = DispatchQueue(label: "com.coremonitor.nowplaying")

    static func snapshot(timeout: TimeInterval = 0.20) -> SystemNowPlayingSnapshot? {
        return legacySnapshot(timeout: timeout)
    }

    private static func legacySnapshot(timeout: TimeInterval) -> SystemNowPlayingSnapshot? {
        guard let nowPlayingInfoFn else { return nil }

        var isPlaying = true
        if let isPlayingFn {
            let playingSemaphore = DispatchSemaphore(value: 0)
            isPlayingFn(queue) { value in
                isPlaying = value
                playingSemaphore.signal()
            }
            _ = playingSemaphore.wait(timeout: .now() + timeout)
        }

        let infoSemaphore = DispatchSemaphore(value: 0)
        var infoDictionary: [String: Any]?
        nowPlayingInfoFn(queue) { info in
            infoDictionary = info as? [String: Any]
            infoSemaphore.signal()
        }
        _ = infoSemaphore.wait(timeout: .now() + timeout)

        guard isPlaying, let infoDictionary else { return nil }

        let title = (infoDictionary["kMRMediaRemoteNowPlayingInfoTitle"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let artist = (infoDictionary["kMRMediaRemoteNowPlayingInfoArtist"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let album = (infoDictionary["kMRMediaRemoteNowPlayingInfoAlbum"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let subtitle: String? = {
            if let artist, !artist.isEmpty { return artist }
            if let album, !album.isEmpty { return album }
            return nil
        }()

        let artworkData = infoDictionary["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data
        let artwork = artworkData.flatMap(NSImage.init(data:))

        guard let title, !title.isEmpty else { return nil }
        return SystemNowPlayingSnapshot(title: title, subtitle: subtitle, artwork: artwork)
    }
}

private enum TBDisplayBrightnessController {
    static func setBrightness(_ value: Float) {
        let clamped = max(0, min(1, value))
        if DisplayServicesBrightnessBridge.setBrightness(clamped) {
            return
        }

        if setBrightness(clamped, matching: "IODisplayConnect") {
            return
        }
        _ = setBrightness(clamped, matching: "AppleBacklightDisplay")
    }

    private static func setBrightness(_ value: Float, matching serviceName: String) -> Bool {
        var iterator: io_iterator_t = 0
        let status = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(serviceName), &iterator)
        guard status == KERN_SUCCESS, iterator != 0 else { return false }
        defer { IOObjectRelease(iterator) }

        var didSetBrightness = false
        var service = IOIteratorNext(iterator)
        while service != 0 {
            let result = IODisplaySetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, value)
            if result == kIOReturnSuccess {
                didSetBrightness = true
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return didSetBrightness
    }
}

final class TBUtilityStripView: NSView {
    private let appearanceMode: TBMetricCardView.Appearance
    private let stack = NSStackView()
    private let leftSymbol = TBSymbol(name: "arrow.up.left.and.arrow.down.right", size: 14, color: .white)
    private let graph = TBLineGraph()
    private let primaryMeter = TBStripMeterView(symbolName: "speaker.wave.2.fill")
    private let secondaryMeter = TBStripMeterView(symbolName: "internaldrive.fill")
    private let tertiaryMeter = TBStripMeterView(symbolName: "sun.max.fill")
    private let terminalIcon = TBSymbol(name: "memorychip.fill", size: 14, color: .white)

    init(appearanceMode: TBMetricCardView.Appearance) {
        self.appearanceMode = appearanceMode
        super.init(frame: .zero)
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 210, height: 18)
    }

    private func build() {
        translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false

        graph.translatesAutoresizingMaskIntoConstraints = false
        graph.widthAnchor.constraint(equalToConstant: 56).isActive = true
        graph.heightAnchor.constraint(equalToConstant: 10).isActive = true

        [leftSymbol, graph, primaryMeter, secondaryMeter, tertiaryMeter, terminalIcon].forEach {
            stack.addArrangedSubview($0)
        }

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    func configure(
        leftSymbolName: String,
        graphValues: [Double],
        primarySymbolName: String,
        primaryFraction: CGFloat,
        secondarySymbolName: String,
        secondaryFraction: CGFloat,
        tertiarySymbolName: String,
        tertiaryFraction: CGFloat,
        terminalSymbolName: String,
        tintColor: NSColor
    ) {
        update(symbol: leftSymbol, name: leftSymbolName, tint: .white)
        graph.values = graphValues
        graph.lineColor = NSColor(calibratedRed: 0.44, green: 0.57, blue: 1.0, alpha: 1)
        primaryMeter.configure(symbolName: primarySymbolName, fraction: primaryFraction, tintColor: tintColor)
        secondaryMeter.configure(symbolName: secondarySymbolName, fraction: secondaryFraction, tintColor: tintColor)
        tertiaryMeter.configure(symbolName: tertiarySymbolName, fraction: tertiaryFraction, tintColor: tintColor)
        update(symbol: terminalIcon, name: terminalSymbolName, tint: tintColor)
    }

    private func update(symbol: TBSymbol, name: String, tint: NSColor) {
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        symbol.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
        symbol.contentTintColor = tint
    }
}

final class TBStripMeterView: NSView {
    private let iconView: TBSymbol
    private let meterView = TBProgressBar(color: .systemBlue, trackColor: NSColor(white: 0.22, alpha: 1))

    init(symbolName: String) {
        self.iconView = TBSymbol(name: symbolName, size: 14, color: .white)
        super.init(frame: .zero)
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 20, height: 18)
    }

    private func build() {
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)
        addSubview(meterView)

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 0),
            meterView.centerXAnchor.constraint(equalTo: centerXAnchor),
            meterView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),
            meterView.widthAnchor.constraint(equalToConstant: 7),
            meterView.heightAnchor.constraint(equalToConstant: 14)
        ])
    }

    override func layout() {
        super.layout()
        meterView.rotation = .pi / 2
    }

    func configure(symbolName: String, fraction: CGFloat, tintColor: NSColor) {
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        iconView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
        iconView.contentTintColor = tintColor
        meterView.trackColorOverride = NSColor(white: 0.24, alpha: 1)
        meterView.tintColor = tintColor
        meterView.fraction = Double(max(0, min(1, fraction)))
    }
}

final class TBBarGraphView: NSView {
    var values: [Double] = [] { didSet { needsDisplay = true } }
    var barColor: NSColor = .white { didSet { needsDisplay = true } }
    var trackColor: NSColor = NSColor(white: 0.22, alpha: 1) { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds
        let radius: CGFloat = 3
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill(with: trackColor)

        let bars = Array(values.suffix(10))
        guard !bars.isEmpty else { return }
        let maxValue = max(bars.max() ?? 1, 1)
        let insetRect = rect.insetBy(dx: 5, dy: 2)
        let barWidth = max(3, floor((insetRect.width - CGFloat(max(bars.count - 1, 0)) * 2) / CGFloat(max(bars.count, 1))))

        for (index, value) in bars.enumerated() {
            let x = insetRect.minX + CGFloat(index) * (barWidth + 2)
            let normalized = max(0.08, CGFloat(value / maxValue))
            let height = insetRect.height * normalized
            let y = insetRect.minY
            NSBezierPath(
                roundedRect: NSRect(x: x, y: y, width: barWidth, height: height),
                xRadius: 1,
                yRadius: 1
            ).fill(with: barColor)
        }
    }
}

final class TBMetricCardView: NSView {
    enum Appearance {
        case dark
        case light
    }

    private let width: CGFloat
    private let appearanceMode: Appearance
    private let iconView: TBSymbol
    private let titleLabel = TBLabel(size: 5.4, weight: .bold, mono: true)
    private let detailLabel = TBLabel(size: 5.2, weight: .medium, mono: true)
    private let valueLabel = TBLabel(size: 8.0, weight: .bold, mono: true)
    private let progressBar: TBProgressBar
    private let separatorLayer = CALayer()

    override var intrinsicContentSize: NSSize {
        NSSize(width: width, height: 22)
    }

    init(width: CGFloat, symbolName: String, accent: NSColor, appearanceMode: Appearance) {
        self.width = width
        self.appearanceMode = appearanceMode
        self.iconView = TBSymbol(name: symbolName, size: 8, color: accent)
        self.progressBar = TBProgressBar(
            color: accent,
            trackColor: appearanceMode == .dark
                ? NSColor(white: 0.26, alpha: 1)
                : NSColor(white: 0.74, alpha: 1)
        )
        super.init(frame: .zero)
        build(accent: accent)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func build(accent: NSColor) {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        separatorLayer.backgroundColor = NSColor(white: 0.28, alpha: 1).cgColor
        layer?.addSublayer(separatorLayer)

        detailLabel.alignment = .right
        titleLabel.textColor = secondaryTextColor
        detailLabel.textColor = detailTextColor
        valueLabel.textColor = primaryTextColor

        [iconView, titleLabel, detailLabel, valueLabel, progressBar].forEach {
            addSubview($0)
        }

        progressBar.tintColor = accent
        progressBar.isHidden = true

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 7),
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 3),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 3),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 3),

            detailLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            detailLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            detailLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 4),

            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 7),
            valueLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
            valueLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),

            progressBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            progressBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            progressBar.widthAnchor.constraint(equalToConstant: 22),
            progressBar.heightAnchor.constraint(equalToConstant: 4)
        ])
    }

    override func layout() {
        super.layout()
        separatorLayer.frame = CGRect(x: bounds.width - 1, y: 4, width: 1, height: max(0, bounds.height - 8))
    }

    func configure(
        symbolName: String,
        title: String,
        value: String,
        detail: String?,
        accent: NSColor,
        trend: [Double]? = nil,
        progress: Double? = nil
    ) {
        iconView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 8, weight: .medium))
        iconView.contentTintColor = accent
        titleLabel.stringValue = title
        detailLabel.stringValue = detail ?? ""
        detailLabel.isHidden = detail?.isEmpty ?? true
        valueLabel.stringValue = value
        titleLabel.textColor = secondaryTextColor
        detailLabel.textColor = detailTextColor
        valueLabel.textColor = primaryTextColor
        progressBar.tintColor = accent
        progressBar.fraction = progress ?? 0
        progressBar.isHidden = progress == nil
    }

    private var primaryTextColor: NSColor {
        switch appearanceMode {
        case .dark:
            return .white
        case .light:
            return NSColor(white: 0.08, alpha: 1)
        }
    }

    private var secondaryTextColor: NSColor {
        switch appearanceMode {
        case .dark:
            return NSColor(white: 0.74, alpha: 1)
        case .light:
            return NSColor(white: 0.24, alpha: 1)
        }
    }

    private var detailTextColor: NSColor {
        switch appearanceMode {
        case .dark:
            return NSColor(white: 0.60, alpha: 1)
        case .light:
            return NSColor(white: 0.35, alpha: 1)
        }
    }
}

final class TBModuleView: NSView {
    enum Style {
        case dark
        case light
    }

    private let style: Style
    private let stack = NSStackView()

    init(style: Style) {
        self.style = style
        super.init(frame: .zero)
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        let size = stack.fittingSize
        return NSSize(width: size.width + 20, height: 28)
    }

    func addMetric(_ metric: NSView) {
        stack.addArrangedSubview(metric)
        invalidateIntrinsicContentSize()
    }

    private func build() {
        wantsLayer = true
        layer?.cornerRadius = 9
        layer?.backgroundColor = backgroundColor.cgColor
        layer?.borderWidth = 0.75
        layer?.borderColor = borderColor.cgColor
        translatesAutoresizingMaskIntoConstraints = false

        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        stack.distribution = .gravityAreas
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 28),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2)
        ])
    }

    private var backgroundColor: NSColor {
        switch style {
        case .dark:
            return NSColor(white: 0.13, alpha: 1)
        case .light:
            return NSColor(white: 0.92, alpha: 1)
        }
    }

    private var borderColor: NSColor {
        switch style {
        case .dark:
            return NSColor(white: 0.28, alpha: 0.9)
        case .light:
            return NSColor(white: 0.72, alpha: 0.95)
        }
    }
}

final class TBLineGraph: NSView {
    var values: [Double] = [] { didSet { needsDisplay = true } }
    var lineColor: NSColor = .systemBlue { didSet { needsDisplay = true } }
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard values.count > 1 else { return }
        let points = Array(values.suffix(24))
        let maxValue = max(points.max() ?? 1, 1)
        let midY = bounds.midY
        let path = NSBezierPath()
        path.lineWidth = 1.4
        path.lineCapStyle = .round
        for (index, value) in points.enumerated() {
            let x = bounds.width * CGFloat(index) / CGFloat(max(points.count - 1, 1))
            let y = midY - CGFloat(value / maxValue) * 6 + (index.isMultiple(of: 2) ? 1 : -1)
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.line(to: CGPoint(x: x, y: y))
            }
        }
        lineColor.setStroke()
        path.stroke()
    }
}

final class TBLabel: NSTextField {
    init(size: CGFloat, weight: NSFont.Weight, mono: Bool = false, color: NSColor = NSColor(white: 0.75, alpha: 1)) {
        super.init(frame: .zero)
        isBezeled = false
        isEditable = false
        drawsBackground = false
        lineBreakMode = .byClipping
        cell?.truncatesLastVisibleLine = false
        font = mono
            ? .monospacedSystemFont(ofSize: size, weight: weight)
            : .systemFont(ofSize: size, weight: weight)
        textColor = color
        translatesAutoresizingMaskIntoConstraints = false
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.defaultHigh, for: .horizontal)
    }

    required init?(coder: NSCoder) { fatalError() }
}

final class TBSymbol: NSImageView {
    init(name: String, size: CGFloat, color: NSColor) {
        super.init(frame: .zero)
        let configuration = NSImage.SymbolConfiguration(pointSize: size, weight: .medium)
        image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
        contentTintColor = color
        imageScaling = .scaleProportionallyUpOrDown
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size + 2),
            heightAnchor.constraint(equalToConstant: size + 2)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}

final class TBProgressBar: NSView {
    var fraction: Double = 0 { didSet { needsDisplay = true } }
    var tintColor: NSColor = .systemBlue { didSet { needsDisplay = true } }
    var rotation: CGFloat = 0 { didSet { needsDisplay = true } }
    var trackColorOverride: NSColor? { didSet { needsDisplay = true } }
    private let trackColor: NSColor

    init(color: NSColor, trackColor: NSColor) {
        self.tintColor = color
        self.trackColor = trackColor
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        if rotation != 0 {
            context.translateBy(x: bounds.midX, y: bounds.midY)
            context.rotate(by: rotation)
            context.translateBy(x: -bounds.midX, y: -bounds.midY)
        }

        let rect = bounds
        let radius = rect.height / 2
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill(with: trackColorOverride ?? trackColor)
        guard fraction > 0 else {
            context.restoreGState()
            return
        }
        let fillWidth = max(radius * 2, rect.width * CGFloat(min(fraction, 1)))
        NSBezierPath(
            roundedRect: NSRect(x: rect.minX, y: rect.minY, width: fillWidth, height: rect.height),
            xRadius: radius,
            yRadius: radius
        ).fill(with: tintColor)
        context.restoreGState()
    }
}

private extension NSBezierPath {
    func fill(with color: NSColor) {
        color.setFill()
        fill()
    }
}
