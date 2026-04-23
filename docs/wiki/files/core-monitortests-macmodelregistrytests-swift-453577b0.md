# File: Core-MonitorTests/MacModelRegistryTests.swift

## Current Role

- Area: Tests.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-MonitorTests/MacModelRegistryTests.swift`](../../../Core-MonitorTests/MacModelRegistryTests.swift) |
| Wiki area | Tests |
| Exists in current checkout | True |
| Size | 3310 bytes |
| Binary | False |
| Line count | 95 |
| Extension | `.swift` |

## Imports

`XCTest`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `MacModelRegistryTests` | 2 |
| func | `testDisplayNameFallsBackToIdentifierWhenModelIsUnknown` | 5 |
| func | `testRegistryMapsModernMacBookProIdentifiersAccurately` | 8 |
| func | `testRegistryIncludesRecentAppleSiliconMacsAcrossFamilies` | 24 |
| func | `testEntriesUseUniqueHardwareModelIdentifiers` | 43 |
| func | `testAppleSiliconDelayedResponseCaveatOnlyAppearsForManagedMacBookProsWithFans` | 47 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `006d70b` | 2026-04-16 | Refresh Mac model registry and fan guidance |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import XCTest
@testable import Core_Monitor

final class MacModelRegistryTests: XCTestCase {
    func testDisplayNameFallsBackToIdentifierWhenModelIsUnknown() {
        XCTAssertEqual(MacModelRegistry.displayName(for: "MysteryMac1,1"), "MysteryMac1,1")
    }

    func testRegistryMapsModernMacBookProIdentifiersAccurately() {
        XCTAssertEqual(
            MacModelRegistry.entry(for: "Mac15,10")?.friendlyName,
            "MacBook Pro (14-inch, Nov 2023, M3 Pro/Max)"
        )
        XCTAssertEqual(
            MacModelRegistry.entry(for: "Mac16,7")?.friendlyName,
            "MacBook Pro (16-inch, 2024, M4 Pro/Max)"
        )
        XCTAssertEqual(
            MacModelRegistry.entry(for: "Mac17,2")?.friendlyName,
            "MacBook Pro (14-inch, 2025, M5)"
        )
        XCTAssertEqual(MacModelRegistry.entry(for: "Mac16,7")?.family, .macBookProMSeries)
    }

    func testRegistryIncludesRecentAppleSiliconMacsAcrossFamilies() {
        XCTAssertEqual(
            MacModelRegistry.entry(for: "Mac16,12")?.friendlyName,
            "MacBook Air (13-inch, 2025, M4)"
        )
        XCTAssertEqual(
            MacModelRegistry.entry(for: "Mac16,11")?.friendlyName,
            "Mac mini (2024)"
        )
        XCTAssertEqual(
            MacModelRegistry.entry(for: "Mac16,3")?.friendlyName,
            "iMac (24-inch, 2024, Four ports)"
        )
        XCTAssertEqual(
            MacModelRegistry.entry(for: "Mac15,14")?.friendlyName,
            "Mac Studio (2025, M3 Ultra)"
```
