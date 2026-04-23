# File: Core-MonitorTests/DashboardWindowLayoutTests.swift

## Current Role

- Area: Tests.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-MonitorTests/DashboardWindowLayoutTests.swift`](../../../Core-MonitorTests/DashboardWindowLayoutTests.swift) |
| Wiki area | Tests |
| Exists in current checkout | True |
| Size | 1431 bytes |
| Binary | False |
| Line count | 38 |
| Extension | `.swift` |

## Imports

`AppKit`, `XCTest`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `DashboardWindowLayoutTests` | 3 |
| func | `testTargetContentSizeUsesLargerLaptopFriendlyDefault` | 6 |
| func | `testTargetContentSizeRespectsSmallDisplayBounds` | 14 |
| func | `testShouldResetFrameWhenWindowIsTooShortForDashboard` | 23 |
| func | `testShouldNotResetFrameWhenWindowFitsComfortably` | 30 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `7baad89` | 2026-04-16 | Refine dashboard window sizing |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import AppKit
import XCTest
@testable import Core_Monitor

final class DashboardWindowLayoutTests: XCTestCase {
    func testTargetContentSizeUsesLargerLaptopFriendlyDefault() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1512, height: 945)

        let size = DashboardWindowLayout.targetContentSize(for: visibleFrame)

        XCTAssertEqual(size.width, 1080, accuracy: 0.001)
        XCTAssertEqual(size.height, 720, accuracy: 0.001)
    }

    func testTargetContentSizeRespectsSmallDisplayBounds() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1024, height: 700)

        let size = DashboardWindowLayout.targetContentSize(for: visibleFrame)

        XCTAssertEqual(size.width, 944, accuracy: 0.001)
        XCTAssertEqual(size.height, 640, accuracy: 0.001)
    }

    func testShouldResetFrameWhenWindowIsTooShortForDashboard() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1512, height: 945)
        let frame = CGRect(x: 80, y: 80, width: 948, height: 560)

        XCTAssertTrue(DashboardWindowLayout.shouldResetFrame(windowFrame: frame, visibleFrame: visibleFrame))
    }

    func testShouldNotResetFrameWhenWindowFitsComfortably() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1512, height: 945)
        let frame = CGRect(x: 80, y: 80, width: 1080, height: 720)

        XCTAssertFalse(DashboardWindowLayout.shouldResetFrame(windowFrame: frame, visibleFrame: visibleFrame))
    }
}
```
