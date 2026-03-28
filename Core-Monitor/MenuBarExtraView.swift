import SwiftUI

extension Notification.Name {
    static let openCoreVisorSheet = Notification.Name("com.coremonitor.openCoreVisorSheet")
}

// MARK: - Menu bar status label
struct MenuBarStatusLabel: View {
    @ObservedObject var systemMonitor: SystemMonitor
    @ObservedObject var updater: AppUpdater
    @State private var angle: Double = 0

    var body: some  View {
        HStack(spacing: 5) {
            Image(systemName: "fanblades.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(fanColor)
                .rotationEffect(.degrees(angle))
                .task(id: spinDuration) {
                    angle = 0
                    withAnimation(.linear(duration: spinDuration).repeatForever(autoreverses: false)) {
                        angle = 360
                    }
                }

            Text(compactMetric)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(metricColor)
                .frame(minWidth: 46, alignment: .leading)

            // Blue dot when update is available
            if updater.updateAvailable != nil {
                Circle()
                    .fill(Color(red: 0.35, green: 0.72, blue: 1.0))
                    .frame(width: 5, height: 5)
            }
        }
    }

    private var compactMetric: String {
        if let temp = systemMonitor.cpuTemperature  { return "\(Int(temp.rounded()))°"                }
        if let watts = systemMonitor.totalSystemWatts { return String(format: "%.0fW", abs(watts))     }
        if let rpm = systemMonitor.fanSpeeds.first, rpm > 0 { return "\(rpm)"                         }
        return "\(Int(systemMonitor.cpuUsagePercent.rounded()))%"
    }

    private var metricColor: Color {
        if let temp = systemMonitor.cpuTemperature {
            if temp > 90 { return .red    }
            if temp > 70 { return .orange }
        }
        return Color(red: 1.0, green: 0.72, blue: 0.18)
    }

    private var fanColor: Color {
        let load = systemMonitor.cpuUsagePercent
        if load > 80 { return .red }
        if load > 50 { return .orange }
        return Color(red: 1.0, green: 0.72, blue: 0.18)
    }

    private var spinDuration: Double {
        let load = max(0, min(100, systemMonitor.cpuUsagePercent))
        return 1.8 - (load / 100.0) * 1.2
    }
}

// MARK: - Menu bar dropdown
struct MenuBarMenuView: View {
    @ObservedObject var systemMonitor: SystemMonitor
    @ObservedObject var fanController: FanController
    @ObservedObject var updater: AppUpdater
    @ObservedObject var coreVisorManager: CoreVisorManager
    var openDashboardAction: () -> Void = {}
    var openCoreVisorAction: () -> Void = {}
    var restoreAppTouchBarAction: () -> Void = {}
    var revertTouchBarAction: () -> Void = {}

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
        VStack(spacing: 0) {
            // Header strip
            HStack(spacing: 8) {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.72, blue: 0.18))
                Text("CORE MONITOR")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 1.0, green: 0.72, blue: 0.18))
                    .cmKerning(1.5)
                Spacer()
                if updater.updateAvailable != nil {
                    HStack(spacing: 4) {
                        Circle().fill(Color(red: 0.35, green: 0.72, blue: 1.0)).frame(width: 5, height: 5)
                        Text("UPDATE")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(red: 0.35, green: 0.72, blue: 1.0))
                            .cmKerning(0.5)
                    }
                } else {
                    Circle()
                        .fill(systemMonitor.hasSMCAccess ? Color(red: 0.22, green: 0.92, blue: 0.55) : .red)
                        .frame(width: 6, height: 6)
                    Text(systemMonitor.hasSMCAccess ? "SMC OK" : "NO SMC")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(white: 0.5)).cmKerning(0.8)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color(red: 0.10, green: 0.10, blue: 0.12))

            Divider().overlay(Color(white: 1, opacity: 0.07))

            // Metrics grid
            VStack(spacing: 1) {
                menuMetricRow(icon: "thermometer.medium", label: "CPU TEMP",
                              value: systemMonitor.cpuTemperature.map { "\(Int($0.rounded()))°C" } ?? "—",
                              color: tempColor(systemMonitor.cpuTemperature))
                menuMetricRow(icon: "chart.bar.fill", label: "CPU LOAD",
                              value: "\(Int(systemMonitor.cpuUsagePercent.rounded()))%",
                              color: loadColor(systemMonitor.cpuUsagePercent))
                menuMetricRow(icon: "memorychip", label: "MEMORY",
                              value: String(format: "%.1f / %.0f GB", systemMonitor.memoryUsedGB, systemMonitor.totalMemoryGB),
                              color: Color(white: 0.75))
                if !systemMonitor.fanSpeeds.isEmpty {
                    menuMetricRow(icon: "fanblades", label: "FAN",
                                  value: systemMonitor.fanSpeeds.map { "\($0)" }.joined(separator: " / ") + " RPM",
                                  color: Color(red: 0.22, green: 0.92, blue: 0.55))
                }
                if let watts = systemMonitor.totalSystemWatts {
                    menuMetricRow(icon: "bolt.fill", label: "POWER",
                                  value: String(format: "%.1f W", abs(watts)),
                                  color: Color(red: 0.35, green: 0.72, blue: 1.0))
                }
                if systemMonitor.batteryInfo.hasBattery, let pct = systemMonitor.batteryInfo.chargePercent {
                    menuMetricRow(icon: systemMonitor.batteryInfo.isCharging ? "battery.100.bolt" : "battery.75",
                                  label: "BATTERY",
                                  value: "\(pct)%\(systemMonitor.batteryInfo.isCharging ? " ⚡" : "")",
                                  color: pct < 20 ? .red : pct < 40 ? .orange : Color(red: 0.22, green: 0.92, blue: 0.55))
                }
                // Network if available
                if systemMonitor.netBytesInPerSec > 0 || systemMonitor.netBytesOutPerSec > 0 {
                    menuMetricRow(icon: "network", label: "NETWORK",
                                  value: "↓ \(formatBytes(systemMonitor.netBytesInPerSec))  ↑ \(formatBytes(systemMonitor.netBytesOutPerSec))",
                                  color: Color(red: 0.72, green: 0.40, blue: 1.0))
                }
                // Disk I/O if active
                if systemMonitor.diskReadBytesPerSec > 0 || systemMonitor.diskWriteBytesPerSec > 0 {
                    menuMetricRow(icon: "internaldrive", label: "DISK I/O",
                                  value: "R \(formatBytes(systemMonitor.diskReadBytesPerSec))  W \(formatBytes(systemMonitor.diskWriteBytesPerSec))",
                                  color: Color(red: 1.0, green: 0.72, blue: 0.18))
                }
                // Volume & brightness
                menuMetricRow(
                    icon: systemMonitor.currentVolume < 0.01 ? "speaker.slash.fill" : "speaker.wave.2.fill",
                    label: "VOLUME",
                    value: "\(Int((systemMonitor.currentVolume * 100).rounded()))%",
                    color: Color(red: 1.0, green: 0.72, blue: 0.18)
                )
                menuMetricRow(
                    icon: "sun.max.fill",
                    label: "BRIGHTNESS",
                    value: "\(Int((systemMonitor.currentBrightness * 100).rounded()))%",
                    color: Color(red: 0.35, green: 0.72, blue: 1.0)
                )
            }
            .padding(.vertical, 6)

            Divider().overlay(Color(white: 1, opacity: 0.07))

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("FAN PROFILE").font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(white: 0.4)).cmKerning(1)
                    Spacer()
                    Text(fanController.mode.title)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(red: 1.0, green: 0.72, blue: 0.18))
                }

                Menu {
                    ForEach(FanControlMode.quickModes, id: \.self) { mode in
                        Button(mode.title) { fanController.setMode(mode) }
                    }
                    Divider()
                    Button("Reset To System Auto") {
                        fanController.resetToSystemAutomatic()
                        fanController.setMode(.automatic)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "fanblades.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text("CHANGE PROFILE")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .cmKerning(0.8)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundStyle(Color(white: 0.7))
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(Color(red: 0.13, green: 0.13, blue: 0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)

            Divider().overlay(Color(white: 1, opacity: 0.07))

            // CoreVisor VM status (only shown when VMs exist)
            if !coreVisorManager.machines.isEmpty {
                VStack(spacing: 1) {
                    HStack(spacing: 6) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color(red: 1.0, green: 0.72, blue: 0.18))
                        Text("COREVISOR")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(red: 1.0, green: 0.72, blue: 0.18))
                            .cmKerning(1)
                        Spacer()
                        let runCount = coreVisorManager.machines.filter {
                            coreVisorManager.runtimeState(for: $0) == .running
                        }.count
                        if runCount > 0 {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color(red: 0.22, green: 0.92, blue: 0.55))
                                    .frame(width: 5, height: 5)
                                Text("\(runCount) RUNNING")
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color(red: 0.22, green: 0.92, blue: 0.55))
                                    .cmKerning(0.5)
                            }
                        }
                    }
                    .padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 4)

                    ForEach(coreVisorManager.machines.prefix(4)) { machine in
                        let state = coreVisorManager.runtimeState(for: machine)
                        HStack(spacing: 8) {
                            Circle()
                                .fill(vmStateColor(state))
                                .frame(width: 5, height: 5)
                            Text(machine.name)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color(white: 0.75))
                                .lineLimit(1)
                            Spacer()
                            Text(state.rawValue.uppercased())
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(vmStateColor(state))
                                .cmKerning(0.5)
                            // Quick start/stop
                            if state == .running || state == .starting {
                                Button {
                                    coreVisorManager.stopMachine(machine)
                                } label: {
                                    Image(systemName: "stop.fill")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(Color(red: 1.0, green: 0.72, blue: 0.18))
                                }
                                .buttonStyle(.plain)
                            } else if state == .stopped || state == .error {
                                Button {
                                    Task { await coreVisorManager.startMachine(machine) }
                                } label: {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(Color(red: 0.22, green: 0.92, blue: 0.55))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 4)
                    }

                    if coreVisorManager.machines.count > 4 {
                        Text("+ \(coreVisorManager.machines.count - 4) more…")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(Color(white: 0.3))
                            .padding(.horizontal, 14).padding(.bottom, 4)
                    }
                }
                .padding(.bottom, 4)

                Divider().overlay(Color(white: 1, opacity: 0.07))
            }

            // Actions
            VStack(spacing: 0) {
                menuActionButton(label: "Open Dashboard", icon: "gauge.medium") {
                    openDashboardAction()
                }
                menuActionButton(label: "Open CoreVisor", icon: "server.rack") {
                    openCoreVisorAction()
                }
                menuActionButton(label: "Restore System Auto", icon: "arrow.counterclockwise") {
                    fanController.resetToSystemAutomatic()
                }
                menuActionButton(label: "Revert to App Touch Bar", icon: "rectangle.on.rectangle") {
                    restoreAppTouchBarAction()
                }
                menuActionButton(label: "Revert to System Touch Bar", icon: "rectangle.3.group") {
                    revertTouchBarAction()
                }
                if updater.updateAvailable != nil {
                    menuActionButton(label: "View Update", icon: "arrow.down.circle", accent: Color(red: 0.35, green: 0.72, blue: 1.0)) {
                        openDashboardAction()
                    }
                }
                Divider().overlay(Color(white: 1, opacity: 0.05)).padding(.vertical, 2)
                menuActionButton(label: "Quit Core Monitor", icon: "power", destructive: true) {
                    NSApp.terminate(nil)
                }
            }
            .padding(.vertical, 4)
        }
        } // ScrollView
        .frame(width: 310)
        .background(Color(red: 0.07, green: 0.07, blue: 0.08))
    }

    private func menuMetricRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 11, weight: .medium)).foregroundStyle(color.opacity(0.7)).frame(width: 16)
            Text(label).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(Color(white: 0.4)).cmKerning(0.8).frame(width: 72, alignment: .leading)
            Spacer()
            Text(value).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(color).monospacedDigit()
        }
        .padding(.horizontal, 14).padding(.vertical, 5)
    }

    private func menuActionButton(label: String, icon: String, destructive: Bool = false, accent: Color? = nil, action: @escaping () -> Void) -> some View {
        HoverActionButton(label: label, icon: icon, destructive: destructive, accent: accent, action: action)
    }

    private func vmStateColor(_ state: CoreVisorRuntimeState) -> Color {
        switch state {
        case .stopped:           return Color(white: 0.3)
        case .starting, .stopping: return Color(red: 1.0, green: 0.72, blue: 0.18)
        case .running:           return Color(red: 0.22, green: 0.92, blue: 0.55)
        case .error:             return Color(red: 1.0, green: 0.34, blue: 0.34)
        }
    }

    private func tempColor(_ temp: Double?) -> Color {
        guard let temp else { return Color(white: 0.5) }
        if temp > 90 { return .red }
        if temp > 70 { return .orange }
        return Color(red: 0.22, green: 0.92, blue: 0.55)
    }
    private func loadColor(_ load: Double) -> Color {
        if load > 80 { return .red }
        if load > 50 { return .orange }
        return Color(red: 1.0, green: 0.72, blue: 0.18)
    }
    private func formatBytes(_ bps: Double) -> String {
        if bps >= 1_000_000 { return String(format: "%.1fM", bps / 1_000_000) }
        if bps >= 1_000     { return String(format: "%.0fK", bps / 1_000) }
        return String(format: "%.0f", bps)
    }

}

// MARK: - Hover-highlighted action button
private struct HoverActionButton: View {
    let label: String
    let icon: String
    var destructive: Bool = false
    var accent: Color? = nil
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(destructive ? Color.red.opacity(0.8) : (accent ?? Color(white: isHovered ? 0.75 : 0.5)))
                    .frame(width: 16)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(destructive ? Color.red : (accent ?? Color(white: isHovered ? 1.0 : 0.78)))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(
                isHovered
                    ? (destructive ? Color.red.opacity(0.12) : Color(white: 1, opacity: 0.07))
                    : Color.clear
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
