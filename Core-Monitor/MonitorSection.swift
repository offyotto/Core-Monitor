import Foundation
import SwiftUI

/// The sections of the main window. Order matches the sidebar.
enum MonitorSection: String, CaseIterable, Identifiable, Hashable {
    case overview
    case cpu
    case memory
    case thermal
    case cooling
    case power
    case network
    case storage
    case rescue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .cpu: return "CPU"
        case .memory: return "Memory"
        case .thermal: return "Thermal"
        case .cooling: return "Cooling"
        case .power: return "Power"
        case .network: return "Network"
        case .storage: return "Storage"
        case .rescue: return "Rescue"
        }
    }

    var symbolName: String {
        switch self {
        case .overview: return "waveform.path.ecg"
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .thermal: return "thermometer.medium"
        case .cooling: return "fan"
        case .power: return "bolt"
        case .network: return "network"
        case .storage: return "internaldrive"
        case .rescue: return "cross.case"
        }
    }

    var tint: Color {
        switch self {
        case .overview: return .accentColor
        case .cpu: return MetricTint.cpu
        case .memory: return MetricTint.memory
        case .thermal: return MetricTint.thermal
        case .cooling: return MetricTint.cooling
        case .power: return MetricTint.power
        case .network: return MetricTint.network
        case .storage: return MetricTint.storage
        case .rescue: return MetricTint.rescue
        }
    }
}

/// Plain-English one-line summary for the Overview page.
enum SystemStatusNarrator {
    static func headline(for snapshot: SystemMonitorSnapshot) -> String {
        switch ReadingThresholds.thermalState(snapshot.thermalState) {
        case .critical:
            return "macOS is applying strong thermal protection."
        case .serious:
            return "Under thermal pressure — performance may be reduced."
        case .elevated:
            return "Warming up — macOS is starting to manage heat."
        case .nominal:
            break
        }

        if snapshot.memoryPressure == .red {
            return "Memory pressure is critical."
        }
        if ReadingThresholds.cpuLoad(snapshot.cpuUsagePercent) >= .serious {
            return "Working hard — CPU load is high."
        }
        if snapshot.memoryPressure == .yellow {
            return "Running fine, with elevated memory pressure."
        }
        if let temperature = snapshot.cpuTemperature, temperature >= 70 {
            return "Running warm but within normal limits."
        }
        return "Running cool. Everything looks normal."
    }

    static func detail(for snapshot: SystemMonitorSnapshot) -> String {
        var parts: [String] = []
        parts.append("CPU \(ReadingFormat.percent(snapshot.cpuUsagePercent))")
        if let temperature = snapshot.cpuTemperature {
            parts.append(ReadingFormat.celsiusLong(temperature))
        }
        let activeFans = snapshot.fanSpeeds.filter { $0 > 0 }
        if let fastest = activeFans.max() {
            parts.append("fans \(ReadingFormat.rpm(fastest))")
        } else if snapshot.numberOfFans > 0 {
            parts.append("fans at rest")
        }
        if let watts = snapshot.totalSystemWatts {
            parts.append(ReadingFormat.watts(watts))
        }
        return parts.joined(separator: " · ")
    }
}
