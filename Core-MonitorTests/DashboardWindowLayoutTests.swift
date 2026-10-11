import AppKit
import XCTest
@testable import Core_Monitor

final class DashboardWindowLayoutTests: XCTestCase {
    func testTargetContentSizeUsesLargerLaptopFriendlyDefault() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1512, height: 945)

        let size = DashboardWindowLayout.targetContentSize(for: visibleFrame)

        XCTAssertEqual(size.width, 1080, accuracy: 0.001)
        XCTAssertEqual(size.height, 720, accuracy: 0.001)
    }

    func testTargetContentSizeRespectsSmallDisplayBounds() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1024, height: 700)

        let size = DashboardWindowLayout.targetContentSize(for: visibleFrame)

        XCTAssertEqual(size.width, 944, accuracy: 0.001)
        XCTAssertEqual(size.height, 640, accuracy: 0.001)
    }

    func testShouldResetFrameWhenWindowIsTooShortForDashboard() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1512, height: 945)
        let frame = CGRect(x: 80, y: 80, width: 948, height: 560)

        XCTAssertTrue(DashboardWindowLayout.shouldResetFrame(windowFrame: frame, visibleFrame: visibleFrame))
    }

    func testTargetContentSizeFitsBelowThePreferredMinimum() {
        let size = DashboardWindowLayout.targetContentSize(for: CGRect(x: 0, y: 0, width: 800, height: 600))
        XCTAssertEqual(size.width, 720)
        XCTAssertEqual(size.height, 570)
    }

    func testRestoredFrameOutsideCurrentDisplayIsReset() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1512, height: 945)
        let disconnectedDisplayFrame = CGRect(x: 2000, y: 100, width: 1080, height: 720)
        XCTAssertTrue(DashboardWindowLayout.shouldResetFrame(windowFrame: disconnectedDisplayFrame, visibleFrame: visibleFrame))
    }

    func testShouldNotResetFrameWhenWindowFitsComfortably() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1512, height: 945)
        let frame = CGRect(x: 80, y: 80, width: 1080, height: 720)

        XCTAssertFalse(DashboardWindowLayout.shouldResetFrame(windowFrame: frame, visibleFrame: visibleFrame))
    }
}
