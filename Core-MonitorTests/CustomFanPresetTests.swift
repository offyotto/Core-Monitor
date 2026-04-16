import XCTest
import CoreGraphics
@testable import Core_Monitor

@MainActor
final class CustomFanPresetTests: XCTestCase {
    func testDefaultFanModeIsSystemAutomatic() {
        XCTAssertEqual(FanController.defaultMode, .automatic)
    }

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

    func testManagedFanModesExposeQuitRestoreGuidance() {
        XCTAssertTrue(FanControlMode.smart.guidance.restoresSystemAutomaticOnExit)
        XCTAssertTrue(FanControlMode.manual.guidance.restoresSystemAutomaticOnExit)
        XCTAssertFalse(FanControlMode.automatic.guidance.restoresSystemAutomaticOnExit)
    }

    func testSystemOwnedModesAreMarkedAsSystemControlled() {
        XCTAssertEqual(FanControlMode.automatic.guidance.ownership, .system)
        XCTAssertEqual(FanControlMode.silent.guidance.ownership, .system)
        XCTAssertEqual(FanControlMode.custom.guidance.ownership, .coreMonitor)
        XCTAssertFalse(FanControlMode.silent.requiresPrivilegedHelper)
        XCTAssertFalse(FanControlMode.silent.guidance.requiresHelper)
    }

    func testAppleSiliconCaveatOnlyAppearsForManagedModes() {
        XCTAssertTrue(FanControlMode.smart.guidance.showsAppleSiliconDelayedResponseNote)
        XCTAssertTrue(FanControlMode.manual.guidance.showsAppleSiliconDelayedResponseNote)
        XCTAssertFalse(FanControlMode.silent.guidance.showsAppleSiliconDelayedResponseNote)
        XCTAssertFalse(FanControlMode.automatic.guidance.showsAppleSiliconDelayedResponseNote)
    }

    func testMonitoringSnapshotHealthReportsWaitingBeforeFirstSample() {
        let now = Date(timeIntervalSinceReferenceDate: 12_000)
        let health = MonitoringSnapshotHealth(sampledAt: .distantPast, expectedInterval: 1, now: now)

        XCTAssertEqual(health.freshness, .waiting)
        XCTAssertNil(health.sampledAt)
        XCTAssertNil(health.age)
        XCTAssertEqual(health.statusLabel, "Waiting")
        XCTAssertEqual(health.ageDescription, "Waiting for the first sample")
        XCTAssertEqual(health.cadenceDescription, "Cadence 1s")
    }

    func testMonitoringSnapshotHealthDistinguishesLiveDelayedAndStaleSamples() {
        let now = Date(timeIntervalSinceReferenceDate: 20_000)

        let live = MonitoringSnapshotHealth(sampledAt: now.addingTimeInterval(-1), expectedInterval: 1, now: now)
        let delayed = MonitoringSnapshotHealth(sampledAt: now.addingTimeInterval(-4), expectedInterval: 1, now: now)
        let stale = MonitoringSnapshotHealth(sampledAt: now.addingTimeInterval(-13), expectedInterval: 1, now: now)

        XCTAssertEqual(live.freshness, .live)
        XCTAssertEqual(live.statusLabel, "Live")
        XCTAssertEqual(live.ageDescription, "Updated just now")

        XCTAssertEqual(delayed.freshness, .delayed)
        XCTAssertEqual(delayed.statusLabel, "Delayed")
        XCTAssertEqual(delayed.ageDescription, "Updated 4s ago")

        XCTAssertEqual(stale.freshness, .stale)
        XCTAssertEqual(stale.statusLabel, "Stale")
        XCTAssertEqual(stale.ageDescription, "Updated 13s ago")
    }

    func testMonitoringSnapshotHealthFormatsCompactDurations() {
        XCTAssertEqual(MonitoringSnapshotHealth.compactDurationDescription(1), "1s")
        XCTAssertEqual(MonitoringSnapshotHealth.compactDurationDescription(30), "30s")
        XCTAssertEqual(MonitoringSnapshotHealth.compactDurationDescription(90), "1m 30s")
        XCTAssertEqual(MonitoringSnapshotHealth.compactDurationDescription(120), "2m")
    }

    func testMenuBarStatusSummaryMakesHelperOptionalInSystemOwnedModes() {
        let automatic = MenuBarStatusSummary.helperSummary(
            for: .automatic,
            connectionState: .missing,
            isInstalled: false
        )
        let silent = MenuBarStatusSummary.helperSummary(
            for: .silent,
            connectionState: .unreachable,
            isInstalled: true
        )

        XCTAssertEqual(automatic.label, "Helper Optional")
        XCTAssertEqual(automatic.tone, .neutral)
        XCTAssertEqual(silent.label, "Helper Optional")
        XCTAssertEqual(silent.tone, .neutral)
    }

    func testMenuBarStatusSummaryKeepsManagedModesExplicitAboutHelperProblems() {
        let missing = MenuBarStatusSummary.helperSummary(
            for: .smart,
            connectionState: .missing,
            isInstalled: false
        )
        let reachable = MenuBarStatusSummary.helperSummary(
            for: .smart,
            connectionState: .reachable,
            isInstalled: true
        )

        XCTAssertEqual(missing.label, "Helper Missing")
        XCTAssertEqual(missing.tone, .warning)
        XCTAssertEqual(reachable.label, "Helper Ready")
        XCTAssertEqual(reachable.tone, .good)
    }

    func testMenuBarStatusSummaryReflectsFanOwnershipInModePill() {
        let automatic = MenuBarStatusSummary.fanModeSummary(for: .automatic)
        let silent = MenuBarStatusSummary.fanModeSummary(for: .silent)
        let smart = MenuBarStatusSummary.fanModeSummary(for: .smart)

        XCTAssertEqual(automatic.label, "System Cooling")
        XCTAssertEqual(automatic.tone, .good)
        XCTAssertEqual(silent.label, "Mode SILENT")
        XCTAssertEqual(silent.tone, .good)
        XCTAssertEqual(smart.label, "Mode SMART")
        XCTAssertEqual(smart.tone, .accent)
    }
}

@MainActor
final class MenuBarSettingsTests: XCTestCase {
    func testFreshSettingsDefaultToBalancedPreset() {
        let settings = MenuBarSettings(defaults: makeDefaults())

        XCTAssertEqual(settings.activePreset, .balanced)
        XCTAssertTrue(settings.isEnabled(.cpu))
        XCTAssertTrue(settings.isEnabled(.memory))
        XCTAssertFalse(settings.isEnabled(.network))
        XCTAssertFalse(settings.isEnabled(.disk))
        XCTAssertTrue(settings.isEnabled(.temperature))
    }

    func testRestoreDefaultsReturnsToBalancedPreset() {
        let settings = MenuBarSettings(defaults: makeDefaults())

        settings.applyPreset(.full)
        XCTAssertEqual(settings.activePreset, .full)

        settings.restoreDefaults()

        XCTAssertEqual(settings.activePreset, .balanced)
        XCTAssertFalse(settings.isEnabled(.network))
        XCTAssertFalse(settings.isEnabled(.disk))
    }

    func testInaccessibleConfigurationRestoresBalancedPreset() {
        let defaults = makeDefaults()
        MenuBarItemKind.allCases.forEach { defaults.set(false, forKey: $0.defaultsKey) }

        let settings = MenuBarSettings(defaults: defaults)

        XCTAssertEqual(settings.activePreset, .balanced)
        XCTAssertEqual(
            settings.lastWarning,
            "Core Monitor restored the Balanced menu bar preset so the app stays reachable."
        )
    }

    func testFullPresetEnablesNetworkItem() {
        let settings = MenuBarSettings(defaults: makeDefaults())

        settings.applyPreset(.full)

        XCTAssertTrue(settings.isEnabled(.network))
        XCTAssertTrue(settings.isEnabled(.disk))
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "MenuBarSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}

@MainActor
final class TopProcessSamplerTests: XCTestCase {
    func testSamplerDoesNotRestartWhenSameIntervalIsAlreadyActive() {
        XCTAssertFalse(
            TopProcessSampler.shouldRestartTimer(
                isRunning: true,
                currentInterval: 5,
                requestedInterval: 5
            )
        )
    }

    func testSamplerRestartsWhenStoppedOrIntervalChanges() {
        XCTAssertTrue(
            TopProcessSampler.shouldRestartTimer(
                isRunning: false,
                currentInterval: 5,
                requestedInterval: 5
            )
        )
        XCTAssertTrue(
            TopProcessSampler.shouldRestartTimer(
                isRunning: true,
                currentInterval: 5,
                requestedInterval: 30
            )
        )
    }
}
