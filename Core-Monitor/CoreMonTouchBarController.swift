import AppKit
import Combine
import CoreWLAN
import Foundation

@MainActor
final class CoreMonTouchBarController: NSObject {
    let touchBar: NSTouchBar
    let weatherViewModel: WeatherViewModel

    private static let customizationNotification = Notification.Name("TouchBarCustomizationDidChange")

    private let systemMonitor: SystemMonitor
    private let ownsSystemMonitor: Bool

    private var cancellables = Set<AnyCancellable>()
    private var networkBaseline: (inBytes: UInt64, outBytes: UInt64)?
    private var widgets: [NSTouchBarItem.Identifier: PKWidgetInfo] = [:]
    private var configuredItems: [NSTouchBarItem.Identifier: TouchBarItemConfiguration] = [:]
    private var cachedItems: [NSTouchBarItem.Identifier: NSTouchBarItem] = [:]

    init(weatherProvider: WeatherProviding? = nil, monitor: SystemMonitor? = nil) {
        let provider = weatherProvider ?? Self.defaultWeatherProvider()
        self.weatherViewModel = WeatherViewModel(provider: provider)
        self.systemMonitor = monitor ?? SystemMonitor()
        self.ownsSystemMonitor = monitor == nil
        self.touchBar = NSTouchBar()
        super.init()

        widgets = PKCoreMonWidgetCatalog.allWidgets()
        touchBar.delegate = self
        touchBar.customizationIdentifier = NSTouchBar.CustomizationIdentifier("com.coremonitor.touchbar.main")

        bindWeather()
        bindSystem()
        bindCustomization()
        applyCustomization()
        refreshViews()
    }

    deinit {
        let viewModel = weatherViewModel
        let monitor = systemMonitor
        let ownsMonitor = ownsSystemMonitor
        Task { @MainActor in
            viewModel.stop()
            if ownsMonitor {
                monitor.stopMonitoring()
            }
        }
    }

    func start() {
        if ownsSystemMonitor {
            systemMonitor.startMonitoring()
        }
        weatherViewModel.start()
        refreshViews()
    }

    func stop() {
        weatherViewModel.stop()
        if ownsSystemMonitor {
            systemMonitor.stopMonitoring()
        }
    }

    func install(in window: NSWindow) {
        window.touchBar = touchBar
    }

    private static func defaultWeatherProvider() -> WeatherProviding {
        if #available(macOS 13.0, *) {
            return LiveWeatherService()
        }
        return MockWeatherService()
    }

    private func bindWeather() {
        weatherViewModel.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshViews()
            }
            .store(in: &cancellables)
    }

    private func bindSystem() {
        NotificationCenter.default.publisher(for: .systemMonitorDidUpdate, object: systemMonitor)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshViews()
            }
            .store(in: &cancellables)
    }

    private func bindCustomization() {
        NotificationCenter.default.publisher(for: Self.customizationNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyCustomization()
                self?.refreshViews()
            }
            .store(in: &cancellables)
    }

    private func applyCustomization() {
        let customization = loadCustomization()
        widgets = PKCoreMonWidgetCatalog.allWidgets()
        configuredItems = Dictionary(uniqueKeysWithValues: customization.items.map { ($0.touchBarIdentifier, $0) })
        cachedItems.removeAll()
        let identifiers = customization.items.map(\.touchBarIdentifier)
        touchBar.customizationAllowedItemIdentifiers = identifiers
        touchBar.defaultItemIdentifiers = identifiers
        touchBar.principalItemIdentifier = nil
        applyThemeToCachedWidgets(customization.theme)
    }

    private func refreshViews() {
        let snapshot = makeSnapshot()
        let now = Date()
        let theme = currentTheme()
        let clockTitle = formattedTime(from: now, timeZone: .current)
        let clockSubtitle = formattedMonthDay(from: now)

        for item in cachedItems.values {
            guard let widget = (item as? PKWidgetTouchBarItem)?.widget else {
                continue
            }
            PKCoreMonWidgetState.apply(
                theme: theme,
                weatherState: weatherViewModel.state,
                snapshot: snapshot,
                clockTitle: clockTitle,
                clockSubtitle: clockSubtitle,
                to: widget
            )
        }
    }

    private func makeSnapshot() -> TouchBarSystemSnapshot {
        let battery = systemMonitor.batteryInfo
        let network = networkThroughput()
        let parisTime = detailedClockStrings()

        return TouchBarSystemSnapshot(
            memPct: clamp(systemMonitor.memoryUsagePercent),
            ssdPct: clamp(storageUsagePercent()),
            cpuPct: clamp(systemMonitor.cpuUsagePercent),
            cpuTempC: systemMonitor.cpuTemperature ?? systemMonitor.cpuUsagePercent,
            brightness: systemMonitor.currentBrightness,
            batPct: max(0, min(100, battery.chargePercent ?? 100)),
            batCharging: battery.isCharging,
            netUpKBs: network.upKBs,
            netDownMBs: network.downMBs,
            fps: currentFPS(),
            wifiName: currentWiFiName(),
            detailedClockTitle: parisTime.title,
            detailedClockSubtitle: parisTime.subtitle
        )
    }

    private func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 100)
    }

    private func detailedClockStrings() -> (title: String, subtitle: String) {
        let now = Date()
        return (
            title: formattedTime(from: now, timeZone: .current),
            subtitle: formattedMonthDay(from: now)
        )
    }

    private func formattedTime(from date: Date, timeZoneID: String) -> String {
        formattedTime(from: date, timeZone: TimeZone(identifier: timeZoneID) ?? .current)
    }

    private func formattedTime(from date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "H:mm"
        return formatter.string(from: date)
    }

    private func formattedMonthDay(from date: Date) -> String {
        let monthDay = DateFormatter()
        monthDay.locale = Locale(identifier: "en_US_POSIX")
        monthDay.timeZone = .current
        monthDay.dateFormat = "MMM d"

        let day = Calendar.current.component(.day, from: date)
        return "\(monthDay.string(from: date))\(ordinalSuffix(for: day))"
    }

    private func ordinalSuffix(for day: Int) -> String {
        let tens = day % 100
        if tens >= 11 && tens <= 13 {
            return "th"
        }

        switch day % 10 {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }

    private func currentFPS() -> Int {
        NSScreen.main?.maximumFramesPerSecond ?? 60
    }

    private func currentWiFiName() -> String {
        CWWiFiClient.shared().interface()?.ssid() ?? "--"
    }

    private func storageUsagePercent() -> Double {
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        guard let values = try? homeURL.resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity,
              let available = values.volumeAvailableCapacityForImportantUsage else {
            return 0
        }
        let used = max(Int64(total) - available, 0)
        return (Double(used) / Double(total)) * 100
    }

    private func networkThroughput() -> (upKBs: Double, downMBs: Double) {
        let current = networkBytes()
        defer { networkBaseline = current }

        guard let baseline = networkBaseline else {
            return (0, 0)
        }

        let upBytes = current.outBytes > baseline.outBytes ? current.outBytes - baseline.outBytes : 0
        let downBytes = current.inBytes > baseline.inBytes ? current.inBytes - baseline.inBytes : 0
        return (
            upKBs: Double(upBytes) / 1000,
            downMBs: Double(downBytes) / 1_000_000
        )
    }

    private func networkBytes() -> (inBytes: UInt64, outBytes: UInt64) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let head = ifaddr else { return (0, 0) }
        defer { freeifaddrs(head) }

        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        var current = head

        while true {
            let interface = current.pointee
            if interface.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                let name = String(cString: interface.ifa_name)
                if name.hasPrefix("en") || name.hasPrefix("utun") || name.hasPrefix("ipsec") {
                    if let data = interface.ifa_data {
                        let stats = data.assumingMemoryBound(to: if_data.self).pointee
                        totalIn += UInt64(stats.ifi_ibytes)
                        totalOut += UInt64(stats.ifi_obytes)
                    }
                }
            }

            if let next = interface.ifa_next {
                current = next
            } else {
                break
            }
        }

        return (totalIn, totalOut)
    }

    private func currentTheme() -> TouchBarTheme {
        loadCustomization().theme
    }

    private func applyThemeToCachedWidgets(_ theme: TouchBarTheme) {
        for item in cachedItems.values {
            guard let widget = (item as? PKWidgetTouchBarItem)?.widget,
                  let pillWidget = widget as? PKPillWidget else {
                continue
            }
            pillWidget.theme = theme
        }
    }

    private func configure(_ item: PKWidgetTouchBarItem) {
        guard let widget = item.widget else {
            return
        }

        let now = Date()
        PKCoreMonWidgetState.apply(
            theme: currentTheme(),
            weatherState: weatherViewModel.state,
            snapshot: makeSnapshot(),
            clockTitle: formattedTime(from: now, timeZone: .current),
            clockSubtitle: formattedMonthDay(from: now),
            to: widget
        )
    }

    private func loadCustomization() -> (theme: TouchBarTheme, items: [TouchBarItemConfiguration]) {
        let settings = TouchBarCustomizationSettings.shared
        return (
            theme: settings.theme,
            items: settings.items.isEmpty ? TouchBarPreset.classic.items : settings.items
        )
    }
}

extension CoreMonTouchBarController: NSTouchBarDelegate {
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        if let item = cachedItems[identifier] {
            return item
        }

        if let configuration = configuredItems[identifier] {
            switch configuration {
            case .builtIn(let kind):
                guard let widgetInfo = widgets[kind.identifier],
                      let item = PKWidgetTouchBarItem(widget: widgetInfo, identifier: identifier) else {
                    return nil
                }
                cachedItems[identifier] = item
                configure(item)
                return item
            case .pinnedApp(let app):
                let item = NSCustomTouchBarItem(identifier: identifier)
                item.view = TouchBarShortcutButton.makeAppButton(app: app, theme: currentTheme())
                cachedItems[identifier] = item
                return item
            case .pinnedFolder(let folder):
                let item = NSCustomTouchBarItem(identifier: identifier)
                item.view = TouchBarShortcutButton.makeFolderButton(folder: folder, theme: currentTheme())
                cachedItems[identifier] = item
                return item
            case .customWidget(let widget):
                let item = NSCustomTouchBarItem(identifier: identifier)
                item.view = TouchBarCustomCommandButton(widget: widget, theme: currentTheme())
                cachedItems[identifier] = item
                return item
            }
        }
        return nil
    }
}

private final class TouchBarShortcutButton: NSButton {
    static func makeAppButton(app: TouchBarPinnedApp, theme: TouchBarTheme) -> TouchBarShortcutButton {
        let button = TouchBarShortcutButton(title: "", target: nil, action: #selector(openShortcut))
        button.shortcutURL = URL(fileURLWithPath: app.filePath)
        button.theme = theme
        button.toolTip = app.displayName
        button.image = (NSWorkspace.shared.icon(forFile: app.filePath)).copy() as? NSImage
        button.configureIconStyle()
        return button
    }

    static func makeFolderButton(folder: TouchBarPinnedFolder, theme: TouchBarTheme) -> TouchBarShortcutButton {
        let button = TouchBarShortcutButton(title: "", target: nil, action: #selector(openShortcut))
        button.shortcutURL = URL(fileURLWithPath: folder.folderPath)
        button.theme = theme
        button.toolTip = folder.displayName
        button.image = (NSWorkspace.shared.icon(forFile: folder.folderPath)).copy() as? NSImage
        button.configureIconStyle()
        return button
    }

    private var shortcutURL: URL?
    private var theme: TouchBarTheme = .dark

    @objc private func openShortcut() {
        guard let shortcutURL else { return }
        NSWorkspace.shared.open(shortcutURL)
    }

    private func configureIconStyle() {
        target = self
        isBordered = false
        bezelStyle = .shadowlessSquare
        focusRingType = .none
        translatesAutoresizingMaskIntoConstraints = false
        imageScaling = .scaleProportionallyUpOrDown
        image?.size = NSSize(width: 22, height: 22)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 28),
            heightAnchor.constraint(equalToConstant: 24)
        ])
    }
}

private final class TouchBarCustomCommandButton: NSButton {
    private let widget: TouchBarCustomWidget

    init(widget: TouchBarCustomWidget, theme: TouchBarTheme) {
        self.widget = widget
        super.init(frame: .zero)
        title = widget.title
        image = NSImage(systemSymbolName: widget.symbolName, accessibilityDescription: widget.title)?
            .withSymbolConfiguration(.init(pointSize: 12, weight: .medium))
        imagePosition = .imageLeading
        target = self
        action = #selector(runCommand)
        isBordered = false
        bezelStyle = .shadowlessSquare
        focusRingType = .none
        font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        contentTintColor = theme.primaryTextColor
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = theme.pillBackgroundColor.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = theme.pillBorderColor.cgColor
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: widget.width),
            heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    @objc private func runCommand() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", widget.command]
        try? process.run()
    }
}
