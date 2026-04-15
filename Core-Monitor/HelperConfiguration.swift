import Foundation

enum HelperConfiguration {
    private static let infoKey = "CoreMonitorPrivilegedHelperLabel"

    static var label: String {
        if let label = Bundle.main.object(forInfoDictionaryKey: infoKey) as? String,
           !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return label
        }

        if let privilegedExecutables = Bundle.main.object(forInfoDictionaryKey: "SMPrivilegedExecutables") as? [String: Any],
           let label = privilegedExecutables.keys.sorted().first,
           !label.isEmpty {
            return label
        }

        return "ventaphobia.smc-helper"
    }
}
