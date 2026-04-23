# File: Core-MonitorTests/DiskProcessSamplerTests.swift

## Current Role

- Area: Tests.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-MonitorTests/DiskProcessSamplerTests.swift`](../../../Core-MonitorTests/DiskProcessSamplerTests.swift) |
| Wiki area | Tests |
| Exists in current checkout | True |
| Size | 2706 bytes |
| Binary | False |
| Line count | 66 |
| Extension | `.swift` |

## Imports

`XCTest`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `DiskProcessSamplerTests` | 2 |
| func | `testActivitiesAggregateDeltasByProcessName` | 5 |
| func | `testActivitiesClampCounterResetsAndRespectLimit` | 33 |
| func | `testFormatBytesUsesCompactLabels` | 58 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `3094642` | 2026-04-16 | Cache disk activity away from menu bar renders |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import XCTest
@testable import Core_Monitor

final class DiskProcessSamplerTests: XCTestCase {
    func testActivitiesAggregateDeltasByProcessName() {
        let previousCounters: [Int32: DiskProcessCounter] = [
            11: DiskProcessCounter(pid: 11, name: "Safari", readBytes: 100, writtenBytes: 50),
            12: DiskProcessCounter(pid: 12, name: "Safari", readBytes: 400, writtenBytes: 100),
            77: DiskProcessCounter(pid: 77, name: "backupd", readBytes: 1_000, writtenBytes: 250)
        ]

        let counters = [
            DiskProcessCounter(pid: 11, name: "Safari", readBytes: 450, writtenBytes: 150),
            DiskProcessCounter(pid: 12, name: "Safari", readBytes: 900, writtenBytes: 300),
            DiskProcessCounter(pid: 77, name: "backupd", readBytes: 1_600, writtenBytes: 250),
            DiskProcessCounter(pid: 99, name: "WindowServer", readBytes: 50, writtenBytes: 50)
        ]

        let activities = DiskProcessSampling.activities(
            from: counters,
            previousCounters: previousCounters,
            limit: 4
        )

        XCTAssertEqual(
            activities,
            [
                DiskProcessActivity(name: "Safari", readBytes: 850, writtenBytes: 300),
                DiskProcessActivity(name: "backupd", readBytes: 600, writtenBytes: 0)
            ]
        )
    }

    func testActivitiesClampCounterResetsAndRespectLimit() {
        let previousCounters: [Int32: DiskProcessCounter] = [
            1: DiskProcessCounter(pid: 1, name: "A", readBytes: 900, writtenBytes: 700),
            2: DiskProcessCounter(pid: 2, name: "B", readBytes: 100, writtenBytes: 100),
            3: DiskProcessCounter(pid: 3, name: "C", readBytes: 100, writtenBytes: 100)
        ]

```
