import Carbon
import XCTest
@testable import Core_Monitor

final class DashboardShortcutConfigurationTests: XCTestCase {
    func testDashboardShortcutUsesOptionCommandM() {
        XCTAssertEqual(DashboardShortcutConfiguration.keyEquivalent, "m")
        XCTAssertEqual(DashboardShortcutConfiguration.displayLabel, "Option-Command-M")
        XCTAssertEqual(
            DashboardShortcutConfiguration.carbonModifiers(),
            UInt32(optionKey) | UInt32(cmdKey)
        )
    }
}
