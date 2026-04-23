# File: Core-MonitorTests/SystemMonitorSupplementalSamplingTests.swift

## Current Role

- Area: Tests.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-MonitorTests/SystemMonitorSupplementalSamplingTests.swift`](../../../Core-MonitorTests/SystemMonitorSupplementalSamplingTests.swift) |
| Wiki area | Tests |
| Exists in current checkout | True |
| Size | 2031 bytes |
| Binary | False |
| Line count | 39 |
| Extension | `.swift` |

## Imports

`XCTest`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `SystemMonitorSupplementalSamplingTests` | 2 |
| func | `testInteractiveMonitoringRefreshesSupplementalReadingsOnMetricCadence` | 5 |
| func | `testBackgroundMonitoringDoesNotRefreshSupplementalReadingsFasterThanMonitorCadence` | 17 |
| func | `testResetForcesImmediateRefreshAgain` | 26 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `bd91092` | 2026-04-16 | Fix merged disk refresh regression |
| `6fcd312` | 2026-04-16 | Throttle slow-moving system monitor reads |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
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
```
