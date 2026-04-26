import AppKit
import SwiftUI

extension Color {
    static var bdAccent: Color { .accentColor }
    static var bdDivider: Color { Color(nsColor: .separatorColor) }
    static var bdSelected: Color { Color(nsColor: .selectedContentBackgroundColor) }
    static var bdSidebar: Color { Color(nsColor: .controlBackgroundColor) }
    static var bdContent: Color { Color(nsColor: .windowBackgroundColor) }
    static var bdCard: Color { Color(nsColor: .controlBackgroundColor) }
    static var bdShellShadow: Color { .clear }
    static var bdSidebarStroke: Color { Color(nsColor: .separatorColor) }
    static var bdSidebarInner: Color { Color(nsColor: .controlBackgroundColor) }
}

struct CoreMonBackdrop: View {
    var body: some View {
        Color(nsColor: .windowBackgroundColor)
            .ignoresSafeArea()
    }
}

enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case overview = "Overview"
    case thermals = "Thermals"
    case memory = "Memory"
    case fans = "Fans"
    case battery = "Battery"
    case system = "System"
    case touchBar = "Touch Bar"
    case help = "Help"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview: return "gauge.medium"
        case .thermals: return "thermometer.medium"
        case .memory: return "memorychip"
        case .fans: return "fanblades"
        case .battery: return "battery.75"
        case .system: return "gearshape"
        case .touchBar: return "rectangle.3.group"
        case .help: return "questionmark.circle"
        case .about: return "info.circle"
        }
    }

    var subtitle: String {
        switch self {
        case .overview: return "Live readings and device status"
        case .thermals: return "Temperature sensors and SMC state"
        case .memory: return "Unified memory pressure and process usage"
        case .fans: return "Cooling mode, helper state, and fan speed"
        case .battery: return "Battery health, charge, and power"
        case .system: return "Startup, privacy, and menu bar behavior"
        case .touchBar: return "Touch Bar layout and presentation"
        case .help: return "Common tasks and support notes"
        case .about: return "Version, model, and language"
        }
    }
}

struct ContentView: View {
    @ObservedObject var systemMonitor: SystemMonitor
    @ObservedObject var fanController: FanController
    @ObservedObject var startupManager: StartupManager
    @ObservedObject private var dashboardNavigationRouter = DashboardNavigationRouter.shared

    @State private var sidebarSelection: SidebarItem? = .overview

    private var selectedItem: SidebarItem {
        sidebarSelection ?? .overview
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $sidebarSelection) {
                Section("Monitoring") {
                    sidebarLink(.overview)
                    sidebarLink(.thermals)
                    sidebarLink(.memory)
                    sidebarLink(.fans)
                    if systemMonitor.snapshot.batteryInfo.hasBattery {
                        sidebarLink(.battery)
                    }
                }

                Section("Settings") {
                    sidebarLink(.system)
                    sidebarLink(.touchBar)
                }

                Section("Support") {
                    sidebarLink(.help)
                    sidebarLink(.about)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Core Monitor")
            .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 280)
        } detail: {
            NativeDashboardDetail(
                selection: selectedItem,
                systemMonitor: systemMonitor,
                fanController: fanController,
                startupManager: startupManager
            )
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 900, minHeight: 640)
        .onAppear {
            systemMonitor.setBasicMode(false)
            systemMonitor.setInteractiveMonitoringEnabled(true, reason: "dashboard")
            applyPendingDashboardRouteIfNeeded()
            syncDashboardSampling()
        }
        .onChange(of: sidebarSelection) { _ in
            syncDashboardSampling()
        }
        .onChange(of: dashboardNavigationRouter.route) { _ in
            applyPendingDashboardRouteIfNeeded()
            syncDashboardSampling()
        }
        .onDisappear {
            systemMonitor.setInteractiveMonitoringEnabled(false, reason: "dashboard")
            systemMonitor.setDetailedSamplingEnabled(false, reason: "dashboard.detail")
        }
    }

    private func sidebarLink(_ item: SidebarItem) -> some View {
        NavigationLink(value: item) {
            Label(item.rawValue, systemImage: item.icon)
        }
    }

    private func applyPendingDashboardRouteIfNeeded() {
        guard let route = dashboardNavigationRouter.route,
              let selection = dashboardNavigationRouter.consume(route) else {
            return
        }
        sidebarSelection = selection
    }

    private func syncDashboardSampling() {
        systemMonitor.setDetailedSamplingEnabled(
            DashboardProcessSamplingPolicy.requiresDetailedSampling(
                isBasicMode: false,
                selection: selectedItem
            ),
            reason: "dashboard.detail"
        )
    }
}

private struct NativeDashboardDetail: View {
    let selection: SidebarItem
    @ObservedObject var systemMonitor: SystemMonitor
    @ObservedObject var fanController: FanController
    @ObservedObject var startupManager: StartupManager

    var body: some View {
        VStack(spacing: 0) {
            NativePageHeader(selection: selection, systemMonitor: systemMonitor)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    page
                }
                .frame(maxWidth: 780, alignment: .leading)
                .padding(24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle(selection.rawValue)
    }

    @ViewBuilder
    private var page: some View {
        let snapshot = systemMonitor.snapshot
        switch selection {
        case .overview:
            NativeOverviewPage(systemMonitor: systemMonitor, snapshot: snapshot)
        case .thermals:
            NativeThermalsPage(snapshot: snapshot)
        case .memory:
            NativeMemoryPage(snapshot: snapshot)
        case .fans:
            NativeFansPage(fanController: fanController, snapshot: snapshot)
        case .battery:
            NativeBatteryPage(snapshot: snapshot)
        case .system:
            NativeSystemPage(systemMonitor: systemMonitor, startupManager: startupManager)
        case .touchBar:
            NativeTouchBarPage()
        case .help:
            NativeHelpPage()
        case .about:
            NativeAboutPage()
        }
    }
}

private struct NativePageHeader: View {
    let selection: SidebarItem
    @ObservedObject var systemMonitor: SystemMonitor

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(selection.rawValue)
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                Text(selection.subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let health = systemMonitor.snapshotHealth(now: context.date)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(health.statusLabel)
                        .font(.callout)
                        .fontWeight(.semibold)
                    Text(health.ageDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }
}

private struct NativeOverviewPage: View {
    @ObservedObject var systemMonitor: SystemMonitor
    let snapshot: SystemMonitorSnapshot

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let health = systemMonitor.snapshotHealth(now: context.date)

            NativeSettingsSection("Monitoring") {
                NativeValueRow("Status", value: health.statusLabel, detail: "\(health.ageDescription). \(health.cadenceDescription).")
                NativeDivider()
                NativeValueRow("Sample Time", value: sampleTime(snapshot.sampledAt))
                NativeDivider()
                NativeValueRow("SMC Access", value: snapshot.hasSMCAccess ? "Available" : "Unavailable", detail: snapshot.lastError)
            }
        }

        NativeSettingsSection("Processor and Memory") {
            NativeProgressRow("CPU Load", value: percentString(snapshot.cpuUsagePercent), fraction: snapshot.cpuUsagePercent / 100)
            if let performance = snapshot.performanceCoreUsagePercent {
                NativeDivider()
                NativeProgressRow("Performance Cores", value: percentString(performance), fraction: performance / 100)
            }
            if let efficiency = snapshot.efficiencyCoreUsagePercent {
                NativeDivider()
                NativeProgressRow("Efficiency Cores", value: percentString(efficiency), fraction: efficiency / 100)
            }
            NativeDivider()
            NativeProgressRow(
                "Memory",
                value: "\(gbString(snapshot.memoryUsedGB)) of \(gbString(snapshot.totalMemoryGB))",
                fraction: snapshot.memoryUsagePercent / 100
            )
        }

        NativeSettingsSection("Temperature, Power, and Storage") {
            NativeValueRow("CPU Temperature", value: temperatureString(snapshot.cpuTemperature))
            NativeDivider()
            NativeValueRow("GPU Temperature", value: temperatureString(snapshot.gpuTemperature))
            if let watts = snapshot.totalSystemWatts {
                NativeDivider()
                NativeValueRow("System Power", value: String(format: "%.1f W", abs(watts)))
            }
            NativeDivider()
            NativeProgressRow(
                "Storage",
                value: "\(gbString(snapshot.diskStats.usedGB)) of \(gbString(snapshot.diskStats.totalGB))",
                fraction: snapshot.diskStats.usagePercent / 100
            )
        }

        NativeSettingsSection("Network") {
            NativeValueRow("Download", value: NetworkThroughputFormatter.compactRate(bytesPerSecond: snapshot.networkStats.downloadBytesPerSec))
            NativeDivider()
            NativeValueRow("Upload", value: NetworkThroughputFormatter.compactRate(bytesPerSecond: snapshot.networkStats.uploadBytesPerSec))
        }
    }
}

private struct NativeThermalsPage: View {
    let snapshot: SystemMonitorSnapshot

    var body: some View {
        NativeSettingsSection("Thermal State") {
            NativeValueRow("macOS Thermal Pressure", value: thermalStateTitle(snapshot.thermalState), detail: thermalStateDetail(snapshot.thermalState))
            NativeDivider()
            NativeValueRow("CPU Temperature", value: temperatureString(snapshot.cpuTemperature))
            NativeDivider()
            NativeValueRow("GPU Temperature", value: temperatureString(snapshot.gpuTemperature))
            NativeDivider()
            NativeValueRow("SSD Temperature", value: temperatureString(snapshot.ssdTemperature))
        }

        NativeSettingsSection("Fan Sensors") {
            if snapshot.fanSpeeds.isEmpty {
                NativeEmptyMessage("No fan sensor readings are available.")
            } else {
                ForEach(Array(snapshot.fanSpeeds.enumerated()), id: \.offset) { index, rpm in
                    NativeValueRow("Fan \(index + 1)", value: "\(rpm) RPM")
                    if index != snapshot.fanSpeeds.indices.last {
                        NativeDivider()
                    }
                }
            }
        }

        NativeSettingsSection("SMC") {
            NativeValueRow("Access", value: snapshot.hasSMCAccess ? "Available" : "Unavailable", detail: snapshot.lastError)
        }
    }
}

private struct NativeMemoryPage: View {
    @ObservedObject private var privacySettings = PrivacySettings.shared
    let snapshot: SystemMonitorSnapshot

    var body: some View {
        NativeSettingsSection("Memory") {
            NativeProgressRow("Usage", value: percentString(snapshot.memoryUsagePercent), fraction: snapshot.memoryUsagePercent / 100)
            NativeDivider()
            NativeValueRow("Pressure", value: memoryPressureTitle(snapshot.memoryPressure))
            NativeDivider()
            NativeValueRow("App Memory", value: gbString(snapshot.appMemoryGB))
            NativeDivider()
            NativeValueRow("Wired Memory", value: gbString(snapshot.wiredMemoryGB))
            NativeDivider()
            NativeValueRow("Compressed", value: gbString(snapshot.compressedMemoryGB))
            NativeDivider()
            NativeValueRow("Free", value: gbString(snapshot.freeMemoryGB))
        }

        NativeSettingsSection("Process Privacy") {
            Toggle("Show app names in process tables", isOn: $privacySettings.processInsightsEnabled)
                .toggleStyle(.switch)
            Text(privacySettings.processInsightsEnabled
                ? "Process names are shown locally to help explain spikes."
                : "Process usage is still sampled locally, but names are hidden in this interface.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        NativeSettingsSection("Top CPU Processes") {
            NativeProcessTable(processes: snapshot.topProcesses.topCPU, showNames: privacySettings.processInsightsEnabled)
        }

        NativeSettingsSection("Top Memory Processes") {
            NativeProcessTable(processes: snapshot.topProcesses.topMemory, showNames: privacySettings.processInsightsEnabled)
        }
    }
}

private struct NativeFansPage: View {
    @ObservedObject var fanController: FanController
    @ObservedObject private var helperManager = SMCHelperManager.shared
    let snapshot: SystemMonitorSnapshot

    var body: some View {
        NativeSettingsSection("Cooling") {
            Picker("Mode", selection: fanModeBinding) {
                ForEach(FanControlMode.quickModes, id: \.rawValue) { mode in
                    Text(mode.nativeTitle).tag(mode.rawValue)
                }
            }
            .pickerStyle(.menu)

            Text(fanController.statusMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if fanController.mode == .manual {
                NativeDivider()
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Target Speed", value: "\(fanController.manualSpeed) RPM")
                    Slider(value: manualSpeedBinding, in: Double(fanController.minSpeed)...Double(fanController.maxSpeed), step: 50)
                }
            }

            if fanController.mode == .smart {
                NativeDivider()
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Aggressiveness", value: String(format: "%.1f", fanController.autoAggressiveness))
                    Slider(value: autoAggressivenessBinding, in: 0...3, step: 0.1)
                    LabeledContent("Maximum Speed", value: "\(fanController.autoMaxSpeed) RPM")
                    Slider(value: autoMaxSpeedBinding, in: Double(fanController.minSpeed)...Double(fanController.maxSpeed), step: 50)
                }
            }

            NativeDivider()
            HStack {
                Button("Restore Automatic") {
                    fanController.resetToSystemAutomatic()
                    fanController.setMode(.automatic)
                }
                Button("Calibrate") {
                    fanController.calibrateFanControl()
                }
                .disabled(fanController.isCalibrating)
            }
        }

        NativeSettingsSection("Fan Readings") {
            if snapshot.fanSpeeds.isEmpty {
                NativeEmptyMessage("No fan readings are available on this Mac.")
            } else {
                ForEach(Array(snapshot.fanSpeeds.enumerated()), id: \.offset) { index, rpm in
                    NativeValueRow("Fan \(index + 1)", value: "\(rpm) RPM", detail: fanRangeText(index: index, snapshot: snapshot))
                    if index != snapshot.fanSpeeds.indices.last {
                        NativeDivider()
                    }
                }
            }
        }

        NativeSettingsSection("Privileged Helper") {
            NativeValueRow("Installation", value: helperManager.isInstalled ? "Installed" : "Not Installed")
            NativeDivider()
            NativeValueRow("Connection", value: helperManager.connectionState.title, detail: helperManager.statusMessage)
            NativeDivider()
            HStack {
                Button(helperManager.isInstalled ? "Repair Helper" : "Install Helper") {
                    helperManager.installFromApp(forceReinstall: helperManager.isInstalled)
                }
                Button("Check Connection") {
                    helperManager.refreshDiagnostics()
                }
            }
        }
    }

    private var fanModeBinding: Binding<String> {
        Binding {
            fanController.mode.rawValue
        } set: { rawValue in
            if let mode = FanControlMode(rawValue: rawValue) {
                fanController.setMode(mode)
            }
        }
    }

    private var manualSpeedBinding: Binding<Double> {
        Binding {
            Double(fanController.manualSpeed)
        } set: { value in
            fanController.setManualSpeed(Int(value.rounded()))
        }
    }

    private var autoAggressivenessBinding: Binding<Double> {
        Binding {
            fanController.autoAggressiveness
        } set: { value in
            fanController.setAutoAggressiveness(value)
        }
    }

    private var autoMaxSpeedBinding: Binding<Double> {
        Binding {
            Double(fanController.autoMaxSpeed)
        } set: { value in
            fanController.setAutoMaxSpeed(Int(value.rounded()))
        }
    }
}

private struct NativeBatteryPage: View {
    let snapshot: SystemMonitorSnapshot

    var body: some View {
        if snapshot.batteryInfo.hasBattery == false {
            NativeSettingsSection("Battery") {
                NativeEmptyMessage("This Mac does not report an internal battery.")
            }
        } else {
            NativeSettingsSection("Charge") {
                NativeProgressRow(
                    "Battery Level",
                    value: "\(snapshot.batteryInfo.chargePercent ?? 0)%",
                    fraction: Double(snapshot.batteryInfo.chargePercent ?? 0) / 100
                )
                NativeDivider()
                NativeValueRow("Power State", value: BatteryDetailFormatter.powerStateDescription(for: snapshot.batteryInfo))
                if let runtime = BatteryDetailFormatter.runtimeDescription(for: snapshot.batteryInfo) {
                    NativeDivider()
                    NativeValueRow(snapshot.batteryInfo.isCharging ? "Time to Full" : "Time Remaining", value: runtime)
                }
            }

            NativeSettingsSection("Health") {
                NativeValueRow("Health", value: snapshot.batteryInfo.healthPercent.map { "\($0)%" } ?? "Unavailable")
                NativeDivider()
                NativeValueRow("Cycle Count", value: snapshot.batteryInfo.cycleCount.map(String.init) ?? "Unavailable")
                NativeDivider()
                NativeValueRow("Temperature", value: BatteryDetailFormatter.temperatureDescription(snapshot.batteryInfo.temperatureC) ?? "Unavailable")
                NativeDivider()
                NativeValueRow("Voltage", value: BatteryDetailFormatter.voltageDescription(snapshot.batteryInfo.voltageV) ?? "Unavailable")
                NativeDivider()
                NativeValueRow("Current", value: BatteryDetailFormatter.amperageDescription(snapshot.batteryInfo.amperageA) ?? "Unavailable")
            }
        }
    }
}

private struct NativeSystemPage: View {
    @ObservedObject var systemMonitor: SystemMonitor
    @ObservedObject var startupManager: StartupManager
    @ObservedObject private var privacySettings = PrivacySettings.shared
    @ObservedObject private var menuBarSettings = MenuBarSettings.shared

    var body: some View {
        let launchSummary = LaunchAtLoginStatusSummary.make(status: startupManager.state, errorMessage: startupManager.errorMessage)

        NativeSettingsSection("Launch at Login") {
            Toggle("Open Core Monitor when you sign in", isOn: launchBinding)
                .toggleStyle(.switch)
            NativeDivider()
            NativeValueRow("Status", value: launchSummary.badge, detail: launchSummary.detail)
            if launchSummary.action == .openSystemSettings {
                NativeDivider()
                Button(launchSummary.actionTitle ?? "Open Login Items") {
                    startupManager.openLoginItemsSettings()
                }
            }
        }

        NativeSettingsSection("Privacy") {
            Toggle("Show app names in process views", isOn: $privacySettings.processInsightsEnabled)
                .toggleStyle(.switch)
            Text("Hardware readings stay local. App names are optional and only used to explain CPU and memory activity.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        NativeSettingsSection("Menu Bar") {
            Picker("Preset", selection: menuBarPresetBinding) {
                ForEach(MenuBarVisibilityPreset.allCases, id: \.title) { preset in
                    Text(preset.title).tag(preset.title)
                }
            }
            .pickerStyle(.menu)

            if let warning = menuBarSettings.lastWarning {
                Text(warning)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            NativeDivider()

            ForEach(MenuBarItemKind.allCases, id: \.defaultsKey) { kind in
                Toggle(kind.title, isOn: Binding {
                    menuBarSettings.isEnabled(kind)
                } set: { enabled in
                    menuBarSettings.setEnabled(enabled, for: kind)
                })
                .toggleStyle(.switch)
            }
        }

        NativeSettingsSection("System Levels") {
            NativeProgressRow("Volume", value: percentString(Double(systemMonitor.snapshot.currentVolume) * 100), fraction: Double(systemMonitor.snapshot.currentVolume))
            NativeDivider()
            NativeProgressRow("Brightness", value: percentString(Double(systemMonitor.snapshot.currentBrightness) * 100), fraction: Double(systemMonitor.snapshot.currentBrightness))
            NativeDivider()
            NativeValueRow("Thermal Pressure", value: thermalStateTitle(systemMonitor.snapshot.thermalState))
        }
    }

    private var launchBinding: Binding<Bool> {
        Binding {
            startupManager.isEnabled
        } set: { enabled in
            startupManager.setEnabled(enabled)
        }
    }

    private var menuBarPresetBinding: Binding<String> {
        Binding {
            (menuBarSettings.activePreset ?? MenuBarSettings.defaultPreset).title
        } set: { title in
            guard let preset = MenuBarVisibilityPreset.allCases.first(where: { $0.title == title }) else { return }
            menuBarSettings.applyPreset(preset)
        }
    }
}

private struct NativeTouchBarPage: View {
    @ObservedObject private var settings = TouchBarCustomizationSettings.shared

    var body: some View {
        NativeSettingsSection("Presentation") {
            Picker("Hardware Touch Bar", selection: presentationModeBinding) {
                ForEach(TouchBarPresentationMode.allCases) { mode in
                    Text(mode.title).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)

            Picker("Theme", selection: themeBinding) {
                ForEach(TouchBarTheme.allCases) { theme in
                    Text(theme.displayName).tag(theme)
                }
            }
            .pickerStyle(.segmented)

            NativeValueRow(
                "Estimated Width",
                value: "\(Int(settings.estimatedWidth.rounded())) pt",
                detail: settings.widthOverflow > 0 ? "This layout exceeds the recommended Touch Bar width." : nil
            )
        }

        NativeSettingsSection("Presets") {
            ForEach(TouchBarPreset.all) { preset in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(preset.title)
                        Text(preset.subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(settings.activePreset == preset ? "Selected" : "Use") {
                        settings.applyPreset(preset)
                    }
                    .disabled(settings.activePreset == preset)
                }
                if preset.id != TouchBarPreset.all.last?.id {
                    NativeDivider()
                }
            }
            NativeDivider()
            Button("Restore Defaults") {
                settings.restoreDefaults()
            }
        }

        NativeSettingsSection("Active Items") {
            ForEach(Array(settings.items.enumerated()), id: \.element.id) { index, item in
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                        Text(item.subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button {
                        settings.moveUp(item)
                    } label: {
                        Image(systemName: "chevron.up")
                    }
                    .help("Move Up")
                    .disabled(index == 0)

                    Button {
                        settings.moveDown(item)
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .help("Move Down")
                    .disabled(index == settings.items.count - 1)

                    Button {
                        settings.remove(item)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .help("Remove")
                    .disabled(settings.items.count <= 1)
                }
                if index != settings.items.indices.last {
                    NativeDivider()
                }
            }
        }

        NativeSettingsSection("Built-In Widgets") {
            ForEach(TouchBarWidgetKind.allCases) { kind in
                Toggle(kind.title, isOn: Binding {
                    settings.contains(kind)
                } set: { _ in
                    settings.toggle(kind)
                })
                .toggleStyle(.switch)
            }
        }
    }

    private var presentationModeBinding: Binding<String> {
        Binding {
            settings.presentationMode.rawValue
        } set: { rawValue in
            settings.presentationMode = TouchBarPresentationMode(rawValue: rawValue) ?? .app
        }
    }

    private var themeBinding: Binding<TouchBarTheme> {
        Binding {
            settings.theme
        } set: { theme in
            settings.theme = theme
        }
    }
}

private struct NativeHelpPage: View {
    var body: some View {
        NativeSettingsSection("Monitoring") {
            NativeHelpRow("Open the dashboard from the menu bar item or the application menu.")
            NativeDivider()
            NativeHelpRow("Detailed process sampling is enabled only while the Memory page is open.")
            NativeDivider()
            NativeHelpRow("SMC access is required for fan speed and temperature readings on supported Macs.")
        }

        NativeSettingsSection("Fan Control") {
            NativeHelpRow("Use System Automatic when you want macOS to own cooling.")
            NativeDivider()
            NativeHelpRow("Managed cooling modes may request administrator approval to install the privileged helper.")
            NativeDivider()
            NativeHelpRow("Restore Automatic before quitting if you want to hand fan control back immediately.")
        }

        NativeSettingsSection("Privacy") {
            NativeHelpRow("Hardware metrics stay on this Mac.")
            NativeDivider()
            NativeHelpRow("Process names are hidden until you enable them in System settings.")
        }
    }
}

private struct NativeAboutPage: View {
    @AppStorage(AppLocaleStore.localeOverrideKey) private var localeOverrideIdentifier = AppLocaleStore.systemLocaleValue

    var body: some View {
        NativeSettingsSection("Core Monitor") {
            HStack(spacing: 14) {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 52, height: 52)
                    .cornerRadius(10)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Core Monitor")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Version \(AppVersion.current)")
                        .foregroundStyle(.secondary)
                }
            }
            NativeDivider()
            NativeValueRow("Mac", value: MacModelRegistry.displayName(for: SystemMonitor.hostModelIdentifier()))
            NativeDivider()
            NativeValueRow("Model Identifier", value: SystemMonitor.hostModelIdentifier())
        }

        NativeSettingsSection("Language") {
            Picker("Language", selection: $localeOverrideIdentifier) {
                Text("System Default").tag(AppLocaleStore.systemLocaleValue)
                ForEach(AppLocaleStore.supportedLocaleIdentifiers, id: \.self) { identifier in
                    Text(AppLocaleStore.optionLabel(for: identifier)).tag(identifier)
                }
            }
            .pickerStyle(.menu)
            Text(AppLocaleStore.selectionSummary(for: localeOverrideIdentifier))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        NativeSettingsSection("Application") {
            Button("Quit Core Monitor") {
                NSApp.terminate(nil)
            }
        }
    }
}

private struct NativeSettingsSection<Content: View>: View {
    private let title: String
    private let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct NativeValueRow: View {
    let title: String
    let value: String
    let detail: String?

    init(_ title: String, value: String, detail: String? = nil) {
        self.title = title
        self.value = value
        self.detail = detail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent(title) {
                Text(value)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
            }
            if let detail, detail.isEmpty == false {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct NativeProgressRow: View {
    let title: String
    let value: String
    let fraction: Double

    init(_ title: String, value: String, fraction: Double) {
        self.title = title
        self.value = value
        self.fraction = clampedFraction(fraction)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            LabeledContent(title) {
                Text(value)
                    .monospacedDigit()
            }
            ProgressView(value: fraction)
                .controlSize(.small)
        }
    }
}

private struct NativeProcessTable: View {
    let processes: [ProcessActivity]
    let showNames: Bool

    var body: some View {
        if processes.isEmpty {
            NativeEmptyMessage("No process samples are available yet.")
        } else {
            Table(processes) {
                TableColumn("Process") { process in
                    Text(showNames ? process.name : "Private Process")
                }
                TableColumn("PID") { process in
                    Text("\(process.pid)")
                        .monospacedDigit()
                }
                TableColumn("CPU") { process in
                    Text(percentString(process.cpuPercent))
                        .monospacedDigit()
                }
                TableColumn("Memory") { process in
                    Text(byteString(process.memoryBytes))
                        .monospacedDigit()
                }
            }
            .frame(minHeight: 180)
        }
    }
}

private struct NativeHelpRow: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct NativeEmptyMessage: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct NativeDivider: View {
    var body: some View {
        Divider()
    }
}

private extension FanControlMode {
    var nativeTitle: String {
        switch self {
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
}

private extension SMCHelperManager.ConnectionState {
    var title: String {
        switch self {
        case .missing: return "Missing"
        case .unknown: return "Unknown"
        case .checking: return "Checking"
        case .reachable: return "Reachable"
        case .unreachable: return "Unavailable"
        }
    }
}

private func percentString(_ value: Double) -> String {
    "\(Int(value.rounded()))%"
}

private func temperatureString(_ value: Double?) -> String {
    guard let value else { return "Unavailable" }
    return "\(Int(value.rounded())) °C"
}

private func gbString(_ value: Double) -> String {
    guard value > 0 else { return "0 GB" }
    if value >= 10 {
        return String(format: "%.0f GB", value)
    }
    return String(format: "%.1f GB", value)
}

private func byteString(_ value: UInt64) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(min(value, UInt64(Int64.max))), countStyle: .memory)
}

private func sampleTime(_ date: Date) -> String {
    guard date != .distantPast else { return "Waiting" }
    return date.formatted(date: .omitted, time: .standard)
}

private func clampedFraction(_ value: Double) -> Double {
    min(max(value, 0), 1)
}

private func memoryPressureTitle(_ pressure: MemoryPressureLevel) -> String {
    switch pressure {
    case .green: return "Normal"
    case .yellow: return "Elevated"
    case .red: return "Critical"
    }
}

private func thermalStateTitle(_ state: ProcessInfo.ThermalState) -> String {
    switch state {
    case .nominal: return "Nominal"
    case .fair: return "Fair"
    case .serious: return "Serious"
    case .critical: return "Critical"
    @unknown default: return "Unknown"
    }
}

private func thermalStateDetail(_ state: ProcessInfo.ThermalState) -> String? {
    switch state {
    case .nominal: return "The system is operating normally."
    case .fair: return "macOS is beginning to manage thermal load."
    case .serious: return "Performance may be reduced to manage heat."
    case .critical: return "macOS is applying strong thermal protection."
    @unknown default: return nil
    }
}

private func fanRangeText(index: Int, snapshot: SystemMonitorSnapshot) -> String? {
    let minSpeed = snapshot.fanMinSpeeds.indices.contains(index) ? snapshot.fanMinSpeeds[index] : nil
    let maxSpeed = snapshot.fanMaxSpeeds.indices.contains(index) ? snapshot.fanMaxSpeeds[index] : nil

    switch (minSpeed, maxSpeed) {
    case let (minSpeed?, maxSpeed?):
        return "Range \(minSpeed)-\(maxSpeed) RPM"
    case let (minSpeed?, nil):
        return "Minimum \(minSpeed) RPM"
    case let (nil, maxSpeed?):
        return "Maximum \(maxSpeed) RPM"
    default:
        return nil
    }
}
