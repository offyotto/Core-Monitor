import XCTest
@testable import Core_Monitor

final class DashboardProcessSamplingPolicyTests: XCTestCase {
    func testBasicModeNeverRequestsDetailedSampling() {
        for selection in SidebarItem.allCases {
            XCTAssertFalse(
                DashboardProcessSamplingPolicy.requiresDetailedSampling(
                    isBasicMode: true,
                    selection: selection
                ),
                "\(selection.rawValue) should stay on background sampling in Basic Mode."
            )
        }
    }

    func testAlertsAndMemoryViewsRequestDetailedSampling() {
        XCTAssertTrue(
            DashboardProcessSamplingPolicy.requiresDetailedSampling(
                isBasicMode: false,
                selection: .alerts
            )
        )
        XCTAssertTrue(
            DashboardProcessSamplingPolicy.requiresDetailedSampling(
                isBasicMode: false,
                selection: .memory
            )
        )
    }

    func testNonProcessDashboardViewsStayOnBackgroundSampling() {
        let lowDetailSelections: [SidebarItem] = [
            .overview, .thermals, .fans, .battery, .system, .touchBar, .help, .about
        ]

        for selection in lowDetailSelections {
            XCTAssertFalse(
                DashboardProcessSamplingPolicy.requiresDetailedSampling(
                    isBasicMode: false,
                    selection: selection
                ),
                "\(selection.rawValue) should not force detailed process sampling."
            )
        }
    }
}
