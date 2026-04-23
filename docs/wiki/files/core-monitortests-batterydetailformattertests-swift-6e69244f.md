# File: Core-MonitorTests/BatteryDetailFormatterTests.swift

## Current Role

- Area: Tests.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-MonitorTests/BatteryDetailFormatterTests.swift`](../../../Core-MonitorTests/BatteryDetailFormatterTests.swift) |
| Wiki area | Tests |
| Exists in current checkout | True |
| Size | 1533 bytes |
| Binary | False |
| Line count | 37 |
| Extension | `.swift` |

## Imports

`XCTest`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `BatteryDetailFormatterTests` | 2 |
| func | `testChargingRuntimeUsesPowerAdapterLanguage` | 5 |
| func | `testBatteryRuntimeUsesRemainingLanguage` | 17 |
| func | `testFormatterUsesStablePrecisionForElectricalValues` | 30 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `16df8e4` | 2026-04-16 | Refine battery diagnostics and dashboard state flow |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import XCTest
@testable import Core_Monitor

final class BatteryDetailFormatterTests: XCTestCase {
    func testChargingRuntimeUsesPowerAdapterLanguage() {
        var info = BatteryInfo()
        info.hasBattery = true
        info.isCharging = true
        info.isPluggedIn = true
        info.timeRemainingMinutes = 95
        info.source = "AC Power"

        XCTAssertEqual(BatteryDetailFormatter.powerStateDescription(for: info), "Charging")
        XCTAssertEqual(BatteryDetailFormatter.sourceDescription(for: info), "Power Adapter")
        XCTAssertEqual(BatteryDetailFormatter.runtimeDescription(for: info), "1h 35m until full")
    }

    func testBatteryRuntimeUsesRemainingLanguage() {
        var info = BatteryInfo()
        info.hasBattery = true
        info.isCharging = false
        info.isPluggedIn = false
        info.timeRemainingMinutes = 42
        info.source = "Battery Power"

        XCTAssertEqual(BatteryDetailFormatter.powerStateDescription(for: info), "Battery Power")
        XCTAssertEqual(BatteryDetailFormatter.sourceDescription(for: info), "Internal Battery")
        XCTAssertEqual(BatteryDetailFormatter.runtimeDescription(for: info), "42m remaining")
    }

    func testFormatterUsesStablePrecisionForElectricalValues() {
        XCTAssertEqual(BatteryDetailFormatter.temperatureDescription(31.26), "31.3 °C")
        XCTAssertEqual(BatteryDetailFormatter.voltageDescription(12.345), "12.35 V")
        XCTAssertEqual(BatteryDetailFormatter.amperageDescription(-1.234), "-1.23 A")
    }
}
```
