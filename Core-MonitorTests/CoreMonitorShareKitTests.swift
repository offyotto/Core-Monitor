import XCTest
@testable import Core_Monitor

final class CoreMonitorShareKitTests: XCTestCase {
    func testProductPitchUsesCanonicalInstallAndSourceLinks() {
        let pitch = CoreMonitorShareKit.productPitch()

        XCTAssertTrue(pitch.contains("free, open-source Apple Silicon system monitor"))
        XCTAssertTrue(pitch.contains("https://offyotto.github.io/Core-Monitor/"))
        XCTAssertTrue(pitch.contains("https://github.com/offyotto/Core-Monitor/releases/latest"))
        XCTAssertTrue(pitch.contains("https://github.com/offyotto/Core-Monitor"))
        XCTAssertFalse(pitch.contains("offyotto-sl3"))
    }

    func testSupportSnapshotFormatsHardwareStateWithoutProcessNames() {
        let context = CoreMonitorShareSnapshotContext(
            generatedAt: Date(timeIntervalSince1970: 1_000),
            appVersion: "15.2.2 (15202)",
            macOSVersion: "Version 15.5",
            hostModelIdentifier: "Mac16,7",
            hostModelName: "MacBook Pro (16-inch, 2024, M4 Pro/Max)",
            chipName: "Apple M4 Pro",
            cpuUsagePercent: 31.4,
            performanceCoreUsagePercent: 42.2,
            efficiencyCoreUsagePercent: 12.3,
            memoryUsagePercent: 54.6,
            memoryUsedGB: 9.4,
            totalMemoryGB: 18,
            cpuTemperature: 62.2,
            gpuTemperature: nil,
            ssdTemperature: 41.8,
            fanSpeeds: [2180, 2215],
            fanModeTitle: "System Automatic",
            helperStateTitle: "Reachable",
            helperInstalled: true,
            batteryChargePercent: 81,
            batteryPowerWatts: -12.4,
            totalSystemWatts: 18.6,
            thermalStateTitle: "Nominal",
            hasSMCAccess: true,
            smcError: nil
        )

        let report = CoreMonitorShareKit.supportSnapshotMarkdown(from: context)

        XCTAssertTrue(report.contains("# Core-Monitor Support Snapshot"))
        XCTAssertTrue(report.contains("- Generated: 1970-01-01T00:16:40Z"))
        XCTAssertTrue(report.contains("- Mac: MacBook Pro (16-inch, 2024, M4 Pro/Max) (Mac16,7)"))
        XCTAssertTrue(report.contains("- CPU: 31%"))
        XCTAssertTrue(report.contains("- P-cores: 42%"))
        XCTAssertTrue(report.contains("- E-cores: 12%"))
        XCTAssertTrue(report.contains("- Memory: 9.4 GB of 18 GB (55%)"))
        XCTAssertTrue(report.contains("- GPU temperature: Unavailable"))
        XCTAssertTrue(report.contains("- Fans: 2180 RPM, 2215 RPM"))
        XCTAssertTrue(report.contains("- Helper: Reachable (installed: yes)"))
        XCTAssertFalse(report.localizedCaseInsensitiveContains("Safari"))
        XCTAssertFalse(report.localizedCaseInsensitiveContains("process"))
    }

    func testSupportSnapshotCarriesSMCNoteOnlyWhenPresent() {
        let context = CoreMonitorShareSnapshotContext(
            generatedAt: Date(timeIntervalSince1970: 2_000),
            appVersion: "Development",
            macOSVersion: "Version 15.5",
            hostModelIdentifier: "Mac14,2",
            hostModelName: "MacBook Pro (13-inch, 2022, M2)",
            chipName: "Apple M2",
            cpuUsagePercent: 10,
            performanceCoreUsagePercent: nil,
            efficiencyCoreUsagePercent: nil,
            memoryUsagePercent: 25,
            memoryUsedGB: 4,
            totalMemoryGB: 16,
            cpuTemperature: nil,
            gpuTemperature: nil,
            ssdTemperature: nil,
            fanSpeeds: [],
            fanModeTitle: "Balanced",
            helperStateTitle: "Missing",
            helperInstalled: false,
            batteryChargePercent: nil,
            batteryPowerWatts: nil,
            totalSystemWatts: nil,
            thermalStateTitle: "Fair",
            hasSMCAccess: false,
            smcError: "AppleSMC could not be opened."
        )

        let report = CoreMonitorShareKit.supportSnapshotMarkdown(from: context)

        XCTAssertTrue(report.contains("- SMC access: Unavailable"))
        XCTAssertTrue(report.contains("- SMC note: AppleSMC could not be opened."))
        XCTAssertTrue(report.contains("- Fans: Unavailable"))
        XCTAssertTrue(report.contains("- Battery: Unavailable"))
    }
}
