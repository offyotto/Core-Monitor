# File: Core-MonitorTests/CoreMonitorLaunchEnvironmentTests.swift

## Current Role

- Area: Tests.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-MonitorTests/CoreMonitorLaunchEnvironmentTests.swift`](../../../Core-MonitorTests/CoreMonitorLaunchEnvironmentTests.swift) |
| Wiki area | Tests |
| Exists in current checkout | True |
| Size | 621 bytes |
| Binary | False |
| Line count | 21 |
| Extension | `.swift` |

## Imports

`XCTest`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `CoreMonitorLaunchEnvironmentTests` | 2 |
| func | `testDuplicateLaunchHandlingEnabledForNormalAppRuns` | 5 |
| func | `testDuplicateLaunchHandlingDisabledForXCTestHostedRuns` | 12 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `2dae7aa` | 2026-04-16 | Prevent duplicate Core Monitor launches |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import XCTest
@testable import Core_Monitor

final class CoreMonitorLaunchEnvironmentTests: XCTestCase {
    func testDuplicateLaunchHandlingEnabledForNormalAppRuns() {
        XCTAssertTrue(
            CoreMonitorLaunchEnvironment.shouldHandleDuplicateLaunch(
                environment: [:]
            )
        )
    }

    func testDuplicateLaunchHandlingDisabledForXCTestHostedRuns() {
        XCTAssertFalse(
            CoreMonitorLaunchEnvironment.shouldHandleDuplicateLaunch(
                environment: ["XCTestConfigurationFilePath": "/tmp/CoreMonitor.xctestconfiguration"]
            )
        )
    }
}
```
