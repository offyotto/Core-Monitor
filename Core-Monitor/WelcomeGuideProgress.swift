import Foundation

enum CoreMonitorLaunchPresentation: Equatable {
    case dashboard
    case menuBarOnly

    var shouldAutoOpenDashboard: Bool {
        self == .dashboard
    }
}

enum WelcomeGuideProgress {
    static let hasSeenDefaultsKey = "com.coremonitor.hasSeenWelcomeGuide.v1"

    static func hasSeen(in defaults: UserDefaults = .standard) -> Bool {
        return (defaults.object(forKey: hasSeenDefaultsKey) as? Bool) ?? false
    }

    static func launchPresentation(defaults: UserDefaults = .standard) -> CoreMonitorLaunchPresentation {
        hasSeen(in: defaults) ? .menuBarOnly : .dashboard
    }

    static func shouldAutoOpenDashboardOnLaunch(defaults: UserDefaults = .standard) -> Bool {
        launchPresentation(defaults: defaults).shouldAutoOpenDashboard
    }
}

enum CoreMonitorDefaultsMaintenance {
    static let legacyWindowStateResetKey = "coremonitor.didResetLegacySwiftUIWindowFrames.v1"
    static let deprecatedLaunchStateResetKey = "coremonitor.didPurgeDeprecatedLaunchState.v1"

    private static let deprecatedLaunchStatePrefixes = [
        "coremonitor.launchDiagnostics."
    ]

    private static let deprecatedLaunchStateKeys = [
        "coremonitor.didShowFirstLaunchDashboard"
    ]

    static func purgeDeprecatedState(
        defaults: UserDefaults = .standard,
        bundleIdentifier: String? = Bundle.main.bundleIdentifier
    ) {
        purgeLegacyWindowFrames(defaults: defaults, bundleIdentifier: bundleIdentifier)
        purgeDeprecatedLaunchState(defaults: defaults, bundleIdentifier: bundleIdentifier)
    }

    private static func purgeLegacyWindowFrames(
        defaults: UserDefaults,
        bundleIdentifier: String?
    ) {
        guard defaults.bool(forKey: legacyWindowStateResetKey) == false else { return }

        for key in persistedKeys(defaults: defaults, bundleIdentifier: bundleIdentifier) {
            if key.hasPrefix("NSWindow Frame SwiftUI.") || key == "NSWindow Frame CoreMonitorMainWindow" {
                defaults.removeObject(forKey: key)
            }
        }

        defaults.set(true, forKey: legacyWindowStateResetKey)
    }

    private static func purgeDeprecatedLaunchState(
        defaults: UserDefaults,
        bundleIdentifier: String?
    ) {
        guard defaults.bool(forKey: deprecatedLaunchStateResetKey) == false else { return }

        for key in persistedKeys(defaults: defaults, bundleIdentifier: bundleIdentifier) {
            if deprecatedLaunchStateKeys.contains(key) || deprecatedLaunchStatePrefixes.contains(where: key.hasPrefix) {
                defaults.removeObject(forKey: key)
            }
        }

        defaults.set(true, forKey: deprecatedLaunchStateResetKey)
    }

    private static func persistedKeys(
        defaults: UserDefaults,
        bundleIdentifier: String?
    ) -> [String] {
        guard let bundleIdentifier else { return [] }
        return defaults.persistentDomain(forName: bundleIdentifier).map { Array($0.keys) } ?? []
    }
}
