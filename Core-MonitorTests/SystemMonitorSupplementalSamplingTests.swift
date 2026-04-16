import XCTest
@testable import Core_Monitor

final class SystemMonitorSupplementalSamplingTests: XCTestCase {
    func testInteractiveMonitoringRefreshesSupplementalReadingsOnMetricCadence() {
        var state = SystemMonitorSupplementalSamplingState()
        let start = Date(timeIntervalSinceReferenceDate: 10_000)

        XCTAssertTrue(state.shouldRefreshBattery(now: start, monitoringInterval: 1))
        XCTAssertFalse(state.shouldRefreshBattery(now: start.addingTimeInterval(9.9), monitoringInterval: 1))
        XCTAssertTrue(state.shouldRefreshBattery(now: start.addingTimeInterval(10.0), monitoringInterval: 1))

        XCTAssertTrue(state.shouldRefreshSystemControls(now: start, monitoringInterval: 1))
        XCTAssertFalse(state.shouldRefreshSystemControls(now: start.addingTimeInterval(4.9), monitoringInterval: 1))
        XCTAssertTrue(state.shouldRefreshSystemControls(now: start.addingTimeInterval(5.0), monitoringInterval: 1))
    }

    func testBackgroundMonitoringDoesNotRefreshSupplementalReadingsFasterThanMonitorCadence() {
        var state = SystemMonitorSupplementalSamplingState()
        let start = Date(timeIntervalSinceReferenceDate: 20_000)

        XCTAssertTrue(state.shouldRefreshSystemControls(now: start, monitoringInterval: 30))
        XCTAssertFalse(state.shouldRefreshSystemControls(now: start.addingTimeInterval(10.0), monitoringInterval: 30))
        XCTAssertTrue(state.shouldRefreshSystemControls(now: start.addingTimeInterval(30.0), monitoringInterval: 30))
    }

    func testResetForcesImmediateRefreshAgain() {
        var state = SystemMonitorSupplementalSamplingState()
        let start = Date(timeIntervalSinceReferenceDate: 30_000)

        XCTAssertTrue(state.shouldRefreshBattery(now: start, monitoringInterval: 1))
        XCTAssertFalse(state.shouldRefreshBattery(now: start.addingTimeInterval(1.0), monitoringInterval: 1))

        state.reset()

        XCTAssertTrue(state.shouldRefreshBattery(now: start.addingTimeInterval(1.0), monitoringInterval: 1))
    }
}
