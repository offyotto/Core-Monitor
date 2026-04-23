# File: Core-MonitorTests/CoreMonitorPlatformCopyTests.swift

## Current Role

- Area: Tests.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-MonitorTests/CoreMonitorPlatformCopyTests.swift`](../../../Core-MonitorTests/CoreMonitorPlatformCopyTests.swift) |
| Wiki area | Tests |
| Exists in current checkout | True |
| Size | 1500 bytes |
| Binary | False |
| Line count | 41 |
| Extension | `.swift` |

## Imports

`XCTest`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `CoreMonitorPlatformCopyTests` | 2 |
| func | `testAppleSiliconCopyUsesArchitectureSpecificLanguage` | 5 |
| func | `testIntelCopyStaysArchitectureNeutral` | 22 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `6cabf2c` | 2026-04-16 | Make onboarding copy platform-aware |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import XCTest
@testable import Core_Monitor

final class CoreMonitorPlatformCopyTests: XCTestCase {
    func testAppleSiliconCopyUsesArchitectureSpecificLanguage() {
        XCTAssertEqual(
            CoreMonitorPlatformCopy.welcomeIntroSubheadline(isAppleSilicon: true),
            "Your M-series Mac, fully visible."
        )
        XCTAssertTrue(
            CoreMonitorPlatformCopy.welcomeIntroBody(isAppleSilicon: true).contains("Apple Silicon Mac")
        )
        XCTAssertEqual(
            CoreMonitorPlatformCopy.thermalMetricsBullet(isAppleSilicon: true),
            "P-core and E-core usage, plus CPU temperature"
        )
        XCTAssertEqual(
            CoreMonitorPlatformCopy.thermalStatusDetail(isAppleSilicon: true),
            "macOS thermal pressure on Apple Silicon."
        )
    }

    func testIntelCopyStaysArchitectureNeutral() {
        XCTAssertEqual(
            CoreMonitorPlatformCopy.welcomeIntroSubheadline(isAppleSilicon: false),
            "Your Mac, fully visible."
        )
        XCTAssertFalse(
            CoreMonitorPlatformCopy.welcomeIntroBody(isAppleSilicon: false).contains("Apple Silicon")
        )
        XCTAssertEqual(
            CoreMonitorPlatformCopy.thermalMetricsBullet(isAppleSilicon: false),
            "CPU usage and temperature"
        )
        XCTAssertEqual(
            CoreMonitorPlatformCopy.thermalStatusDetail(isAppleSilicon: false),
            "macOS thermal pressure reported by the system."
        )
    }
}
```
