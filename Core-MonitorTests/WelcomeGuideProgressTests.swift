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

    func testDefaultsMaintenanceRemovesDeprecatedLaunchDiagnosticsResidue() {
        let defaults = makeDefaults()
        let bundleIdentifier = defaultsSuiteName(for: defaults)

        defaults.set("launch", forKey: "coremonitor.launchDiagnostics.lastOpenRequestSource")
        defaults.set("2026-04-16T00:00:00Z", forKey: "coremonitor.launchDiagnostics.lastVisibleAt")
        defaults.set(true, forKey: "coremonitor.didShowFirstLaunchDashboard")
        defaults.set("keep", forKey: "coremonitor.unrelated")

        CoreMonitorDefaultsMaintenance.purgeDeprecatedState(
            defaults: defaults,
            bundleIdentifier: bundleIdentifier
        )

        XCTAssertNil(defaults.object(forKey: "coremonitor.launchDiagnostics.lastOpenRequestSource"))
        XCTAssertNil(defaults.object(forKey: "coremonitor.launchDiagnostics.lastVisibleAt"))
        XCTAssertNil(defaults.object(forKey: "coremonitor.didShowFirstLaunchDashboard"))
        XCTAssertEqual(defaults.string(forKey: "coremonitor.unrelated"), "keep")
        XCTAssertTrue(defaults.bool(forKey: CoreMonitorDefaultsMaintenance.deprecatedLaunchStateResetKey))
    }

    func testDefaultsMaintenanceRechecksDeprecatedLaunchDiagnosticsWhenResetMarkerAlreadyExists() {
        let defaults = makeDefaults()
        let bundleIdentifier = defaultsSuiteName(for: defaults)

        defaults.set(true, forKey: CoreMonitorDefaultsMaintenance.deprecatedLaunchStateResetKey)
        defaults.set("automation", forKey: "coremonitor.launchDiagnostics.lastOpenRequestSource")
        defaults.set("2026-04-16T12:00:00Z", forKey: "coremonitor.launchDiagnostics.lastVisibleAt")
        defaults.set(true, forKey: "coremonitor.didShowFirstLaunchDashboard")
        defaults.set("keep", forKey: "coremonitor.unrelated")

        CoreMonitorDefaultsMaintenance.purgeDeprecatedState(
            defaults: defaults,
            bundleIdentifier: bundleIdentifier
        )

        XCTAssertNil(defaults.object(forKey: "coremonitor.launchDiagnostics.lastOpenRequestSource"))
        XCTAssertNil(defaults.object(forKey: "coremonitor.launchDiagnostics.lastVisibleAt"))
        XCTAssertNil(defaults.object(forKey: "coremonitor.didShowFirstLaunchDashboard"))
        XCTAssertEqual(defaults.string(forKey: "coremonitor.unrelated"), "keep")
        XCTAssertTrue(defaults.bool(forKey: CoreMonitorDefaultsMaintenance.deprecatedLaunchStateResetKey))
    }

    func testDefaultsMaintenanceRemovesLegacyWindowFrameKeysWithoutTouchingOtherState() {
        let defaults = makeDefaults()
        let bundleIdentifier = defaultsSuiteName(for: defaults)

        defaults.set("10 10 900 640 0 0 1440 900", forKey: "NSWindow Frame CoreMonitorMainWindow")
        defaults.set("10 10 900 640 0 0 1440 900", forKey: "NSWindow Frame SwiftUI.ModifiedContent<App>")
        defaults.set("keep", forKey: "NSWindow Frame SomeOtherWindow")

        CoreMonitorDefaultsMaintenance.purgeDeprecatedState(
            defaults: defaults,
            bundleIdentifier: bundleIdentifier
        )

        XCTAssertNil(defaults.object(forKey: "NSWindow Frame CoreMonitorMainWindow"))
        XCTAssertNil(defaults.object(forKey: "NSWindow Frame SwiftUI.ModifiedContent<App>"))
        XCTAssertEqual(defaults.string(forKey: "NSWindow Frame SomeOtherWindow"), "keep")
        XCTAssertTrue(defaults.bool(forKey: CoreMonitorDefaultsMaintenance.legacyWindowStateResetKey))
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "WelcomeGuideProgressTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(suiteName, forKey: "__suite_name__")
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }

    private func defaultsSuiteName(for defaults: UserDefaults) -> String {
        defaults.string(forKey: "__suite_name__") ?? ""
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
