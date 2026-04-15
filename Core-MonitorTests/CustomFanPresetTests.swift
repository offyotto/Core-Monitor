import XCTest
@testable import Core_Monitor

final class CustomFanPresetTests: XCTestCase {
    func testCurvePointDecodesLegacyJSONWithoutIdentifier() throws {
        let data = Data(
            """
            {
              "name": "Legacy",
              "version": 1,
              "sensor": "cpu",
              "points": [
                { "temperatureC": 40, "speedPercent": 25 },
                { "temperatureC": 80, "speedPercent": 100 }
              ]
            }
            """.utf8
        )

        let preset = try JSONDecoder().decode(CustomFanPreset.self, from: data)

        XCTAssertEqual(preset.points.count, 2)
        XCTAssertNotEqual(preset.points[0].id, preset.points[1].id)
    }

    func testValidationRejectsDescendingTemperatures() {
        let preset = CustomFanPreset(
            name: "Broken",
            version: 1,
            sensor: .cpu,
            updateIntervalSeconds: 2,
            smoothingStepRPM: 75,
            minimumRPM: 1400,
            maximumRPM: 6200,
            perFanRPMOffset: nil,
            powerBoost: .init(),
            points: [
                .init(temperatureC: 70, speedPercent: 50),
                .init(temperatureC: 60, speedPercent: 65),
            ]
        )

        XCTAssertTrue(
            preset.validationErrors(globalMinRPM: 1000, globalMaxRPM: 6500)
                .contains("Curve temperatures must be strictly increasing.")
        )
    }

    func testInterpolationReturnsExpectedMidpoint() {
        let preset = CustomFanPreset(
            name: "Interp",
            version: 1,
            sensor: .cpu,
            updateIntervalSeconds: 2,
            smoothingStepRPM: 75,
            minimumRPM: 1400,
            maximumRPM: 6200,
            perFanRPMOffset: nil,
            powerBoost: .init(),
            points: [
                .init(temperatureC: 40, speedPercent: 20),
                .init(temperatureC: 80, speedPercent: 100),
            ]
        )

        XCTAssertEqual(preset.interpolatedSpeedPercent(for: 60), 60, accuracy: 0.001)
    }
}
