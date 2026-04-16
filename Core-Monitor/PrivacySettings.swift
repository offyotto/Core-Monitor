import Foundation
import Combine

final class PrivacySettings: ObservableObject {
    static let shared = PrivacySettings()

    private enum Key {
        static let processInsightsEnabled = "coremonitor.privacy.processInsightsEnabled"
    }

    @Published var processInsightsEnabled: Bool {
        didSet {
            defaults.set(processInsightsEnabled, forKey: Key.processInsightsEnabled)
        }
    }

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if defaults.object(forKey: Key.processInsightsEnabled) == nil {
            self.processInsightsEnabled = false
            defaults.set(false, forKey: Key.processInsightsEnabled)
        } else {
            self.processInsightsEnabled = defaults.bool(forKey: Key.processInsightsEnabled)
        }
    }
}
