import SwiftUI

struct MenuBarStatusLabel: View {
    @ObservedObject var systemMonitor: SystemMonitor
    @State private var angle: Double = 0

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "fanblades.fill")
                .rotationEffect(.degrees(angle))
                .onAppear {
                    withAnimation(.linear(duration: spinDuration).repeatForever(autoreverses: false)) {
                        angle = 360
                    }
                }

            Text(compactMetric)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
    }

    private var compactMetric: String {
        if let temp = systemMonitor.cpuTemperature {
            return "\(Int(temp.rounded()))C"
        }

        if let watts = systemMonitor.totalSystemWatts {
            return String(format: "%.1fW", watts)
        }

        if let rpm = systemMonitor.fanSpeeds.first, rpm > 0 {
            return "\(rpm)"
        }

        return "\(Int(systemMonitor.cpuUsagePercent.rounded()))%"
    }

    private var spinDuration: Double {
        let load = max(0.0, min(100.0, systemMonitor.cpuUsagePercent))
        return 1.8 - (load / 100.0) * 1.2
    }
}

struct MenuBarMenuView: View {
    @ObservedObject var systemMonitor: SystemMonitor
    @ObservedObject var fanController: FanController

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Core Monitor")
                .font(.headline)

            metricRow("CPU Temp", systemMonitor.cpuTemperature.map { String(format: "%.1f C", $0) } ?? "--")
            metricRow("CPU Load", String(format: "%.0f%%", systemMonitor.cpuUsagePercent))
            metricRow("Fan RPM", systemMonitor.fanSpeeds.first.map { "\($0)" } ?? "--")
            metricRow("Power", systemMonitor.totalSystemWatts.map { String(format: "%.1f W", $0) } ?? "--")

            Divider()

            Button("Open Dashboard") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }

            Picker("Mode", selection: Binding(
                get: { fanController.mode },
                set: { fanController.setMode($0) }
            )) {
                ForEach(FanControlMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue.capitalized).tag(mode)
                }
            }
            .pickerStyle(.menu)

            Button("Restore System Auto") {
                fanController.resetToSystemAutomatic()
            }

            Divider()

            Button("Quit Core Monitor") {
                NSApp.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 255)
    }

    @ViewBuilder
    private func metricRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .monospacedDigit()
        }
        .font(.system(size: 12, weight: .medium, design: .rounded))
    }
}
