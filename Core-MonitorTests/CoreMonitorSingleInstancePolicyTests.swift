import XCTest
@testable import Core_Monitor

@MainActor
final class CoreMonitorSingleInstancePolicyTests: XCTestCase {
    func testOnlyLockOwnerIsSelectedEvenIfItIsStillLaunching() {
        let owner = CoreMonitorRunningInstance(processIdentifier: 901, launchDate: Date(), isFinishedLaunching: false, isTerminated: false)
        let older = CoreMonitorRunningInstance(processIdentifier: 800, launchDate: .distantPast, isFinishedLaunching: true, isTerminated: false)
        XCTAssertEqual(CoreMonitorSingleInstancePolicy.handoffTarget(from: [older, owner], currentPID: 900, ownerPID: 901), owner)
        XCTAssertNil(CoreMonitorSingleInstancePolicy.handoffTarget(from: [older, owner], currentPID: 900, ownerPID: nil))
        XCTAssertNil(CoreMonitorSingleInstancePolicy.handoffTarget(from: [owner], currentPID: 901, ownerPID: 901))
    }

    func testDeadLockOwnerIsNotUsedForHandoff() {
        let owner = CoreMonitorRunningInstance(processIdentifier: 901, launchDate: nil, isFinishedLaunching: true, isTerminated: true)
        XCTAssertNil(CoreMonitorSingleInstancePolicy.handoffTarget(from: [owner], currentPID: 900, ownerPID: 901))
    }

    func testAcknowledgementMustMatchRequestAndRequestingProcess() {
        let request = CoreMonitorDashboardHandoffRequest(bundleIdentifier: "CoreTools.Core-Monitor", targetProcessIdentifier: 901,
                                                        requesterProcessIdentifier: 900)
        XCTAssertTrue(CoreMonitorDashboardHandoffRequest.acceptsAcknowledgement(userInfo: request.userInfo,
            bundleIdentifier: request.bundleIdentifier, requestIdentifier: request.requestIdentifier, requesterPID: 900, ownerPID: 901))
        XCTAssertFalse(CoreMonitorDashboardHandoffRequest.acceptsAcknowledgement(userInfo: request.userInfo,
            bundleIdentifier: request.bundleIdentifier, requestIdentifier: UUID(), requesterPID: 900, ownerPID: 901))
        XCTAssertFalse(CoreMonitorDashboardHandoffRequest.acceptsAcknowledgement(userInfo: request.userInfo,
            bundleIdentifier: request.bundleIdentifier, requestIdentifier: request.requestIdentifier, requesterPID: 902, ownerPID: 901))
        XCTAssertFalse(CoreMonitorDashboardHandoffRequest.acceptsAcknowledgement(userInfo: request.userInfo,
            bundleIdentifier: request.bundleIdentifier, requestIdentifier: request.requestIdentifier, requesterPID: 900, ownerPID: 902))
    }

    func testDashboardHandoffRequestRequiresExpectedBundleAndTargetPID() {
        let request = CoreMonitorDashboardHandoffRequest(
            bundleIdentifier: "CoreTools.Core-Monitor",
            targetProcessIdentifier: 1234
        )

        XCTAssertTrue(
            CoreMonitorDashboardHandoffRequest.accepts(
                userInfo: request.userInfo,
                expectedBundleIdentifier: "CoreTools.Core-Monitor",
                currentProcessIdentifier: 1234
            )
        )

        XCTAssertFalse(
            CoreMonitorDashboardHandoffRequest.accepts(
                userInfo: request.userInfo,
                expectedBundleIdentifier: "CoreTools.Core-Monitor",
                currentProcessIdentifier: 5678
            )
        )

        XCTAssertFalse(
            CoreMonitorDashboardHandoffRequest.accepts(
                userInfo: ["bundleIdentifier": "CoreTools.Core-Monitor"],
                expectedBundleIdentifier: "CoreTools.Core-Monitor",
                currentProcessIdentifier: 1234
            )
        )

        XCTAssertFalse(
            CoreMonitorDashboardHandoffRequest.accepts(
                userInfo: request.userInfo,
                expectedBundleIdentifier: "com.example.other",
                currentProcessIdentifier: 1234
            )
        )
    }

    func testHandoffRoundTripsInSandboxCompatibleObjectWithoutUserInfo() throws {
        let request = CoreMonitorDashboardHandoffRequest(bundleIdentifier: "CoreTools.Core-Monitor",
                                                        targetProcessIdentifier: 901, requesterProcessIdentifier: 900)
        let object = try XCTUnwrap(request.notificationObject)
        let info = CoreMonitorDashboardHandoffRequest.notificationInfo(object: object, legacyUserInfo: nil)
        XCTAssertTrue(CoreMonitorDashboardHandoffRequest.accepts(userInfo: info,
            expectedBundleIdentifier: request.bundleIdentifier, currentProcessIdentifier: 901))
        XCTAssertTrue(CoreMonitorDashboardHandoffRequest.acceptsAcknowledgement(userInfo: info,
            bundleIdentifier: request.bundleIdentifier, requestIdentifier: request.requestIdentifier, requesterPID: 900, ownerPID: 901))
        XCTAssertNil(CoreMonitorDashboardHandoffRequest.notificationInfo(object: "invalid", legacyUserInfo: nil))
        XCTAssertNil(CoreMonitorDashboardHandoffRequest.notificationInfo(object: String(repeating: "x", count: 4_097), legacyUserInfo: nil))
    }
}
