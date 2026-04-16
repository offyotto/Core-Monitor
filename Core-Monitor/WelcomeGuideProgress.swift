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
