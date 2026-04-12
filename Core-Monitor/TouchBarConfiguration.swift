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
    case controlCenter
    case dock
    case cpu
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
        case .controlCenter: return "Control Center"
        case .dock: return "Dock"
        case .cpu: return "CPU"
        case .stats: return "Stats"
        case .detailedStats: return "Stats + Clocks"
        case .combined: return "Combined"
        case .hardware: return "Hardware Icons"
        case .network: return "Network"
        }
    }

    var subtitle: String {
        switch self {
        case .worldClocks: return "Wi-Fi, battery and clock"
        case .weather: return "Weather widget powered by WeatherKit"
        case .controlCenter: return "Brightness and volume controls"
        case .dock: return "Running apps and persistent items"
        case .cpu: return "CPU temperature and usage"
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
        case .worldClocks: return 182
        case .weather: return 194
        case .controlCenter: return 144
        case .dock: return 96
        case .cpu: return 92
        case .stats: return 314
        case .detailedStats: return 348
        case .combined: return 628
        case .hardware: return 380
        case .network: return 180
        }
    }
}

struct TouchBarPinnedApp: Codable, Identifiable, Equatable {
    let id: String
    var displayName: String
    var filePath: String
    var bundleIdentifier: String?
}

struct TouchBarPinnedFolder: Codable, Identifiable, Equatable {
    let id: String
    var displayName: String
    var folderPath: String
}

struct TouchBarCustomWidget: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var symbolName: String
    var command: String
    var width: CGFloat
}

enum TouchBarItemConfiguration: Codable, Identifiable, Equatable {
    case builtIn(TouchBarWidgetKind)
    case pinnedApp(TouchBarPinnedApp)
    case pinnedFolder(TouchBarPinnedFolder)
    case customWidget(TouchBarCustomWidget)

    var id: String {
        switch self {
        case .builtIn(let kind):
            return "builtin.\(kind.rawValue)"
        case .pinnedApp(let app):
            return "app.\(app.id)"
        case .pinnedFolder(let folder):
            return "folder.\(folder.id)"
        case .customWidget(let widget):
            return "custom.\(widget.id)"
        }
    }

    var touchBarIdentifier: NSTouchBarItem.Identifier {
        NSTouchBarItem.Identifier("com.coremonitor.touchbar.item.\(id)")
    }

    var title: String {
        switch self {
        case .builtIn(let kind):
            return kind.title
        case .pinnedApp(let app):
            return app.displayName
        case .pinnedFolder(let folder):
            return folder.displayName
        case .customWidget(let widget):
            return widget.title
        }
    }

    var subtitle: String {
        switch self {
        case .builtIn(let kind):
            return kind.subtitle
        case .pinnedApp:
            return "Pinned application launcher"
        case .pinnedFolder:
            return "Pinned folder shortcut"
        case .customWidget(let widget):
            return widget.command
        }
    }

    var estimatedWidth: CGFloat {
        switch self {
        case .builtIn(let kind):
            return kind.estimatedWidth
        case .pinnedApp, .pinnedFolder:
            return 32
        case .customWidget(let widget):
            return max(widget.width, 72)
        }
    }

    var isBuiltIn: Bool {
        if case .builtIn = self {
            return true
        }
        return false
    }

    var builtInKind: TouchBarWidgetKind? {
        if case .builtIn(let kind) = self {
            return kind
        }
        return nil
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case builtInKind
        case pinnedApp
        case pinnedFolder
        case customWidget
    }

    private enum Discriminator: String, Codable {
        case builtIn
        case pinnedApp
        case pinnedFolder
        case customWidget
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let discriminator = try container.decode(Discriminator.self, forKey: .kind)
        switch discriminator {
        case .builtIn:
            self = .builtIn(try container.decode(TouchBarWidgetKind.self, forKey: .builtInKind))
        case .pinnedApp:
            self = .pinnedApp(try container.decode(TouchBarPinnedApp.self, forKey: .pinnedApp))
        case .pinnedFolder:
            self = .pinnedFolder(try container.decode(TouchBarPinnedFolder.self, forKey: .pinnedFolder))
        case .customWidget:
            self = .customWidget(try container.decode(TouchBarCustomWidget.self, forKey: .customWidget))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .builtIn(let kind):
            try container.encode(Discriminator.builtIn, forKey: .kind)
            try container.encode(kind, forKey: .builtInKind)
        case .pinnedApp(let app):
            try container.encode(Discriminator.pinnedApp, forKey: .kind)
            try container.encode(app, forKey: .pinnedApp)
        case .pinnedFolder(let folder):
            try container.encode(Discriminator.pinnedFolder, forKey: .kind)
            try container.encode(folder, forKey: .pinnedFolder)
        case .customWidget(let widget):
            try container.encode(Discriminator.customWidget, forKey: .kind)
            try container.encode(widget, forKey: .customWidget)
        }
    }
}

struct TouchBarPreset: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let theme: TouchBarTheme
    let items: [TouchBarItemConfiguration]

    static let classic = TouchBarPreset(
        id: "classic",
        title: "Classic",
        subtitle: "Status, weather and CPU",
        theme: .dark,
        items: [.builtIn(.worldClocks), .builtIn(.weather), .builtIn(.controlCenter), .builtIn(.dock), .builtIn(.cpu)]
    )

    static let detailed = TouchBarPreset(
        id: "detailed",
        title: "Detailed",
        subtitle: "Detailed stats with clock expansion",
        theme: .light,
        items: [.builtIn(.worldClocks), .builtIn(.weather), .builtIn(.controlCenter), .builtIn(.detailedStats)]
    )

    static let combined = TouchBarPreset(
        id: "combined",
        title: "Combined",
        subtitle: "The dense combined strip",
        theme: .dark,
        items: [.builtIn(.worldClocks), .builtIn(.weather), .builtIn(.controlCenter), .builtIn(.dock), .builtIn(.cpu), .builtIn(.stats)]
    )

    static let compact = TouchBarPreset(
        id: "compact",
        title: "Compact",
        subtitle: "Network, combined metrics and weather",
        theme: .light,
        items: [.builtIn(.worldClocks), .builtIn(.weather), .builtIn(.controlCenter), .builtIn(.dock), .builtIn(.cpu), .builtIn(.stats)]
    )

    static let all: [TouchBarPreset] = [.classic, .detailed, .combined, .compact]
}

private struct PersistedTouchBarConfiguration: Codable {
    var theme: TouchBarTheme
    var items: [TouchBarItemConfiguration]
}

private struct LegacyPersistedTouchBarConfiguration: Codable {
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

    @Published var items: [TouchBarItemConfiguration] {
        didSet {
            if items.isEmpty {
                items = TouchBarPreset.classic.items
                return
            }
            persistAndNotify()
        }
    }

    var estimatedWidth: CGFloat {
        let gaps = max(CGFloat(items.count - 1), 0) * TB.groupGap
        return items.reduce(0) { $0 + $1.estimatedWidth } + gaps
    }

    var widthOverflow: CGFloat {
        max(0, estimatedWidth - Self.recommendedTouchBarWidth)
    }

    private let defaultsKey = "coremonitor.touchBarConfiguration.v5"
    private let legacyDefaultsKey = "coremonitor.touchBarConfiguration.v4"

    private init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode(PersistedTouchBarConfiguration.self, from: data) {
            self.theme = decoded.theme
            self.items = decoded.items.isEmpty ? TouchBarPreset.classic.items : decoded.items
        } else if let data = UserDefaults.standard.data(forKey: legacyDefaultsKey),
                  let decoded = try? JSONDecoder().decode(LegacyPersistedTouchBarConfiguration.self, from: data) {
            self.theme = decoded.theme
            self.items = decoded.widgets.isEmpty ? TouchBarPreset.classic.items : decoded.widgets.map(TouchBarItemConfiguration.builtIn)
        } else {
            self.theme = TouchBarPreset.classic.theme
            self.items = TouchBarPreset.classic.items
        }
    }

    func applyPreset(_ preset: TouchBarPreset) {
        theme = preset.theme
        items = preset.items
    }

    func contains(_ kind: TouchBarWidgetKind) -> Bool {
        items.contains(where: { $0.builtInKind == kind })
    }

    func toggle(_ kind: TouchBarWidgetKind) {
        if let index = items.firstIndex(where: { $0.builtInKind == kind }) {
            guard items.count > 1 else { return }
            items.remove(at: index)
        } else {
            items.append(.builtIn(kind))
        }
    }

    func moveUp(_ item: TouchBarItemConfiguration) {
        guard let index = items.firstIndex(of: item), index > 0 else { return }
        items.swapAt(index, index - 1)
    }

    func moveDown(_ item: TouchBarItemConfiguration) {
        guard let index = items.firstIndex(of: item), index < items.count - 1 else { return }
        items.swapAt(index, index + 1)
    }

    func remove(_ item: TouchBarItemConfiguration) {
        guard let index = items.firstIndex(of: item), items.count > 1 else { return }
        items.remove(at: index)
    }

    func addPinnedApps(urls: [URL]) {
        let newItems = urls.map { url in
            TouchBarItemConfiguration.pinnedApp(
                TouchBarPinnedApp(
                    id: UUID().uuidString,
                    displayName: FileManager.default.displayName(atPath: url.path),
                    filePath: url.path,
                    bundleIdentifier: Bundle(url: url)?.bundleIdentifier
                )
            )
        }
        items.append(contentsOf: newItems)
    }

    func addPinnedFolders(urls: [URL]) {
        let newItems = urls.map { url in
            TouchBarItemConfiguration.pinnedFolder(
                TouchBarPinnedFolder(
                    id: UUID().uuidString,
                    displayName: FileManager.default.displayName(atPath: url.path),
                    folderPath: url.path
                )
            )
        }
        items.append(contentsOf: newItems)
    }

    func addCustomWidget(title: String, symbolName: String, command: String, width: CGFloat = 96) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedCommand.isEmpty else { return }
        items.append(
            .customWidget(
                TouchBarCustomWidget(
                    id: UUID().uuidString,
                    title: trimmedTitle,
                    symbolName: symbolName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "terminal.fill" : symbolName,
                    command: trimmedCommand,
                    width: width
                )
            )
        )
    }

    private func persistAndNotify() {
        let payload = PersistedTouchBarConfiguration(theme: theme, items: items)
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
        NotificationCenter.default.post(name: .touchBarCustomizationDidChange, object: self)
    }
}
