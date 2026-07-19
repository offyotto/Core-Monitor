import SwiftUI

/// Root of the dashboard window: live sidebar on the left, section pages on
/// the right. Every sidebar row carries its current reading so the sidebar
/// doubles as an always-on instrument cluster.
struct MainWindowView: View {
    @ObservedObject var systemMonitor: SystemMonitor
    @ObservedObject var fanController: FanController
    @ObservedObject var startupManager: StartupManager
    @ObservedObject private var navigationRouter = DashboardNavigationRouter.shared

    @AppStorage(WelcomeGuideProgress.hasSeenDefaultsKey) private var hasSeenWelcome = false
    @State private var selection: MonitorSection? = .overview

    private var selectedSection: MonitorSection {
        selection ?? .overview
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            SectionPageView(
                section: selectedSection,
                systemMonitor: systemMonitor,
                fanController: fanController,
                openSection: { selection = $0 }
            )
            .navigationTitle(selectedSection.title)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 880, minHeight: 620)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    SettingsWindowManager.shared.show()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .help("Core Monitor settings (⌘,)")
            }
        }
        .sheet(isPresented: welcomeBinding) {
            WelcomeView {
                hasSeenWelcome = true
            }
        }
        .onAppear {
            systemMonitor.setBasicMode(false)
            systemMonitor.setInteractiveMonitoringEnabled(true, reason: "dashboard")
            consumePendingRoute()
            syncDetailedSampling()
        }
        .onChange(of: selection) { _ in
            syncDetailedSampling()
        }
        .onChange(of: navigationRouter.route) { _ in
            consumePendingRoute()
            syncDetailedSampling()
        }
        .onDisappear {
            systemMonitor.setInteractiveMonitoringEnabled(false, reason: "dashboard")
            systemMonitor.setDetailedSamplingEnabled(false, reason: "dashboard.detail")
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selection) {
            Section("Monitor") {
                sidebarRow(.overview)
                sidebarRow(.cpu)
                sidebarRow(.memory)
                sidebarRow(.thermal)
                sidebarRow(.cooling)
                sidebarRow(.power)
                sidebarRow(.network)
                sidebarRow(.storage)
            }
            Section("Toolkit") {
                sidebarRow(.rescue)
            }
        }
        .listStyle(.sidebar)
        // Drop the translucent sidebar material so the sidebar matches the
        // detail pages' flat window background instead of reading as gray.
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .windowBackgroundColor))
        // With the material gone the split view no longer draws its own edge,
        // so add a hairline to separate the sidebar from the detail pane.
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(width: 1)
                .ignoresSafeArea()
        }
        .navigationTitle("Core Monitor")
        .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 280)
    }

    private func sidebarRow(_ section: MonitorSection) -> some View {
        NavigationLink(value: section) {
            HStack {
                Label {
                    Text(section.title)
                } icon: {
                    Image(systemName: section.symbolName)
                        .foregroundStyle(section.tint)
                }
                Spacer(minLength: 8)
                if let readout = sidebarReadout(for: section) {
                    Text(readout)
                        .font(.readingSmall.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func sidebarReadout(for section: MonitorSection) -> String? {
        let snapshot = systemMonitor.snapshot
        guard snapshot.sampledAt != .distantPast else { return nil }

        switch section {
        case .overview, .rescue:
            return nil
        case .cpu:
            return ReadingFormat.percent(snapshot.cpuUsagePercent)
        case .memory:
            return ReadingFormat.percent(snapshot.memoryUsagePercent)
        case .thermal:
            return ReadingFormat.celsius(snapshot.cpuTemperature)
        case .cooling:
            let active = snapshot.fanSpeeds.filter { $0 > 0 }
            guard let fastest = active.max() else {
                return snapshot.numberOfFans > 0 ? "rest" : nil
            }
            return ReadingFormat.rpmShort(fastest)
        case .power:
            if let percent = snapshot.batteryInfo.chargePercent {
                return "\(percent)%"
            }
            return snapshot.totalSystemWatts.map { ReadingFormat.watts($0) }
        case .network:
            let stats = snapshot.networkStats
            let dominant = max(stats.downloadBytesPerSec, stats.uploadBytesPerSec)
            guard dominant >= 1_000 else { return nil }
            let arrow = stats.downloadBytesPerSec >= stats.uploadBytesPerSec ? "↓" : "↑"
            return arrow + ReadingFormat.rate(dominant)
        case .storage:
            return ReadingFormat.percent(snapshot.diskStats.usagePercent)
        }
    }

    // MARK: - Plumbing

    private var welcomeBinding: Binding<Bool> {
        Binding {
            hasSeenWelcome == false
        } set: { isPresented in
            if isPresented == false {
                hasSeenWelcome = true
            }
        }
    }

    private func consumePendingRoute() {
        guard let route = navigationRouter.route,
              let destination = navigationRouter.consume(route) else {
            return
        }
        selection = destination
    }

    private func syncDetailedSampling() {
        systemMonitor.setDetailedSamplingEnabled(
            DashboardProcessSamplingPolicy.requiresDetailedSampling(
                isBasicMode: false,
                selection: selectedSection
            ),
            reason: "dashboard.detail"
        )
    }
}

/// Routes a section to its page view.
private struct SectionPageView: View {
    let section: MonitorSection
    @ObservedObject var systemMonitor: SystemMonitor
    @ObservedObject var fanController: FanController
    let openSection: (MonitorSection) -> Void

    var body: some View {
        switch section {
        case .overview:
            OverviewPage(systemMonitor: systemMonitor, openSection: openSection)
        case .cpu:
            CPUPage(systemMonitor: systemMonitor)
        case .memory:
            MemoryPage(systemMonitor: systemMonitor)
        case .thermal:
            ThermalPage(systemMonitor: systemMonitor)
        case .cooling:
            CoolingPage(systemMonitor: systemMonitor, fanController: fanController)
        case .power:
            PowerPage(systemMonitor: systemMonitor)
        case .network:
            NetworkPage(systemMonitor: systemMonitor)
        case .storage:
            StoragePage(systemMonitor: systemMonitor)
        case .rescue:
            RescuePage()
        }
    }
}
