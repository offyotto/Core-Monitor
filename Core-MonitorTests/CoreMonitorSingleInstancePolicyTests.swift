import XCTest
@testable import Core_Monitor

final class CoreMonitorSingleInstancePolicyTests: XCTestCase {
    func testHandoffTargetIgnoresCurrentProcessAndUnreadyPeers() {
        let currentPID = pid_t(900)
        let launchDate = Date(timeIntervalSince1970: 100)

        let candidates = [
            CoreMonitorRunningInstance(
                processIdentifier: currentPID,
                launchDate: launchDate,
                isFinishedLaunching: true,
                isTerminated: false
            ),
            CoreMonitorRunningInstance(
                processIdentifier: 901,
                launchDate: Date(timeIntervalSince1970: 90),
                isFinishedLaunching: false,
                isTerminated: false
            ),
            CoreMonitorRunningInstance(
                processIdentifier: 902,
                launchDate: Date(timeIntervalSince1970: 80),
                isFinishedLaunching: true,
                isTerminated: true
            )
        ]

        XCTAssertNil(
            CoreMonitorSingleInstancePolicy.handoffTarget(
                from: candidates,
                currentPID: currentPID
            )
        )
    }

    func testHandoffTargetPrefersOldestFinishedRunningInstance() {
        let currentPID = pid_t(900)
        let oldest = CoreMonitorRunningInstance(
            processIdentifier: 800,
            launchDate: Date(timeIntervalSince1970: 10),
            isFinishedLaunching: true,
            isTerminated: false
        )
        let newer = CoreMonitorRunningInstance(
            processIdentifier: 850,
            launchDate: Date(timeIntervalSince1970: 20),
            isFinishedLaunching: true,
            isTerminated: false
        )

        let target = CoreMonitorSingleInstancePolicy.handoffTarget(
            from: [newer, oldest],
            currentPID: currentPID
        )

        XCTAssertEqual(target, oldest)
    }

    func testHandoffTargetFallsBackToPIDWhenLaunchDateIsMissing() {
        let currentPID = pid_t(900)
        let lowerPID = CoreMonitorRunningInstance(
            processIdentifier: 700,
            launchDate: nil,
            isFinishedLaunching: true,
            isTerminated: false
        )
        let higherPID = CoreMonitorRunningInstance(
            processIdentifier: 750,
            launchDate: nil,
            isFinishedLaunching: true,
            isTerminated: false
        )

        let target = CoreMonitorSingleInstancePolicy.handoffTarget(
            from: [higherPID, lowerPID],
            currentPID: currentPID
        )

        XCTAssertEqual(target, lowerPID)
    }
}
