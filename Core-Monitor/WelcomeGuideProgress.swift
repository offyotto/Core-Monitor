import Foundation

enum WelcomeGuideProgress {
    static let hasSeenDefaultsKey = "com.coremonitor.hasSeenWelcomeGuide.v1"

    static func hasSeen(in defaults: UserDefaults = .standard) -> Bool {
        if defaults === UserDefaults.standard,
           let bundleIdentifier = Bundle.main.bundleIdentifier {
            return (defaults.persistentDomain(forName: bundleIdentifier)?[hasSeenDefaultsKey] as? Bool) ?? false
        }

        return (defaults.object(forKey: hasSeenDefaultsKey) as? Bool) ?? false
    }

    static func shouldAutoOpenDashboardOnLaunch(defaults: UserDefaults = .standard) -> Bool {
        hasSeen(in: defaults) == false
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

        let persistedKeys = persistedKeys(defaults: defaults, bundleIdentifier: bundleIdentifier)
        let hasDeprecatedLaunchState = persistedKeys.contains { key in
            deprecatedLaunchStateKeys.contains(key) || deprecatedLaunchStatePrefixes.contains(where: key.hasPrefix)
        }

        guard hasDeprecatedLaunchState || defaults.bool(forKey: deprecatedLaunchStateResetKey) == false else {
            return
        }

        for key in persistedKeys where deprecatedLaunchStateKeys.contains(key) || deprecatedLaunchStatePrefixes.contains(where: key.hasPrefix) {
            defaults.removeObject(forKey: key)
        }

        defaults.set(true, forKey: deprecatedLaunchStateResetKey)
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
