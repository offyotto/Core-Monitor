# File: Core-MonitorTests/HelpViewSearchTests.swift

## Current Role

- Area: Tests.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-MonitorTests/HelpViewSearchTests.swift`](../../../Core-MonitorTests/HelpViewSearchTests.swift) |
| Wiki area | Tests |
| Exists in current checkout | True |
| Size | 3344 bytes |
| Binary | False |
| Line count | 90 |
| Extension | `.swift` |

## Imports

`SwiftUI`, `XCTest`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `HelpViewSearchTests` | 3 |
| func | `testHelpSectionMatchesKeywordsAndTitleCaseInsensitively` | 6 |
| func | `testHelpSectionRequiresAllQueryTokensToMatch` | 19 |
| func | `testHelpSectionMatchesMenuBarRecoveryLanguage` | 32 |
| func | `testHelpSectionMatchesBatteryRuntimeAndElectricalKeywords` | 47 |
| func | `testHelpSectionMatchesNetworkThroughputKeywords` | 61 |
| func | `testHelpSectionMatchesDashboardShortcutKeywords` | 75 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `7c0c8d6` | 2026-04-16 | Add dashboard shortcut and app menu access |
| `be75b81` | 2026-04-16 | Add dashboard network throughput visibility |
| `0574661` | 2026-04-16 | Sync menu bar guidance with the latest thermal UX |
| `86747c6` | 2026-04-16 | Refresh in-app help for trends and battery details |
| `f7b2ac8` | 2026-04-16 | Clarify menu bar visibility recovery in support docs |
| `84427d5` | 2026-04-16 | Improve in-app help search discoverability |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import SwiftUI
import XCTest
@testable import Core_Monitor

final class HelpViewSearchTests: XCTestCase {
    func testHelpSectionMatchesKeywordsAndTitleCaseInsensitively() {
        let section = HelpView.HelpSection(
            id: "system",
            title: "System Controls",
            icon: "gearshape",
            keywords: ["launch at login", "login items", "helper diagnostics"],
            content: AnyView(EmptyView())
        )

        XCTAssertTrue(section.matches(query: "system"))
        XCTAssertTrue(section.matches(query: "LOGIN"))
        XCTAssertTrue(section.matches(query: "helper"))
    }

    func testHelpSectionRequiresAllQueryTokensToMatch() {
        let section = HelpView.HelpSection(
            id: "weather",
            title: "Weather Permission Tips",
            icon: "cloud.sun.rain.fill",
            keywords: ["weatherkit", "location services", "permission"],
            content: AnyView(EmptyView())
        )

        XCTAssertTrue(section.matches(query: "weather location"))
        XCTAssertFalse(section.matches(query: "weather helper"))
    }

    func testHelpSectionMatchesMenuBarRecoveryLanguage() {
        let section = HelpView.HelpSection(
            id: "menubar",
            title: "Menu Bar Items and Popovers",
            icon: "menubar.rectangle",
            keywords: ["fan", "rpm", "allow in menu bar", "hidden icon", "missing icon", "macos 26"],
            content: AnyView(EmptyView())
        )
```
