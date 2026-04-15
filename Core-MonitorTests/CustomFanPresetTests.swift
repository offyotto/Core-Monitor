import XCTest
import CoreGraphics
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

    func testFanCurveChartGeometryRoundTripsPointCoordinates() {
        let point = CustomFanPreset.CurvePoint(temperatureC: 64, speedPercent: 57)
        let size = CGSize(width: 420, height: 230)

        let plotPoint = FanCurveChartGeometry.plotPoint(for: point, size: size)
        let values = FanCurveChartGeometry.values(for: plotPoint, size: size)

        XCTAssertEqual(values.temperature, point.temperatureC, accuracy: 0.001)
        XCTAssertEqual(values.speed, point.speedPercent, accuracy: 0.001)
    }

    func testFanCurveChartGeometryClampsDraggedPointBetweenNeighbors() {
        let points: [CustomFanPreset.CurvePoint] = [
            .init(temperatureC: 40, speedPercent: 20),
            .init(temperatureC: 60, speedPercent: 50),
            .init(temperatureC: 80, speedPercent: 90),
        ]

        let clampedHigh = FanCurveChartGeometry.clampedValues(
            for: points[1].id,
            rawTemperature: 120,
            rawSpeed: 140,
            points: points
        )
        let clampedLow = FanCurveChartGeometry.clampedValues(
            for: points[1].id,
            rawTemperature: 10,
            rawSpeed: -10,
            points: points
        )

        XCTAssertEqual(clampedHigh?.temperature, 79)
        XCTAssertEqual(clampedHigh?.speed, 100)
        XCTAssertEqual(clampedLow?.temperature, 41)
        XCTAssertEqual(clampedLow?.speed, 0)
    }

    func testFanCurveChartGeometrySelectsNearestHandleInsteadOfDefaultingToLastPoint() {
        let points: [CustomFanPreset.CurvePoint] = [
            .init(temperatureC: 40, speedPercent: 20),
            .init(temperatureC: 60, speedPercent: 50),
            .init(temperatureC: 80, speedPercent: 90),
        ]
        let size = CGSize(width: 420, height: 230)
        let middleHandle = FanCurveChartGeometry.plotPoint(for: points[1], size: size)
        let selectedPointID = FanCurveChartGeometry.nearestPointID(
            to: CGPoint(x: middleHandle.x + 6, y: middleHandle.y - 4),
            size: size,
            points: points
        )

        XCTAssertEqual(selectedPointID, points[1].id)
    }

    func testTouchBarCommandRunnerRejectsControlCharacters() {
        XCTAssertNil(TouchBarCommandRunner.sanitizedCommand(from: "echo hello\nrm -rf /"))
        XCTAssertNil(TouchBarCommandRunner.sanitizedCommand(from: "\u{0}"))
    }

    func testTouchBarCommandRunnerUsesIsolatedShellConfiguration() {
        let command = "open /Applications"
        let process = TouchBarCommandRunner.makeProcess(for: command)

        XCTAssertNotNil(process)
        XCTAssertEqual(process?.executableURL?.path, "/bin/zsh")
        XCTAssertEqual(process?.arguments ?? [], ["-f", "-c", command])
        XCTAssertEqual(process?.environment?["PATH"], "/usr/bin:/bin:/usr/sbin:/sbin")
        XCTAssertEqual(process?.environment?["SHELL"], "/bin/zsh")
        XCTAssertEqual(process?.currentDirectoryURL, FileManager.default.homeDirectoryForCurrentUser)
    }

    func testMonitoringTrendSeriesTrimsSamplesOutsideRetentionWindow() {
        var series = MonitoringTrendSeries(retention: 60)
        let start = Date(timeIntervalSinceReferenceDate: 1_000)

        series.append(45, at: start)
        series.append(55, at: start.addingTimeInterval(30))
        series.append(65, at: start.addingTimeInterval(61))

        XCTAssertEqual(series.count, 2)
        XCTAssertEqual(series.values(for: .fifteenMinutes, now: start.addingTimeInterval(61)), [55, 65])
    }

    func testMonitoringTrendSeriesSummaryUsesSelectedRangeWindow() {
        var series = MonitoringTrendSeries(retention: MonitoringTrendRange.fifteenMinutes.duration)
        let start = Date(timeIntervalSinceReferenceDate: 5_000)

        series.append(40, at: start)
        series.append(50, at: start.addingTimeInterval(120))
        series.append(70, at: start.addingTimeInterval(240))
        series.append(55, at: start.addingTimeInterval(360))

        let oneMinuteSummary = series.summary(for: .oneMinute, now: start.addingTimeInterval(360))
        let fiveMinuteSummary = series.summary(for: .fiveMinutes, now: start.addingTimeInterval(360))

        XCTAssertNotNil(oneMinuteSummary)
        XCTAssertNotNil(fiveMinuteSummary)
        XCTAssertEqual(oneMinuteSummary?.latest, 55)
        XCTAssertEqual(oneMinuteSummary?.minimum, 55)
        XCTAssertEqual(oneMinuteSummary?.maximum, 55)
        XCTAssertEqual(oneMinuteSummary?.average, 55)
        XCTAssertEqual(oneMinuteSummary?.delta, 0)

        XCTAssertEqual(fiveMinuteSummary?.latest, 55)
        XCTAssertEqual(fiveMinuteSummary?.minimum, 50)
        XCTAssertEqual(fiveMinuteSummary?.maximum, 70)
        XCTAssertEqual(fiveMinuteSummary?.average ?? 0, 58.333333333333336, accuracy: 0.0001)
        XCTAssertEqual(fiveMinuteSummary?.delta, 5)
    }
}
