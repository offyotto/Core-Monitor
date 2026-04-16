import XCTest
@testable import Core_Monitor

final class CoreMonitorLaunchEnvironmentTests: XCTestCase {
    func testDuplicateLaunchHandlingEnabledForNormalAppRuns() {
        XCTAssertTrue(
            CoreMonitorLaunchEnvironment.shouldHandleDuplicateLaunch(
                environment: [:]
            )
        )
    }

    func testDuplicateLaunchHandlingDisabledForXCTestHostedRuns() {
        XCTAssertFalse(
            CoreMonitorLaunchEnvironment.shouldHandleDuplicateLaunch(
                environment: ["XCTestConfigurationFilePath": "/tmp/CoreMonitor.xctestconfiguration"]
            )
        )
    }
}
