import Foundation
import Combine

extension Notification.Name {
    static let menuBarSettingsDidChange = Notification.Name("CoreMonitor.MenuBarSettingsDidChange")
}

enum MenuBarVisibilityPreset: CaseIterable, Identifiable {
    case thermalFocus
    case balanced
    case full

    var id: Self { self }

    var title: String {
        switch self {
        case .thermalFocus:
            return "Compact"
        case .balanced:
            return "Balanced"
        case .full:
            return "Full"
        }
    }

    var detail: String {
        switch self {
        case .thermalFocus:
            return "Keep the menu bar heat-first with CPU load and temperature only."
        case .balanced:
            return "Show CPU load, live fan RPM, and temperature without turning the menu bar into noise."
        case .full:
            return "Expose CPU, fan, memory, network, storage, and temperature all at once."
        }
    }

    var isRecommended: Bool {
        self == .balanced
    }

    var enabledItems: [MenuBarItemKind] {
        switch self {
        case .thermalFocus:
            return [.cpu, .temperature]
        case .balanced:
            return [.cpu, .fan, .temperature]
        case .full:
            return MenuBarItemKind.allCases
        }
    }
}

@MainActor
final class MenuBarSettings: ObservableObject {
    static let shared = MenuBarSettings()
    static let defaultPreset: MenuBarVisibilityPreset = .balanced

    @Published private(set) var cpuEnabled: Bool
    @Published private(set) var fanEnabled: Bool
    @Published private(set) var memoryEnabled: Bool
    @Published private(set) var networkEnabled: Bool
    @Published private(set) var diskEnabled: Bool
    @Published private(set) var temperatureEnabled: Bool
    @Published private(set) var lastWarning: String?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.cpuEnabled = Self.boolValue(for: .cpu, defaults: defaults)
        self.fanEnabled = Self.boolValue(for: .fan, defaults: defaults)
        self.memoryEnabled = Self.boolValue(for: .memory, defaults: defaults)
        self.networkEnabled = Self.boolValue(for: .network, defaults: defaults)
        self.diskEnabled = Self.boolValue(for: .disk, defaults: defaults)
        self.temperatureEnabled = Self.boolValue(for: .temperature, defaults: defaults)
        ensureAccessibleConfiguration()
    }

    func isEnabled(_ kind: MenuBarItemKind) -> Bool {
        switch kind {
        case .cpu:
            return cpuEnabled
        case .fan:
            return fanEnabled
        case .memory:
            return memoryEnabled
        case .network:
            return networkEnabled
        case .disk:
            return diskEnabled
        case .temperature:
            return temperatureEnabled
        }
    }

    func setEnabled(_ enabled: Bool, for kind: MenuBarItemKind) {
        if enabled == false, enabledItemCount <= 1, isEnabled(kind) {
            lastWarning = "At least one menu bar item must remain visible so Core-Monitor stays accessible."
            return
        }

        let previousValue = isEnabled(kind)
        guard previousValue != enabled else { return }

        assign(enabled, to: kind)
        defaults.set(enabled, forKey: kind.defaultsKey)
        lastWarning = nil
        NotificationCenter.default.post(name: .menuBarSettingsDidChange, object: kind)
    }

    func restoreDefaults() {
        applyPreset(Self.defaultPreset)
    }

    func applyPreset(_ preset: MenuBarVisibilityPreset) {
        applyPreset(preset, shouldNotify: true)
    }

    private func applyPreset(_ preset: MenuBarVisibilityPreset, shouldNotify: Bool) {
        let enabledItems = Set(preset.enabledItems)
        for kind in MenuBarItemKind.allCases {
            let enabled = enabledItems.contains(kind)
            defaults.set(enabled, forKey: kind.defaultsKey)
            assign(enabled, to: kind)
        }
        lastWarning = nil
        if shouldNotify {
            NotificationCenter.default.post(name: .menuBarSettingsDidChange, object: nil)
        }
    }

    var enabledItemCount: Int {
        MenuBarItemKind.allCases.filter(isEnabled).count
    }

    var activePreset: MenuBarVisibilityPreset? {
        MenuBarVisibilityPreset.allCases.first { preset in
            MenuBarItemKind.allCases.allSatisfy { kind in
                isEnabled(kind) == preset.enabledItems.contains(kind)
            }
        }
    }

    private func assign(_ enabled: Bool, to kind: MenuBarItemKind) {
        switch kind {
        case .cpu:
            cpuEnabled = enabled
        case .fan:
            fanEnabled = enabled
        case .memory:
            memoryEnabled = enabled
        case .network:
            networkEnabled = enabled
        case .disk:
            diskEnabled = enabled
        case .temperature:
            temperatureEnabled = enabled
        }
    }

    private func ensureAccessibleConfiguration() {
        guard enabledItemCount == 0 else { return }
        applyPreset(Self.defaultPreset, shouldNotify: false)
        lastWarning = "Core Monitor restored the Balanced menu bar preset so the app stays reachable."
    }

    private static func boolValue(for kind: MenuBarItemKind, defaults: UserDefaults) -> Bool {
        if defaults.object(forKey: kind.defaultsKey) == nil {
            return defaultPreset.enabledItems.contains(kind)
        }
        return defaults.bool(forKey: kind.defaultsKey)
    }
}
