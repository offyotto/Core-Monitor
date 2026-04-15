import AppKit
import Foundation
import Security
import UniformTypeIdentifiers

enum HelperDiagnosticsConnectionState: String, Codable, Equatable {
    case missing
    case unknown
    case checking
    case reachable
    case unreachable
}

struct HelperDiagnosticsSigningInfo: Codable, Equatable {
    let signedIdentifier: String?
    let teamIdentifier: String?
    let isAdHocOrUnsigned: Bool
    let issue: String?
}

struct HelperDiagnosticsContext: Equatable {
    let generatedAt: Date
    let appBundleIdentifier: String
    let appVersion: String
    let appBuild: String
    let macOSVersion: String
    let hostModelIdentifier: String
    let chipName: String
    let helperLabel: String
    let bundledHelperPath: String
    let bundledHelperExists: Bool
    let installedHelperPath: String
    let installedHelperExists: Bool
    let connectionState: HelperDiagnosticsConnectionState
    let helperStatusMessage: String?
    let launchAtLoginEnabled: Bool
    let launchAtLoginError: String?
    let enabledMenuBarItemCount: Int
    let menuBarPresetTitle: String
    let dashboardLaunch: DashboardLaunchDiagnosticsSnapshot
    let signingInfo: HelperDiagnosticsSigningInfo
}

struct HelperDiagnosticsReport: Codable, Equatable {
    struct AppDetails: Codable, Equatable {
        let bundleIdentifier: String
        let version: String
        let build: String
        let macOSVersion: String
        let hostModelIdentifier: String
        let chipName: String
        let signing: HelperDiagnosticsSigningInfo
    }

    struct HelperDetails: Codable, Equatable {
        let label: String
        let monitoringWorksWithoutHelper: Bool
        let fanControlRequiresHelper: Bool
        let bundledHelperPath: String
        let bundledHelperExists: Bool
        let installedHelperPath: String
        let installedHelperExists: Bool
        let connectionState: HelperDiagnosticsConnectionState
        let statusMessage: String?
    }

    struct LaunchAtLoginDetails: Codable, Equatable {
        let enabled: Bool
        let errorMessage: String?
    }

    struct MenuBarDetails: Codable, Equatable {
        let enabledItemCount: Int
        let presetTitle: String
    }

    struct DashboardLaunchDetails: Codable, Equatable {
        let welcomeGuideSeen: Bool
        let autoOpenEligible: Bool
        let lastOpenRequestAt: Date?
        let lastOpenRequestSource: DashboardOpenSource?
        let lastVisibleAt: Date?
        let lastClosedAt: Date?
        let lastKnownActivationPolicy: String?
        let recordedVisibleWindowForLastRequest: Bool
    }

    let generatedAt: Date
    let summary: String
    let recommendedActions: [String]
    let app: AppDetails
    let helper: HelperDetails
    let launchAtLogin: LaunchAtLoginDetails
    let menuBar: MenuBarDetails
    let dashboardLaunch: DashboardLaunchDetails
}

enum HelperDiagnosticsExporter {
    @MainActor
    static func exportReport(
        helperManager: SMCHelperManager,
        startupManager: StartupManager,
        menuBarSettings: MenuBarSettings
    ) throws -> URL? {
        let context = makeContext(
            helperManager: helperManager,
            startupManager: startupManager,
            menuBarSettings: menuBarSettings
        )
        let report = makeReport(from: context)

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = defaultFileName(for: context.generatedAt)
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(report)
        try data.write(to: url, options: .atomic)
        NSWorkspace.shared.activateFileViewerSelecting([url])
        return url
    }

    @MainActor
    static func makeContext(
        helperManager: SMCHelperManager,
        startupManager: StartupManager,
        menuBarSettings: MenuBarSettings
    ) -> HelperDiagnosticsContext {
        let helperLabel = HelperConfiguration.label
        let bundledHelperURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/LaunchServices/\(helperLabel)")
        let installedHelperPath = "/Library/PrivilegedHelperTools/\(helperLabel)"
        let fileManager = FileManager.default

        return HelperDiagnosticsContext(
            generatedAt: Date(),
            appBundleIdentifier: Bundle.main.bundleIdentifier ?? "unknown",
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            appBuild: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            hostModelIdentifier: SystemMonitor.hostModelIdentifier(),
            chipName: SystemMonitor.chipName(),
            helperLabel: helperLabel,
            bundledHelperPath: bundledHelperURL.path,
            bundledHelperExists: fileManager.fileExists(atPath: bundledHelperURL.path),
            installedHelperPath: installedHelperPath,
            installedHelperExists: fileManager.fileExists(atPath: installedHelperPath),
            connectionState: map(helperManager.connectionState),
            helperStatusMessage: helperManager.statusMessage,
            launchAtLoginEnabled: startupManager.isEnabled,
            launchAtLoginError: startupManager.errorMessage,
            enabledMenuBarItemCount: menuBarSettings.enabledItemCount,
            menuBarPresetTitle: menuBarSettings.activePreset?.title ?? "Custom",
            dashboardLaunch: DashboardLaunchDiagnostics.snapshot(),
            signingInfo: currentSigningInfo()
        )
    }

    static func makeReport(from context: HelperDiagnosticsContext) -> HelperDiagnosticsReport {
        HelperDiagnosticsReport(
            generatedAt: context.generatedAt,
            summary: summary(for: context),
            recommendedActions: recommendedActions(for: context),
            app: .init(
                bundleIdentifier: context.appBundleIdentifier,
                version: context.appVersion,
                build: context.appBuild,
                macOSVersion: context.macOSVersion,
                hostModelIdentifier: context.hostModelIdentifier,
                chipName: context.chipName,
                signing: context.signingInfo
            ),
            helper: .init(
                label: context.helperLabel,
                monitoringWorksWithoutHelper: true,
                fanControlRequiresHelper: true,
                bundledHelperPath: context.bundledHelperPath,
                bundledHelperExists: context.bundledHelperExists,
                installedHelperPath: context.installedHelperPath,
                installedHelperExists: context.installedHelperExists,
                connectionState: context.connectionState,
                statusMessage: context.helperStatusMessage
            ),
            launchAtLogin: .init(
                enabled: context.launchAtLoginEnabled,
                errorMessage: context.launchAtLoginError
            ),
            menuBar: .init(
                enabledItemCount: context.enabledMenuBarItemCount,
                presetTitle: context.menuBarPresetTitle
            ),
            dashboardLaunch: .init(
                welcomeGuideSeen: context.dashboardLaunch.welcomeGuideSeen,
                autoOpenEligible: context.dashboardLaunch.autoOpenEligible,
                lastOpenRequestAt: context.dashboardLaunch.lastOpenRequestAt,
                lastOpenRequestSource: context.dashboardLaunch.lastOpenRequestSource,
                lastVisibleAt: context.dashboardLaunch.lastVisibleAt,
                lastClosedAt: context.dashboardLaunch.lastClosedAt,
                lastKnownActivationPolicy: context.dashboardLaunch.lastKnownActivationPolicy,
                recordedVisibleWindowForLastRequest: context.dashboardLaunch.recordedVisibleWindowForLastRequest
            )
        )
    }

    private static func summary(for context: HelperDiagnosticsContext) -> String {
        switch context.connectionState {
        case .reachable:
            return "Helper reachable. Core Monitor should be able to perform privileged fan writes on supported Macs."
        case .checking, .unknown:
            return "Helper exists, but Core Monitor has not completed a trusted health probe yet."
        case .unreachable:
            return "Helper is installed, but this app could not establish a trusted connection to it."
        case .missing:
            return "Monitoring-only configuration. The privileged helper is not installed."
        }
    }

    private static func recommendedActions(for context: HelperDiagnosticsContext) -> [String] {
        var actions: [String] = []

        switch context.connectionState {
        case .missing:
            actions.append("Monitoring already works without the helper. Install it only if you want manual or profile-based fan control.")
        case .unknown, .checking:
            actions.append("Use Recheck after the helper finishes installing or after relaunching Core Monitor.")
        case .unreachable:
            if let issue = context.signingInfo.issue, issue.isEmpty == false {
                actions.append(issue)
            } else {
                actions.append("Reinstall the privileged helper from this exact app build, then recheck connectivity before trusting fan control.")
            }
        case .reachable:
            break
        }

        if context.bundledHelperExists == false {
            actions.append("This app bundle does not contain the embedded helper payload expected for fan control. Rebuild or re-download the app bundle before attempting helper installation.")
        }

        if let launchAtLoginError = context.launchAtLoginError, launchAtLoginError.isEmpty == false {
            actions.append("Launch at login needs attention: \(launchAtLoginError)")
        }

        if context.enabledMenuBarItemCount <= 1 {
            actions.append("Keep at least one menu bar item enabled so Core Monitor stays reachable after launch.")
        }

        if context.dashboardLaunch.autoOpenEligible,
           context.dashboardLaunch.lastOpenRequestAt != nil,
           context.dashboardLaunch.recordedVisibleWindowForLastRequest == false {
            actions.append("Core Monitor expected to open the onboarding dashboard on launch but did not record a visible dashboard window. Reopen it from the menu bar, then attach this report if the issue repeats.")
        }

        if actions.isEmpty {
            actions.append("Helper connectivity looks healthy. If fan writes still fail, export a fresh report right after reproducing the issue.")
        }

        return actions
    }

    private static func defaultFileName(for date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let timestamp = formatter.string(from: date)
            .replacingOccurrences(of: ":", with: "-")
        return "Core-Monitor-Helper-Diagnostics-\(timestamp).json"
    }

    private static func map(_ state: SMCHelperManager.ConnectionState) -> HelperDiagnosticsConnectionState {
        switch state {
        case .missing:
            return .missing
        case .unknown:
            return .unknown
        case .checking:
            return .checking
        case .reachable:
            return .reachable
        case .unreachable:
            return .unreachable
        }
    }

    private static func currentSigningInfo() -> HelperDiagnosticsSigningInfo {
        var staticCode: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(Bundle.main.bundleURL as CFURL, SecCSFlags(), &staticCode)
        guard createStatus == errSecSuccess, let staticCode else {
            return HelperDiagnosticsSigningInfo(
                signedIdentifier: nil,
                teamIdentifier: nil,
                isAdHocOrUnsigned: true,
                issue: nil
            )
        }

        var signingInfoRef: CFDictionary?
        let copyStatus = SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &signingInfoRef
        )
        guard copyStatus == errSecSuccess,
              let signingInfo = signingInfoRef as? [String: Any] else {
            return HelperDiagnosticsSigningInfo(
                signedIdentifier: nil,
                teamIdentifier: nil,
                isAdHocOrUnsigned: true,
                issue: nil
            )
        }

        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "unknown"
        let signedIdentifier = signingInfo[kSecCodeInfoIdentifier as String] as? String
        let teamIdentifier = signingInfo[kSecCodeInfoTeamIdentifier as String] as? String

        if teamIdentifier?.isEmpty != false {
            return HelperDiagnosticsSigningInfo(
                signedIdentifier: signedIdentifier,
                teamIdentifier: teamIdentifier,
                isAdHocOrUnsigned: true,
                issue: "This Core Monitor build is ad-hoc signed, so an installed privileged helper will reject it. Run the signed app bundle or reinstall the helper from a matching signed build."
            )
        }

        if let signedIdentifier, signedIdentifier != bundleIdentifier {
            return HelperDiagnosticsSigningInfo(
                signedIdentifier: signedIdentifier,
                teamIdentifier: teamIdentifier,
                isAdHocOrUnsigned: false,
                issue: "App signature identifier \(signedIdentifier) does not match bundle identifier \(bundleIdentifier). Rebuild and reinstall the helper from the same signed app."
            )
        }

        return HelperDiagnosticsSigningInfo(
            signedIdentifier: signedIdentifier,
            teamIdentifier: teamIdentifier,
            isAdHocOrUnsigned: false,
            issue: nil
        )
    }
}
