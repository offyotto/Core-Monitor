import SwiftUI

// MARK: - Menu bar status label
struct MenuBarStatusLabel: View {
    @ObservedObject var systemMonitor: SystemMonitor
    @ObservedObject var updater: AppUpdater
    @State private var angle: Double = 0

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "fanblades.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(fanColor)
                .rotationEffect(.degrees(angle))
                .task(id: spinDuration) {
                    angle = 0
                    withAnimation(.linear(duration: spinDuration).repeatForever(autoreverses: false)) { angle = 360 }
                }
            Text(compactMetric)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(metricColor)
                .frame(minWidth: 46, alignment: .leading)
            if updater.updateAvailable != nil {
                Circle().fill(Color(red: 0.35, green: 0.72, blue: 1)).frame(width: 5, height: 5)
            }
        }
    }

    private var compactMetric: String {
        if let t = systemMonitor.cpuTemperature  { return "\(Int(t.rounded()))°"                }
        if let w = systemMonitor.totalSystemWatts  { return String(format: "%.0fW", abs(w))     }
        if let r = systemMonitor.fanSpeeds.first, r > 0 { return "\(r)"                        }
        return "\(Int(systemMonitor.cpuUsagePercent.rounded()))%"
    }
    private var metricColor: Color {
        if let t = systemMonitor.cpuTemperature { if t > 90 { return .red }; if t > 70 { return .orange } }
        return Color(red: 1.0, green: 0.72, blue: 0.18)
    }
    private var fanColor: Color {
        let l = systemMonitor.cpuUsagePercent; if l > 80 { return .red }; if l > 50 { return .orange }
        return Color(red: 1.0, green: 0.72, blue: 0.18)
    }
    private var spinDuration: Double { 1.8 - (max(0, min(100, systemMonitor.cpuUsagePercent)) / 100.0) * 1.2 }
}

// MARK: - Colours (matches ContentView dark palette)
private extension Color {
    static let mbBG     = Color.clear
    static let mbCard   = Color.white.opacity(0.06)
    static let mbDiv    = Color.white.opacity(0.10)
    static let mbAccent = Color.white.opacity(0.92)
    static let mbTint   = Color(red: 0.66, green: 0.72, blue: 0.96)
}

private struct MenuPopoverSurface<Content: View>: View {
    @ObservedObject private var appearanceSettings = AppAppearanceSettings.shared
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            VisualEffectView(
                material: .underWindowBackground,
                blendingMode: .behindWindow,
                opacity: appearanceSettings.surfaceOpacity
            )

            LinearGradient(
                colors: [
                    Color(red: 0.22, green: 0.24, blue: 0.33).opacity(0.06 * appearanceSettings.surfaceOpacity),
                    Color(red: 0.15, green: 0.17, blue: 0.25).opacity(0.05 * appearanceSettings.surfaceOpacity),
                    Color(red: 0.11, green: 0.12, blue: 0.19).opacity(0.07 * appearanceSettings.surfaceOpacity)
                ],
                startPoint: .topLeading,
                endPoint: .bottom
            )

            Ellipse()
                .fill(Color.mbTint.opacity(0.02 * appearanceSettings.surfaceOpacity))
                .frame(width: 360, height: 120)
                .blur(radius: 34)
                .offset(y: 150)

            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color.white.opacity(0.03 * appearanceSettings.surfaceOpacity), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 1)
                Spacer()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.05 * appearanceSettings.surfaceOpacity), lineWidth: 1)
        )
        .overlay(content())
        .shadow(color: .black.opacity(0.10 * appearanceSettings.surfaceOpacity), radius: 18, y: 10)
    }
}

// MARK: - Menu bar popover
struct MenuBarMenuView: View {
    @ObservedObject var systemMonitor: SystemMonitor
    @ObservedObject var fanController: FanController
    @ObservedObject var updater: AppUpdater
    var openDashboardAction:      () -> Void = {}
    var restoreAppTouchBarAction: () -> Void = {}
    var revertTouchBarAction:     () -> Void = {}

    var body: some View {
        MenuPopoverSurface {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    headerStrip
                    mbDivider
                    metricsSection
                    mbDivider
                    fanSection
                    mbDivider
                    actionsSection
                }
            }
        }
        .preferredColorScheme(.dark)
        .frame(width: 350)
    }

    // MARK: Header
    private var headerStrip: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.07)).frame(width: 34, height: 34)
                Image(systemName: "fanblades.fill").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.white.opacity(0.86))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Core Monitor").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.92))
                Text("System summary").font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.58))
            }
            Spacer()
            // SMC / update pill
            if updater.updateAvailable != nil {
                statusPill(dot: Color.mbAccent, label: "Update", tint: Color.mbAccent)
            } else {
                statusPill(dot: systemMonitor.hasSMCAccess ? .green : .red,
                           label: systemMonitor.hasSMCAccess ? "SMC OK" : "No SMC",
                           tint: nil)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Color.white.opacity(0.025))
    }

    // MARK: Metrics
    private var metricsSection: some View {
        VStack(spacing: 0) {
            metricRow(icon: "thermometer.medium", label: "CPU Temp",
                      value: systemMonitor.cpuTemperature.map { "\(Int($0.rounded()))°C" } ?? "—",
                      color: tempColor(systemMonitor.cpuTemperature))
            metricRow(icon: "cpu.fill", label: "CPU Load",
                      value: "\(Int(systemMonitor.cpuUsagePercent.rounded()))%",
                      color: loadColor(systemMonitor.cpuUsagePercent))
            metricRow(icon: "memorychip", label: "Memory",
                      value: String(format: "%.1f / %.0f GB", systemMonitor.memoryUsedGB, systemMonitor.totalMemoryGB),
                      color: .secondary)
            if !systemMonitor.fanSpeeds.isEmpty {
                metricRow(icon: "fanblades", label: "Fan",
                          value: systemMonitor.fanSpeeds.map { "\($0)" }.joined(separator: " / ") + " RPM",
                          color: .green)
            }
            if let w = systemMonitor.totalSystemWatts {
                metricRow(icon: "bolt.fill", label: "Power", value: String(format: "%.1f W", abs(w)), color: Color.mbAccent)
            }
            if systemMonitor.batteryInfo.hasBattery, let pct = systemMonitor.batteryInfo.chargePercent {
                metricRow(icon: systemMonitor.batteryInfo.isCharging ? "battery.100.bolt" : "battery.75",
                          label: "Battery",
                          value: "\(pct)%\(systemMonitor.batteryInfo.isCharging ? " ⚡" : "")",
                          color: pct < 20 ? .red : pct < 40 ? .orange : .green)
            }
            metricRow(icon: "internaldrive", label: "Disk",
                      value: "R \(fmtBytes(systemMonitor.diskReadBytesPerSec))  W \(fmtBytes(systemMonitor.diskWriteBytesPerSec))",
                      color: diskColor)
            metricRow(icon: systemMonitor.currentVolume < 0.01 ? "speaker.slash.fill" : "speaker.wave.2.fill",
                      label: "Volume", value: "\(Int((systemMonitor.currentVolume * 100).rounded()))%", color: .yellow)
            metricRow(icon: "sun.max.fill", label: "Brightness",
                      value: "\(Int((systemMonitor.currentBrightness * 100).rounded()))%", color: Color.mbAccent)
        }
        .padding(.vertical, 4)
    }

    // MARK: Fan
    private var fanSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Fan Profile").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Text(fanController.mode.title).font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.86))
            }
            Menu {
                ForEach(FanControlMode.quickModes, id: \.self) { mode in
                    Button(mode.title) { fanController.setMode(mode) }
                }
                Divider()
                Button("Reset to System Auto") { fanController.resetToSystemAutomatic(); fanController.setMode(.automatic) }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "fanblades.fill").font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.78))
                    Text("Change Profile").font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
                }
                .foregroundStyle(.white.opacity(0.88))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    // MARK: Actions
    private var actionsSection: some View {
        VStack(spacing: 0) {
            actionRow("Open Dashboard",             icon: "gauge.medium")     { openDashboardAction() }
            actionRow("Reset Fan to System Auto",   icon: "arrow.counterclockwise") { fanController.resetToSystemAutomatic() }
            actionRow("Restore App Touch Bar",      icon: "rectangle.on.rectangle") { restoreAppTouchBarAction() }
            actionRow("Revert to System Touch Bar", icon: "rectangle.3.group") { revertTouchBarAction() }
            if updater.updateAvailable != nil {
                actionRow("View Update", icon: "arrow.down.circle", tint: Color.mbAccent) { openDashboardAction() }
            }
            mbDivider.padding(.horizontal, 14).padding(.vertical, 2)
            actionRow("Quit Core Monitor", icon: "power", tint: .red) { NSApp.terminate(nil) }
        }
        .padding(.vertical, 4)
    }

    // MARK: Reusable rows
    private func metricRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 12, weight: .medium)).foregroundStyle(color.opacity(0.85)).frame(width: 18)
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.70)).frame(width: 72, alignment: .leading)
            Spacer()
            Text(value).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(color).monospacedDigit()
        }
        .padding(.horizontal, 14).padding(.vertical, 5)
    }

    private func actionRow(_ label: String, icon: String, tint: Color? = nil, action: @escaping () -> Void) -> some View {
        MBActionButton(label: label, icon: icon, tint: tint, action: action)
    }

    private var mbDivider: some View {
        Rectangle().fill(Color.mbDiv).frame(height: 1)
    }

    private func statusPill(dot: Color, label: String, tint: Color?) -> some View {
        HStack(spacing: 4) {
            Circle().fill(dot).frame(width: 5, height: 5)
            Text(label).font(.system(size: 10, weight: .semibold)).foregroundStyle(tint ?? .white.opacity(0.76))
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
    }

    // MARK: Helpers
    private func tempColor(_ t: Double?) -> Color {
        guard let t else { return .secondary }; return t > 90 ? .red : t > 70 ? .orange : .green
    }
    private func loadColor(_ l: Double) -> Color { l > 80 ? .red : l > 50 ? .orange : Color.mbAccent }
    private func fmtBytes(_ bps: Double) -> String {
        if bps <= 0 { return "0" }
        if bps >= 1_000_000 { return String(format: "%.1fM", bps / 1_000_000) }
        if bps >= 1_000     { return String(format: "%.0fK", bps / 1_000) }
        return String(format: "%.0f", bps)
    }
    private var diskColor: Color {
        systemMonitor.diskReadBytesPerSec > 0 || systemMonitor.diskWriteBytesPerSec > 0 ? .orange : .secondary
    }
}

// MARK: - Hover action button
private struct MBActionButton: View {
    let label: String; let icon: String; var tint: Color? = nil; let action: () -> Void
    @State private var isHovered = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 12, weight: .medium))
                    .foregroundStyle(tint ?? (isHovered ? Color.white : Color.white.opacity(0.72)))
                    .frame(width: 18)
                Text(label).font(.system(size: 13, weight: .medium))
                    .foregroundStyle(tint ?? (isHovered ? Color.white : Color.white.opacity(0.78)))
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(isHovered ? Color.white.opacity(0.07) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
