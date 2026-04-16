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
    private var widgets: [NSTouchBarItem.Identifier: PKWidgetInfo] = [:]
    private var configuredItems: [NSTouchBarItem.Identifier: TouchBarItemConfiguration] = [:]
    private var cachedItems: [NSTouchBarItem.Identifier: NSTouchBarItem] = [:]
    private var isStarted = false
    private var isWeatherRunning = false
    private var refreshTimer: Timer?
    private var lastRefreshDate = Date.distantPast
    private lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "H:mm"
        return formatter
    }()
    private lazy var monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter
    }()

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
        refreshViews(force: true)
    }

    deinit {
        refreshTimer?.invalidate()
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
        guard !isStarted else {
            updateWeatherMonitoring()
            refreshViews(force: true)
            return
        }
        isStarted = true
        if ownsSystemMonitor {
            systemMonitor.startMonitoring()
        }
        updateWeatherMonitoring()
        startRefreshTimer()
        refreshViews(force: true)
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false
        refreshTimer?.invalidate()
        refreshTimer = nil
        lastRefreshDate = .distantPast
        updateWeatherMonitoring()
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
                self?.refreshViews(force: true)
            }
            .store(in: &cancellables)
    }

    private func bindSystem() {
        systemMonitor.$snapshot
            .map(\.sampledAt)
            .removeDuplicates()
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
                self?.refreshViews(force: true)
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
        updateWeatherMonitoring()
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: TB.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshViews(force: true)
            }
        }
        timer.tolerance = TB.refreshInterval * 0.2
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    private func updateWeatherMonitoring() {
        let shouldRunWeather = isStarted && configuredItems.values.contains(where: { $0.builtInKind == .weather })
        guard shouldRunWeather != isWeatherRunning else { return }

        isWeatherRunning = shouldRunWeather
        if shouldRunWeather {
            weatherViewModel.start()
        } else {
            weatherViewModel.stop()
        }
    }

    private func refreshViews(force: Bool = false) {
        guard isStarted, cachedItems.isEmpty == false else { return }
        let now = Date()
        if force == false && now.timeIntervalSince(lastRefreshDate) < TB.refreshInterval {
            return
        }

        lastRefreshDate = now
        let snapshot = makeSnapshot()
        let theme = currentTheme()
        let clockTitle = formattedTime(from: lastRefreshDate, timeZone: .current)
        let clockSubtitle = formattedMonthDay(from: lastRefreshDate)

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
        let network = systemMonitor.networkStats
        let parisTime = detailedClockStrings()

        return TouchBarSystemSnapshot(
            memPct: clamp(systemMonitor.memoryUsagePercent),
            ssdPct: clamp(storageUsagePercent()),
            cpuPct: clamp(systemMonitor.cpuUsagePercent),
            cpuTempC: systemMonitor.cpuTemperature ?? systemMonitor.cpuUsagePercent,
            brightness: systemMonitor.currentBrightness,
            batPct: max(0, min(100, battery.chargePercent ?? 100)),
            batCharging: battery.isCharging,
            netUpKBs: network.uploadBytesPerSec / 1_000,
            netDownMBs: network.downloadBytesPerSec / 1_000_000,
            fps: currentFPS(),
            wifiName: currentWiFiName(),
            detailedClockTitle: parisTime.title,
            detailedClockSubtitle: parisTime.subtitle,
            memoryPressure: systemMonitor.memoryPressure
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
        timeFormatter.timeZone = timeZone
        return timeFormatter.string(from: date)
    }

    private func formattedMonthDay(from date: Date) -> String {
        monthDayFormatter.timeZone = .current
        let day = Calendar.current.component(.day, from: date)
        return "\(monthDayFormatter.string(from: date))\(ordinalSuffix(for: day))"
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

        if let configuration = configuredItems[identifier],
           let item = TouchBarItemFactory.makeTouchBarItem(
                for: configuration,
                widgets: widgets,
                theme: currentTheme()
           ) {
            cachedItems[identifier] = item
            if isStarted, let widgetItem = item as? PKWidgetTouchBarItem {
                configure(widgetItem)
            }
            return item
        }
        return nil
    }
}

final class TouchBarShortcutButton: NSButton {
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

enum TouchBarCommandRunner {
    private static let maxCommandLength = 512
    private static let allowedEnvironmentKeys = ["HOME", "LANG", "LOGNAME", "TMPDIR", "USER"]

    static func sanitizedCommand(from rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.utf8.count <= maxCommandLength else {
            return nil
        }

        let disallowedControlCharacters = CharacterSet.controlCharacters
            .subtracting(CharacterSet(charactersIn: "\t"))
        guard trimmed.unicodeScalars.allSatisfy({ !disallowedControlCharacters.contains($0) }) else {
            return nil
        }

        return trimmed
    }

    static func makeProcess(for rawCommand: String) -> Process? {
        guard let command = sanitizedCommand(from: rawCommand) else { return nil }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-f", "-c", command]
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser

        var environment: [String: String] = [
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
            "SHELL": "/bin/zsh",
        ]

        let inheritedEnvironment = ProcessInfo.processInfo.environment
        for key in allowedEnvironmentKeys {
            if let value = inheritedEnvironment[key], !value.isEmpty {
                environment[key] = value
            }
        }

        process.environment = environment
        return process
    }
}

final class TouchBarCustomCommandButton: NSButton {
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
        guard let process = TouchBarCommandRunner.makeProcess(for: widget.command) else {
            NSSound.beep()
            return
        }

        do {
            try process.run()
        } catch {
            NSSound.beep()
        }
    }
}
