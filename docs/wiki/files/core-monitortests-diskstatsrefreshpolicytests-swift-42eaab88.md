# File: Core-MonitorTests/DiskStatsRefreshPolicyTests.swift

## Current Role

- Area: Tests.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-MonitorTests/DiskStatsRefreshPolicyTests.swift`](../../../Core-MonitorTests/DiskStatsRefreshPolicyTests.swift) |
| Wiki area | Tests |
| Exists in current checkout | True |
| Size | 916 bytes |
| Binary | False |
| Line count | 32 |
| Extension | `.swift` |

## Imports

`XCTest`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `DiskStatsRefreshPolicyTests` | 2 |
| func | `testRefreshesImmediatelyWhenNoPreviousSampleExists` | 5 |
| func | `testSkipsRefreshesInsideMinimumInterval` | 13 |
| func | `testRefreshesAgainOnceMinimumIntervalExpires` | 22 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `767668c` | 2026-04-16 | Throttle disk stats refresh cadence |
| `108166d` | 2026-04-16 | Throttle disk stats refresh cadence |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import XCTest
@testable import Core_Monitor

final class DiskStatsRefreshPolicyTests: XCTestCase {
    func testRefreshesImmediatelyWhenNoPreviousSampleExists() {
        XCTAssertTrue(
            DiskStatsRefreshPolicy.shouldRefresh(
                lastUpdatedAt: nil,
                now: Date(timeIntervalSince1970: 100)
            )
        )
    }

    func testSkipsRefreshesInsideMinimumInterval() {
        XCTAssertFalse(
            DiskStatsRefreshPolicy.shouldRefresh(
                lastUpdatedAt: Date(timeIntervalSince1970: 100),
                now: Date(timeIntervalSince1970: 129)
            )
        )
    }

    func testRefreshesAgainOnceMinimumIntervalExpires() {
        XCTAssertTrue(
            DiskStatsRefreshPolicy.shouldRefresh(
                lastUpdatedAt: Date(timeIntervalSince1970: 100),
                now: Date(timeIntervalSince1970: 130)
            )
        )
    }
}
```
