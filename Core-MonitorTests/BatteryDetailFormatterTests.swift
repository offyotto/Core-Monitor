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
