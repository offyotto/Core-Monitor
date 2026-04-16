import SwiftUI
import UserNotifications

private struct AlertSurfaceCard<Content: View>: View {
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

private struct AlertSeverityBadge: View {
    let severity: AlertSeverity

    var body: some View {
        Text(severity.title.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.16))
            .clipShape(Capsule())
    }

    private var color: Color {
        switch severity {
        case .none: return .secondary
        case .info: return Color.bdAccent
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

struct AlertsDashboardStrip: View {
    @ObservedObject var alertManager: AlertManager
    var openAlerts: (() -> Void)? = nil

    var body: some View {
        AlertSurfaceCard {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        AlertSeverityBadge(severity: alertManager.highestActiveSeverity)
                        Text(alertManager.summaryLine)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    if alertManager.activeAlerts.isEmpty {
                        Text("In-app history stays available even when desktop notifications are muted.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(alertManager.activeAlerts.count) active alert\(alertManager.activeAlerts.count == 1 ? "" : "s")")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 12)

                if let openAlerts {
                    Button(action: openAlerts) {
                        Label("Open Alerts", systemImage: "bell.badge")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

struct TopMemoryProcessesPanel: View {
    let snapshot: TopProcessSnapshot
    @ObservedObject private var privacySettings = PrivacySettings.shared

    var body: some View {
        AlertSurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Top Memory Pressure")
                    .font(.system(size: 16, weight: .bold))
                if privacySettings.processInsightsEnabled == false {
                    Text("Process insights are off. Memory alerts still work without collecting app names.")
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
    }
}

struct SystemStatusBoard: View {
    @ObservedObject var alertManager: AlertManager
    @ObservedObject var systemMonitor: SystemMonitor
    @ObservedObject private var helperManager = SMCHelperManager.shared

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statusCard(
                title: "Notifications",
                value: notificationLabel,
                detail: notificationDetail,
                icon: "bell.badge",
                color: notificationColor
            )
            statusCard(
                title: "Overall Thermal",
                value: AlertEvaluator.thermalStateLabel(systemMonitor.thermalState),
                detail: "macOS thermal pressure on Apple Silicon.",
                icon: "waveform.path.ecg",
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

    private func statusCard(title: String, value: String, detail: String, icon: String, color: Color) -> some View {
        AlertSurfaceCard {
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

    private var notificationLabel: String {
        switch alertManager.authorizationStatus {
        case .authorized, .provisional:
            if let mutedUntil = alertManager.notificationsMutedUntil, mutedUntil > Date() {
                return "Muted"
            }
            return alertManager.desktopNotificationsEnabled ? "Allowed" : "In-App Only"
        case .denied:
            return "Denied"
        case .notDetermined:
            return "Pending"
        @unknown default:
            return "Unknown"
        }
    }

    private var notificationDetail: String {
        if let mutedUntil = alertManager.notificationsMutedUntil, mutedUntil > Date() {
            return "Muted until \(mutedUntil.formatted(date: .omitted, time: .shortened))."
        }
        switch alertManager.authorizationStatus {
        case .authorized, .provisional:
            return alertManager.desktopNotificationsEnabled
                ? "Desktop notifications follow the selected alerts policy."
                : "Desktop banners are off; in-app history still records events."
        case .denied:
            return "Turn notifications on in System Settings if you want desktop banners."
        case .notDetermined:
            return "Request permission from the Alerts screen."
        @unknown default:
            return "Notification permission state is unavailable."
        }
    }

    private var notificationColor: Color {
        switch alertManager.authorizationStatus {
        case .authorized, .provisional:
            return alertManager.desktopNotificationsEnabled ? .green : .orange
        case .denied:
            return .red
        case .notDetermined:
            return Color.bdAccent
        @unknown default:
            return .secondary
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

    private var helperValue: String {
        switch helperManager.connectionState {
        case .reachable:
            return "Ready"
        case .checking:
            return "Checking"
        case .unreachable:
            return "Rejected"
        case .unknown where helperManager.isInstalled:
            return "Installed"
        case .unknown, .missing:
            return "Missing"
        }
    }

    private var helperDetail: String {
        switch helperManager.connectionState {
        case .reachable:
            return "Fan control can use the privileged helper."
        case .checking:
            return "Core Monitor is probing the local helper service."
        case .unreachable:
            return helperManager.statusMessage ?? "The helper is installed but this app build cannot talk to it."
        case .unknown where helperManager.isInstalled:
            return "The helper exists on disk, but Core Monitor has not completed a health probe yet."
        case .unknown, .missing:
            return "Install the helper before trusting manual or managed fan modes."
        }
    }

    private var helperColor: Color {
        switch helperManager.connectionState {
        case .reachable:
            return Color.bdAccent
        case .checking:
            return .yellow
        case .unreachable:
            return .orange
        case .unknown where helperManager.isInstalled:
            return .yellow
        case .unknown, .missing:
            return .orange
        }
    }
}

struct AlertsView: View {
    @ObservedObject var alertManager: AlertManager
    @ObservedObject var systemMonitor: SystemMonitor
    @ObservedObject var fanController: FanController

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            summaryCards
            presetCard
            notificationCard
            privacyCard
            activeAlertsCard
            ruleGroups
            historyCard
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Alerts")
                .font(.system(size: 22, weight: .bold))
            Text("Thresholds, notification policy, and recent alert history.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var summaryCards: some View {
        VStack(spacing: 12) {
            AlertsDashboardStrip(alertManager: alertManager)
            SystemStatusBoard(alertManager: alertManager, systemMonitor: systemMonitor)
        }
    }

    private var presetCard: some View {
        AlertSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Preset")
                            .font(.system(size: 16, weight: .bold))
                        Text(alertManager.selectedPreset.subtitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                Picker(
                    "Preset",
                    selection: Binding(
                        get: { alertManager.selectedPreset },
                        set: { alertManager.applyPreset($0) }
                    )
                ) {
                    ForEach(AlertPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var notificationCard: some View {
        AlertSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Notification Controls")
                    .font(.system(size: 16, weight: .bold))

                Toggle(
                    "Enable desktop notifications",
                    isOn: Binding(
                        get: { alertManager.desktopNotificationsEnabled },
                        set: { alertManager.setDesktopNotificationsEnabled($0) }
                    )
                )
                .toggleStyle(.switch)

                Picker(
                    "Policy",
                    selection: Binding(
                        get: { alertManager.notificationPolicy },
                        set: { alertManager.setNotificationPolicy($0) }
                    )
                ) {
                    ForEach(AlertNotificationPolicy.allCases) { policy in
                        Text(policy.title).tag(policy)
                    }
                }
                .pickerStyle(.menu)

                HStack(spacing: 10) {
                    Button("Allow Notifications") {
                        alertManager.requestNotificationAuthorization()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(alertManager.authorizationStatus == .authorized || alertManager.authorizationStatus == .provisional)

                    Button("Mute 1 Hour") {
                        alertManager.muteNotifications(for: 3_600)
                    }
                    .buttonStyle(.bordered)

                    Button("Mute 8 Hours") {
                        alertManager.muteNotifications(for: 28_800)
                    }
                    .buttonStyle(.bordered)

                    if alertManager.notificationsMutedUntil != nil {
                        Button("Clear Mute") {
                            alertManager.clearNotificationMute()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Text(permissionSummary)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var activeAlertsCard: some View {
        AlertSurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Active Alerts")
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                    AlertSeverityBadge(severity: alertManager.highestActiveSeverity)
                }

                if alertManager.activeAlerts.isEmpty {
                    Text("No active alerts. Recent alert history remains below.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(alertManager.activeAlerts) { alert in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(alert.title)
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(alert.message)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    if let context = alert.context {
                                        Text(context)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(Color.bdAccent)
                                    }
                                }
                                Spacer()
                                AlertSeverityBadge(severity: alert.severity)
                            }

                            HStack(spacing: 10) {
                                Button("Snooze 1h") {
                                    alertManager.snooze(alert.kind, for: 3_600)
                                }
                                .buttonStyle(.bordered)

                                Button("Hide For Now") {
                                    alertManager.dismissUntilRecovery(alert.kind)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
    }

    private var privacyCard: some View {
        AlertSurfaceCard {
            PrivacyControlsSectionContent(alertManager: alertManager)
        }
    }

    private var ruleGroups: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(AlertCategory.allCases) { category in
                if let configs = alertManager.groupedConfigs[category] {
                    AlertSurfaceCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(category.title)
                                .font(.system(size: 16, weight: .bold))
                            ForEach(configs) { config in
                                AlertRuleConfigRow(
                                    alertManager: alertManager,
                                    config: config,
                                    availabilityReason: alertManager.availabilityReasons[config.kind] ?? nil
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private var historyCard: some View {
        AlertSurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent History")
                    .font(.system(size: 16, weight: .bold))
                if alertManager.history.isEmpty {
                    Text("No alert history yet.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                } else {
                    if alertManager.processInsightsEnabled == false {
                        Text("Process names are removed from recent history while privacy controls are on.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(alertManager.history.prefix(12)) { event in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: event.kind.systemImageName)
                                .foregroundStyle(color(for: event.severity))
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(event.title)
                                        .font(.system(size: 12, weight: .semibold))
                                    Spacer()
                                    Text(event.timestamp.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                                Text(event.message)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                if let context = event.context {
                                    Text(context)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.bdAccent)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var permissionSummary: String {
        switch alertManager.authorizationStatus {
        case .authorized, .provisional:
            if let mutedUntil = alertManager.notificationsMutedUntil, mutedUntil > Date() {
                return "Desktop notifications are muted until \(mutedUntil.formatted(date: .omitted, time: .shortened)). In-app history is still active."
            }
            return "Notifications are allowed. Current fan mode: \(fanController.mode.title)."
        case .denied:
            return "Notifications are denied in System Settings. Core Monitor still keeps in-app history and active alert state."
        case .notDetermined:
            return "Notifications have not been authorized yet. In-app history and alert state are already active."
        @unknown default:
            return "Notification permission state is unavailable."
        }
    }

    private func color(for severity: AlertSeverity) -> Color {
        switch severity {
        case .none: return .secondary
        case .info: return Color.bdAccent
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

private struct AlertRuleConfigRow: View {
    @ObservedObject var alertManager: AlertManager
    let config: AlertRuleConfig
    let availabilityReason: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Toggle(
                    isOn: Binding(
                        get: { config.isEnabled },
                        set: { alertManager.setRuleEnabled($0, for: config.kind) }
                    )
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: config.kind.systemImageName)
                                .foregroundStyle(Color.bdAccent)
                            Text(config.kind.title)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        Text(config.kind.subtitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Spacer()

                if let active = alertManager.activeAlerts.first(where: { $0.kind == config.kind }) {
                    AlertSeverityBadge(severity: active.severity)
                }
            }

            if let availabilityReason {
                Text(availabilityReason)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.orange)
            }

            if config.kind.supportsThresholdEditing {
                AlertThresholdEditor(alertManager: alertManager, config: config)
            } else {
                Text(nonNumericSummary)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Stepper(
                    "Cooldown \(config.cooldownMinutes)m",
                    value: Binding(
                        get: { config.cooldownMinutes },
                        set: { alertManager.setCooldownMinutes($0, for: config.kind) }
                    ),
                    in: 1...180
                )
                .labelsHidden()

                Text("Cooldown \(config.cooldownMinutes)m")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                if config.kind.supportsDesktopNotifications {
                    Toggle(
                        "Desktop",
                        isOn: Binding(
                            get: { config.desktopNotificationsEnabled },
                            set: { alertManager.setRuleDesktopNotificationsEnabled($0, for: config.kind) }
                        )
                    )
                    .toggleStyle(.switch)
                    .labelsHidden()
                    Text("Desktop")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var nonNumericSummary: String {
        switch config.kind {
        case .overallThermalState:
            return "Warns from macOS thermal pressure transitions."
        case .memoryPressure:
            return "Warns from yellow/red pressure, not a guessed RAM percentage."
        case .fanTooLowUnderHeat:
            return "Warns when fan RPM stays too low relative to current heat."
        case .smcUnavailable, .helperUnavailable:
            return "Service-state rule. Thresholds are determined by live availability."
        default:
            return "Thresholds are controlled by the active preset."
        }
    }
}

private struct AlertThresholdEditor: View {
    @ObservedObject var alertManager: AlertManager
    let config: AlertRuleConfig

    var body: some View {
        HStack(spacing: 16) {
            thresholdStepper(
                label: "Warning",
                value: warningBinding,
                range: warningRange,
                formattedValue: format(value: config.threshold.warning)
            )
            thresholdStepper(
                label: "Critical",
                value: criticalBinding,
                range: criticalRange,
                formattedValue: format(value: config.threshold.critical)
            )
        }
    }

    private func thresholdStepper(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        formattedValue: String
    ) -> some View {
        HStack(spacing: 8) {
            Text("\(label) \(formattedValue)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Stepper("", value: value, in: range, step: stepValue)
                .labelsHidden()
        }
    }

    private var warningBinding: Binding<Double> {
        Binding(
            get: { config.threshold.warning ?? warningRange.lowerBound },
            set: { alertManager.setWarningThreshold($0, for: config.kind) }
        )
    }

    private var criticalBinding: Binding<Double> {
        Binding(
            get: { config.threshold.critical ?? criticalRange.upperBound },
            set: { alertManager.setCriticalThreshold($0, for: config.kind) }
        )
    }

    private var stepValue: Double {
        switch config.kind {
        case .swapUsage: return 1
        default: return 1
        }
    }

    private var warningRange: ClosedRange<Double> {
        switch config.kind {
        case .batteryHealth, .lowBatteryDischarging:
            return 5...100
        case .swapUsage:
            return 1...64
        case .cpuUsage:
            return 50...100
        case .cpuTemperature, .gpuTemperature, .batteryTemperature:
            return 25...110
        default:
            return 0...100
        }
    }

    private var criticalRange: ClosedRange<Double> {
        switch config.kind {
        case .batteryHealth, .lowBatteryDischarging:
            return 1...(config.threshold.warning ?? 100)
        case .swapUsage:
            return (config.threshold.warning ?? 1)...96
        default:
            return (config.threshold.warning ?? 1)...120
        }
    }

    private func format(value: Double?) -> String {
        guard let value else { return "Off" }
        if let unit = config.kind.unitLabel {
            return unit == "GB" ? String(format: "%.0f %@", value, unit) : String(format: "%.0f%@", value, unit)
        }
        return String(format: "%.0f", value)
    }
}
