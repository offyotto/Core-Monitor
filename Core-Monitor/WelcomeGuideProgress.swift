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
        mutatePersistentDomain(defaults: defaults, bundleIdentifier: bundleIdentifier, resetKey: legacyWindowStateResetKey) { domain in
            for key in Array(domain.keys) where key.hasPrefix("NSWindow Frame SwiftUI.") || key == "NSWindow Frame CoreMonitorMainWindow" {
                domain.removeValue(forKey: key)
            }
        }
    }

    private static func purgeDeprecatedLaunchState(
        defaults: UserDefaults,
        bundleIdentifier: String?
    ) {
        guard let bundleIdentifier else {
            mutatePersistentDomain(defaults: defaults, bundleIdentifier: nil, resetKey: deprecatedLaunchStateResetKey) { domain in
                for key in Array(domain.keys) where deprecatedLaunchStateKeys.contains(key) || deprecatedLaunchStatePrefixes.contains(where: key.hasPrefix) {
                    domain.removeValue(forKey: key)
                }
            }
            return
        }

        let storedKeys = persistedKeys(defaults: defaults, bundleIdentifier: bundleIdentifier)
        let hasDeprecatedLaunchState = storedKeys.contains { key in
            deprecatedLaunchStateKeys.contains(key) || deprecatedLaunchStatePrefixes.contains(where: key.hasPrefix)
        }

        guard hasDeprecatedLaunchState || defaults.bool(forKey: deprecatedLaunchStateResetKey) == false else {
            return
        }

        for key in storedKeys where deprecatedLaunchStateKeys.contains(key) || deprecatedLaunchStatePrefixes.contains(where: key.hasPrefix) {
            defaults.removeObject(forKey: key)
        }

        defaults.set(true, forKey: deprecatedLaunchStateResetKey)
    }

    private static func persistedKeys(
        defaults: UserDefaults,
        bundleIdentifier: String?
    ) -> [String] {
        if let bundleIdentifier,
           let domain = defaults.persistentDomain(forName: bundleIdentifier) {
            return Array(domain.keys)
        }

        return Array(defaults.dictionaryRepresentation().keys)
    }

    private static func mutatePersistentDomain(
        defaults: UserDefaults,
        bundleIdentifier: String?,
        resetKey: String,
        mutate: (inout [String: Any]) -> Void
    ) {
        guard let bundleIdentifier else {
            if defaults.bool(forKey: resetKey) {
                return
            }

            var domain = defaults.dictionaryRepresentation()
            mutate(&domain)
            for key in Set(defaults.dictionaryRepresentation().keys).subtracting(domain.keys) {
                defaults.removeObject(forKey: key)
            }
            for (key, value) in domain {
                defaults.set(value, forKey: key)
            }
            defaults.set(true, forKey: resetKey)
            return
        }

        var domain = defaults.persistentDomain(forName: bundleIdentifier) ?? [:]
        if (domain[resetKey] as? Bool) == true {
            return
        }

        mutate(&domain)
        domain[resetKey] = true
        defaults.setPersistentDomain(domain, forName: bundleIdentifier)
    }
}
