# File: Core-MonitorTests/LaunchAtLoginStatusSummaryTests.swift

## Current Role

- Area: Tests.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-MonitorTests/LaunchAtLoginStatusSummaryTests.swift`](../../../Core-MonitorTests/LaunchAtLoginStatusSummaryTests.swift) |
| Wiki area | Tests |
| Exists in current checkout | True |
| Size | 1807 bytes |
| Binary | False |
| Line count | 47 |
| Extension | `.swift` |

## Imports

`XCTest`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `LaunchAtLoginStatusSummaryTests` | 2 |
| func | `testEnabledStatusUsesHealthySummaryByDefault` | 5 |
| func | `testDisabledStatusOffersEnableAction` | 13 |
| func | `testRequiresApprovalOpensLoginItemsSettings` | 22 |
| func | `testPermissionErrorWhileDisabledKeepsSettingsActionAvailable` | 34 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `cfea009` | 2026-04-16 | Polish launch-at-login recovery flow |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import XCTest
@testable import Core_Monitor

final class LaunchAtLoginStatusSummaryTests: XCTestCase {
    func testEnabledStatusUsesHealthySummaryByDefault() {
        let summary = LaunchAtLoginStatusSummary.make(status: .enabled, errorMessage: nil)

        XCTAssertEqual(summary.badge, "Enabled")
        XCTAssertEqual(summary.tone, .positive)
        XCTAssertNil(summary.action)
        XCTAssertNil(summary.actionTitle)
    }

    func testDisabledStatusOffersEnableAction() {
        let summary = LaunchAtLoginStatusSummary.make(status: .disabled, errorMessage: nil)

        XCTAssertEqual(summary.badge, "Optional")
        XCTAssertEqual(summary.tone, .neutral)
        XCTAssertEqual(summary.action, .enable)
        XCTAssertEqual(summary.actionTitle, "Enable")
    }

    func testRequiresApprovalOpensLoginItemsSettings() {
        let summary = LaunchAtLoginStatusSummary.make(
            status: .requiresApproval,
            errorMessage: "Launch at Login needs approval in System Settings > General > Login Items."
        )

        XCTAssertEqual(summary.badge, "Approval Needed")
        XCTAssertEqual(summary.tone, .caution)
        XCTAssertEqual(summary.action, .openSystemSettings)
        XCTAssertEqual(summary.actionTitle, "Open Login Items")
    }

    func testPermissionErrorWhileDisabledKeepsSettingsActionAvailable() {
        let summary = LaunchAtLoginStatusSummary.make(
            status: .disabled,
            errorMessage: "Permission denied. Open System Settings > General > Login Items to allow Core-Monitor."
        )

```
