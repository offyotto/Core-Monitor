import XCTest
@testable import Core_Monitor

final class DashboardProcessSamplingPolicyTests: XCTestCase {
    func testBasicModeDisablesDetailedSamplingForEverySurface() {
        for item in SidebarItem.allCases {
            XCTAssertFalse(
                DashboardProcessSamplingPolicy.shouldEnableDetailedSampling(
                    selection: item,
                    isBasicMode: true
                ),
                "Expected basic mode to keep detailed sampling off for \(item.rawValue)."
            )
        }
    }

    func testAlertsAndMemoryEnableDetailedSamplingInFullDashboard() {
        XCTAssertTrue(
            DashboardProcessSamplingPolicy.shouldEnableDetailedSampling(
                selection: .alerts,
                isBasicMode: false
            )
        )
        XCTAssertTrue(
            DashboardProcessSamplingPolicy.shouldEnableDetailedSampling(
                selection: .memory,
                isBasicMode: false
            )
        )
    }

    func testNonProcessSurfacesStayOnBackgroundSamplingInFullDashboard() {
        let backgroundItems: [SidebarItem] = [.overview, .thermals, .fans, .battery, .system, .touchBar, .help, .about]

        for item in backgroundItems {
            XCTAssertFalse(
                DashboardProcessSamplingPolicy.shouldEnableDetailedSampling(
                    selection: item,
                    isBasicMode: false
                ),
                "Expected \(item.rawValue) to stay on background process sampling."
            )
        }
    }
}
