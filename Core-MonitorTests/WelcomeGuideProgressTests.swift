import XCTest
@testable import Core_Monitor

final class WelcomeGuideProgressTests: XCTestCase {
    func testShouldAutoOpenDashboardOnLaunchWhenGuideHasNotBeenSeen() {
        let defaults = makeDefaults()

        XCTAssertTrue(WelcomeGuideProgress.shouldAutoOpenDashboardOnLaunch(defaults: defaults))
        XCTAssertFalse(WelcomeGuideProgress.hasSeen(in: defaults))
    }

    func testShouldNotAutoOpenDashboardAfterGuideHasBeenSeen() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: WelcomeGuideProgress.hasSeenDefaultsKey)

        XCTAssertFalse(WelcomeGuideProgress.shouldAutoOpenDashboardOnLaunch(defaults: defaults))
        XCTAssertTrue(WelcomeGuideProgress.hasSeen(in: defaults))
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "WelcomeGuideProgressTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}

@MainActor
final class DashboardNavigationRouterTests: XCTestCase {
    func testConsumeReturnsRequestedSelectionAndClearsRoute() throws {
        let router = DashboardNavigationRouter()

        router.open(.alerts)

        let route = try XCTUnwrap(router.route)
        XCTAssertEqual(router.consume(route), .alerts)
        XCTAssertNil(router.route)
    }

    func testConsumeRejectsStaleRouteAfterNewRequest() throws {
        let router = DashboardNavigationRouter()

        router.open(.alerts)
        let staleRoute = try XCTUnwrap(router.route)

        router.open(.memory)
        let currentRoute = try XCTUnwrap(router.route)

        XCTAssertNil(router.consume(staleRoute))
        XCTAssertEqual(router.consume(currentRoute), .memory)
        XCTAssertNil(router.route)
    }
}
