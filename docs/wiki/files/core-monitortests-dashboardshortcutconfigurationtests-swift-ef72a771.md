# File: Core-MonitorTests/DashboardShortcutConfigurationTests.swift

## Current Role

- Area: Tests.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-MonitorTests/DashboardShortcutConfigurationTests.swift`](../../../Core-MonitorTests/DashboardShortcutConfigurationTests.swift) |
| Wiki area | Tests |
| Exists in current checkout | True |
| Size | 487 bytes |
| Binary | False |
| Line count | 15 |
| Extension | `.swift` |

## Imports

`Carbon`, `XCTest`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `DashboardShortcutConfigurationTests` | 3 |
| func | `testDashboardShortcutUsesOptionCommandM` | 6 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `7c0c8d6` | 2026-04-16 | Add dashboard shortcut and app menu access |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import Carbon
import XCTest
@testable import Core_Monitor

final class DashboardShortcutConfigurationTests: XCTestCase {
    func testDashboardShortcutUsesOptionCommandM() {
        XCTAssertEqual(DashboardShortcutConfiguration.keyEquivalent, "m")
        XCTAssertEqual(DashboardShortcutConfiguration.displayLabel, "Option-Command-M")
        XCTAssertEqual(
            DashboardShortcutConfiguration.carbonModifiers(),
            UInt32(optionKey) | UInt32(cmdKey)
        )
    }
}
```
