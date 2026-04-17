import SwiftUI

private struct DashboardSurfaceCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(18)
            .background(
                CoreMonGlassBackground(
                    cornerRadius: 18,
                    tintOpacity: 0.12,
                    strokeOpacity: 0.14,
                    shadowRadius: 10
                )
            )
    }
}

struct MonitoringDashboardStrip: View {
    @ObservedObject var systemMonitor: SystemMonitor
    @ObservedObject var fanController: FanController
    @ObservedObject private var helperManager = SMCHelperManager.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let health = systemMonitor.snapshotHealth(now: context.date)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statusCard(
                    title: "Monitoring",
                    value: health.statusLabel,
                    detail: "\(health.ageDescription). \(health.cadenceDescription).",
                    icon: "waveform.path.ecg.rectangle",
                    color: monitoringColor(health)
                )
                statusCard(
                    title: "Overall Thermal",
                    value: AlertEvaluator.thermalStateLabel(systemMonitor.thermalState),
                    detail: CoreMonitorPlatformCopy.thermalStatusDetail(),
                    icon: "thermometer.medium",
                    color: thermalColor
                )
                statusCard(
                    title: "Helper",
                    value: helperValue,
                    detail: helperDetail,
                    icon: "lock.shield",
                    color: helperColor
                )
                statusCard(
                    title: "SMC / Fan State",
                    value: systemMonitor.hasSMCAccess ? "Healthy" : "Unavailable",
                    detail: systemMonitor.hasSMCAccess
                        ? "AppleSMC is reachable on this Mac."
                        : (systemMonitor.lastError ?? "AppleSMC could not be opened."),
                    icon: "cpu.fill",
                    color: systemMonitor.hasSMCAccess ? .green : .red
                )
            }
        }
    }

    private var summaryLine: String {
        if systemMonitor.hasSMCAccess {
            return "Core Monitor is sampling live hardware metrics."
        }
        if let lastError = systemMonitor.lastError, lastError.isEmpty == false {
            return lastError
        }
        return "Waiting for AppleSMC access."
    }

    private var fanModeSummary: MenuBarStatusPillSummary {
        MenuBarStatusSummary.fanModeSummary(for: fanController.mode)
    }

    private var helperSummary: MenuBarStatusPillSummary {
        MenuBarStatusSummary.helperSummary(
            for: fanController.mode,
            connectionState: helperManager.connectionState,
            isInstalled: helperManager.isInstalled
        )
    }

    private var helperValue: String {
        helperSummary.label
    }

    private var helperDetail: String {
        if let statusMessage = helperManager.statusMessage, statusMessage.isEmpty == false {
            return statusMessage
        }

        if fanController.mode.requiresPrivilegedHelper == false {
            return "Current cooling mode does not require the helper."
        }

        switch helperManager.connectionState {
        case .reachable:
            return "The privileged helper is installed and responding."
        case .checking:
            return "Core Monitor is checking the helper connection."
        case .unreachable:
            return "The helper is installed but not responding yet."
        case .unknown:
            return "The helper is installed but has not been checked yet."
        case .missing:
            return "Install the helper before using helper-backed fan modes."
        }
    }

    private var helperColor: Color {
        pillColor(for: helperSummary.tone)
    }

    private func statusCard(title: String, value: String, detail: String, icon: String, color: Color) -> some View {
        DashboardSurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func monitoringColor(_ health: MonitoringSnapshotHealth) -> Color {
        switch health.freshness {
        case .waiting:
            return Color.bdAccent
        case .live:
            return .green
        case .delayed:
            return .orange
        case .stale:
            return .red
        }
    }

    private var thermalColor: Color {
        switch systemMonitor.thermalState {
        case .nominal: return .green
        case .fair: return Color.bdAccent
        case .serious: return .orange
        case .critical: return .red
        @unknown default: return .secondary
        }
    }

    private func pillColor(for tone: MenuBarStatusPillTone) -> Color {
        switch tone {
        case .neutral:
            return .secondary
        case .accent:
            return Color.bdAccent
        case .good:
            return .green
        case .warning:
            return .orange
        case .critical:
            return .red
        }
    }
}

struct SystemStatusBoard: View {
    @ObservedObject var systemMonitor: SystemMonitor
    @ObservedObject var fanController: FanController
    @ObservedObject private var helperManager = SMCHelperManager.shared
    @ObservedObject private var privacySettings = PrivacySettings.shared

    var body: some View {
        let health = systemMonitor.snapshotHealth()

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statusCard(
                title: "Monitoring",
                value: health.statusLabel,
                detail: "\(health.ageDescription). \(health.cadenceDescription).",
                icon: "waveform.path.ecg.rectangle",
                color: monitoringColor(health)
            )
            statusCard(
                title: "Privacy",
                value: privacySettings.processInsightsEnabled ? "Context Visible" : "Private",
                detail: privacySettings.processInsightsEnabled
                    ? "Top-process names can appear in memory views."
                    : "Memory views stay on-device without showing app names.",
                icon: "hand.raised.fill",
                color: privacySettings.processInsightsEnabled ? Color.bdAccent : .green
            )
            statusCard(
                title: "Overall Thermal",
                value: thermalStateLabel(systemMonitor.thermalState),
                detail: "macOS thermal pressure on Apple Silicon.",
                icon: "thermometer.medium",
                color: thermalColor
            )
            statusCard(
                title: "Helper",
                value: helperSummary.label,
                detail: helperDetail,
                icon: "lock.shield",
                color: pillColor(for: helperSummary.tone)
            )
            statusCard(
                title: "Cooling Mode",
                value: fanModeSummary.label,
                detail: fanController.mode.guidance.detail,
                icon: "fanblades.fill",
                color: pillColor(for: fanModeSummary.tone)
            )
            statusCard(
                title: "SMC Access",
                value: systemMonitor.hasSMCAccess ? "Healthy" : "Unavailable",
                detail: systemMonitor.hasSMCAccess
                    ? "AppleSMC is reachable on this Mac."
                    : (systemMonitor.lastError ?? "AppleSMC could not be opened."),
                icon: "cpu.fill",
                color: systemMonitor.hasSMCAccess ? .green : .red
            )
        }
    }

    private var fanModeSummary: MenuBarStatusPillSummary {
        MenuBarStatusSummary.fanModeSummary(for: fanController.mode)
    }

    private var helperSummary: MenuBarStatusPillSummary {
        MenuBarStatusSummary.helperSummary(
            for: fanController.mode,
            connectionState: helperManager.connectionState,
            isInstalled: helperManager.isInstalled
        )
    }

    private var helperDetail: String {
        if let statusMessage = helperManager.statusMessage, statusMessage.isEmpty == false {
            return statusMessage
        }

        if fanController.mode.requiresPrivilegedHelper == false {
            return "Current cooling mode does not require the helper."
        }

        switch helperManager.connectionState {
        case .reachable:
            return "The privileged helper is installed and responding."
        case .checking:
            return "Core Monitor is checking the helper connection."
        case .unreachable:
            return "The helper is installed but not responding yet."
        case .unknown:
            return "The helper is installed but has not been checked yet."
        case .missing:
            return "Install the helper before using helper-backed fan modes."
        }
    }

    private func statusCard(title: String, value: String, detail: String, icon: String, color: Color) -> some View {
        DashboardSurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func monitoringColor(_ health: MonitoringSnapshotHealth) -> Color {
        switch health.freshness {
        case .waiting:
            return Color.bdAccent
        case .live:
            return .green
        case .delayed:
            return .orange
        case .stale:
            return .red
        }
    }

    private var thermalColor: Color {
        switch systemMonitor.thermalState {
        case .nominal: return .green
        case .fair: return Color.bdAccent
        case .serious: return .orange
        case .critical: return .red
        @unknown default: return .secondary
        }
    }

    private func thermalStateLabel(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal:
            return "Nominal"
        case .fair:
            return "Fair"
        case .serious:
            return "Serious"
        case .critical:
            return "Critical"
        @unknown default:
            return "Unknown"
        }
    }

    private func pillColor(for tone: MenuBarStatusPillTone) -> Color {
        switch tone {
        case .neutral:
            return .secondary
        case .accent:
            return Color.bdAccent
        case .good:
            return .green
        case .warning:
            return .orange
        case .critical:
            return .red
        }
    }
}

struct TopMemoryProcessesPanel: View {
    @ObservedObject var systemMonitor: SystemMonitor
    let snapshot: TopProcessSnapshot
    @ObservedObject private var privacySettings = PrivacySettings.shared

    var body: some View {
        DashboardSurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Top Memory Pressure")
                    .font(.system(size: 16, weight: .bold))
                if privacySettings.processInsightsEnabled == false {
                    Text("Process insights are off. Memory views stay local without showing app names.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                } else if snapshot.topMemory.isEmpty {
                    Text("Top process context becomes available after a few samples.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(snapshot.topMemory) { process in
                        HStack(spacing: 10) {
                            Image(systemName: "app.fill")
                                .foregroundStyle(process.memoryBytes > 2_000_000_000 ? .red : Color.bdAccent)
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(process.name)
                                    .font(.system(size: 13, weight: .semibold))
                                Text(String(format: "%.1f GB resident", process.memoryGB))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
        .onAppear {
            systemMonitor.setDetailedSamplingEnabled(true, reason: "dashboard.memory")
        }
        .onDisappear {
            systemMonitor.setDetailedSamplingEnabled(false, reason: "dashboard.memory")
        }
    }
}
