# File: Core-MonitorTests/AlertEngineTests.swift

## Current Role

- Area: Tests.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-MonitorTests/AlertEngineTests.swift`](../../../Core-MonitorTests/AlertEngineTests.swift) |
| Wiki area | Tests |
| Exists in current checkout | True |
| Size | 15078 bytes |
| Binary | False |
| Line count | 394 |
| Extension | `.swift` |

## Imports

`XCTest`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `AlertEngineTests` | 2 |
| func | `testThresholdCrossingEscalatesFromWarningToCritical` | 6 |
| func | `testHysteresisKeepsAlertActiveUntilMetricRecoversPastFloor` | 32 |
| func | `testCooldownBlocksRepeatEventsUntilWindowExpires` | 72 |
| func | `testSnoozeSuppressesDesktopNotificationRepeats` | 102 |
| func | `testDismissUntilRecoveryHidesCurrentAlertUntilSafeAgain` | 128 |
| func | `testPresetConfigAndPersistenceRoundTrip` | 160 |
| func | `testServiceRulesFlagHelperAndSMCProblems` | 177 |
| func | `testHelperAvailabilityRuleUsesConnectionStateInsteadOfMessageGuessing` | 200 |
| func | `testHelperAvailabilityRuleStaysInactiveWhileSystemModeOwnsCooling` | 240 |
| func | `testProcessInsightsDisabledRedactsTopProcessContext` | 271 |
| func | `testNotificationStripPresentationHighlightsActiveNotifications` | 300 |
| func | `testNotificationStripPresentationRequestsSetupWhenNotificationsArePending` | 316 |
| func | `testNotificationStripPresentationStaysQuietWhenSystemIsHealthy` | 335 |
| func | `testNotificationStripPresentationRoutesMutedSessionsToSettings` | 351 |
| func | `makeInput` | 371 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `734d179` | 2026-04-17 | Remove remaining alerts strings |
| `099460c` | 2026-04-16 | Refine overview alert status strip |
| `77dcc07` | 2026-04-16 | Make silent fan mode truly system-owned |
| `9d84730` | 2026-04-16 | Tighten actor isolation in test suites |
| `5dc29ed` | 2026-04-16 | Add privacy controls and refine Core Monitor presentation |
| `3dbf6ac` | 2026-04-16 | Default fan control to system mode |
| `3c34251` | 2026-04-16 | Refine helper reachability across alerts and menu bar |
| `1ff7bdb` | 2026-04-16 | Refine helper health states and service alerts |
| `7185d36` | 2026-04-15 | Improve fan control and alert surfaces |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
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
```
