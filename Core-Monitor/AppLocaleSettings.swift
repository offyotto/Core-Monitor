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
        ContentView(
            systemMonitor: systemMonitor,
            fanController: fanController,
            startupManager: startupManager
        )
        .environment(\.locale, AppLocaleStore.locale(forStoredIdentifier: localeOverrideIdentifier))
    }
}

struct LocalizationSettingsCard: View {
    @AppStorage(AppLocaleStore.localeOverrideKey) private var localeOverrideIdentifier = AppLocaleStore.systemLocaleValue

    private let quickPickIdentifiers = ["en", "ja", "ru", "zh-Hans", "zh-Hant", "de", "fr", "es"]

    private var availableLocales: [String] {
        AppLocaleStore.supportedLocaleIdentifiers
    }

    private var quickPicks: [String] {
        quickPickIdentifiers.filter { availableLocales.contains($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Language & Locale")
                            .font(.system(size: 18, weight: .bold))
                        Text("Switch the dashboard to any bundled localization without leaving the app.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(localeOverrideIdentifier == AppLocaleStore.systemLocaleValue ? "Following macOS" : localeOverrideIdentifier)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.bdAccent)
                        Text("\(availableLocales.count) bundled localizations")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(alignment: .center, spacing: 12) {
                    Label("Current language", systemImage: "globe")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer(minLength: 12)
                    Picker("Current language", selection: $localeOverrideIdentifier) {
                        Text("System Default").tag(AppLocaleStore.systemLocaleValue)
                        ForEach(availableLocales, id: \.self) { identifier in
                            Text(AppLocaleStore.optionLabel(for: identifier)).tag(identifier)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 420, alignment: .trailing)
                }

                if quickPicks.isEmpty == false {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Quick picks")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 8)], spacing: 8) {
                            ForEach(quickPicks, id: \.self) { identifier in
                                Button {
                                    localeOverrideIdentifier = identifier
                                } label: {
                                    quickPickLabel(for: identifier)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Text(AppLocaleStore.selectionSummary(for: localeOverrideIdentifier))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)

                Text("Translations are machine-generated and may not be perfect in every language or context.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                if localeOverrideIdentifier != AppLocaleStore.systemLocaleValue {
                    Button("Follow System Locale") {
                        localeOverrideIdentifier = AppLocaleStore.systemLocaleValue
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.bdAccent)
                }
            }
            .padding(18)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func quickPickLabel(for identifier: String) -> some View {
        let isSelected = localeOverrideIdentifier == identifier

        return HStack(spacing: 8) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 11, weight: .bold))
            Text(AppLocaleStore.englishDisplayName(for: identifier))
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.82))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(isSelected ? Color.bdSelected.opacity(0.34) : Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(isSelected ? Color.bdAccent.opacity(0.45) : Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}
