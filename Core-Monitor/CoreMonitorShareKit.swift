import Foundation

struct CoreMonitorShareSnapshotContext: Equatable {
    let generatedAt: Date
    let appVersion: String
    let macOSVersion: String
    let hostModelIdentifier: String
    let hostModelName: String
    let chipName: String
    let cpuUsagePercent: Double
    let performanceCoreUsagePercent: Double?
    let efficiencyCoreUsagePercent: Double?
    let memoryUsagePercent: Double
    let memoryUsedGB: Double
    let totalMemoryGB: Double
    let cpuTemperature: Double?
    let gpuTemperature: Double?
    let ssdTemperature: Double?
    let fanSpeeds: [Int]
    let fanModeTitle: String
    let helperStateTitle: String
    let helperInstalled: Bool
    let batteryChargePercent: Int?
    let batteryPowerWatts: Double?
    let totalSystemWatts: Double?
    let thermalStateTitle: String
    let hasSMCAccess: Bool
    let smcError: String?
}

enum CoreMonitorShareKit {
    static let websiteURL = URL(string: "https://offyotto.github.io/Core-Monitor/")!
    static let repositoryURL = URL(string: "https://github.com/offyotto/Core-Monitor")!
    static let latestReleaseURL = URL(string: "https://github.com/offyotto/Core-Monitor/releases/latest")!
    static let appStoreURL = URL(string: "https://apps.apple.com/us/app/core-monitor/id6762558526?mt=12")!

    static func productPitch() -> String {
        """
        Core-Monitor is a free, open-source Apple Silicon system monitor and optional fan-control app for macOS.

        It tracks thermals, power, battery, CPU, GPU, memory, menu bar status, alerts, Touch Bar widgets, and helper-backed fan control locally on your Mac. Monitoring works without elevated access; the helper is only needed for fan writes.

        Website: \(websiteURL.absoluteString)
        Download: \(latestReleaseURL.absoluteString)
        Mac App Store edition: \(appStoreURL.absoluteString)
        Source: \(repositoryURL.absoluteString)
        """
    }

    static func launchPost() -> String {
        """
        Core-Monitor is a free, open-source Apple Silicon monitor for macOS: thermals, watts, battery, fans, menu bar status, alerts, Touch Bar widgets, and optional fan control with no account or telemetry.

        Download: \(latestReleaseURL.absoluteString)
        Source: \(repositoryURL.absoluteString)
        """
    }

    @MainActor
    static func makeSupportSnapshot(
        systemMonitor: SystemMonitor,
        fanController: FanController,
        helperManager: SMCHelperManager = .shared,
        generatedAt: Date = Date()
    ) -> String {
        let snapshot = systemMonitor.snapshot
        let modelIdentifier = SystemMonitor.hostModelIdentifier()
        let context = CoreMonitorShareSnapshotContext(
            generatedAt: generatedAt,
            appVersion: AppVersion.current,
            macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            hostModelIdentifier: modelIdentifier,
            hostModelName: MacModelRegistry.displayName(for: modelIdentifier),
            chipName: SystemMonitor.chipName(),
            cpuUsagePercent: snapshot.cpuUsagePercent,
            performanceCoreUsagePercent: snapshot.performanceCoreUsagePercent,
            efficiencyCoreUsagePercent: snapshot.efficiencyCoreUsagePercent,
            memoryUsagePercent: snapshot.memoryUsagePercent,
            memoryUsedGB: snapshot.memoryUsedGB,
            totalMemoryGB: snapshot.totalMemoryGB,
            cpuTemperature: snapshot.cpuTemperature,
            gpuTemperature: snapshot.gpuTemperature,
            ssdTemperature: snapshot.ssdTemperature,
            fanSpeeds: snapshot.fanSpeeds,
            fanModeTitle: fanModeTitle(fanController.mode),
            helperStateTitle: helperStateTitle(helperManager.connectionState),
            helperInstalled: helperManager.isInstalled,
            batteryChargePercent: snapshot.batteryInfo.chargePercent,
            batteryPowerWatts: snapshot.batteryInfo.powerWatts,
            totalSystemWatts: snapshot.totalSystemWatts,
            thermalStateTitle: thermalStateTitle(snapshot.thermalState),
            hasSMCAccess: snapshot.hasSMCAccess,
            smcError: snapshot.lastError
        )
        return supportSnapshotMarkdown(from: context)
    }

    static func supportSnapshotMarkdown(from context: CoreMonitorShareSnapshotContext) -> String {
        var lines: [String] = [
            "# Core-Monitor Support Snapshot",
            "",
            "- Generated: \(iso8601String(context.generatedAt))",
            "- App: Core Monitor \(context.appVersion)",
            "- macOS: \(context.macOSVersion)",
            "- Mac: \(context.hostModelName) (\(context.hostModelIdentifier))",
            "- Chip: \(context.chipName)",
            "",
            "## Monitoring",
            "",
            "- CPU: \(percentString(context.cpuUsagePercent))"
        ]

        if let performanceCoreUsagePercent = context.performanceCoreUsagePercent {
            lines.append("- P-cores: \(percentString(performanceCoreUsagePercent))")
        }

        if let efficiencyCoreUsagePercent = context.efficiencyCoreUsagePercent {
            lines.append("- E-cores: \(percentString(efficiencyCoreUsagePercent))")
        }

        lines.append("- Memory: \(gbString(context.memoryUsedGB)) of \(gbString(context.totalMemoryGB)) (\(percentString(context.memoryUsagePercent)))")
        lines.append("- Thermal pressure: \(context.thermalStateTitle)")
        lines.append("- CPU temperature: \(temperatureString(context.cpuTemperature))")
        lines.append("- GPU temperature: \(temperatureString(context.gpuTemperature))")
        lines.append("- SSD temperature: \(temperatureString(context.ssdTemperature))")
        lines.append("- System power: \(wattsString(context.totalSystemWatts))")
        lines.append("- Battery: \(batteryString(chargePercent: context.batteryChargePercent, watts: context.batteryPowerWatts))")
        lines.append("- Fans: \(fanSpeedsString(context.fanSpeeds))")
        lines.append("- SMC access: \(context.hasSMCAccess ? "Available" : "Unavailable")")

        if let smcError = context.smcError?.trimmingCharacters(in: .whitespacesAndNewlines), smcError.isEmpty == false {
            lines.append("- SMC note: \(smcError)")
        }

        lines.append(contentsOf: [
            "",
            "## Cooling",
            "",
            "- Mode: \(context.fanModeTitle)",
            "- Helper: \(context.helperStateTitle) (installed: \(context.helperInstalled ? "yes" : "no"))",
            "",
            "Core-Monitor: \(websiteURL.absoluteString)",
            "Source: \(repositoryURL.absoluteString)"
        ])

        return lines.joined(separator: "\n")
    }

    private static func iso8601String(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private static func percentString(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    private static func gbString(_ value: Double) -> String {
        guard value > 0 else { return "0 GB" }
        if value >= 10 {
            return String(format: "%.0f GB", value)
        }
        return String(format: "%.1f GB", value)
    }

    private static func temperatureString(_ value: Double?) -> String {
        guard let value else { return "Unavailable" }
        return "\(Int(value.rounded())) C"
    }

    private static func wattsString(_ value: Double?) -> String {
        guard let value else { return "Unavailable" }
        return String(format: "%.1f W", value)
    }

    private static func batteryString(chargePercent: Int?, watts: Double?) -> String {
        let charge = chargePercent.map { "\($0)%" } ?? "Unavailable"
        guard let watts else { return charge }
        return "\(charge), \(wattsString(watts))"
    }

    private static func fanSpeedsString(_ fanSpeeds: [Int]) -> String {
        guard fanSpeeds.isEmpty == false else { return "Unavailable" }
        return fanSpeeds.map { "\($0) RPM" }.joined(separator: ", ")
    }

    private static func fanModeTitle(_ mode: FanControlMode) -> String {
        switch mode {
        case .smart: return "Smart"
        case .silent: return "System"
        case .balanced: return "Balanced"
        case .performance: return "Performance"
        case .max: return "Maximum"
        case .manual: return "Manual"
        case .custom: return "Custom"
        case .automatic: return "System Automatic"
        }
    }

    private static func helperStateTitle(_ state: SMCHelperManager.ConnectionState) -> String {
        switch state {
        case .missing: return "Missing"
        case .unknown: return "Unknown"
        case .checking: return "Checking"
        case .reachable: return "Reachable"
        case .unreachable: return "Unavailable"
        }
    }

    private static func thermalStateTitle(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}
