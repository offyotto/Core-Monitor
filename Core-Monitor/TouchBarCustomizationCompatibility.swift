import AppKit
import Combine
import Foundation

extension Notification.Name {
    static let touchBarCustomizationDidChange = Notification.Name("TouchBarCustomizationDidChange")
}

enum TouchBarPresentationMode: String, Codable, CaseIterable, Identifiable {
    case app
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .app: return "Core Monitor"
        case .system: return "System"
        }
    }

    var subtitle: String {
        switch self {
        case .app: return "Show the custom Core Monitor Touch Bar"
        case .system: return "Fall back to the standard macOS Touch Bar"
        }
    }
}

private enum StoredTouchBarTheme: String, Codable {
    case dark
    case light

    init(theme: TouchBarTheme) {
        self = theme == .light ? .light : .dark
    }

    var theme: TouchBarTheme {
        switch self {
        case .dark: return .dark
        case .light: return .light
        }
    }
}

extension TouchBarTheme: CaseIterable, Identifiable {
    static var allCases: [TouchBarTheme] { [.dark, .light] }

    var id: String { StoredTouchBarTheme(theme: self).rawValue }

    var displayName: String {
        self == .light ? "Light" : "Dark"
    }

    var tertiaryTextColor: NSColor {
        self == .light
            ? NSColor(calibratedWhite: 0.18, alpha: 0.56)
            : NSColor.white.withAlphaComponent(0.52)
    }

    var accentBlue: NSColor {
        NSColor(red: 0.10, green: 0.58, blue: 0.97, alpha: 1.0)
    }

    var accentPurple: NSColor {
        NSColor(red: 0.43, green: 0.30, blue: 0.89, alpha: 1.0)
    }

    var ringStrokeColor: NSColor {
        self == .light
            ? NSColor(calibratedWhite: 0.24, alpha: 0.55)
            : NSColor(calibratedWhite: 0.62, alpha: 1.0)
    }

    var barTrackColor: NSColor {
        self == .light
            ? NSColor.black.withAlphaComponent(0.08)
            : NSColor.white.withAlphaComponent(0.14)
    }

    var glyphFillColor: NSColor {
        self == .light ? NSColor(calibratedWhite: 0.12, alpha: 1.0) : .white
    }

    var graphBackgroundColor: NSColor {
        self == .light
            ? NSColor(calibratedWhite: 0.18, alpha: 1.0)
            : NSColor.white.withAlphaComponent(0.05)
    }
}

struct TouchBarPinnedApp: Codable, Hashable, Identifiable {
    let id: String
    var displayName: String
    var filePath: String
    var bundleIdentifier: String?
}

struct TouchBarPinnedFolder: Codable, Hashable, Identifiable {
    let id: String
    var displayName: String
    var folderPath: String
}

struct TouchBarCustomWidget: Codable, Hashable, Identifiable {
    let id: String
    var title: String
    var symbolName: String
    var command: String
    var width: CGFloat
}

enum TouchBarItemConfiguration: Codable, Identifiable, Hashable {
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
        subtitle: "Status, weather, control center, dock, and CPU",
        theme: .dark,
        items: [.builtIn(.worldClocks), .builtIn(.weather), .builtIn(.controlCenter), .builtIn(.dock), .builtIn(.cpu)]
    )

    static let detailed = TouchBarPreset(
        id: "detailed",
        title: "Detailed",
        subtitle: "Status with weather and expanded stats",
        theme: .light,
        items: [.builtIn(.worldClocks), .builtIn(.weather), .builtIn(.controlCenter), .builtIn(.detailedStats)]
    )

    static let fullStrip = TouchBarPreset(
        id: "fullStrip",
        title: "Full Strip",
        subtitle: "A dense full-width monitoring layout",
        theme: .dark,
        items: [
            .builtIn(.worldClocks),
            .builtIn(.weather),
            .builtIn(.controlCenter),
            .builtIn(.dock),
            .builtIn(.cpu),
            .builtIn(.stats),
            .builtIn(.combined),
            .builtIn(.hardware),
            .builtIn(.network),
            .builtIn(.ramPressure)
        ]
    )

    static let compact = TouchBarPreset(
        id: "compact",
        title: "Compact",
        subtitle: "Small weather, CPU, and memory-focused strip",
        theme: .dark,
        items: [.builtIn(.weather), .builtIn(.cpu), .builtIn(.network), .builtIn(.ramPressure)]
    )

    static let all: [TouchBarPreset] = [.classic, .detailed, .fullStrip, .compact]
}

private struct PersistedTouchBarConfigurationV6: Codable {
    var theme: StoredTouchBarTheme
    var items: [TouchBarItemConfiguration]
    var presentationMode: TouchBarPresentationMode
}

private struct LegacyPersistedTouchBarConfigurationV5: Codable {
    var theme: StoredTouchBarTheme
    var items: [TouchBarItemConfiguration]
}

private struct LegacyPersistedTouchBarConfigurationV4: Codable {
    var theme: StoredTouchBarTheme
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

    @Published var presentationMode: TouchBarPresentationMode {
        didSet { persistAndNotify() }
    }

    var estimatedWidth: CGFloat {
        let gaps = max(CGFloat(items.count - 1), 0) * TB.groupGap
        return items.reduce(0) { $0 + $1.estimatedWidth } + gaps
    }

    var widthOverflow: CGFloat {
        max(0, estimatedWidth - Self.recommendedTouchBarWidth)
    }

    private let defaultsKey = "coremonitor.touchBarConfiguration.v6"
    private let legacyDefaultsKey = "coremonitor.touchBarConfiguration.v5"
    private let legacyWidgetOnlyDefaultsKey = "coremonitor.touchBarConfiguration.v4"
    private let legacyPresentationModeKey = "coremonitor.touchBarMode"

    private init() {
        let defaults = UserDefaults.standard
        let fallbackPresentation = TouchBarPresentationMode(
            rawValue: defaults.string(forKey: legacyPresentationModeKey) ?? TouchBarPresentationMode.app.rawValue
        ) ?? .app

        if let data = defaults.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode(PersistedTouchBarConfigurationV6.self, from: data) {
            theme = decoded.theme.theme
            items = decoded.items.isEmpty ? TouchBarPreset.classic.items : decoded.items
            presentationMode = decoded.presentationMode
            return
        }

        if let data = defaults.data(forKey: legacyDefaultsKey),
           let decoded = try? JSONDecoder().decode(LegacyPersistedTouchBarConfigurationV5.self, from: data) {
            theme = decoded.theme.theme
            items = decoded.items.isEmpty ? TouchBarPreset.classic.items : decoded.items
            presentationMode = fallbackPresentation
            return
        }

        if let data = defaults.data(forKey: legacyWidgetOnlyDefaultsKey),
           let decoded = try? JSONDecoder().decode(LegacyPersistedTouchBarConfigurationV4.self, from: data) {
            theme = decoded.theme.theme
            items = decoded.widgets.isEmpty ? TouchBarPreset.classic.items : decoded.widgets.map(TouchBarItemConfiguration.builtIn)
            presentationMode = fallbackPresentation
            return
        }

        theme = TouchBarPreset.classic.theme
        items = TouchBarPreset.classic.items
        presentationMode = fallbackPresentation
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
        let trimmedSymbol = symbolName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty, !trimmedCommand.isEmpty else { return }

        items.append(
            .customWidget(
                TouchBarCustomWidget(
                    id: UUID().uuidString,
                    title: trimmedTitle,
                    symbolName: trimmedSymbol.isEmpty ? "terminal.fill" : trimmedSymbol,
                    command: trimmedCommand,
                    width: max(width, 72)
                )
            )
        )
    }

    private func persistAndNotify() {
        let payload = PersistedTouchBarConfigurationV6(
            theme: StoredTouchBarTheme(theme: theme),
            items: items,
            presentationMode: presentationMode
        )

        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }

        NotificationCenter.default.post(name: .touchBarCustomizationDidChange, object: self)
    }
}

extension MeterControl {
    func update(usage: Float, pressure: MemoryPressureLevel) {
        set(value: usage)
        switch pressure {
        case .green:
            fillColor = NSColor(red: 0.25, green: 0.90, blue: 0.58, alpha: 1.0)
        case .yellow:
            fillColor = NSColor(red: 1.00, green: 0.62, blue: 0.20, alpha: 1.0)
        case .red:
            fillColor = .systemRed
        }
    }
}
