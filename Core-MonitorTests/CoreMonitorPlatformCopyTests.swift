import XCTest
@testable import Core_Monitor

final class CoreMonitorPlatformCopyTests: XCTestCase {
    func testAppleSiliconCopyUsesArchitectureSpecificLanguage() {
        XCTAssertEqual(
            CoreMonitorPlatformCopy.welcomeIntroSubheadline(isAppleSilicon: true),
            "Your M-series Mac, fully visible."
        )
        XCTAssertTrue(
            CoreMonitorPlatformCopy.welcomeIntroBody(isAppleSilicon: true).contains("Apple Silicon Mac")
        )
        XCTAssertEqual(
            CoreMonitorPlatformCopy.thermalMetricsBullet(isAppleSilicon: true),
            "P-core and E-core usage, plus CPU temperature"
        )
        XCTAssertEqual(
            CoreMonitorPlatformCopy.thermalStatusDetail(isAppleSilicon: true),
            "macOS thermal pressure on Apple Silicon."
        )
    }

    func testIntelCopyStaysArchitectureNeutral() {
        XCTAssertEqual(
            CoreMonitorPlatformCopy.welcomeIntroSubheadline(isAppleSilicon: false),
            "Your Mac, fully visible."
        )
        XCTAssertFalse(
            CoreMonitorPlatformCopy.welcomeIntroBody(isAppleSilicon: false).contains("Apple Silicon")
        )
        XCTAssertEqual(
            CoreMonitorPlatformCopy.thermalMetricsBullet(isAppleSilicon: false),
            "CPU usage and temperature"
        )
        XCTAssertEqual(
            CoreMonitorPlatformCopy.thermalStatusDetail(isAppleSilicon: false),
            "macOS thermal pressure reported by the system."
        )
    }
}
