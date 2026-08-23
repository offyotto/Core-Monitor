import SwiftUI

/// Landing page: one plain-English status line, then a grid of live metric
/// cards. Every card opens its section.
struct OverviewPage: View {
    @ObservedObject var systemMonitor: SystemMonitor
    let openSection: (MonitorSection) -> Void

    private let columns = [GridItem(.adaptive(minimum: 210), spacing: 12)]

    var body: some View {
        let snapshot = systemMonitor.snapshot

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                statusHeader(snapshot)

                LazyVGrid(columns: columns, spacing: 12) {
                    cpuCard(snapshot)
                    memoryCard(snapshot)
                    thermalCard(snapshot)
                    coolingCard(snapshot)
                    powerCard(snapshot)
                    networkCard(snapshot)
                    storageCard(snapshot)
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Status header

    private func statusHeader(_ snapshot: SystemMonitorSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if snapshot.sampledAt == .distantPast {
                Text("Reading sensors…")
                    .font(.title2.weight(.semibold))
                Text("The first sample arrives within a few seconds.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text(SystemStatusNarrator.headline(for: snapshot))
                    .font(.title2.weight(.semibold))
                Text(SystemStatusNarrator.detail(for: snapshot))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 2)
    }

    // MARK: - Cards

    private func cpuCard(_ snapshot: SystemMonitorSnapshot) -> some View {
        MetricCard(
            section: .cpu,
            reading: ReadingFormat.percent(snapshot.cpuUsagePercent),
            caption: coresCaption(snapshot),
            severity: ReadingThresholds.cpuLoad(snapshot.cpuUsagePercent),
            points: systemMonitor.cpuUsageTrend.points,
            openSection: openSection
        )
    }

    private func memoryCard(_ snapshot: SystemMonitorSnapshot) -> some View {
        MetricCard(
            section: .memory,
            reading: ReadingFormat.percent(snapshot.memoryUsagePercent),
            caption: "\(ReadingFormat.gigabytes(snapshot.memoryUsedGB)) of \(ReadingFormat.gigabytes(snapshot.totalMemoryGB))",
            severity: ReadingThresholds.memory(snapshot.memoryUsagePercent, pressure: snapshot.memoryPressure),
            points: systemMonitor.memoryUsageTrend.points,
            openSection: openSection
        )
    }

    private func thermalCard(_ snapshot: SystemMonitorSnapshot) -> some View {
        MetricCard(
            section: .thermal,
            reading: ReadingFormat.celsius(snapshot.cpuTemperature),
            caption: thermalCaption(snapshot),
            severity: snapshot.cpuSafetyTemperature.map(ReadingThresholds.temperature)
                ?? ReadingThresholds.thermalState(snapshot.thermalState),
            points: systemMonitor.cpuTemperatureTrend.points,
            openSection: openSection
        )
    }

    private func coolingCard(_ snapshot: SystemMonitorSnapshot) -> some View {
        let active = snapshot.fanSpeeds.filter { $0 > 0 }
        let reading: String
        let caption: String
        if snapshot.numberOfFans == 0 {
            reading = "—"
            caption = "No fans reported"
        } else if let fastest = active.max() {
            reading = ReadingFormat.rpmShort(fastest)
            caption = active.count == 1 ? "1 fan spinning" : "\(active.count) fans spinning"
        } else {
            reading = "Rest"
            caption = "Fans are idle"
        }

        return MetricCard(
            section: .cooling,
            reading: reading,
            caption: caption,
            severity: .nominal,
            points: systemMonitor.primaryFanSpeedTrend.points,
            openSection: openSection
        )
    }

    private func powerCard(_ snapshot: SystemMonitorSnapshot) -> some View {
        let battery = snapshot.batteryInfo
        let reading: String
        let caption: String
        if let percent = battery.chargePercent, battery.hasBattery {
            reading = "\(percent)%"
            caption = BatteryDetailFormatter.powerStateDescription(for: battery)
        } else {
            reading = ReadingFormat.watts(snapshot.totalSystemWatts)
            caption = "System power draw"
        }

        return MetricCard(
            section: .power,
            reading: reading,
            caption: caption,
            severity: .nominal,
            points: systemMonitor.totalPowerTrend.points,
            openSection: openSection
        )
    }

    private func networkCard(_ snapshot: SystemMonitorSnapshot) -> some View {
        let stats = snapshot.networkStats
        return MetricCard(
            section: .network,
            reading: "↓" + ReadingFormat.rate(stats.downloadBytesPerSec),
            caption: "↑ " + ReadingFormat.rate(stats.uploadBytesPerSec),
            severity: .nominal,
            points: systemMonitor.networkDownloadTrend.points,
            openSection: openSection
        )
    }

    private func storageCard(_ snapshot: SystemMonitorSnapshot) -> some View {
        MetricCard(
            section: .storage,
            reading: ReadingFormat.percent(snapshot.diskStats.usagePercent),
            caption: "\(ReadingFormat.gigabytes(snapshot.diskStats.freeGB)) free",
            severity: ReadingThresholds.disk(snapshot.diskStats.usagePercent),
            points: [],
            openSection: openSection
        )
    }

    // MARK: - Captions

    private func coresCaption(_ snapshot: SystemMonitorSnapshot) -> String {
        if let performance = snapshot.performanceCoreUsagePercent,
           let efficiency = snapshot.efficiencyCoreUsagePercent {
            return "P \(ReadingFormat.percent(performance)) · E \(ReadingFormat.percent(efficiency))"
        }
        return "All cores"
    }

    private func thermalCaption(_ snapshot: SystemMonitorSnapshot) -> String {
        switch snapshot.thermalState {
        case .nominal: return "No thermal pressure"
        case .fair: return "Mild thermal pressure"
        case .serious: return "Serious thermal pressure"
        case .critical: return "Critical thermal pressure"
        @unknown default: return "Thermal state unknown"
        }
    }
}

// MARK: - Metric card

private struct MetricCard: View {
    let section: MonitorSection
    let reading: String
    let caption: String
    let severity: ReadingSeverity
    let points: [MonitoringTrendPoint]
    let openSection: (MonitorSection) -> Void

    @State private var isHovered = false

    var body: some View {
        Button {
            openSection(section)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: section.symbolName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(section.tint)
                    Text(section.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if severity > .nominal {
                        StatusDot(severity: severity)
                    }
                }

                Text(reading)
                    .font(.readingLarge.monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Sparkline(points: points, tint: section.tint, height: 30)

                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isHovered
                            ? section.tint.opacity(0.5)
                            : Color(nsColor: .separatorColor).opacity(0.6),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityLabel("\(section.title), \(reading)")
        .accessibilityHint("Opens the \(section.title) section")
    }
}
