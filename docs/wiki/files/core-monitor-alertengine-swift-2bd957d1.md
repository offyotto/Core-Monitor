# File: Core-Monitor/AlertEngine.swift

## Current Role

- Legacy pure alert-evaluation logic retained for tests and possible future alert reintroduction.
- The current UI removed the old alerts screen surface; do not extend this path casually.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/AlertEngine.swift`](../../../Core-Monitor/AlertEngine.swift) |
| Wiki area | Legacy alert system |
| Exists in current checkout | True |
| Size | 27493 bytes |
| Binary | False |
| Line count | 675 |
| Extension | `.swift` |

## Imports

`Foundation`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| struct | `AlertEvaluationInput` | 2 |
| struct | `AlertMeasurement` | 12 |
| struct | `AlertEvaluationOutcome` | 22 |
| enum | `AlertEvaluator` | 30 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `ce9e812` | 2026-04-16 | Fix Xcode 16.2 CI compatibility |
| `5b96f6f` | 2026-04-16 | Fix Xcode 16.2 CI compatibility |
| `5dc29ed` | 2026-04-16 | Add privacy controls and refine Core Monitor presentation |
| `3c34251` | 2026-04-16 | Refine helper reachability across alerts and menu bar |
| `1ff7bdb` | 2026-04-16 | Refine helper health states and service alerts |
| `7185d36` | 2026-04-15 | Improve fan control and alert surfaces |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import Foundation

struct AlertEvaluationInput {
    let snapshot: SystemMonitorSnapshot
    let fanMode: FanControlMode
    let helperInstalled: Bool
    let helperConnectionState: SMCHelperManager.ConnectionState
    let helperStatusMessage: String?
    let processInsightsEnabled: Bool
    let now: Date
}

struct AlertMeasurement {
    let severity: AlertSeverity
    let metricValue: Double?
    let title: String
    let message: String
    let context: String?
    let isAvailable: Bool
    let unavailableReason: String?
}

struct AlertEvaluationOutcome {
    let runtime: AlertRuleRuntime
    let activeState: AlertActiveState?
    let event: AlertEvent?
    let shouldNotify: Bool
    let availabilityReason: String?
}

enum AlertEvaluator {
    static func evaluate(
        config: AlertRuleConfig,
        runtime: AlertRuleRuntime,
        input: AlertEvaluationInput
    ) -> AlertEvaluationOutcome {
        guard config.isEnabled else {
            return AlertEvaluationOutcome(
                runtime: runtimeReset(from: runtime),
                activeState: nil,
```
