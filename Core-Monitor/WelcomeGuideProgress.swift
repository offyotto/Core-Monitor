import Foundation

enum WelcomeGuideProgress {
    static let hasSeenDefaultsKey = "com.coremonitor.hasSeenWelcomeGuide.v1"

    static func hasSeen(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: hasSeenDefaultsKey)
    }

    static func shouldAutoOpenDashboardOnLaunch(defaults: UserDefaults = .standard) -> Bool {
        hasSeen(in: defaults) == false
    }
}
