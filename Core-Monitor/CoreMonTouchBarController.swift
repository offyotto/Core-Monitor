import AppKit
import Combine
import CoreWLAN
import Foundation

@MainActor
final class CoreMonTouchBarController: NSObject {
    let touchBar: NSTouchBar
    let weatherViewModel: WeatherViewModel

    private static let customizationNotification = Notification.Name("TouchBarCustomizationDidChange")
    private static let customizationDefaultsKey = "coremonitor.touchBarConfiguration.v4"
    private static let defaultTheme = "dark"
    private static let defaultWidgetIdentifiers: [NSTouchBarItem.Identifier] = [
        TouchBarWidgetKind.worldClocks.identifier,
        TouchBarWidgetKind.weather.identifier,
        TouchBarWidgetKind.stats.identifier
    ]

    private let systemMonitor: SystemMonitor
    private let ownsSystemMonitor: Bool

    private var cancellables = Set<AnyCancellable>()
    private var networkBaseline: (inBytes: UInt64, outBytes: UInt64)?
    private var widgets: [NSTouchBarItem.Identifier: PKWidgetInfo] = [:]
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
        touchBar.customizationIdentifier = NSTouchBar.CustomizationIdentifier("com.coremonitor.touchbar.istat")

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
        touchBar.customizationAllowedItemIdentifiers = TouchBarWidgetKind.allCases.map(\.identifier)
        touchBar.defaultItemIdentifiers = customization.widgets
        touchBar.principalItemIdentifier = nil
        applyThemeToCachedWidgets(TouchBarTheme(rawValue: customization.theme) ?? .dark)
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
        TouchBarTheme(rawValue: loadCustomization().theme) ?? .dark
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

    private func loadCustomization() -> (theme: String, widgets: [NSTouchBarItem.Identifier]) {
        guard let data = UserDefaults.standard.data(forKey: Self.customizationDefaultsKey),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (Self.defaultTheme, Self.defaultWidgetIdentifiers)
        }

        let theme = payload["theme"] as? String ?? Self.defaultTheme
        let validIdentifiers = Set(TouchBarWidgetKind.allCases.map(\.identifier))
        let widgets = (payload["widgets"] as? [String])?
            .map { NSTouchBarItem.Identifier($0) }
            .filter { validIdentifiers.contains($0) }

        return (theme, widgets?.isEmpty == false ? widgets ?? Self.defaultWidgetIdentifiers : Self.defaultWidgetIdentifiers)
    }
}

extension CoreMonTouchBarController: NSTouchBarDelegate {
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        if let item = cachedItems[identifier] {
            return item
        }

        guard let widgetInfo = widgets[identifier],
              let item = PKWidgetTouchBarItem(widget: widgetInfo) else {
            return nil
        }

        cachedItems[identifier] = item
        configure(item)
        return item
    }
}
