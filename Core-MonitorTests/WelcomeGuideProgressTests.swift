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
