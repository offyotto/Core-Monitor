import XCTest
@testable import Core_Monitor

final class HelperDiagnosticsReportTests: XCTestCase {
    func testMakeReportExplainsMonitoringOnlyModeWhenHelperIsMissing() {
        let context = HelperDiagnosticsContext(
            generatedAt: Date(timeIntervalSince1970: 1_000),
            appBundleIdentifier: "CoreTools.Core-Monitor",
            appVersion: "1.4.1",
            appBuild: "1410",
            macOSVersion: "macOS 15.5",
            hostModelIdentifier: "Mac16,7",
            hostModelName: "MacBook Pro (16-inch, 2024, M4 Pro/Max)",
            chipName: "Apple M4 Pro",
            helperLabel: "ventaphobia.smc-helper",
            bundledHelperPath: "/Applications/Core-Monitor.app/Contents/Library/LaunchServices/ventaphobia.smc-helper",
            bundledHelperExists: true,
            installedHelperPath: "/Library/PrivilegedHelperTools/ventaphobia.smc-helper",
            installedHelperExists: false,
            connectionState: .missing,
            helperStatusMessage: nil,
            launchAtLoginEnabled: false,
            launchAtLoginError: nil,
            enabledMenuBarItemCount: 1,
            menuBarPresetTitle: "Balanced",
            signingInfo: HelperDiagnosticsSigningInfo(
                signedIdentifier: "CoreTools.Core-Monitor",
                teamIdentifier: "TEAM1234",
                isAdHocOrUnsigned: false,
                issue: nil
            )
        )

        let report = HelperDiagnosticsExporter.makeReport(from: context)

        XCTAssertEqual(report.summary, "Monitoring-only configuration. The privileged helper is not installed.")
        XCTAssertTrue(report.recommendedActions.contains("Monitoring already works without the helper. Install it only if you want manual or profile-based fan control."))
        XCTAssertEqual(report.helper.connectionState, .missing)
        XCTAssertEqual(report.app.hostModelName, "MacBook Pro (16-inch, 2024, M4 Pro/Max)")
        XCTAssertTrue(report.recommendedActions.contains("Keep at least one menu bar item enabled so Core Monitor stays reachable after launch."))
    }

    func testMakeReportPrioritizesSigningMismatchRecovery() {
        let context = HelperDiagnosticsContext(
            generatedAt: Date(timeIntervalSince1970: 2_000),
            appBundleIdentifier: "CoreTools.Core-Monitor",
            appVersion: "1.4.1",
            appBuild: "1410",
            macOSVersion: "macOS 15.5",
            hostModelIdentifier: "Mac16,7",
            hostModelName: "MacBook Pro (16-inch, 2024, M4 Pro/Max)",
            chipName: "Apple M4 Pro",
            helperLabel: "ventaphobia.smc-helper",
            bundledHelperPath: "/Applications/Core-Monitor.app/Contents/Library/LaunchServices/ventaphobia.smc-helper",
            bundledHelperExists: true,
            installedHelperPath: "/Library/PrivilegedHelperTools/ventaphobia.smc-helper",
            installedHelperExists: true,
            connectionState: .unreachable,
            helperStatusMessage: "The helper rejected this build.",
            launchAtLoginEnabled: true,
            launchAtLoginError: nil,
            enabledMenuBarItemCount: 3,
            menuBarPresetTitle: "Balanced",
            signingInfo: HelperDiagnosticsSigningInfo(
                signedIdentifier: "com.example.other",
                teamIdentifier: "TEAM1234",
                isAdHocOrUnsigned: false,
                issue: "App signature identifier com.example.other does not match bundle identifier CoreTools.Core-Monitor. Rebuild and reinstall the helper from the same signed app."
            )
        )

        let report = HelperDiagnosticsExporter.makeReport(from: context)

        XCTAssertEqual(report.summary, "Helper is installed, but this app could not establish a trusted connection to it.")
        XCTAssertEqual(report.recommendedActions.first, "App signature identifier com.example.other does not match bundle identifier CoreTools.Core-Monitor. Rebuild and reinstall the helper from the same signed app.")
        XCTAssertEqual(report.app.signing.issue, "App signature identifier com.example.other does not match bundle identifier CoreTools.Core-Monitor. Rebuild and reinstall the helper from the same signed app.")
    }

    func testMakeReportCarriesLoginApprovalGuidance() {
        let context = HelperDiagnosticsContext(
            generatedAt: Date(timeIntervalSince1970: 3_000),
            appBundleIdentifier: "CoreTools.Core-Monitor",
            appVersion: "1.4.1",
            appBuild: "1410",
            macOSVersion: "macOS 15.5",
            hostModelIdentifier: "Mac16,7",
            hostModelName: "MacBook Pro (16-inch, 2024, M4 Pro/Max)",
            chipName: "Apple M4 Pro",
            helperLabel: "ventaphobia.smc-helper",
            bundledHelperPath: "/Applications/Core-Monitor.app/Contents/Library/LaunchServices/ventaphobia.smc-helper",
            bundledHelperExists: true,
            installedHelperPath: "/Library/PrivilegedHelperTools/ventaphobia.smc-helper",
            installedHelperExists: true,
            connectionState: .reachable,
            helperStatusMessage: nil,
            launchAtLoginEnabled: false,
            launchAtLoginError: "Startup requires approval in System Settings → General → Login Items.",
            enabledMenuBarItemCount: 3,
            menuBarPresetTitle: "Balanced",
            signingInfo: HelperDiagnosticsSigningInfo(
                signedIdentifier: "CoreTools.Core-Monitor",
                teamIdentifier: "TEAM1234",
                isAdHocOrUnsigned: false,
                issue: nil
            )
        )

        let report = HelperDiagnosticsExporter.makeReport(from: context)

        XCTAssertTrue(report.recommendedActions.contains("Launch at login needs attention: Startup requires approval in System Settings → General → Login Items."))
        XCTAssertEqual(report.launchAtLogin.errorMessage, "Startup requires approval in System Settings → General → Login Items.")
    }

    func testHelperInstallAppearsOrphanedWhenFilesExistButLaunchdServiceIsMissing() {
        XCTAssertTrue(
            SMCHelperManager.helperInstallAppearsOrphaned(
                installedHelperExists: true,
                installedLaunchDaemonExists: true,
                launchctlExitStatus: 113
            )
        )
    }

    func testHelperInstallDoesNotAppearOrphanedWhenLaunchdServiceExists() {
        XCTAssertFalse(
            SMCHelperManager.helperInstallAppearsOrphaned(
                installedHelperExists: true,
                installedLaunchDaemonExists: true,
                launchctlExitStatus: 0
            )
        )
    }

    func testOrphanedHelperCleanupScriptTargetsInstalledHelperArtifacts() {
        let script = SMCHelperManager.orphanedHelperCleanupShellScript(label: "ventaphobia.smc-helper")

        XCTAssertTrue(script.contains("/bin/launchctl bootout 'system/ventaphobia.smc-helper'"))
        XCTAssertTrue(script.contains("/bin/rm -f '/Library/PrivilegedHelperTools/ventaphobia.smc-helper' '/Library/LaunchDaemons/ventaphobia.smc-helper.plist'"))
    }
}
