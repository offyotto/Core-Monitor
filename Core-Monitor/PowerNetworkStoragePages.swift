import Charts
import SwiftUI

// MARK: - Power page

struct PowerPage: View {
    @ObservedObject var systemMonitor: SystemMonitor
    @State private var range: MonitoringTrendRange = .fiveMinutes

    var body: some View {
        let snapshot = systemMonitor.snapshot
        let battery = snapshot.batteryInfo

        MonitorPage("Power", subtitle: "System draw, battery charge, and battery health.") {
            Panel {
                HeroReading(
                    value: ReadingFormat.watts(snapshot.totalSystemWatts),
                    label: "system power draw",
                    tint: MetricTint.power
                )
                TrendRangePicker(range: $range)
                TrendChart(
                    points: systemMonitor.totalPowerTrend.points,
                    range: range,
                    tint: MetricTint.power
                )
                TrendSummaryStrip(
                    series: systemMonitor.totalPowerTrend,
                    range: range,
                    format: { ReadingFormat.watts($0) }
                )
            }

            if let cpuWatts = snapshot.cpuPowerWatts {
                Panel("Draw by Component") {
                    ReadingRow("CPU", value: ReadingFormat.watts(cpuWatts))
                    if let gpuWatts = snapshot.gpuPowerWatts {
                        ReadingRow("GPU", value: ReadingFormat.watts(gpuWatts))
                    }
                }
            }

            if battery.hasBattery {
                Panel("Battery") {
                    HStack(spacing: 18) {
                        Gauge(value: Double(battery.chargePercent ?? 0), in: 0...100) {
                            Text("Charge")
                        } currentValueLabel: {
                            Text("\(battery.chargePercent ?? 0)%")
                                .font(.readingSmall.monospacedDigit())
                        }
                        .gaugeStyle(.accessoryCircularCapacity)
                        .tint(MetricTint.power)
                        .scaleEffect(1.1)
                        .frame(width: 64, height: 64)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(BatteryDetailFormatter.powerStateDescription(for: battery))
                                .font(.body.weight(.medium))
                            if let runtime = BatteryDetailFormatter.runtimeDescription(for: battery) {
                                Text(battery.isCharging ? "Full in about \(runtime)" : "About \(runtime) remaining")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }

                    Divider()

                    ReadingRow("Health", value: battery.healthPercent.map { "\($0)%" } ?? "Unavailable")
                    ReadingRow("Cycle count", value: battery.cycleCount.map(String.init) ?? "Unavailable")
                    ReadingRow(
                        "Temperature",
                        value: BatteryDetailFormatter.temperatureDescription(battery.temperatureC) ?? "Unavailable"
                    )
                    ReadingRow(
                        "Voltage",
                        value: BatteryDetailFormatter.voltageDescription(battery.voltageV) ?? "Unavailable"
                    )
                    ReadingRow(
                        "Current",
                        value: BatteryDetailFormatter.amperageDescription(battery.amperageA) ?? "Unavailable"
                    )
                }
            } else {
                Panel("Battery") {
                    Text("This Mac does not report an internal battery.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            }
        }
    }
}

// MARK: - Network page

struct NetworkPage: View {
    @ObservedObject var systemMonitor: SystemMonitor
    @State private var range: MonitoringTrendRange = .fiveMinutes

    var body: some View {
        let stats = systemMonitor.snapshot.networkStats

        MonitorPage("Network", subtitle: "Throughput across all interfaces.") {
            Panel {
                HStack(spacing: 28) {
                    directionReading(
                        symbol: "arrow.down",
                        label: "Download",
                        value: ReadingFormat.rate(stats.downloadBytesPerSec),
                        tint: MetricTint.network
                    )
                    directionReading(
                        symbol: "arrow.up",
                        label: "Upload",
                        value: ReadingFormat.rate(stats.uploadBytesPerSec),
                        tint: MetricTint.network.opacity(0.6)
                    )
                    Spacer()
                }

                TrendRangePicker(range: $range)
                dualTrendChart
                legend
            }
        }
    }

    private func directionReading(symbol: String, label: String, value: String, tint: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.readingLarge.monospacedDigit())
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var dualTrendChart: some View {
        let cutoff = Date().addingTimeInterval(-range.duration)
        let download = systemMonitor.networkDownloadTrend.points.filter { $0.timestamp >= cutoff }
        let upload = systemMonitor.networkUploadTrend.points.filter { $0.timestamp >= cutoff }

        return Group {
            if download.count < 2 && upload.count < 2 {
                VStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Collecting samples")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 132)
            } else {
                Chart {
                    ForEach(download, id: \.timestamp) { point in
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Rate", point.value),
                            series: .value("Direction", "Download")
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(MetricTint.network)
                    }
                    ForEach(upload, id: \.timestamp) { point in
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Rate", point.value),
                            series: .value("Direction", "Upload")
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(MetricTint.network.opacity(0.55))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    }
                }
                .chartXScale(domain: cutoff...Date())
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.hour().minute(), anchor: .top)
                            .font(.caption2)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let rate = value.as(Double.self) {
                                Text(NetworkThroughputFormatter.abbreviatedRate(bytesPerSecond: rate))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 132)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem("Download", color: MetricTint.network, dashed: false)
            legendItem("Upload", color: MetricTint.network.opacity(0.55), dashed: true)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func legendItem(_ label: String, color: Color, dashed: Bool) -> some View {
        HStack(spacing: 5) {
            Rectangle()
                .fill(color)
                .frame(width: 14, height: 2)
                .overlay {
                    if dashed {
                        Rectangle()
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .frame(width: 3, height: 2)
                    }
                }
            Text(label)
        }
    }
}

// MARK: - Storage page

struct StoragePage: View {
    @ObservedObject var systemMonitor: SystemMonitor

    var body: some View {
        let disk = systemMonitor.snapshot.diskStats

        MonitorPage("Storage", subtitle: "Startup disk capacity.") {
            Panel {
                HeroReading(
                    value: ReadingFormat.percent(disk.usagePercent),
                    label: "of \(ReadingFormat.gigabytes(disk.totalGB)) in use",
                    tint: MetricTint.storage,
                    severity: ReadingThresholds.disk(disk.usagePercent)
                )

                segmentedCapacityBar(disk)

                HStack(spacing: 16) {
                    legendSwatch("Used", tint: MetricTint.storage)
                    legendSwatch("Purgeable", tint: MetricTint.storage.opacity(0.35))
                    legendSwatch("Free", tint: Color(nsColor: .quaternaryLabelColor))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Panel("Details") {
                ReadingRow("Used", value: ReadingFormat.gigabytes(disk.usedGB))
                ReadingRow(
                    "Purgeable",
                    value: ReadingFormat.gigabytes(disk.purgeableGB),
                    note: "Space macOS can reclaim automatically when needed."
                )
                ReadingRow("Free", value: ReadingFormat.gigabytes(disk.freeGB))
                ReadingRow(
                    "Capacity",
                    value: ReadingFormat.gigabytes(disk.totalGB),
                    note: "SMART health for the internal drive lives in Rescue, next to the other hardware diagnostics."
                )
            }
        }
    }

    private func segmentedCapacityBar(_ disk: DiskStats) -> some View {
        GeometryReader { proxy in
            let total = max(disk.totalGB, 1)
            let usedWidth = proxy.size.width * min(disk.usedGB / total, 1)
            let purgeableWidth = proxy.size.width * min(disk.purgeableGB / total, 1)

            HStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(MetricTint.storage)
                    .frame(width: max(usedWidth, 3))
                if purgeableWidth > 2 {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(MetricTint.storage.opacity(0.35))
                        .frame(width: purgeableWidth)
                }
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(nsColor: .quaternaryLabelColor))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 12)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func legendSwatch(_ label: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(tint)
                .frame(width: 9, height: 9)
            Text(label)
        }
    }
}
