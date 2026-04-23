# File: Core-MonitorTests/NetworkThroughputFormatterTests.swift

## Current Role

- Area: Tests.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-MonitorTests/NetworkThroughputFormatterTests.swift`](../../../Core-MonitorTests/NetworkThroughputFormatterTests.swift) |
| Wiki area | Tests |
| Exists in current checkout | True |
| Size | 1096 bytes |
| Binary | False |
| Line count | 22 |
| Extension | `.swift` |

## Imports

`XCTest`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `NetworkThroughputFormatterTests` | 2 |
| func | `testFormatterHandlesByteKilobyteAndMegabyteRanges` | 5 |
| func | `testFormatterUsesAbsoluteValueForTrendDeltas` | 11 |
| func | `testAbbreviatedFormatterProducesMenuBarFriendlyUnits` | 15 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `58feb7a` | 2026-04-16 | Add network menu bar item and popover |
| `be75b81` | 2026-04-16 | Add dashboard network throughput visibility |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import XCTest
@testable import Core_Monitor

final class NetworkThroughputFormatterTests: XCTestCase {
    func testFormatterHandlesByteKilobyteAndMegabyteRanges() {
        XCTAssertEqual(NetworkThroughputFormatter.compactRate(bytesPerSecond: 0), "0 B/s")
        XCTAssertEqual(NetworkThroughputFormatter.compactRate(bytesPerSecond: 845), "845 B/s")
        XCTAssertEqual(NetworkThroughputFormatter.compactRate(bytesPerSecond: 12_400), "12 KB/s")
        XCTAssertEqual(NetworkThroughputFormatter.compactRate(bytesPerSecond: 1_550_000), "1.6 MB/s")
    }

    func testFormatterUsesAbsoluteValueForTrendDeltas() {
        XCTAssertEqual(NetworkThroughputFormatter.compactRate(bytesPerSecond: -8_400), "8.4 KB/s")
    }

    func testAbbreviatedFormatterProducesMenuBarFriendlyUnits() {
        XCTAssertEqual(NetworkThroughputFormatter.abbreviatedRate(bytesPerSecond: 925), "925 B")
        XCTAssertEqual(NetworkThroughputFormatter.abbreviatedRate(bytesPerSecond: 12_400), "12 K")
        XCTAssertEqual(NetworkThroughputFormatter.abbreviatedRate(bytesPerSecond: 1_550_000), "1.6 M")
    }
}
```
