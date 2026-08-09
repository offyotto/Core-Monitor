import XCTest
@testable import Core_Monitor

final class CoreMonitorShareKitTests: XCTestCase {
    func testCanonicalLinksPointAtTheOfficialHosts() {
        XCTAssertEqual(
            CoreMonitorShareKit.websiteURL.absoluteString,
            "https://offyotto.github.io/Core-Monitor/"
        )
        XCTAssertEqual(
            CoreMonitorShareKit.repositoryURL.absoluteString,
            "https://github.com/offyotto/Core-Monitor"
        )
        XCTAssertEqual(
            CoreMonitorShareKit.latestReleaseURL.absoluteString,
            "https://github.com/offyotto/Core-Monitor/releases/latest"
        )
    }

    func testLinksDoNotPointAtTheStagingFork() {
        for url in [
            CoreMonitorShareKit.websiteURL,
            CoreMonitorShareKit.repositoryURL,
            CoreMonitorShareKit.latestReleaseURL
        ] {
            XCTAssertFalse(url.absoluteString.contains("offyotto-sl3"))
        }
    }

    func testLatestReleaseLinkStaysUnderTheRepository() {
        XCTAssertTrue(
            CoreMonitorShareKit.latestReleaseURL.absoluteString
                .hasPrefix(CoreMonitorShareKit.repositoryURL.absoluteString)
        )
    }
}
