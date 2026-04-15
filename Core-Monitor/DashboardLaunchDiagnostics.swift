import Foundation

enum DashboardOpenSource: String, Codable, Equatable {
    case launch
    case menuBar
    case reopen
    case direct
}

struct DashboardLaunchDiagnosticsSnapshot: Codable, Equatable {
    let welcomeGuideSeen: Bool
    let autoOpenEligible: Bool
    let lastOpenRequestAt: Date?
    let lastOpenRequestSource: DashboardOpenSource?
    let lastVisibleAt: Date?
    let lastClosedAt: Date?
    let lastKnownActivationPolicy: String?

    var recordedVisibleWindowForLastRequest: Bool {
        guard let lastOpenRequestAt else { return false }
        guard let lastVisibleAt else { return false }
        return lastVisibleAt >= lastOpenRequestAt
    }
}

enum DashboardLaunchDiagnostics {
    private static let welcomeGuideSeenKey = "coremonitor.launchDiagnostics.welcomeGuideSeen"
    private static let autoOpenEligibleKey = "coremonitor.launchDiagnostics.autoOpenEligible"
    private static let lastOpenRequestAtKey = "coremonitor.launchDiagnostics.lastOpenRequestAt"
    private static let lastOpenRequestSourceKey = "coremonitor.launchDiagnostics.lastOpenRequestSource"
    private static let lastVisibleAtKey = "coremonitor.launchDiagnostics.lastVisibleAt"
    private static let lastClosedAtKey = "coremonitor.launchDiagnostics.lastClosedAt"
    private static let lastKnownActivationPolicyKey = "coremonitor.launchDiagnostics.lastKnownActivationPolicy"

    static func recordLaunchState(
        welcomeGuideSeen: Bool,
        autoOpenEligible: Bool,
        activationPolicyDescription: String?,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(welcomeGuideSeen, forKey: welcomeGuideSeenKey)
        defaults.set(autoOpenEligible, forKey: autoOpenEligibleKey)
        defaults.set(activationPolicyDescription, forKey: lastKnownActivationPolicyKey)
    }

    static func recordDashboardOpenRequested(
        source: DashboardOpenSource,
        activationPolicyDescription: String?,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(Date(), forKey: lastOpenRequestAtKey)
        defaults.set(source.rawValue, forKey: lastOpenRequestSourceKey)
        defaults.set(activationPolicyDescription, forKey: lastKnownActivationPolicyKey)
    }

    static func recordDashboardDidBecomeVisible(defaults: UserDefaults = .standard) {
        defaults.set(Date(), forKey: lastVisibleAtKey)
    }

    static func recordDashboardClosed(defaults: UserDefaults = .standard) {
        defaults.set(Date(), forKey: lastClosedAtKey)
    }

    static func snapshot(defaults: UserDefaults = .standard) -> DashboardLaunchDiagnosticsSnapshot {
        DashboardLaunchDiagnosticsSnapshot(
            welcomeGuideSeen: defaults.bool(forKey: welcomeGuideSeenKey),
            autoOpenEligible: defaults.bool(forKey: autoOpenEligibleKey),
            lastOpenRequestAt: defaults.object(forKey: lastOpenRequestAtKey) as? Date,
            lastOpenRequestSource: (defaults.string(forKey: lastOpenRequestSourceKey)).flatMap(DashboardOpenSource.init(rawValue:)),
            lastVisibleAt: defaults.object(forKey: lastVisibleAtKey) as? Date,
            lastClosedAt: defaults.object(forKey: lastClosedAtKey) as? Date,
            lastKnownActivationPolicy: defaults.string(forKey: lastKnownActivationPolicyKey)
        )
    }
}
