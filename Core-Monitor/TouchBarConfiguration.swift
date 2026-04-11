import AppKit
import Combine
import Foundation

extension Notification.Name {
    static let touchBarCustomizationDidChange = Notification.Name("TouchBarCustomizationDidChange")
}

enum TouchBarTheme: String, CaseIterable, Codable, Identifiable {
    case dark
    case light

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
        }
    }

    var pillBackgroundColor: NSColor {
        switch self {
        case .dark: return NSColor(calibratedWhite: 0.18, alpha: 1)
        case .light: return NSColor(calibratedWhite: 0.92, alpha: 1)
        }
    }

    var pillBorderColor: NSColor {
        switch self {
        case .dark: return NSColor(calibratedWhite: 0.28, alpha: 1)
        case .light: return NSColor(calibratedWhite: 0.82, alpha: 1)
        }
    }

    var primaryTextColor: NSColor {
        switch self {
        case .dark: return .white
        case .light: return NSColor(calibratedWhite: 0.06, alpha: 1)
        }
    }

    var secondaryTextColor: NSColor {
        switch self {
        case .dark: return NSColor.white.withAlphaComponent(0.78)
        case .light: return NSColor(calibratedWhite: 0.16, alpha: 0.78)
        }
    }

    var tertiaryTextColor: NSColor {
        switch self {
        case .dark: return NSColor.white.withAlphaComponent(0.52)
        case .light: return NSColor(calibratedWhite: 0.18, alpha: 0.56)
        }
    }

    var accentBlue: NSColor {
        NSColor(red: 0.10, green: 0.58, blue: 0.97, alpha: 1)
    }

    var accentPurple: NSColor {
        NSColor(red: 0.43, green: 0.30, blue: 0.89, alpha: 1)
    }

    var ringStrokeColor: NSColor {
        switch self {
        case .dark: return NSColor(calibratedWhite: 0.62, alpha: 1)
        case .light: return NSColor(calibratedWhite: 0.24, alpha: 0.55)
        }
    }

    var barTrackColor: NSColor {
        NSColor(calibratedWhite: 0.16, alpha: 1)
    }

    var barOutlineColor: NSColor {
        switch self {
        case .dark: return NSColor(calibratedWhite: 0.45, alpha: 1)
        case .light: return NSColor(calibratedWhite: 0.38, alpha: 1)
        }
    }

    var glyphFillColor: NSColor {
        switch self {
        case .dark: return .white
        case .light: return NSColor(calibratedWhite: 0.12, alpha: 1)
        }
    }

    var graphBackgroundColor: NSColor {
        switch self {
        case .dark: return NSColor(calibratedWhite: 0.10, alpha: 1)
        case .light: return NSColor(calibratedWhite: 0.18, alpha: 1)
        }
    }
}

enum TouchBarWidgetKind: String, CaseIterable, Codable, Identifiable {
    case worldClocks
    case weather
    case stats
    case detailedStats
    case combined
    case hardware
    case network

    var id: String { rawValue }

    var title: String {
        switch self {
        case .worldClocks: return "Status"
        case .weather: return "Weather"
        case .stats: return "Stats"
        case .detailedStats: return "Stats + Clocks"
        case .combined: return "Combined"
        case .hardware: return "Hardware Icons"
        case .network: return "Network"
        }
    }

    var subtitle: String {
        switch self {
        case .worldClocks: return "Language, Wi-Fi, battery and clock"
        case .weather: return "Pock weather view powered by WeatherKit"
        case .stats: return "Time, MEM, SSD, CPU"
        case .detailedStats: return "Compact stats with local date"
        case .combined: return "Network, MEM, CPU, BAT, SSD, graph, time"
        case .hardware: return "Waveform, bolt, battery, drives, chip, graph"
        case .network: return "Live up/down rates"
        }
    }

    var identifier: NSTouchBarItem.Identifier {
        NSTouchBarItem.Identifier("com.coremonitor.touchbar.\(rawValue)")
    }

    var estimatedWidth: CGFloat {
        switch self {
        case .worldClocks: return 228
        case .weather: return 194
        case .stats: return 314
        case .detailedStats: return 348
        case .combined: return 628
        case .hardware: return 380
        case .network: return 180
        }
    }
}

struct TouchBarPreset: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let theme: TouchBarTheme
    let widgets: [TouchBarWidgetKind]

    static let classic = TouchBarPreset(
        id: "classic",
        title: "Classic",
        subtitle: "Status, weather and system stats",
        theme: .dark,
        widgets: [.worldClocks, .weather, .stats]
    )

    static let detailed = TouchBarPreset(
        id: "detailed",
        title: "Detailed",
        subtitle: "Detailed stats with clock expansion",
        theme: .light,
        widgets: [.detailedStats, .worldClocks, .weather]
    )

    static let combined = TouchBarPreset(
        id: "combined",
        title: "Combined",
        subtitle: "The dense iStat-style combined strip",
        theme: .dark,
        widgets: [.network, .combined, .weather, .hardware]
    )

    static let compact = TouchBarPreset(
        id: "compact",
        title: "Compact",
        subtitle: "Network, combined metrics and weather",
        theme: .light,
        widgets: [.network, .combined, .weather]
    )

    static let all: [TouchBarPreset] = [.classic, .detailed, .combined, .compact]
}

private struct PersistedTouchBarConfiguration: Codable {
    var theme: TouchBarTheme
    var widgets: [TouchBarWidgetKind]
}

@MainActor
final class TouchBarCustomizationSettings: ObservableObject {
    static let shared = TouchBarCustomizationSettings()
    static let recommendedTouchBarWidth: CGFloat = 1085

    @Published var theme: TouchBarTheme {
        didSet { persistAndNotify() }
    }

    @Published var widgets: [TouchBarWidgetKind] {
        didSet {
            if widgets.isEmpty {
                widgets = TouchBarPreset.classic.widgets
                return
            }
            persistAndNotify()
        }
    }

    var estimatedWidth: CGFloat {
        let gaps = max(CGFloat(widgets.count - 1), 0) * TB.groupGap
        return widgets.reduce(0) { $0 + $1.estimatedWidth } + gaps
    }

    var widthOverflow: CGFloat {
        max(0, estimatedWidth - Self.recommendedTouchBarWidth)
    }

    private let defaultsKey = "coremonitor.touchBarConfiguration.v4"

    private init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode(PersistedTouchBarConfiguration.self, from: data) {
            self.theme = decoded.theme
            self.widgets = decoded.widgets.isEmpty ? TouchBarPreset.classic.widgets : decoded.widgets
        } else {
            self.theme = TouchBarPreset.classic.theme
            self.widgets = TouchBarPreset.classic.widgets
        }
    }

    func applyPreset(_ preset: TouchBarPreset) {
        theme = preset.theme
        widgets = preset.widgets
    }

    func contains(_ kind: TouchBarWidgetKind) -> Bool {
        widgets.contains(kind)
    }

    func toggle(_ kind: TouchBarWidgetKind) {
        if let index = widgets.firstIndex(of: kind) {
            guard widgets.count > 1 else { return }
            widgets.remove(at: index)
        } else {
            widgets.append(kind)
        }
    }

    func moveUp(_ kind: TouchBarWidgetKind) {
        guard let index = widgets.firstIndex(of: kind), index > 0 else { return }
        widgets.swapAt(index, index - 1)
    }

    func moveDown(_ kind: TouchBarWidgetKind) {
        guard let index = widgets.firstIndex(of: kind), index < widgets.count - 1 else { return }
        widgets.swapAt(index, index + 1)
    }

    private func persistAndNotify() {
        let payload = PersistedTouchBarConfiguration(theme: theme, widgets: widgets)
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
        NotificationCenter.default.post(name: .touchBarCustomizationDidChange, object: self)
    }
}
