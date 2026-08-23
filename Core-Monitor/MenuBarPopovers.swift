import SwiftUI

/// One popover design for every menu bar item: header, hero reading,
/// sparkline, quick stats, then actions. The kind decides the data.
struct MetricPopoverView: View {
    let kind: MenuBarItemKind
    @ObservedObject var systemMonitor: SystemMonitor
    @ObservedObject var fanController: FanController
    let openSection: (MonitorSection) -> Void

    var body: some View {
        let snapshot = systemMonitor.snapshot

        VStack(alignment: .leading, spacing: 14) {
            header(snapshot)
            hero(snapshot)
            sparkline
            quickStats(snapshot)

            if kind == .fan || kind == .temperature {
                Divider()
                coolingModeRow
            }

            Divider()
            footer
        }
        .padding(16)
        .frame(width: 300)
    }

    // MARK: Header

    private func header(_ snapshot: SystemMonitorSnapshot) -> some View {
        HStack(spacing: 7) {
            Image(systemName: section.symbolName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(section.tint)
            Text(headerTitle)
                .font(.subheadline.weight(.semibold))
            Spacer()
            let severity = severity(snapshot)
            if severity > .nominal {
                StatusDot(severity: severity)
            }
        }
    }

    private var headerTitle: String {
        switch kind {
        case .cpu: return "Processor"
        case .fan: return "Fans"
        case .memory: return "Memory"
        case .network: return "Network"
        case .disk: return "Storage"
        case .temperature: return "Thermal"
        }
    }

    // MARK: Hero

    private func hero(_ snapshot: SystemMonitorSnapshot) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(heroValue(snapshot))
                .font(.system(size: 30, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(section.tint)
            Text(heroLabel(snapshot))
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func heroValue(_ snapshot: SystemMonitorSnapshot) -> String {
        switch kind {
        case .cpu:
            return ReadingFormat.percent(snapshot.cpuUsagePercent)
        case .memory:
            return ReadingFormat.percent(snapshot.memoryUsagePercent)
        case .disk:
            return ReadingFormat.percent(snapshot.diskStats.usagePercent)
        case .network:
            return "↓" + ReadingFormat.rate(snapshot.networkStats.downloadBytesPerSec)
        case .temperature:
            return ReadingFormat.celsius(snapshot.cpuTemperature)
        case .fan:
            let active = snapshot.fanSpeeds.filter { $0 > 0 }
            guard let fastest = active.max() else { return "Rest" }
            return ReadingFormat.rpmShort(fastest)
        }
    }

    private func heroLabel(_ snapshot: SystemMonitorSnapshot) -> String {
        switch kind {
        case .cpu: return "load"
        case .memory: return "of \(ReadingFormat.gigabytes(snapshot.totalMemoryGB))"
        case .disk: return "used"
        case .network: return "↑ " + ReadingFormat.rate(snapshot.networkStats.uploadBytesPerSec)
        case .temperature: return "CPU average"
        case .fan:
            let active = snapshot.fanSpeeds.filter { $0 > 0 }.count
            if active == 0 { return "fans idle" }
            return active == 1 ? "1 fan spinning" : "\(active) fans spinning"
        }
    }

    private func severity(_ snapshot: SystemMonitorSnapshot) -> ReadingSeverity {
        switch kind {
        case .cpu:
            return ReadingThresholds.cpuLoad(snapshot.cpuUsagePercent)
        case .memory:
            return ReadingThresholds.memory(snapshot.memoryUsagePercent, pressure: snapshot.memoryPressure)
        case .disk:
            return ReadingThresholds.disk(snapshot.diskStats.usagePercent)
        case .network, .fan:
            return .nominal
        case .temperature:
            return snapshot.cpuSafetyTemperature.map(ReadingThresholds.temperature) ?? .nominal
        }
    }

    // MARK: Sparkline

    @ViewBuilder
    private var sparkline: some View {
        switch kind {
        case .cpu:
            Sparkline(points: systemMonitor.cpuUsageTrend.points, tint: section.tint, height: 40)
        case .memory:
            Sparkline(points: systemMonitor.memoryUsageTrend.points, tint: section.tint, height: 40)
        case .network:
            Sparkline(points: systemMonitor.networkDownloadTrend.points, tint: section.tint, height: 40)
        case .temperature:
            Sparkline(points: systemMonitor.cpuTemperatureTrend.points, tint: section.tint, height: 40)
        case .fan:
            Sparkline(points: systemMonitor.primaryFanSpeedTrend.points, tint: section.tint, height: 40)
        case .disk:
            diskBar
        }
    }

    private var diskBar: some View {
        let disk = systemMonitor.snapshot.diskStats
        return GeometryReader { proxy in
            let total = max(disk.totalGB, 1)
            HStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(section.tint)
                    .frame(width: max(proxy.size.width * min(disk.usedGB / total, 1), 3))
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(nsColor: .quaternaryLabelColor))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 10)
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    // MARK: Quick stats

    private func quickStats(_ snapshot: SystemMonitorSnapshot) -> some View {
        let stats = statPairs(snapshot)
        return Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 7) {
            ForEach(0..<((stats.count + 1) / 2), id: \.self) { rowIndex in
                GridRow {
                    statCell(stats[rowIndex * 2])
                    if rowIndex * 2 + 1 < stats.count {
                        statCell(stats[rowIndex * 2 + 1])
                    }
                }
            }
        }
    }

    private func statCell(_ stat: (label: String, value: String)) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(stat.value)
                .font(.readingSmall.monospacedDigit())
            Text(stat.label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statPairs(_ snapshot: SystemMonitorSnapshot) -> [(label: String, value: String)] {
        switch kind {
        case .cpu:
            var stats: [(String, String)] = []
            if let performance = snapshot.performanceCoreUsagePercent {
                stats.append(("Performance cores", ReadingFormat.percent(performance)))
            }
            if let efficiency = snapshot.efficiencyCoreUsagePercent {
                stats.append(("Efficiency cores", ReadingFormat.percent(efficiency)))
            }
            stats.append(("CPU average temperature", ReadingFormat.celsiusLong(snapshot.cpuTemperature)))
            if let watts = snapshot.totalSystemWatts {
                stats.append(("System power", ReadingFormat.watts(watts)))
            }
            return stats

        case .memory:
            return [
                ("Used", ReadingFormat.gigabytes(snapshot.memoryUsedGB)),
                ("Free", ReadingFormat.gigabytes(snapshot.freeMemoryGB)),
                ("Pressure", pressureTitle(snapshot.memoryPressure)),
                ("Swap", snapshot.swapUsedBytes > 0 ? ReadingFormat.bytes(snapshot.swapUsedBytes) : "None")
            ]

        case .disk:
            return [
                ("Used", ReadingFormat.gigabytes(snapshot.diskStats.usedGB)),
                ("Free", ReadingFormat.gigabytes(snapshot.diskStats.freeGB)),
                ("Purgeable", ReadingFormat.gigabytes(snapshot.diskStats.purgeableGB)),
                ("Capacity", ReadingFormat.gigabytes(snapshot.diskStats.totalGB))
            ]

        case .network:
            return [
                ("Download", ReadingFormat.rate(snapshot.networkStats.downloadBytesPerSec)),
                ("Upload", ReadingFormat.rate(snapshot.networkStats.uploadBytesPerSec))
            ]

        case .temperature:
            var stats: [(String, String)] = [
                ("CPU peak", ReadingFormat.celsiusLong(snapshot.cpuPeakTemperature)),
                ("GPU average", ReadingFormat.celsiusLong(snapshot.gpuTemperature)),
                ("GPU peak", ReadingFormat.celsiusLong(snapshot.gpuPeakTemperature)),
                (snapshot.storageTemperatureLabel, ReadingFormat.celsiusLong(snapshot.ssdTemperature))
            ]
            if let fastest = snapshot.fanSpeeds.filter({ $0 > 0 }).max() {
                stats.append(("Fastest fan", ReadingFormat.rpm(fastest)))
            }
            stats.append(("Thermal pressure", thermalTitle(snapshot.thermalState)))
            return stats

        case .fan:
            var stats: [(String, String)] = snapshot.fanSpeeds.enumerated().map { index, rpm in
                let value = rpm < 0 ? "Unavailable" : (rpm > 0 ? ReadingFormat.rpm(rpm) : "At rest")
                return ("Fan \(index + 1)", value)
            }
            stats.append(("CPU average temperature", ReadingFormat.celsiusLong(snapshot.cpuTemperature)))
            return stats
        }
    }

    // MARK: Cooling mode

    private var coolingModeRow: some View {
        HStack {
            Text("Cooling")
                .font(.callout)
            Spacer()
            Picker("Cooling mode", selection: coolingModeBinding) {
                ForEach(FanControlMode.quickModes, id: \.rawValue) { mode in
                    Text(coolingModeTitle(mode)).tag(mode.rawValue)
                }
            }
            .labelsHidden()
            .fixedSize()
        }
    }

    private var coolingModeBinding: Binding<String> {
        Binding {
            fanController.mode.rawValue
        } set: { rawValue in
            if let mode = FanControlMode(rawValue: rawValue) {
                fanController.setMode(mode)
            }
        }
    }

    private func coolingModeTitle(_ mode: FanControlMode) -> String {
        switch mode {
        case .smart: return "Smart"
        case .silent: return "System Handoff"
        case .balanced: return "Balanced"
        case .performance: return "Performance"
        case .max: return "Maximum"
        case .manual: return "Manual"
        case .custom: return "Custom Curve"
        case .automatic: return "System Automatic"
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Button("Open Core Monitor") {
                openSection(section)
            }
            Spacer()
            Button {
                SettingsWindowManager.shared.show()
            } label: {
                Image(systemName: "gearshape")
            }
            .help("Core Monitor settings")
        }
        .controlSize(.small)
    }

    // MARK: Section mapping

    private var section: MonitorSection {
        switch kind {
        case .cpu: return .cpu
        case .memory: return .memory
        case .disk: return .storage
        case .network: return .network
        case .temperature: return .thermal
        case .fan: return .cooling
        }
    }

    // MARK: Titles

    private func pressureTitle(_ pressure: MemoryPressureLevel) -> String {
        switch pressure {
        case .green: return "Normal"
        case .yellow: return "Elevated"
        case .red: return "Critical"
        }
    }

    private func thermalTitle(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}
