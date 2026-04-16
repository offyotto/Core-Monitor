import XCTest
@testable import Core_Monitor

final class LaunchAtLoginStatusSummaryTests: XCTestCase {
    func testEnabledStatusUsesHealthySummaryByDefault() {
        let summary = LaunchAtLoginStatusSummary.make(status: .enabled, errorMessage: nil)

        XCTAssertEqual(summary.badge, "Enabled")
        XCTAssertEqual(summary.tone, .positive)
        XCTAssertNil(summary.action)
        XCTAssertNil(summary.actionTitle)
    }

    func testDisabledStatusOffersEnableAction() {
        let summary = LaunchAtLoginStatusSummary.make(status: .disabled, errorMessage: nil)

        XCTAssertEqual(summary.badge, "Optional")
        XCTAssertEqual(summary.tone, .neutral)
        XCTAssertEqual(summary.action, .enable)
        XCTAssertEqual(summary.actionTitle, "Enable")
    }

    func testRequiresApprovalOpensLoginItemsSettings() {
        let summary = LaunchAtLoginStatusSummary.make(
            status: .requiresApproval,
            errorMessage: "Launch at Login needs approval in System Settings > General > Login Items."
        )

        XCTAssertEqual(summary.badge, "Approval Needed")
        XCTAssertEqual(summary.tone, .caution)
        XCTAssertEqual(summary.action, .openSystemSettings)
        XCTAssertEqual(summary.actionTitle, "Open Login Items")
    }

    func testPermissionErrorWhileDisabledKeepsSettingsActionAvailable() {
        let summary = LaunchAtLoginStatusSummary.make(
            status: .disabled,
            errorMessage: "Permission denied. Open System Settings > General > Login Items to allow Core-Monitor."
        )

        XCTAssertEqual(summary.badge, "Needs Attention")
        XCTAssertEqual(summary.tone, .caution)
        XCTAssertEqual(summary.action, .openSystemSettings)
        XCTAssertEqual(summary.actionTitle, "Open Login Items")
    }
}
