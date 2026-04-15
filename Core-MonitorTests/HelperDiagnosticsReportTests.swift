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
            dashboardLaunch: makeDashboardLaunchSnapshot(),
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
            dashboardLaunch: makeDashboardLaunchSnapshot(),
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
            dashboardLaunch: makeDashboardLaunchSnapshot(),
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

    func testMakeReportFlagsMissingVisibleDashboardForAutoOpenLaunch() {
        let requestAt = Date(timeIntervalSince1970: 4_000)
        let context = HelperDiagnosticsContext(
            generatedAt: Date(timeIntervalSince1970: 4_100),
            appBundleIdentifier: "CoreTools.Core-Monitor",
            appVersion: "1.4.1",
            appBuild: "1410",
            macOSVersion: "macOS 15.5",
            hostModelIdentifier: "Mac16,7",
            chipName: "Apple M4 Pro",
            helperLabel: "ventaphobia.smc-helper",
            bundledHelperPath: "/Applications/Core-Monitor.app/Contents/Library/LaunchServices/ventaphobia.smc-helper",
            bundledHelperExists: true,
            installedHelperPath: "/Library/PrivilegedHelperTools/ventaphobia.smc-helper",
            installedHelperExists: true,
            connectionState: .reachable,
            helperStatusMessage: nil,
            launchAtLoginEnabled: false,
            launchAtLoginError: nil,
            enabledMenuBarItemCount: 3,
            menuBarPresetTitle: "Balanced",
            dashboardLaunch: DashboardLaunchDiagnosticsSnapshot(
                welcomeGuideSeen: false,
                autoOpenEligible: true,
                lastOpenRequestAt: requestAt,
                lastOpenRequestSource: .launch,
                lastVisibleAt: nil,
                lastClosedAt: nil,
                lastKnownActivationPolicy: "accessory"
            ),
            signingInfo: HelperDiagnosticsSigningInfo(
                signedIdentifier: "CoreTools.Core-Monitor",
                teamIdentifier: "TEAM1234",
                isAdHocOrUnsigned: false,
                issue: nil
            )
        )

        let report = HelperDiagnosticsExporter.makeReport(from: context)

        XCTAssertEqual(report.dashboardLaunch.lastOpenRequestSource, .launch)
        XCTAssertFalse(report.dashboardLaunch.recordedVisibleWindowForLastRequest)
        XCTAssertTrue(report.recommendedActions.contains("Core Monitor expected to open the onboarding dashboard on launch but did not record a visible dashboard window. Reopen it from the menu bar, then attach this report if the issue repeats."))
    }

    private func makeDashboardLaunchSnapshot() -> DashboardLaunchDiagnosticsSnapshot {
        DashboardLaunchDiagnosticsSnapshot(
            welcomeGuideSeen: true,
            autoOpenEligible: false,
            lastOpenRequestAt: nil,
            lastOpenRequestSource: nil,
            lastVisibleAt: nil,
            lastClosedAt: nil,
            lastKnownActivationPolicy: "accessory"
        )
    }
}
