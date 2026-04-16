import XCTest
@testable import Core_Monitor

@MainActor
final class AlertEngineTests: XCTestCase {
    func testThresholdCrossingEscalatesFromWarningToCritical() {
        let config = AlertRuleConfig(
            kind: .cpuTemperature,
            isEnabled: true,
            threshold: .init(warning: 80, critical: 90, hysteresis: 3),
            cooldownMinutes: 10,
            debounceSamples: 1,
            desktopNotificationsEnabled: true
        )

        let warningInput = makeInput { snapshot in
            snapshot.cpuTemperature = 84
        }
        let warningOutcome = AlertEvaluator.evaluate(config: config, runtime: .initial(for: .cpuTemperature), input: warningInput)

        XCTAssertEqual(warningOutcome.activeState?.severity, .warning)
        XCTAssertEqual(warningOutcome.event?.severity, .warning)

        let criticalInput = makeInput(now: warningInput.now.addingTimeInterval(5)) { snapshot in
            snapshot.cpuTemperature = 95
        }
        let criticalOutcome = AlertEvaluator.evaluate(config: config, runtime: warningOutcome.runtime, input: criticalInput)

        XCTAssertEqual(criticalOutcome.activeState?.severity, .critical)
        XCTAssertEqual(criticalOutcome.event?.severity, .critical)
    }

    func testHysteresisKeepsAlertActiveUntilMetricRecoversPastFloor() {
        let config = AlertRuleConfig(
            kind: .cpuTemperature,
            isEnabled: true,
            threshold: .init(warning: 85, critical: 95, hysteresis: 3),
            cooldownMinutes: 10,
            debounceSamples: 1,
            desktopNotificationsEnabled: true
        )

        let first = AlertEvaluator.evaluate(
            config: config,
            runtime: .initial(for: .cpuTemperature),
            input: makeInput { $0.cpuTemperature = 96 }
        )
        XCTAssertEqual(first.activeState?.severity, .critical)

        let stillCritical = AlertEvaluator.evaluate(
            config: config,
            runtime: first.runtime,
            input: makeInput(now: first.event!.timestamp.addingTimeInterval(5)) { $0.cpuTemperature = 93 }
        )
        XCTAssertEqual(stillCritical.activeState?.severity, .critical)

        let downgraded = AlertEvaluator.evaluate(
            config: config,
            runtime: stillCritical.runtime,
            input: makeInput(now: first.event!.timestamp.addingTimeInterval(10)) { $0.cpuTemperature = 89 }
        )
        XCTAssertEqual(downgraded.activeState?.severity, .warning)

        let recovered = AlertEvaluator.evaluate(
            config: config,
            runtime: downgraded.runtime,
            input: makeInput(now: first.event!.timestamp.addingTimeInterval(15)) { $0.cpuTemperature = 81 }
        )
        XCTAssertNil(recovered.activeState)
        XCTAssertNil(recovered.event)
    }

    func testCooldownBlocksRepeatEventsUntilWindowExpires() {
        let config = AlertRuleConfig(
            kind: .cpuUsage,
            isEnabled: true,
            threshold: .init(warning: 80, critical: 95, hysteresis: 5),
            cooldownMinutes: 10,
            debounceSamples: 1,
            desktopNotificationsEnabled: true
        )

        let firstInput = makeInput { $0.cpuUsagePercent = 97 }
        let first = AlertEvaluator.evaluate(config: config, runtime: .initial(for: .cpuUsage), input: firstInput)
        XCTAssertTrue(first.shouldNotify)

        let insideCooldown = AlertEvaluator.evaluate(
            config: config,
            runtime: first.runtime,
            input: makeInput(now: firstInput.now.addingTimeInterval(120)) { $0.cpuUsagePercent = 97 }
        )
        XCTAssertNil(insideCooldown.event)

        let afterCooldown = AlertEvaluator.evaluate(
            config: config,
            runtime: first.runtime,
            input: makeInput(now: firstInput.now.addingTimeInterval(601)) { $0.cpuUsagePercent = 97 }
        )
        XCTAssertNotNil(afterCooldown.event)
        XCTAssertTrue(afterCooldown.shouldNotify)
    }

    func testSnoozeSuppressesDesktopNotificationRepeats() {
        let config = AlertRuleConfig(
            kind: .cpuUsage,
            isEnabled: true,
            threshold: .init(warning: 80, critical: 95, hysteresis: 5),
            cooldownMinutes: 10,
            debounceSamples: 1,
            desktopNotificationsEnabled: true
        )

        var runtime = AlertRuleRuntime.initial(for: .cpuUsage)
        runtime.activeSeverity = .critical
        runtime.lastEventDate = Date(timeIntervalSince1970: 1_000)
        runtime.lastNotificationDate = runtime.lastEventDate
        runtime.snoozedUntil = runtime.lastEventDate?.addingTimeInterval(3_600)

        let outcome = AlertEvaluator.evaluate(
            config: config,
            runtime: runtime,
            input: makeInput(now: Date(timeIntervalSince1970: 1_700)) { $0.cpuUsagePercent = 97 }
        )

        XCTAssertNotNil(outcome.event)
        XCTAssertFalse(outcome.shouldNotify)
    }

    func testDismissUntilRecoveryHidesCurrentAlertUntilSafeAgain() {
        let config = AlertRuleConfig(
            kind: .cpuTemperature,
            isEnabled: true,
            threshold: .init(warning: 85, critical: 95, hysteresis: 3),
            cooldownMinutes: 10,
            debounceSamples: 1,
            desktopNotificationsEnabled: true
        )

        var runtime = AlertRuleRuntime.initial(for: .cpuTemperature)
        runtime.activeSeverity = .warning
        runtime.dismissUntilRecovery = true
        runtime.lastEventDate = Date(timeIntervalSince1970: 1_000)

        let suppressed = AlertEvaluator.evaluate(
            config: config,
            runtime: runtime,
            input: makeInput(now: Date(timeIntervalSince1970: 1_030)) { $0.cpuTemperature = 90 }
        )
        XCTAssertNil(suppressed.activeState)
        XCTAssertNil(suppressed.event)

        let recovered = AlertEvaluator.evaluate(
            config: config,
            runtime: suppressed.runtime,
            input: makeInput(now: Date(timeIntervalSince1970: 1_060)) { $0.cpuTemperature = 70 }
        )
        XCTAssertNil(recovered.event)
        XCTAssertFalse(recovered.runtime.dismissUntilRecovery)
    }

    func testPresetConfigAndPersistenceRoundTrip() throws {
        var store = AlertStore.default()
        store.selectedPreset = .performance
        store.ruleConfigs = AlertPreset.performance.configurations()
        store.notificationsMutedUntil = Date(timeIntervalSince1970: 5_000)

        let data = try JSONEncoder().encode(store)
        let decoded = try JSONDecoder().decode(AlertStore.self, from: data)

        XCTAssertEqual(decoded.selectedPreset, .performance)
        XCTAssertEqual(decoded.notificationsMutedUntil, store.notificationsMutedUntil)
        XCTAssertEqual(
            decoded.ruleConfigs.first(where: { $0.kind == .cpuUsage })?.threshold.warning,
            80
        )
    }

    func testServiceRulesFlagHelperAndSMCProblems() {
        let smcOutcome = AlertEvaluator.evaluate(
            config: AlertPreset.default.configurations().first(where: { $0.kind == .smcUnavailable })!,
            runtime: .initial(for: .smcUnavailable),
            input: makeInput {
                $0.hasSMCAccess = false
                $0.lastError = "AppleSMC unavailable"
            }
        )
        XCTAssertEqual(smcOutcome.activeState?.severity, .critical)

        let helperOutcome = AlertEvaluator.evaluate(
            config: AlertPreset.default.configurations().first(where: { $0.kind == .helperUnavailable })!,
            runtime: .initial(for: .helperUnavailable),
            input: makeInput(
                fanMode: .performance,
                helperInstalled: false,
                helperConnectionState: .missing
            ) { _ in }
        )
        XCTAssertEqual(helperOutcome.activeState?.severity, .warning)
    }

    func testHelperAvailabilityRuleUsesConnectionStateInsteadOfMessageGuessing() {
        let config = AlertPreset.default.configurations().first(where: { $0.kind == .helperUnavailable })!

        let unreachable = AlertEvaluator.evaluate(
            config: config,
            runtime: .initial(for: .helperUnavailable),
            input: makeInput(
                fanMode: .performance,
                helperInstalled: true,
                helperConnectionState: .unreachable,
                helperStatusMessage: nil
            ) { _ in }
        )
        XCTAssertEqual(unreachable.activeState?.severity, .critical)

        let checking = AlertEvaluator.evaluate(
            config: config,
            runtime: .initial(for: .helperUnavailable),
            input: makeInput(
                fanMode: .performance,
                helperInstalled: true,
                helperConnectionState: .checking,
                helperStatusMessage: "Core Monitor is probing the local helper service."
            ) { _ in }
        )
        XCTAssertNil(checking.activeState)

        let missing = AlertEvaluator.evaluate(
            config: config,
            runtime: .initial(for: .helperUnavailable),
            input: makeInput(
                fanMode: .performance,
                helperInstalled: false,
                helperConnectionState: .missing,
                helperStatusMessage: nil
            ) { _ in }
        )
        XCTAssertEqual(missing.activeState?.severity, .warning)
    }

    func testHelperAvailabilityRuleStaysInactiveWhileSystemModeOwnsCooling() {
        let config = AlertPreset.default.configurations().first(where: { $0.kind == .helperUnavailable })!

        let automatic = AlertEvaluator.evaluate(
            config: config,
            runtime: .initial(for: .helperUnavailable),
            input: makeInput(
                fanMode: .automatic,
                helperInstalled: false,
                helperConnectionState: .unreachable,
                helperStatusMessage: "The helper rejected this ad-hoc build."
            ) { _ in }
        )

        let silent = AlertEvaluator.evaluate(
            config: config,
            runtime: .initial(for: .helperUnavailable),
            input: makeInput(
                fanMode: .silent,
                helperInstalled: false,
                helperConnectionState: .unreachable,
                helperStatusMessage: "The helper rejected this ad-hoc build."
            ) { _ in }
        )

        XCTAssertNil(automatic.activeState)
        XCTAssertNil(automatic.event)
        XCTAssertNil(silent.activeState)
        XCTAssertNil(silent.event)
    }

    func testProcessInsightsDisabledRedactsTopProcessContext() {
        let config = AlertRuleConfig(
            kind: .cpuUsage,
            isEnabled: true,
            threshold: .init(warning: 80, critical: 95, hysteresis: 5),
            cooldownMinutes: 10,
            debounceSamples: 1,
            desktopNotificationsEnabled: true
        )

        let outcome = AlertEvaluator.evaluate(
            config: config,
            runtime: .initial(for: .cpuUsage),
            input: makeInput(processInsightsEnabled: false) { snapshot in
                snapshot.cpuUsagePercent = 97
                snapshot.topProcesses = TopProcessSnapshot(
                    sampledAt: Date(timeIntervalSince1970: 1_000),
                    topCPU: [
                        ProcessActivity(pid: 42, name: "Xcode", cpuPercent: 97, memoryBytes: 1_024)
                    ],
                    topMemory: []
                )
            }
        )

        XCTAssertNil(outcome.activeState?.context)
        XCTAssertNil(outcome.event?.context)
    }

    func testAlertsDashboardStripPresentationHighlightsActiveAlerts() {
        let presentation = AlertsDashboardStripPresentation(
            activeAlertCount: 2,
            authorizationStatus: .authorized,
            desktopNotificationsEnabled: true,
            notificationsMutedUntil: nil,
            now: Date(timeIntervalSince1970: 10_000)
        )

        XCTAssertEqual(presentation.detail, "2 active alerts")
        XCTAssertEqual(
            presentation.action,
            .init(title: "Open Alerts", icon: "bell.badge", style: .prominent)
        )
    }

    func testAlertsDashboardStripPresentationRequestsSetupWhenNotificationsArePending() {
        let presentation = AlertsDashboardStripPresentation(
            activeAlertCount: 0,
            authorizationStatus: .notDetermined,
            desktopNotificationsEnabled: true,
            notificationsMutedUntil: nil,
            now: Date(timeIntervalSince1970: 10_000)
        )

        XCTAssertEqual(
            presentation.detail,
            "Desktop notifications are not set up yet. In-app history already records every alert."
        )
        XCTAssertEqual(
            presentation.action,
            .init(title: "Set Up Alerts", icon: "bell.badge", style: .standard)
        )
    }

    func testAlertsDashboardStripPresentationStaysQuietWhenSystemIsHealthy() {
        let presentation = AlertsDashboardStripPresentation(
            activeAlertCount: 0,
            authorizationStatus: .authorized,
            desktopNotificationsEnabled: true,
            notificationsMutedUntil: nil,
            now: Date(timeIntervalSince1970: 10_000)
        )

        XCTAssertEqual(
            presentation.detail,
            "Alert thresholds and recent history stay available from the Alerts screen."
        )
        XCTAssertNil(presentation.action)
    }

    func testAlertsDashboardStripPresentationRoutesMutedSessionsToAlertSettings() {
        let now = Date(timeIntervalSince1970: 10_000)
        let presentation = AlertsDashboardStripPresentation(
            activeAlertCount: 0,
            authorizationStatus: .authorized,
            desktopNotificationsEnabled: true,
            notificationsMutedUntil: now.addingTimeInterval(600),
            now: now
        )

        XCTAssertEqual(
            presentation.detail,
            "Desktop notifications are muted for now. In-app history still records every alert."
        )
        XCTAssertEqual(
            presentation.action,
            .init(title: "Alert Settings", icon: "bell.slash", style: .standard)
        )
    }

    private func makeInput(
        fanMode: FanControlMode = .automatic,
        helperInstalled: Bool = true,
        helperConnectionState: SMCHelperManager.ConnectionState = .reachable,
        helperStatusMessage: String? = nil,
        processInsightsEnabled: Bool = true,
        now: Date = Date(timeIntervalSince1970: 1_000),
        configure: (inout SystemMonitorSnapshot) -> Void
    ) -> AlertEvaluationInput {
        var snapshot = SystemMonitorSnapshot.empty
        configure(&snapshot)
        return AlertEvaluationInput(
            snapshot: snapshot,
            fanMode: fanMode,
            helperInstalled: helperInstalled,
            helperConnectionState: helperConnectionState,
            helperStatusMessage: helperStatusMessage,
            processInsightsEnabled: processInsightsEnabled,
            now: now
        )
    }
}
