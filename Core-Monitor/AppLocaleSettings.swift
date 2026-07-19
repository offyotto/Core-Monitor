import Foundation
import SwiftUI

enum AppLocaleStore {
    nonisolated static let localeOverrideKey = "coremonitor.localeOverride"
    nonisolated static let systemLocaleValue = "__system__"

    private nonisolated static let englishReferenceLocale = Locale(identifier: "en")

    nonisolated static var currentLocale: Locale {
        locale(forStoredIdentifier: UserDefaults.standard.string(forKey: localeOverrideKey) ?? systemLocaleValue)
    }

    nonisolated static func locale(forStoredIdentifier storedIdentifier: String) -> Locale {
        guard storedIdentifier.isEmpty == false, storedIdentifier != systemLocaleValue else {
            return .autoupdatingCurrent
        }
        return Locale(identifier: storedIdentifier)
    }

    nonisolated static var supportedLocaleIdentifiers: [String] {
        Bundle.main.localizations
            .filter { $0 != "Base" }
            .sorted { lhs, rhs in
                if lhs == "en" { return true }
                if rhs == "en" { return false }

                let lhsName = englishDisplayName(for: lhs)
                let rhsName = englishDisplayName(for: rhs)
                let comparison = lhsName.localizedCaseInsensitiveCompare(rhsName)
                if comparison == .orderedSame {
                    return lhs < rhs
                }
                return comparison == .orderedAscending
            }
    }

    nonisolated static func optionLabel(for identifier: String) -> String {
        let english = englishDisplayName(for: identifier)
        let native = nativeDisplayName(for: identifier)

        if native.localizedCaseInsensitiveCompare(english) == .orderedSame {
            return "\(english) (\(identifier))"
        }
        return "\(english) • \(native)"
    }

    nonisolated static func selectionSummary(for storedIdentifier: String) -> String {
        guard storedIdentifier != systemLocaleValue else {
            let currentIdentifier = Locale.autoupdatingCurrent.identifier
            return "System Default • \(englishDisplayName(for: currentIdentifier))"
        }
        return optionLabel(for: storedIdentifier)
    }

    nonisolated static func englishDisplayName(for identifier: String) -> String {
        displayName(for: identifier, locale: englishReferenceLocale)
    }

    nonisolated static func nativeDisplayName(for identifier: String) -> String {
        displayName(for: identifier, locale: Locale(identifier: identifier))
    }

    private nonisolated static func displayName(for identifier: String, locale: Locale) -> String {
        locale.localizedString(forIdentifier: identifier)
            ?? locale.localizedString(forLanguageCode: identifier)
            ?? identifier
    }
}

struct DashboardRootView: View {
    @AppStorage(AppLocaleStore.localeOverrideKey) private var localeOverrideIdentifier = AppLocaleStore.systemLocaleValue

    let systemMonitor: SystemMonitor
    let fanController: FanController
    let startupManager: StartupManager

    var body: some View {
        MainWindowView(
            systemMonitor: systemMonitor,
            fanController: fanController,
            startupManager: startupManager
        )
        .environment(\.locale, AppLocaleStore.locale(forStoredIdentifier: localeOverrideIdentifier))
    }
}
