import SwiftUI

// MARK: - Menu bar status label (compact, monospaced)
struct MenuBarStatusLabel: View {
    @ObservedObject var systemMonitor: SystemMonitor
    @State private var angle: Double = 0

    var body: some View {
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
        }
    }

    private var compactMetric: String {
        if let temp = systemMonitor.cpuTemperature {
            return "\(Int(temp.rounded()))°"
        }
        if let watts = systemMonitor.totalSystemWatts {
            return String(format: "%.0fW", abs(watts))
        }
        if let rpm = systemMonitor.fanSpeeds.first, rpm > 0 {
            return "\(rpm)"
        }
        return "\(Int(systemMonitor.cpuUsagePercent.rounded()))%"
    }

    private var metricColor: Color {
        if let temp = systemMonitor.cpuTemperature {
            if temp > 90 { return .red }
            if temp > 70 { return .orange }
        }
        return Color(red: 1.0, green: 0.72, blue: 0.18) // cmAmber
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
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            // Header strip
            HStack(spacing: 8) {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.72, blue: 0.18))
                Text("CORE MONITOR")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 1.0, green: 0.72, blue: 0.18))
                    .kerning(1.5)
                Spacer()
                Circle()
                    .fill(systemMonitor.hasSMCAccess ? Color(red: 0.22, green: 0.92, blue: 0.55) : .red)
                    .frame(width: 6, height: 6)
                Text(systemMonitor.hasSMCAccess ? "SMC OK" : "NO SMC")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(white: 0.5))
                    .kerning(0.8)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(red: 0.10, green: 0.10, blue: 0.12))

            Divider().overlay(Color(white: 1, opacity: 0.07))

            // Metrics grid
            VStack(spacing: 1) {
                menuMetricRow(
                    icon: "thermometer.medium",
                    label: "CPU TEMP",
                    value: systemMonitor.cpuTemperature.map { "\(Int($0.rounded()))°C" } ?? "—",
                    color: tempColor(systemMonitor.cpuTemperature)
                )
                menuMetricRow(
                    icon: "chart.bar.fill",
                    label: "CPU LOAD",
                    value: "\(Int(systemMonitor.cpuUsagePercent.rounded()))%",
                    color: loadColor(systemMonitor.cpuUsagePercent)
                )
                menuMetricRow(
                    icon: "memorychip",
                    label: "MEMORY",
                    value: String(format: "%.1f / %.0f GB", systemMonitor.memoryUsedGB, systemMonitor.totalMemoryGB),
                    color: Color(white: 0.75)
                )
                if !systemMonitor.fanSpeeds.isEmpty {
                    menuMetricRow(
                        icon: "fanblades",
                        label: "FAN",
                        value: systemMonitor.fanSpeeds.map { "\($0)" }.joined(separator: " / ") + " RPM",
                        color: Color(red: 0.22, green: 0.92, blue: 0.55)
                    )
                }
                if let watts = systemMonitor.totalSystemWatts {
                    menuMetricRow(
                        icon: "bolt.fill",
                        label: "POWER",
                        value: String(format: "%.1f W", abs(watts)),
                        color: Color(red: 0.35, green: 0.72, blue: 1.0)
                    )
                }
                if systemMonitor.batteryInfo.hasBattery, let pct = systemMonitor.batteryInfo.chargePercent {
                    menuMetricRow(
                        icon: systemMonitor.batteryInfo.isCharging ? "battery.100.bolt" : "battery.75",
                        label: "BATTERY",
                        value: "\(pct)%\(systemMonitor.batteryInfo.isCharging ? " ⚡" : "")",
                        color: pct < 20 ? .red : pct < 40 ? .orange : Color(red: 0.22, green: 0.92, blue: 0.55)
                    )
                }
            }
            .padding(.vertical, 6)

            Divider().overlay(Color(white: 1, opacity: 0.07))

            // Fan mode quick-switch
            HStack(spacing: 6) {
                Text("FAN")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(white: 0.4))
                    .kerning(1)
                ForEach(FanControlMode.allCases, id: \.self) { mode in
                    Button {
                        fanController.setMode(mode)
                    } label: {
                        Text(mode.rawValue.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .kerning(0.8)
                            .foregroundStyle(fanController.mode == mode ? Color(red: 0.07, green: 0.07, blue: 0.08) : Color(white: 0.5))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(fanController.mode == mode ? Color(red: 1.0, green: 0.72, blue: 0.18) : Color(red: 0.13, green: 0.13, blue: 0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider().overlay(Color(white: 1, opacity: 0.07))

            // Actions
            VStack(spacing: 0) {
                menuActionButton(label: "Open Dashboard", icon: "gauge.medium") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "main")
                }
                menuActionButton(label: "Restore System Auto", icon: "arrow.counterclockwise") {
                    fanController.resetToSystemAutomatic()
                }
                Divider().overlay(Color(white: 1, opacity: 0.05)).padding(.vertical, 2)
                menuActionButton(label: "Quit Core Monitor", icon: "power", destructive: true) {
                    NSApp.terminate(nil)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(width: 300)
        .background(Color(red: 0.07, green: 0.07, blue: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func menuMetricRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(color.opacity(0.7))
                .frame(width: 16)
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(white: 0.4))
                .kerning(0.8)
                .frame(width: 72, alignment: .leading)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
    }

    private func menuActionButton(label: String, icon: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(destructive ? Color.red.opacity(0.8) : Color(white: 0.5))
                    .frame(width: 16)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(destructive ? Color.red : Color(white: 0.78))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.clear)
        .hoverEffect()
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
}

// MARK: - Hover effect helper (macOS doesn't have native hover modifier for buttons)
private extension View {
    func hoverEffect() -> some View {
        self.onHover { hovering in
            // NSCursor and background changes are handled by the button style
        }
    }
}
