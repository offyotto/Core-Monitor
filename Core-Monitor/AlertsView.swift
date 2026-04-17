import SwiftUI
import UserNotifications

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

struct AlertsDashboardStripPresentation: Equatable {
    struct Action: Equatable {
        enum Style: Equatable {
            case prominent
            case standard
        }

        let title: String
        let icon: String
        let style: Style
    }

    let detail: String
    let action: Action?

    init(alertManager: AlertManager) {
        self.init(
            activeAlertCount: alertManager.activeAlerts.count,
            authorizationStatus: alertManager.authorizationStatus,
            desktopNotificationsEnabled: alertManager.desktopNotificationsEnabled,
            notificationsMutedUntil: alertManager.notificationsMutedUntil
        )
    }

    init(
        activeAlertCount: Int,
        authorizationStatus: UNAuthorizationStatus,
        desktopNotificationsEnabled: Bool,
        notificationsMutedUntil: Date?,
        now: Date = Date()
    ) {
        if activeAlertCount > 0 {
            detail = "\(activeAlertCount) active alert\(activeAlertCount == 1 ? "" : "s")"
            action = Action(title: "Open Alerts", icon: "bell.badge", style: .prominent)
            return
        }

        let notificationsMuted = notificationsMutedUntil.map { $0 > now } ?? false

        switch authorizationStatus {
        case .notDetermined:
            detail = "Desktop notifications are not set up yet. In-app history already records every alert."
            action = Action(title: "Set Up Alerts", icon: "bell.badge", style: .standard)
        case .denied:
            detail = "Desktop notifications are off in System Settings. In-app history still records every alert."
            action = Action(title: "Alert Settings", icon: "bell.slash", style: .standard)
        case .authorized, .provisional:
            if notificationsMuted {
                detail = "Desktop notifications are muted for now. In-app history still records every alert."
                action = Action(title: "Alert Settings", icon: "bell.slash", style: .standard)
            } else if desktopNotificationsEnabled == false {
                detail = "Desktop banners are off. In-app history still records every alert."
                action = Action(title: "Alert Settings", icon: "bell.slash", style: .standard)
            } else {
                detail = "Alert thresholds and recent history stay available from the Alerts screen."
                action = nil
            }
        @unknown default:
            detail = "Alert thresholds and recent history stay available from the Alerts screen."
            action = nil
        }
    }
}

struct AlertsDashboardStrip: View {
    @ObservedObject var alertManager: AlertManager
    var openAlerts: (() -> Void)? = nil

    var body: some View {
        let presentation = AlertsDashboardStripPresentation(alertManager: alertManager)

        DashboardSurfaceCard {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        AlertSeverityBadge(severity: alertManager.highestActiveSeverity)
                        Text(alertManager.summaryLine)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    Text(presentation.detail)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                if let openAlerts, let action = presentation.action {
                    if action.style == .prominent {
                        Button(action: openAlerts) {
                            Label(action.title, systemImage: action.icon)
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button(action: openAlerts) {
                            Label(action.title, systemImage: action.icon)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
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
                    title: "Notifications",
                    value: notificationLabel,
                    detail: notificationDetail,
                    icon: "bell.badge",
                    color: notificationColor
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

    private var notificationLabel: String {
        "Alerts"
    }

    private var notificationDetail: String {
        "Open the Alerts screen to review thresholds, notification policy, and history."
    }

    private var notificationColor: Color {
        Color.bdAccent
    }

    private var helperValue: String {
        helperSummary.label
    }

    private var helperDetail: String {
        if fanController.mode.requiresPrivilegedHelper == false {
            return "Current cooling mode does not require the helper."
        }

        if let statusMessage = helperManager.statusMessage, statusMessage.isEmpty == false {
            return statusMessage
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

    private func summaryPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color.opacity(0.16))
            .clipShape(Capsule())
    }

    private func statusBadge(label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.16))
            .clipShape(Capsule())
    }

    private func freshnessColor(_ health: MonitoringSnapshotHealth) -> Color {
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
        .onAppear {
            systemMonitor.setDetailedSamplingEnabled(true, reason: "dashboard.alerts")
        }
        .onDisappear {
            systemMonitor.setDetailedSamplingEnabled(false, reason: "dashboard.alerts")
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
            SystemStatusBoard(systemMonitor: systemMonitor, fanController: fanController)
        }
    }

    private var presetCard: some View {
        DashboardSurfaceCard {
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
        DashboardSurfaceCard {
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

    private var privacyCard: some View {
        DashboardSurfaceCard {
            PrivacyControlsSectionContent()
        }
    }

    private var activeAlertsCard: some View {
        DashboardSurfaceCard {
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

    private var ruleGroups: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(AlertCategory.allCases) { category in
                if let configs = alertManager.groupedConfigs[category] {
                    DashboardSurfaceCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(category.title)
                                .font(.system(size: 16, weight: .bold))
                            ForEach(configs) { config in
                                AlertRuleConfigRow(
                                    alertManager: alertManager,
                                    config: config,
                                    availabilityReason: alertManager.availabilityReasons[config.kind]
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private var historyCard: some View {
        DashboardSurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Recent History")
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                    Button("Clear History") {
                        alertManager.clearHistory()
                    }
                    .buttonStyle(.bordered)
                    .disabled(alertManager.history.isEmpty)
                }

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

                if let availabilityReason, config.isEnabled {
                    Text(availabilityReason)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }

            if config.kind.supportsThresholdEditing {
                HStack(spacing: 16) {
                    thresholdField(
                        title: "Warning",
                        value: config.threshold.warning,
                        unitLabel: config.kind.unitLabel
                    ) { value in
                        alertManager.setWarningThreshold(value, for: config.kind)
                    }

                    thresholdField(
                        title: "Critical",
                        value: config.threshold.critical,
                        unitLabel: config.kind.unitLabel
                    ) { value in
                        alertManager.setCriticalThreshold(value, for: config.kind)
                    }
                }
            }

            HStack(spacing: 16) {
                Stepper(value: Binding(
                    get: { config.cooldownMinutes },
                    set: { alertManager.setCooldownMinutes($0, for: config.kind) }
                ), in: 1...1_440, step: 1) {
                    Text("Repeat every \(config.cooldownMinutes) min")
                        .font(.system(size: 11, weight: .medium))
                }
                .labelsHidden()

                if config.kind.supportsDesktopNotifications {
                    Toggle(
                        "Desktop banner",
                        isOn: Binding(
                            get: { config.desktopNotificationsEnabled },
                            set: { alertManager.setRuleDesktopNotificationsEnabled($0, for: config.kind) }
                        )
                    )
                    .toggleStyle(.switch)
                }
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func thresholdField(
        title: String,
        value: Double?,
        unitLabel: String?,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                TextField(
                    title,
                    text: Binding(
                        get: { value.map { Self.formattedValue($0) } ?? "" },
                        set: { newValue in
                            guard let parsed = Double(newValue) else { return }
                            onChange(parsed)
                        }
                    )
                )
                .textFieldStyle(.roundedBorder)
                .frame(width: 72)

                if let unitLabel {
                    Text(unitLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private static func formattedValue(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
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
        if fanController.mode.requiresPrivilegedHelper == false {
            return "Current cooling mode does not require the helper."
        }

        if let statusMessage = helperManager.statusMessage, statusMessage.isEmpty == false {
            return statusMessage
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
