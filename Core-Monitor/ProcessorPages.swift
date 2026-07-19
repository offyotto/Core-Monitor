import SwiftUI

// MARK: - CPU page

struct CPUPage: View {
    @ObservedObject var systemMonitor: SystemMonitor
    @ObservedObject private var privacySettings = PrivacySettings.shared
    @State private var range: MonitoringTrendRange = .fiveMinutes

    var body: some View {
        let snapshot = systemMonitor.snapshot

        MonitorPage("CPU", subtitle: "Load across all cores, sampled live.") {
            Panel {
                HeroReading(
                    value: ReadingFormat.percent(snapshot.cpuUsagePercent),
                    label: "current load",
                    tint: MetricTint.cpu,
                    severity: ReadingThresholds.cpuLoad(snapshot.cpuUsagePercent)
                )
                TrendRangePicker(range: $range)
                TrendChart(
                    points: systemMonitor.cpuUsageTrend.points,
                    range: range,
                    tint: MetricTint.cpu,
                    yDomain: 0...100
                )
                TrendSummaryStrip(
                    series: systemMonitor.cpuUsageTrend,
                    range: range,
                    format: ReadingFormat.percent
                )
            }

            if snapshot.performanceCoreUsagePercent != nil || snapshot.efficiencyCoreUsagePercent != nil {
                Panel("Core Clusters", caption: "Apple Silicon splits work between performance and efficiency cores.") {
                    if let performance = snapshot.performanceCoreUsagePercent {
                        CapacityRow(
                            label: "Performance cores",
                            value: ReadingFormat.percent(performance),
                            fraction: performance / 100,
                            tint: MetricTint.cpu
                        )
                    }
                    if let efficiency = snapshot.efficiencyCoreUsagePercent {
                        CapacityRow(
                            label: "Efficiency cores",
                            value: ReadingFormat.percent(efficiency),
                            fraction: efficiency / 100,
                            tint: MetricTint.cpu.opacity(0.55)
                        )
                    }
                }
            }

            ProcessListPanel(
                title: "Top Processes by CPU",
                processes: snapshot.topProcesses.topCPU,
                showNames: privacySettings.processInsightsEnabled,
                tint: MetricTint.cpu,
                metric: { ReadingFormat.percent($0.cpuPercent) },
                fraction: { min($0.cpuPercent / 100, 1) }
            )
        }
    }
}

// MARK: - Memory page

struct MemoryPage: View {
    @ObservedObject var systemMonitor: SystemMonitor
    @ObservedObject private var privacySettings = PrivacySettings.shared
    @State private var range: MonitoringTrendRange = .fiveMinutes

    var body: some View {
        let snapshot = systemMonitor.snapshot

        MonitorPage("Memory", subtitle: "Unified memory use and pressure.") {
            Panel {
                HeroReading(
                    value: ReadingFormat.percent(snapshot.memoryUsagePercent),
                    label: "\(ReadingFormat.gigabytes(snapshot.memoryUsedGB)) of \(ReadingFormat.gigabytes(snapshot.totalMemoryGB)) in use",
                    tint: MetricTint.memory,
                    severity: ReadingThresholds.memory(snapshot.memoryUsagePercent, pressure: snapshot.memoryPressure)
                )
                TrendRangePicker(range: $range)
                TrendChart(
                    points: systemMonitor.memoryUsageTrend.points,
                    range: range,
                    tint: MetricTint.memory,
                    yDomain: 0...100
                )
                TrendSummaryStrip(
                    series: systemMonitor.memoryUsageTrend,
                    range: range,
                    format: ReadingFormat.percent
                )
            }

            Panel("Breakdown") {
                CapacityRow(
                    label: "App memory",
                    value: ReadingFormat.gigabytes(snapshot.appMemoryGB),
                    fraction: fraction(snapshot.appMemoryGB, of: snapshot.totalMemoryGB),
                    tint: MetricTint.memory
                )
                CapacityRow(
                    label: "Wired",
                    value: ReadingFormat.gigabytes(snapshot.wiredMemoryGB),
                    fraction: fraction(snapshot.wiredMemoryGB, of: snapshot.totalMemoryGB),
                    tint: MetricTint.memory.opacity(0.7)
                )
                CapacityRow(
                    label: "Compressed",
                    value: ReadingFormat.gigabytes(snapshot.compressedMemoryGB),
                    fraction: fraction(snapshot.compressedMemoryGB, of: snapshot.totalMemoryGB),
                    tint: MetricTint.memory.opacity(0.45)
                )
                CapacityRow(
                    label: "Free",
                    value: ReadingFormat.gigabytes(snapshot.freeMemoryGB),
                    fraction: fraction(snapshot.freeMemoryGB, of: snapshot.totalMemoryGB),
                    tint: Color(nsColor: .tertiaryLabelColor)
                )
                Divider()
                ReadingRow(
                    "Pressure",
                    value: pressureTitle(snapshot.memoryPressure),
                    valueColor: pressureColor(snapshot.memoryPressure)
                )
                ReadingRow(
                    "Swap used",
                    value: snapshot.swapUsedBytes > 0 ? ReadingFormat.bytes(snapshot.swapUsedBytes) : "None"
                )
            }

            ProcessListPanel(
                title: "Top Processes by Memory",
                processes: snapshot.topProcesses.topMemory,
                showNames: privacySettings.processInsightsEnabled,
                tint: MetricTint.memory,
                metric: { ReadingFormat.bytes($0.memoryBytes) },
                fraction: { activity in
                    guard snapshot.totalMemoryGB > 0 else { return 0 }
                    return min(activity.memoryGB / snapshot.totalMemoryGB, 1)
                }
            )
        }
    }

    private func fraction(_ part: Double, of whole: Double) -> Double {
        guard whole > 0 else { return 0 }
        return part / whole
    }

    private func pressureTitle(_ pressure: MemoryPressureLevel) -> String {
        switch pressure {
        case .green: return "Normal"
        case .yellow: return "Elevated"
        case .red: return "Critical"
        }
    }

    private func pressureColor(_ pressure: MemoryPressureLevel) -> Color {
        switch pressure {
        case .green: return .primary
        case .yellow: return .orange
        case .red: return .red
        }
    }
}

// MARK: - Shared pieces

/// Big rounded numeral with a severity dot, opens each section page.
struct HeroReading: View {
    let value: String
    let label: String
    let tint: Color
    var severity: ReadingSeverity = .nominal

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(value)
                .font(.readingHero.monospacedDigit())
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 1) {
                if severity > .nominal {
                    HStack(spacing: 5) {
                        StatusDot(severity: severity)
                        Text(severityLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(severity.color)
                    }
                }
                Text(label)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var severityLabel: String {
        switch severity {
        case .nominal: return ""
        case .elevated: return "Elevated"
        case .serious: return "High"
        case .critical: return "Critical"
        }
    }
}

struct TrendRangePicker: View {
    @Binding var range: MonitoringTrendRange

    var body: some View {
        Picker("History range", selection: $range) {
            ForEach(MonitoringTrendRange.allCases) { candidate in
                Text(candidate.title).tag(candidate)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: 200)
    }
}

/// Ranked process rows with a quiet inline bar. Respects the privacy toggle.
struct ProcessListPanel: View {
    let title: String
    let processes: [ProcessActivity]
    let showNames: Bool
    let tint: Color
    let metric: (ProcessActivity) -> String
    let fraction: (ProcessActivity) -> Double

    var body: some View {
        Panel(title, caption: showNames ? nil : "Names are hidden. Turn them on in Settings › General.") {
            if processes.isEmpty {
                Text("No process samples yet.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                VStack(spacing: 8) {
                    ForEach(processes) { process in
                        HStack(spacing: 10) {
                            Text(showNames ? process.name : "App \(process.pid)")
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color(nsColor: .quaternaryLabelColor))
                                    Capsule()
                                        .fill(tint.opacity(0.8))
                                        .frame(width: max(proxy.size.width * min(max(fraction(process), 0), 1), 2))
                                }
                            }
                            .frame(width: 110, height: 4)

                            Text(metric(process))
                                .font(.readingSmall.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 72, alignment: .trailing)
                        }
                        .font(.callout)
                    }
                }
            }
        }
    }
}
