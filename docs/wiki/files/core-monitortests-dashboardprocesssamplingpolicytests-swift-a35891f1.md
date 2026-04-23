# File: Core-MonitorTests/DashboardProcessSamplingPolicyTests.swift

## Current Role

- Area: Tests.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-MonitorTests/DashboardProcessSamplingPolicyTests.swift`](../../../Core-MonitorTests/DashboardProcessSamplingPolicyTests.swift) |
| Wiki area | Tests |
| Exists in current checkout | True |
| Size | 1355 bytes |
| Binary | False |
| Line count | 42 |
| Extension | `.swift` |

## Imports

`XCTest`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `DashboardProcessSamplingPolicyTests` | 2 |
| func | `testBasicModeNeverRequestsDetailedSampling` | 5 |
| func | `testMemoryViewRequestsDetailedSampling` | 16 |
| func | `testNonProcessDashboardViewsStayOnBackgroundSampling` | 25 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `a570f09` | 2026-04-16 | Scope detailed sampling to active monitoring views |
| `1cc987e` | 2026-04-16 | Scope dashboard process sampling by surface |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import XCTest
@testable import Core_Monitor

final class DashboardProcessSamplingPolicyTests: XCTestCase {
    func testBasicModeNeverRequestsDetailedSampling() {
        for selection in SidebarItem.allCases {
            XCTAssertFalse(
                DashboardProcessSamplingPolicy.requiresDetailedSampling(
                    isBasicMode: true,
                    selection: selection
                ),
                "\(selection.rawValue) should stay on background sampling in Basic Mode."
            )
        }
    }

    func testMemoryViewRequestsDetailedSampling() {
        XCTAssertTrue(
            DashboardProcessSamplingPolicy.requiresDetailedSampling(
                isBasicMode: false,
                selection: .memory
            )
        )
    }

    func testNonProcessDashboardViewsStayOnBackgroundSampling() {
        let lowDetailSelections: [SidebarItem] = [
            .overview, .thermals, .fans, .battery, .system, .touchBar, .help, .about
        ]

        for selection in lowDetailSelections {
            XCTAssertFalse(
                DashboardProcessSamplingPolicy.requiresDetailedSampling(
                    isBasicMode: false,
                    selection: selection
                ),
                "\(selection.rawValue) should not force detailed process sampling."
            )
        }
    }
```
