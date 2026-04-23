# File: Core-MonitorTests/CoreMonitorSingleInstancePolicyTests.swift

## Current Role

- Area: Tests.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-MonitorTests/CoreMonitorSingleInstancePolicyTests.swift`](../../../Core-MonitorTests/CoreMonitorSingleInstancePolicyTests.swift) |
| Wiki area | Tests |
| Exists in current checkout | True |
| Size | 2631 bytes |
| Binary | False |
| Line count | 84 |
| Extension | `.swift` |

## Imports

`XCTest`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `CoreMonitorSingleInstancePolicyTests` | 2 |
| func | `testHandoffTargetIgnoresCurrentProcessAndUnreadyPeers` | 5 |
| func | `testHandoffTargetPrefersOldestFinishedRunningInstance` | 37 |
| func | `testHandoffTargetFallsBackToPIDWhenLaunchDateIsMissing` | 60 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `a62ded6` | 2026-04-16 | Prevent duplicate Core Monitor launches |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
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
```
