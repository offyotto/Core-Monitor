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
        case .app: return "Core-Monitor"
        case .system: return "System"
        }
    }

    var subtitle: String {
        switch self {
        case .app: return "Show the Core-Monitor Touch Bar layout on the hardware Touch Bar"
        case .system: return "Keep editing the Core-Monitor layout, but show the standard macOS Touch Bar on the hardware until you press Command-Shift-6 or switch back to Core-Monitor"
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
        subtitle: "Status, weather, controls, dock, and CPU",
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
        subtitle: "Weather, CPU, network, and memory pressure",
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
    static let defaultPreset: TouchBarPreset = .classic
    static let recommendedTouchBarWidth: CGFloat = 1085

    @Published var theme: TouchBarTheme {
        didSet {
            guard isApplyingConfiguration == false else { return }
            persistAndNotify()
        }
    }

    @Published var items: [TouchBarItemConfiguration] {
        didSet {
            guard isApplyingConfiguration == false else { return }

            let normalizedItems = Self.normalizedItems(items)
            if normalizedItems != items {
                isApplyingConfiguration = true
                items = normalizedItems
                isApplyingConfiguration = false
            }

            persistAndNotify()
        }
    }

    @Published var presentationMode: TouchBarPresentationMode {
        didSet {
            guard isApplyingConfiguration == false else { return }
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

    var activePreset: TouchBarPreset? {
        TouchBarPreset.all.first { preset in
            preset.theme == theme && preset.items == items
        }
    }

    private let defaultsKey = "coremonitor.touchBarConfiguration.v6"
    private let legacyDefaultsKey = "coremonitor.touchBarConfiguration.v5"
    private let legacyWidgetOnlyDefaultsKey = "coremonitor.touchBarConfiguration.v4"
    private let legacyPresentationModeKey = "coremonitor.touchBarMode"
    private let defaults: UserDefaults
    private var isApplyingConfiguration = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let fallbackPresentation = TouchBarPresentationMode(
            rawValue: defaults.string(forKey: legacyPresentationModeKey) ?? TouchBarPresentationMode.app.rawValue
        ) ?? .app

        if let data = defaults.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode(PersistedTouchBarConfigurationV6.self, from: data) {
            theme = decoded.theme.theme
            items = Self.normalizedItems(decoded.items)
            presentationMode = decoded.presentationMode
            return
        }

        if let data = defaults.data(forKey: legacyDefaultsKey),
           let decoded = try? JSONDecoder().decode(LegacyPersistedTouchBarConfigurationV5.self, from: data) {
            theme = decoded.theme.theme
            items = Self.normalizedItems(decoded.items)
            presentationMode = fallbackPresentation
            return
        }

        if let data = defaults.data(forKey: legacyWidgetOnlyDefaultsKey),
           let decoded = try? JSONDecoder().decode(LegacyPersistedTouchBarConfigurationV4.self, from: data) {
            theme = decoded.theme.theme
            items = Self.normalizedItems(decoded.widgets.map(TouchBarItemConfiguration.builtIn))
            presentationMode = fallbackPresentation
            return
        }

        theme = Self.defaultPreset.theme
        items = Self.defaultPreset.items
        presentationMode = fallbackPresentation
    }

    func applyPreset(_ preset: TouchBarPreset) {
        applyConfiguration(theme: preset.theme, items: preset.items)
    }

    func restoreDefaults() {
        applyConfiguration(
            theme: Self.defaultPreset.theme,
            items: Self.defaultPreset.items,
            presentationMode: .app
        )
    }

    func contains(_ kind: TouchBarWidgetKind) -> Bool {
        items.contains(where: { $0.builtInKind == kind })
    }

    func toggle(_ kind: TouchBarWidgetKind) {
        var updatedItems = items
        if let index = items.firstIndex(where: { $0.builtInKind == kind }) {
            guard updatedItems.count > 1 else { return }
            updatedItems.remove(at: index)
        } else {
            updatedItems.append(.builtIn(kind))
        }
        applyConfiguration(items: updatedItems)
    }

    func moveUp(_ item: TouchBarItemConfiguration) {
        guard let index = items.firstIndex(of: item), index > 0 else { return }
        var updatedItems = items
        updatedItems.swapAt(index, index - 1)
        applyConfiguration(items: updatedItems)
    }

    func moveDown(_ item: TouchBarItemConfiguration) {
        guard let index = items.firstIndex(of: item), index < items.count - 1 else { return }
        var updatedItems = items
        updatedItems.swapAt(index, index + 1)
        applyConfiguration(items: updatedItems)
    }

    func remove(_ item: TouchBarItemConfiguration) {
        guard let index = items.firstIndex(of: item), items.count > 1 else { return }
        var updatedItems = items
        updatedItems.remove(at: index)
        applyConfiguration(items: updatedItems)
    }

    func addPinnedApps(urls: [URL]) {
        var seenPinnedApps = Set(items.compactMap(\.pinnedAppPath))
        let newItems = urls.compactMap { url -> TouchBarItemConfiguration? in
            let normalizedPath = Self.standardizedPath(url.path)
            guard seenPinnedApps.insert(normalizedPath).inserted else { return nil }

            return .pinnedApp(
                TouchBarPinnedApp(
                    id: UUID().uuidString,
                    displayName: FileManager.default.displayName(atPath: normalizedPath),
                    filePath: normalizedPath,
                    bundleIdentifier: Bundle(url: URL(fileURLWithPath: normalizedPath))?.bundleIdentifier
                )
            )
        }
        applyConfiguration(items: items + newItems)
    }

    func addPinnedFolders(urls: [URL]) {
        var seenPinnedFolders = Set(items.compactMap(\.pinnedFolderPath))
        let newItems = urls.compactMap { url -> TouchBarItemConfiguration? in
            let normalizedPath = Self.standardizedPath(url.path)
            guard seenPinnedFolders.insert(normalizedPath).inserted else { return nil }

            return .pinnedFolder(
                TouchBarPinnedFolder(
                    id: UUID().uuidString,
                    displayName: FileManager.default.displayName(atPath: normalizedPath),
                    folderPath: normalizedPath
                )
            )
        }
        applyConfiguration(items: items + newItems)
    }

    func addCustomWidget(title: String, symbolName: String, command: String, width: CGFloat = 96) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSymbol = symbolName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty, !trimmedCommand.isEmpty else { return }

        applyConfiguration(
            items: items + [
                .customWidget(
                    TouchBarCustomWidget(
                        id: UUID().uuidString,
                        title: trimmedTitle,
                        symbolName: trimmedSymbol.isEmpty ? "terminal.fill" : trimmedSymbol,
                        command: trimmedCommand,
                        width: max(width, 72)
                    )
                )
            ]
        )
    }

    private func persistAndNotify() {
        let payload = PersistedTouchBarConfigurationV6(
            theme: StoredTouchBarTheme(theme: theme),
            items: items,
            presentationMode: presentationMode
        )

        if let data = try? JSONEncoder().encode(payload) {
            defaults.set(data, forKey: defaultsKey)
        }

        NotificationCenter.default.post(name: .touchBarCustomizationDidChange, object: self)
    }

    private func applyConfiguration(
        theme: TouchBarTheme? = nil,
        items: [TouchBarItemConfiguration]? = nil,
        presentationMode: TouchBarPresentationMode? = nil
    ) {
        let resolvedTheme = theme ?? self.theme
        let resolvedItems = Self.normalizedItems(items ?? self.items)
        let resolvedPresentationMode = presentationMode ?? self.presentationMode

        guard resolvedTheme != self.theme
            || resolvedItems != self.items
            || resolvedPresentationMode != self.presentationMode else {
            return
        }

        isApplyingConfiguration = true
        self.theme = resolvedTheme
        self.items = resolvedItems
        self.presentationMode = resolvedPresentationMode
        isApplyingConfiguration = false
        persistAndNotify()
    }

    static func normalizedItems(_ items: [TouchBarItemConfiguration]) -> [TouchBarItemConfiguration] {
        var normalized: [TouchBarItemConfiguration] = []
        var seenBuiltIns = Set<TouchBarWidgetKind>()
        var seenPinnedApps = Set<String>()
        var seenPinnedFolders = Set<String>()

        for item in items {
            guard let sanitized = sanitized(item) else { continue }

            switch sanitized {
            case .builtIn(let kind):
                guard seenBuiltIns.insert(kind).inserted else { continue }
            case .pinnedApp(let app):
                guard seenPinnedApps.insert(standardizedPath(app.filePath)).inserted else { continue }
            case .pinnedFolder(let folder):
                guard seenPinnedFolders.insert(standardizedPath(folder.folderPath)).inserted else { continue }
            case .customWidget:
                break
            }

            normalized.append(sanitized)
        }

        return normalized.isEmpty ? Self.defaultPreset.items : normalized
    }

    private static func sanitized(_ item: TouchBarItemConfiguration) -> TouchBarItemConfiguration? {
        switch item {
        case .builtIn:
            return item
        case .pinnedApp(var app):
            let filePath = standardizedPath(app.filePath)
            guard filePath.isEmpty == false else { return nil }
            app.filePath = filePath
            let trimmedName = app.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            app.displayName = trimmedName.isEmpty
                ? FileManager.default.displayName(atPath: filePath)
                : trimmedName
            return .pinnedApp(app)
        case .pinnedFolder(var folder):
            let folderPath = standardizedPath(folder.folderPath)
            guard folderPath.isEmpty == false else { return nil }
            folder.folderPath = folderPath
            let trimmedName = folder.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            folder.displayName = trimmedName.isEmpty
                ? FileManager.default.displayName(atPath: folderPath)
                : trimmedName
            return .pinnedFolder(folder)
        case .customWidget(var widget):
            let trimmedCommand = widget.command.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedCommand.isEmpty == false else { return nil }
            let trimmedTitle = widget.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedSymbol = widget.symbolName.trimmingCharacters(in: .whitespacesAndNewlines)
            widget.command = trimmedCommand
            widget.title = trimmedTitle.isEmpty ? "Command" : trimmedTitle
            widget.symbolName = trimmedSymbol.isEmpty ? "terminal.fill" : trimmedSymbol
            widget.width = min(max(widget.width, 72), 220)
            return .customWidget(widget)
        }
    }

    fileprivate static func standardizedPath(_ rawPath: String) -> String {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let expanded = (trimmed as NSString).expandingTildeInPath
        return (expanded as NSString).standardizingPath
    }
}

private extension TouchBarItemConfiguration {
    var pinnedAppPath: String? {
        guard case .pinnedApp(let app) = self else { return nil }
        return TouchBarCustomizationSettings.standardizedPath(app.filePath)
    }

    var pinnedFolderPath: String? {
        guard case .pinnedFolder(let folder) = self else { return nil }
        return TouchBarCustomizationSettings.standardizedPath(folder.folderPath)
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
