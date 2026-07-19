import XCTest
@testable import Core_Monitor

final class DashboardProcessSamplingPolicyTests: XCTestCase {
    func testBasicModeNeverRequestsDetailedSampling() {
        for selection in MonitorSection.allCases {
            XCTAssertFalse(
                DashboardProcessSamplingPolicy.requiresDetailedSampling(
                    isBasicMode: true,
                    selection: selection
                ),
                "\(selection) should stay on background sampling in Basic Mode."
            )
        }
    }

    func testCPUAndMemoryViewsRequestDetailedSampling() {
        for selection in [MonitorSection.cpu, .memory] {
            XCTAssertTrue(
                DashboardProcessSamplingPolicy.requiresDetailedSampling(
                    isBasicMode: false,
                    selection: selection
                ),
                "\(selection) drives the process lists and needs detailed sampling."
            )
        }
    }

    func testNonProcessDashboardViewsStayOnBackgroundSampling() {
        let lowDetailSelections: [MonitorSection] = [
            .overview, .thermal, .cooling, .power, .network, .storage, .rescue
        ]

        for selection in lowDetailSelections {
            XCTAssertFalse(
                DashboardProcessSamplingPolicy.requiresDetailedSampling(
                    isBasicMode: false,
                    selection: selection
                ),
                "\(selection) should not force detailed process sampling."
            )
        }
    }
}
