import Foundation
import Combine

extension Notification.Name {
    static let menuBarSettingsDidChange = Notification.Name("CoreMonitor.MenuBarSettingsDidChange")
}

@MainActor
final class MenuBarSettings: ObservableObject {
    static let shared = MenuBarSettings()

    @Published private(set) var cpuEnabled: Bool
    @Published private(set) var memoryEnabled: Bool
    @Published private(set) var diskEnabled: Bool
    @Published private(set) var temperatureEnabled: Bool
    @Published private(set) var lastWarning: String?

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.cpuEnabled = Self.boolValue(for: .cpu, defaults: defaults)
        self.memoryEnabled = Self.boolValue(for: .memory, defaults: defaults)
        self.diskEnabled = Self.boolValue(for: .disk, defaults: defaults)
        self.temperatureEnabled = Self.boolValue(for: .temperature, defaults: defaults)
    }

    func isEnabled(_ kind: MenuBarItemKind) -> Bool {
        switch kind {
        case .cpu:
            return cpuEnabled
        case .memory:
            return memoryEnabled
        case .disk:
            return diskEnabled
        case .temperature:
            return temperatureEnabled
        }
    }

    func setEnabled(_ enabled: Bool, for kind: MenuBarItemKind) {
        if enabled == false, enabledItemCount <= 1, isEnabled(kind) {
            lastWarning = "At least one menu bar item must remain visible so Core Monitor stays accessible."
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
        for kind in MenuBarItemKind.allCases {
            defaults.set(true, forKey: kind.defaultsKey)
            assign(true, to: kind)
        }
        lastWarning = nil
        NotificationCenter.default.post(name: .menuBarSettingsDidChange, object: nil)
    }

    private var enabledItemCount: Int {
        MenuBarItemKind.allCases.filter(isEnabled).count
    }

    private func assign(_ enabled: Bool, to kind: MenuBarItemKind) {
        switch kind {
        case .cpu:
            cpuEnabled = enabled
        case .memory:
            memoryEnabled = enabled
        case .disk:
            diskEnabled = enabled
        case .temperature:
            temperatureEnabled = enabled
        }
    }

    private static func boolValue(for kind: MenuBarItemKind, defaults: UserDefaults) -> Bool {
        if defaults.object(forKey: kind.defaultsKey) == nil {
            return true
        }
        return defaults.bool(forKey: kind.defaultsKey)
    }
}
