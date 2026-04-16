import XCTest
@testable import Core_Monitor

final class DiskStatsRefreshPolicyTests: XCTestCase {
    func testRefreshesImmediatelyWhenNoPreviousSampleExists() {
        XCTAssertTrue(
            DiskStatsRefreshPolicy.shouldRefresh(
                lastUpdatedAt: nil,
                now: Date(timeIntervalSince1970: 100)
            )
        )
    }

    func testSkipsRefreshesInsideMinimumInterval() {
        XCTAssertFalse(
            DiskStatsRefreshPolicy.shouldRefresh(
                lastUpdatedAt: Date(timeIntervalSince1970: 100),
                now: Date(timeIntervalSince1970: 129)
            )
        )
    }

    func testRefreshesAgainOnceMinimumIntervalExpires() {
        XCTAssertTrue(
            DiskStatsRefreshPolicy.shouldRefresh(
                lastUpdatedAt: Date(timeIntervalSince1970: 100),
                now: Date(timeIntervalSince1970: 130)
            )
        )
    }
}
