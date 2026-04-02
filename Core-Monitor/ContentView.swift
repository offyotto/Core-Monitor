import SwiftUI
import Darwin
import AVFoundation
import Combine

// MARK: - App-wide mode state
final class AppModeState: ObservableObject {
    @Published var isBasicMode: Bool {
        didSet { UserDefaults.standard.set(isBasicMode, forKey: "basicMode") }
    }
    init() { isBasicMode = UserDefaults.standard.bool(forKey: "basicMode") }
}

// MARK: - Colours (BetterDisplay-matched dark palette)
private extension Color {
    // Window / pane backgrounds
    static let bdSidebar  = Color.black.opacity(0.10)
    static let bdContent  = Color.clear
    static let bdCard     = Color.white.opacity(0.035)
    static let bdDivider  = Color.white.opacity(0.06)                    // hairline between panels
    static let bdAccent   = Color(red: 0.35,  green: 0.72,  blue: 1.00) // system blue
    static let bdSelected = Color.white.opacity(0.10)
}

// MARK: - Copy-on-click
private struct CopyOnTap: ViewModifier {
    let text: String
    @State private var flashed = false
    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .opacity(flashed ? 0.45 : 1.0)
            .onTapGesture {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                flashed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { flashed = false }
            }
    }
}
private extension View {
    func copyOnTap(_ text: String) -> some View { modifier(CopyOnTap(text: text)) }
}

// MARK: - Dark card (BetterDisplay style)
private struct DarkCard<Content: View>: View {
    var padding: CGFloat = 14
    @ViewBuilder let content: () -> Content
    var body: some View {
        content()
            .padding(padding)
            .background(Color.bdCard)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Gauge ring
private struct GaugeRing: View {
    let value: Double
    let color: Color
    var lineWidth: CGFloat = 4
    var size: CGFloat = 44
    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: value)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: value)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Sparkline
private struct Sparkline: View {
    let values: [Double]
    let color: Color
    var height: CGFloat = 26
    var body: some View {
        GeometryReader { geo in
            if values.count > 1 {
                let w = geo.size.width, h = geo.size.height
                let step = w / CGFloat(values.count - 1)
                Path { p in
                    for (i, v) in values.enumerated() {
                        let pt = CGPoint(x: CGFloat(i) * step, y: h - (CGFloat(v) / 100) * h)
                        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h))
                    for (i, v) in values.enumerated() {
                        p.addLine(to: CGPoint(x: CGFloat(i) * step, y: h - (CGFloat(v) / 100) * h))
                    }
                    p.addLine(to: CGPoint(x: w, y: h)); p.closeSubpath()
                }
                .fill(LinearGradient(colors: [color.opacity(0.20), .clear], startPoint: .top, endPoint: .bottom))
            }
        }
        .frame(height: height).clipped()
    }
}

// MARK: - Metric tile
private struct MetricTile: View {
    let label: String
    let value: String
    let unit: String
    let color: Color
    var gauge: Double = 0
    var history: [Double] = []
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.72))
                    HStack(alignment: .lastTextBaseline, spacing: 5) {
                        Text(value)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(color)
                            .cmNumericTextTransition()
                        Text(unit)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(color.opacity(0.65))
                    }
                }
                Spacer(minLength: 10)
                GaugeRing(value: gauge, color: color, lineWidth: 5, size: 70)
            }
            if !history.isEmpty {
                Sparkline(values: history, color: color, height: 28)
                    .padding(.top, 12)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .frame(minHeight: 132, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.42))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        }
        .copyOnTap("\(value)\(unit)")
    }
}

// MARK: - Compact row
private struct CompactRow: View {
    let icon: String; let label: String; let value: String; let color: Color
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color).frame(width: 20)
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(.primary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
                .cmNumericTextTransition()
        }
        .padding(.vertical, 5)
        .copyOnTap("\(label): \(value)")
    }
}

// MARK: - Fan bar
private struct FanBar: View {
    let index: Int; let rpm: Int; let minRPM: Int; let maxRPM: Int
    private var fraction: Double {
        guard maxRPM > minRPM else { return 0 }
        return max(0, min(1, Double(rpm - minRPM) / Double(maxRPM - minRPM)))
    }
    private var rpmColor: Color { fraction > 0.8 ? .red : fraction > 0.5 ? .orange : .green }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Fan \(index + 1)", systemImage: "fanblades.fill")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Text("\(rpm) RPM")
                    .font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(rpmColor)
                    .cmNumericTextTransition()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08)).frame(height: 5)
                    Capsule().fill(rpmColor)
                        .frame(width: max(0, geo.size.width * fraction), height: 5)
                        .animation(.spring(duration: 0.5), value: fraction)
                }
            }.frame(height: 5)
        }
        .copyOnTap("\(rpm) RPM")
    }
}

// MARK: - Battery bar
private struct BatteryBar: View {
    let info: BatteryInfo
    private var chargeColor: Color {
        let p = info.chargePercent ?? 100
        if p < 15 { return .red }; if p < 40 { return .orange }
        return info.isCharging ? Color.bdAccent : .green
    }
    var body: some View {
        DarkCard(padding: 14) {
            HStack(spacing: 14) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.25), lineWidth: 1.5).frame(width: 44, height: 22)
                    RoundedRectangle(cornerRadius: 3).fill(chargeColor)
                        .frame(width: max(0, 40 * Double(info.chargePercent ?? 0) / 100), height: 18).padding(.leading, 2)
                    RoundedRectangle(cornerRadius: 1.5).fill(Color.white.opacity(0.25)).frame(width: 3, height: 10).offset(x: 46)
                }.frame(width: 52)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("\(info.chargePercent ?? 0)%")
                            .font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(chargeColor)
                        if info.isCharging { Image(systemName: "bolt.fill").font(.system(size: 11)).foregroundStyle(.yellow) }
                        Text(info.isCharging ? "Charging" : info.isPluggedIn ? "AC Power" : "On Battery")
                            .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 6) {
                        if let w = info.powerWatts { pill(String(format: "%.1f W", abs(w))) }
                        if let h = info.healthPercent { pill("Health \(h)%") }
                        if let c = info.cycleCount { pill("\(c) cycles") }
                    }
                }
                Spacer()
                if let temp = info.temperatureC {
                    VStack(spacing: 2) {
                        Text(String(format: "%.0f°", temp)).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(.secondary)
                        Text("Batt").font(.system(size: 9)).foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
    private func pill(_ t: String) -> some View {
        Text(t).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Color.white.opacity(0.08)).clipShape(Capsule())
    }
}

// MARK: - Fan control panel
private struct FanControlPanel: View {
    struct Snapshot { var fanSpeeds: [Int] = []; var fanMinSpeeds: [Int] = []; var fanMaxSpeeds: [Int] = [] }
    @ObservedObject var fanController: FanController
    let snapshot: Snapshot
    var body: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FanControlMode.quickModes, id: \.self) { mode in
                        Button { fanController.setMode(mode) } label: {
                            HStack(spacing: 5) {
                                Image(systemName: modeIcon(mode)).font(.system(size: 11, weight: .semibold))
                                Text(mode.shortTitle).font(.system(size: 12, weight: .semibold, design: .rounded))
                            }
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(fanController.mode == mode ? Color.bdAccent.opacity(0.22) : Color.white.opacity(0.06))
                            .foregroundStyle(fanController.mode == mode ? Color.bdAccent : .secondary)
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(
                                fanController.mode == mode ? Color.bdAccent.opacity(0.5) : Color.clear, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .animation(.spring(duration: 0.2), value: fanController.mode)
                    }
                }.padding(.horizontal, 1)
            }
            if fanController.mode.usesManualSlider {
                DarkCard(padding: 14) {
                    VStack(spacing: 8) {
                        HStack {
                            Label("Target Speed", systemImage: "slider.horizontal.3")
                                .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                            Spacer()
                            Text("\(fanController.manualSpeed) RPM")
                                .font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundStyle(Color.bdAccent)
                                .cmNumericTextTransition()
                        }
                        Slider(value: Binding(get: { Double(fanController.manualSpeed) },
                                              set: { fanController.setManualSpeed(Int($0)) }),
                               in: Double(fanController.minSpeed)...Double(fanController.maxSpeed), step: 50)
                            .tint(Color.bdAccent)
                    }
                }
            } else if fanController.mode == .smart {
                DarkCard(padding: 14) {
                    VStack(spacing: 8) {
                        HStack {
                            Label("Aggressiveness", systemImage: "bolt.shield.fill")
                                .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.1f×", fanController.autoAggressiveness))
                                .font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundStyle(.green)
                        }
                        Slider(value: Binding(get: { fanController.autoAggressiveness },
                                              set: { fanController.setAutoAggressiveness($0) }),
                               in: 0...3, step: 0.1).tint(.green)
                    }
                }
            }
            if !snapshot.fanSpeeds.isEmpty {
                DarkCard(padding: 14) {
                    VStack(spacing: 12) {
                        ForEach(snapshot.fanSpeeds.indices, id: \.self) { i in
                            FanBar(index: i, rpm: snapshot.fanSpeeds[i],
                                   minRPM: i < snapshot.fanMinSpeeds.count ? snapshot.fanMinSpeeds[i] : 1000,
                                   maxRPM: i < snapshot.fanMaxSpeeds.count ? snapshot.fanMaxSpeeds[i] : 6500)
                        }
                    }
                }
            }
            Button { fanController.resetToSystemAutomatic() } label: {
                Label("Reset to System Auto", systemImage: "arrow.counterclockwise")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 9)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }.buttonStyle(.plain)
        }
    }
    private func modeIcon(_ mode: FanControlMode) -> String {
        switch mode {
        case .smart: return "bolt.shield.fill"; case .silent: return "wind"
        case .balanced: return "dial.medium"; case .performance: return "speedometer"
        case .max: return "tornado"; case .manual: return "slider.horizontal.3"; case .automatic: return "cpu"
        }
    }
}

// MARK: - Sidebar items
private enum SidebarItem: String, CaseIterable, Identifiable {
    case overview="Overview", thermals="Thermals", memory="Memory", fans="Fans"
    case battery="Battery", system="System"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .overview: return "gauge.medium"; case .thermals: return "thermometer.medium"
        case .memory: return "memorychip"; case .fans: return "fanblades.fill"
        case .battery: return "battery.75"; case .system: return "gearshape"
        }
    }
}

// MARK: - Sidebar row
private struct SidebarRow: View {
    let item: SidebarItem; let isSelected: Bool
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? Color.bdAccent : Color.secondary)
                .frame(width: 20, alignment: .center)
            Text(item.rawValue)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            Spacer()
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(isSelected
            ? RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.bdSelected)
            : RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.clear))
        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

// MARK: - Sidebar
private struct Sidebar: View {
    @Binding var selection: SidebarItem
    let hasBattery: Bool
    let modeState: AppModeState

    var visibleItems: [SidebarItem] {
        var items: [SidebarItem] = [.overview, .thermals, .memory, .fans]
        if hasBattery {
            items.append(.battery)
        }
        items.append(.system)
        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 2) {
                    ForEach(visibleItems) { item in
                        Button {
                            withAnimation(.spring(duration: 0.18)) { selection = item }
                        } label: {
                            SidebarRow(item: item, isSelected: selection == item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 18)
                .padding(.bottom, 8)
            }

            Spacer()

            // hairline
            Rectangle().fill(Color.bdDivider).frame(height: 1)

            // ── Footer ───────────────────────────────────
            Button { modeState.isBasicMode = true } label: {
                Label("Basic Mode", systemImage: "square.grid.2x2.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Color.white.opacity(0.035))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10).padding(.vertical, 12)
        }
        .frame(width: 220)
        .frame(maxHeight: .infinity)
        .background(Color.bdSidebar)
        // BetterDisplay-style right border: one thin white/8% line
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.bdDivider)
                .frame(width: 1)
        }
    }
}

// MARK: - Detail pane
private struct DetailPane: View {
    let selection: SidebarItem
    let state: ContentView.DashboardState
    let cpuHistory: [Double]; let memHistory: [Double]; let cpuTempHistory: [Double]
    let fanController: FanController; let systemMonitor: SystemMonitor
    let startupManager: StartupManager; let touchBarWidgetSettings: TouchBarWidgetSettings
    let benchmarkStore: BenchmarkStore; let updater: AppUpdater
    @Binding var showUpdateCheck: Bool

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                switch selection {
                case .overview:  overviewContent
                case .thermals:  thermalsContent
                case .memory:    memoryContent
                case .fans:      fansContent
                case .battery:   batteryContent
                case .system:    systemContent
                }
                Spacer(minLength: 24)
            }
            .padding(.top, 28).padding(.horizontal, 24).padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Overview
    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            header("Overview", subtitle: hostModelName())
            if let update = updater.updateAvailable {
                DarkCard(padding: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.down.circle.fill").font(.system(size: 22)).foregroundStyle(Color.bdAccent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Update Available: \(update.displayName)").font(.system(size: 13, weight: .semibold))
                            Text("Tap to view release notes").font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { showUpdateCheck = true } label: {
                            Text("Update").font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(Color.bdAccent.opacity(0.2)).clipShape(Capsule())
                                .overlay(Capsule().strokeBorder(Color.bdAccent.opacity(0.4), lineWidth: 1))
                        }.buttonStyle(.plain)
                    }
                }.transition(.move(edge: .top).combined(with: .opacity))
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricTile(label: "CPU Load",  value: "\(Int(state.cpuUsagePercent.rounded()))", unit: "%",
                           color: cpuColor, gauge: state.cpuUsagePercent / 100, history: cpuHistory)
                MetricTile(label: "Memory",    value: "\(Int(state.memoryUsagePercent.rounded()))", unit: "%",
                           color: memColor, gauge: state.memoryUsagePercent / 100, history: memHistory)
                if let t = state.cpuTemperature {
                    MetricTile(label: "CPU Temp", value: "\(Int(t.rounded()))", unit: "°C",
                               color: tempColor(t), gauge: min(t, 110) / 110, history: cpuTempHistory)
                }
                if let rpm = state.fanSpeeds.first, rpm > 0 {
                    MetricTile(label: "Fan", value: "\(rpm)", unit: " RPM", color: Color.bdAccent)
                }
                if let w = state.totalSystemWatts {
                    MetricTile(label: "Power", value: String(format: "%.1f", abs(w)), unit: " W", color: .purple)
                }
                if state.batteryInfo.hasBattery {
                    MetricTile(label: "Battery", value: "\(state.batteryInfo.chargePercent ?? 0)", unit: "%",
                               color: battColor, gauge: battFrac)
                }
            }
        }
    }

    private var thermalsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            header("Thermals", subtitle: "CPU & GPU temperature sensors")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if let t = state.cpuTemperature {
                    MetricTile(label: "CPU Temp", value: "\(Int(t.rounded()))", unit: "°C",
                               color: tempColor(t), gauge: min(t, 110) / 110, history: cpuTempHistory)
                }
                if let t = state.gpuTemperature {
                    MetricTile(label: "GPU Temp", value: "\(Int(t.rounded()))", unit: "°C",
                               color: tempColor(t), gauge: min(t, 110) / 110)
                }
            }
            if state.cpuTemperature == nil && state.gpuTemperature == nil {
                emptyState(icon: "thermometer.slash", message: "No thermal sensors available.\nSMC access is required.")
            }
        }
    }

    private var memoryContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            header("Memory", subtitle: "Unified memory pressure and usage")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricTile(label: "Usage", value: "\(Int(state.memoryUsagePercent.rounded()))", unit: "%",
                           color: memColor, gauge: state.memoryUsagePercent / 100, history: memHistory)
                MetricTile(label: "Used", value: String(format: "%.1f", state.memoryUsedGB), unit: " GB",
                           color: memColor, gauge: state.memoryUsedGB / max(1, state.totalMemoryGB))
            }
            DarkCard(padding: 16) {
                VStack(spacing: 0) {
                    CompactRow(icon: "memorychip", label: "Total",    value: String(format: "%.0f GB", state.totalMemoryGB), color: .secondary)
                    rowDivider
                    CompactRow(icon: "chart.bar.fill", label: "Pressure", value: pressureLabel, color: pressureColor)
                    if let w = state.totalSystemWatts {
                        rowDivider
                        CompactRow(icon: "bolt.fill", label: "System Power", value: String(format: "%.1f W", abs(w)), color: .purple)
                    }
                }
            }
        }
    }

    private var fansContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            header("Fans", subtitle: fanController.statusMessage)
            FanControlPanel(fanController: fanController,
                            snapshot: FanControlPanel.Snapshot(fanSpeeds: state.fanSpeeds,
                                                               fanMinSpeeds: state.fanMinSpeeds,
                                                               fanMaxSpeeds: state.fanMaxSpeeds))
        }
    }

    private var networkContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            header("Network", subtitle: "Real-time throughput")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricTile(label: "Download", value: fmtBytes(state.netBytesInPerSec),  unit: "", color: .green)
                MetricTile(label: "Upload",   value: fmtBytes(state.netBytesOutPerSec), unit: "", color: Color.bdAccent)
            }
        }
    }

    private var diskContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            header("Disk I/O", subtitle: "Read and write throughput")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricTile(label: "Read",  value: fmtBytes(state.diskReadBytesPerSec),  unit: "", color: .orange)
                MetricTile(label: "Write", value: fmtBytes(state.diskWriteBytesPerSec), unit: "", color: .purple)
            }
            if state.diskReadBytesPerSec == 0 && state.diskWriteBytesPerSec == 0 {
                emptyState(icon: "internaldrive", message: "No disk activity detected.")
            }
        }
    }

    private var batteryContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            header("Battery", subtitle: "Power and health information")
            BatteryBar(info: state.batteryInfo)
            DarkCard(padding: 16) {
                VStack(spacing: 0) {
                    CompactRow(icon: "battery.100", label: "Charge", value: "\(state.batteryInfo.chargePercent ?? 0)%", color: battColor)
                    if let h = state.batteryInfo.healthPercent {
                        rowDivider
                        CompactRow(icon: "heart.fill", label: "Health", value: "\(h)%", color: h > 80 ? .green : h > 60 ? .orange : .red)
                    }
                    if let c = state.batteryInfo.cycleCount {
                        rowDivider
                        CompactRow(icon: "arrow.2.circlepath", label: "Cycles", value: "\(c)", color: .secondary)
                    }
                    if let w = state.batteryInfo.powerWatts {
                        rowDivider
                        CompactRow(icon: "bolt.fill", label: "Power", value: String(format: "%.1f W", abs(w)), color: .yellow)
                    }
                }
            }
        }
    }

    private var benchmarkContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            header("Benchmark", subtitle: "CPU performance scoring")
            BenchmarkView(systemMonitor: systemMonitor, store: benchmarkStore)
        }
    }

    private var systemContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            header("System", subtitle: "Controls and startup")
            DarkCard(padding: 16) {
                VStack(spacing: 8) {
                    levelRow(label: "Volume",     icon: state.currentVolume < 0.01 ? "speaker.slash.fill" : "speaker.wave.2.fill",
                             fraction: Double(state.currentVolume),      color: .yellow)
                    Rectangle().fill(Color.bdDivider).frame(height: 1)
                    levelRow(label: "Brightness", icon: "sun.max.fill",
                             fraction: Double(state.currentBrightness),  color: Color.bdAccent)
                }
            }
            DarkCard(padding: 16) {
                HStack(spacing: 14) {
                    Image(systemName: "power").font(.system(size: 16, weight: .medium))
                        .foregroundStyle(startupManager.isEnabled ? .green : .secondary)
                        .frame(width: 32, height: 32)
                        .background((startupManager.isEnabled ? Color.green : Color.secondary).opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Launch at Login").font(.system(size: 13, weight: .semibold))
                        Text(startupManager.isEnabled ? "Starts automatically with macOS" : "Start manually from Applications")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(get: { startupManager.isEnabled },
                                            set: { startupManager.setEnabled($0) }))
                        .toggleStyle(.switch).tint(.green)
                }
            }
            if let msg = startupManager.errorMessage {
                DarkCard(padding: 14) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(msg).font(.system(size: 11)).foregroundStyle(.orange)
                            Text("Open System Settings → General → Login Items to approve.")
                                .font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .onAppear { startupManager.refreshState() }
    }

    // MARK: Sub-helpers
    private func header(_ title: String, subtitle: String = "") -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 22, weight: .bold))
            if !subtitle.isEmpty {
                Text(subtitle).font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
            }
        }
    }

    private func emptyState(icon: String, message: String) -> some View {
        DarkCard(padding: 32) {
            VStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 28)).foregroundStyle(.tertiary)
                Text(message).font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }.frame(maxWidth: .infinity)
        }
    }

    private var rowDivider: some View {
        Rectangle().fill(Color.bdDivider).frame(height: 1).padding(.vertical, 4)
    }

    private func levelRow(label: String, icon: String, fraction: Double, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(color).frame(width: 20)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(.primary)
                    Spacer()
                    Text("\(Int((fraction * 100).rounded()))%").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(color)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08)).frame(height: 5)
                        Capsule().fill(color).frame(width: max(0, geo.size.width * fraction), height: 5)
                            .animation(.spring(duration: 0.4), value: fraction)
                    }
                }.frame(height: 5)
            }
        }
        .padding(.vertical, 4)
        .copyOnTap("\(label): \(Int((fraction * 100).rounded()))%")
    }

    // MARK: Colour helpers
    private var cpuColor: Color   { state.cpuUsagePercent > 80 ? .red : state.cpuUsagePercent > 50 ? .orange : .green }
    private var memColor: Color   { switch state.memoryPressure { case .green: return .green; case .yellow: return .orange; case .red: return .red } }
    private var pressureLabel: String { switch state.memoryPressure { case .green: return "Normal"; case .yellow: return "Elevated"; case .red: return "Critical" } }
    private var pressureColor: Color  { memColor }
    private var battFrac: Double  { Double(state.batteryInfo.chargePercent ?? 0) / 100 }
    private var battColor: Color  {
        let p = state.batteryInfo.chargePercent ?? 100
        return p < 20 ? .red : p < 40 ? .orange : state.batteryInfo.isCharging ? Color.bdAccent : .green
    }
    private func tempColor(_ t: Double) -> Color { t > 90 ? .red : t > 70 ? .orange : .green }
    private func hostModelName() -> String {
        var size = 0; sysctlbyname("hw.model", nil, &size, nil, 0)
        var m = [CChar](repeating: 0, count: size); sysctlbyname("hw.model", &m, &size, nil, 0)
        return String(cString: m)
    }
    private func fmtBytes(_ bps: Double) -> String {
        if bps >= 1_000_000 { return String(format: "%.1f MB/s", bps / 1_000_000) }
        if bps >= 1_000     { return String(format: "%.0f KB/s", bps / 1_000) }
        return String(format: "%.0f B/s", bps)
    }
}

// MARK: - Basic mode
struct BasicModeView: View {
    @ObservedObject var systemMonitor: SystemMonitor
    @ObservedObject var fanController: FanController
    @ObservedObject var modeState: AppModeState

    var body: some View {
        ZStack {
            Color.bdSidebar.ignoresSafeArea()
            VStack(spacing: 0) {
                basicHeader; Rectangle().fill(Color.bdDivider).frame(height: 1)
                basicMetrics; Rectangle().fill(Color.bdDivider).frame(height: 1)
                basicFans; Spacer(); basicFooter
            }
        }
        .preferredColorScheme(.dark)
    }

    private var basicHeader: some View {
        HStack {
            Label("Core Monitor", systemImage: "fanblades.fill")
                .font(.system(size: 12, weight: .bold)).foregroundStyle(.primary)
            Spacer()
            Button { withAnimation(.spring(duration: 0.2)) { modeState.isBasicMode = false } } label: {
                Text("Full UI").font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.white.opacity(0.08)).clipShape(Capsule())
            }.buttonStyle(.plain)
        }.padding(.horizontal, 16).padding(.vertical, 12)
    }

    private var basicMetrics: some View {
        HStack(spacing: 0) {
            basicCell("CPU", "\(Int(systemMonitor.cpuUsagePercent.rounded()))%",
                      systemMonitor.cpuTemperature.map { String(format: "%.0f°C", $0) })
            Rectangle().fill(Color.bdDivider).frame(width: 1)
            basicCell("MEM", "\(Int(systemMonitor.memoryUsagePercent.rounded()))%",
                      String(format: "%.1f/%.0f GB", systemMonitor.memoryUsedGB, systemMonitor.totalMemoryGB))
            if systemMonitor.batteryInfo.hasBattery {
                Rectangle().fill(Color.bdDivider).frame(width: 1)
                basicCell("BAT", "\(systemMonitor.batteryInfo.chargePercent ?? 0)%",
                          systemMonitor.batteryInfo.isCharging ? "Charging" : nil)
            }
        }.frame(maxWidth: .infinity)
    }

    private func basicCell(_ l: String, _ v: String, _ sub: String?) -> some View {
        VStack(spacing: 4) {
            Text(l).font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
            Text(v).font(.system(size: 24, weight: .bold, design: .rounded)).cmNumericTextTransition()
            if let sub { Text(sub).font(.system(size: 9)).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity).padding(.vertical, 16).copyOnTap("\(l): \(v)")
    }

    private var basicFans: some View {
        VStack(spacing: 8) {
            if let rpm = systemMonitor.fanSpeeds.first {
                HStack {
                    Label("Fan", systemImage: "fanblades.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(rpm) RPM").font(.system(size: 14, weight: .bold, design: .monospaced)).cmNumericTextTransition()
                }.padding(.horizontal, 16).padding(.top, 12)
            }
            HStack(spacing: 10) {
                basicFanBtn("Cool Down", icon: "wind",    active: fanController.mode == .silent) { fanController.setMode(.silent) }
                basicFanBtn("Boost",     icon: "tornado", active: fanController.mode == .max)    { fanController.setMode(.max) }
            }.padding(.horizontal, 16)
            Button { fanController.setMode(.smart) } label: {
                Label("Smart", systemImage: "bolt.shield.fill").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(fanController.mode == .smart ? Color.bdAccent : .secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                    .background(fanController.mode == .smart ? Color.bdAccent.opacity(0.15) : Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }.buttonStyle(.plain).padding(.horizontal, 16).padding(.bottom, 12)
        }
    }

    private func basicFanBtn(_ t: String, icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 18, weight: .light)).foregroundStyle(active ? Color.bdAccent : .secondary)
                Text(t).font(.system(size: 11, weight: .semibold)).foregroundStyle(active ? Color.bdAccent : .secondary)
            }.frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(active ? Color.bdAccent.opacity(0.15) : Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }.buttonStyle(.plain)
    }

    private var basicFooter: some View {
        HStack {
            Circle().fill(systemMonitor.hasSMCAccess ? Color.green : .secondary).frame(width: 5, height: 5)
            Text(systemMonitor.hasSMCAccess ? "SMC OK" : "No SMC").font(.system(size: 9)).foregroundStyle(.secondary)
            Spacer()
        }.padding(.horizontal, 16).padding(.vertical, 8)
    }
}

// MARK: - VisualEffectView (NSVisualEffectView wrapper)
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView(); v.material = material; v.blendingMode = blendingMode; v.state = .active; return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - ContentView
struct ContentView: View {
    struct DashboardState {
        var hasSMCAccess = false; var numberOfFans = 0
        var fanSpeeds: [Int] = []; var fanMinSpeeds: [Int] = []; var fanMaxSpeeds: [Int] = []
        var cpuUsagePercent: Double = 0; var cpuTemperature: Double?; var gpuTemperature: Double?
        var memoryUsagePercent: Double = 0; var memoryUsedGB: Double = 0; var totalMemoryGB: Double = 0
        var memoryPressure: MemoryPressureLevel = .green
        var batteryInfo = BatteryInfo(); var totalSystemWatts: Double?
        var diskReadBytesPerSec: Double = 0; var diskWriteBytesPerSec: Double = 0
        var netBytesInPerSec: Double = 0; var netBytesOutPerSec: Double = 0
        var currentVolume: Float = 0.5; var currentBrightness: Float = 1.0
    }

    let systemMonitor: SystemMonitor
    @ObservedObject var fanController: FanController
    @ObservedObject var startupManager: StartupManager
    @ObservedObject var touchBarWidgetSettings: TouchBarWidgetSettings

    @StateObject private var updater        = AppUpdater.shared
    @StateObject private var modeState      = AppModeState()
    @StateObject private var benchmarkStore = BenchmarkStore()

    @State private var cpuHistory:     [Double] = Array(repeating: 0, count: 60)
    @State private var memHistory:     [Double] = Array(repeating: 0, count: 60)
    @State private var cpuTempHistory: [Double] = Array(repeating: 0, count: 60)
    @State private var sidebarSelection: SidebarItem = .overview
    @State private var dashboardState = DashboardState()
    @State private var showUpdateCheck = false

    var body: some View {
        Group {
            if modeState.isBasicMode {
                BasicModeView(systemMonitor: systemMonitor, fanController: fanController, modeState: modeState)
            } else {
                fullDashboard
            }
        }
        .cmHideWindowToolbarBackground()
        .onReceive(NotificationCenter.default.publisher(for: .systemMonitorDidUpdate)) { _ in
            refreshDashboardState(); updateHistories()
        }
        .onChange(of: modeState.isBasicMode) { systemMonitor.setBasicMode($0) }
        .onAppear { systemMonitor.setBasicMode(modeState.isBasicMode); refreshDashboardState() }
    }

    private var fullDashboard: some View {
        HStack(spacing: 0) {
            Sidebar(
                selection: $sidebarSelection,
                hasBattery: dashboardState.batteryInfo.hasBattery,
                modeState: modeState
            )
            DetailPane(
                selection: sidebarSelection,
                state: dashboardState,
                cpuHistory: cpuHistory, memHistory: memHistory, cpuTempHistory: cpuTempHistory,
                fanController: fanController, systemMonitor: systemMonitor,
                startupManager: startupManager, touchBarWidgetSettings: touchBarWidgetSettings,
                benchmarkStore: benchmarkStore, updater: updater,
                showUpdateCheck: $showUpdateCheck
            )
            .background(Color.bdContent)
        }
        .background {
            VisualEffectView(material: .fullScreenUI, blendingMode: .behindWindow)
                .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showUpdateCheck) { UpdateCheckSheet(updater: updater) }
        .welcomeGuide()
    }

    private func updateHistories() {
        cpuHistory.removeFirst(); cpuHistory.append(dashboardState.cpuUsagePercent)
        memHistory.removeFirst(); memHistory.append(dashboardState.memoryUsagePercent)
        let n = dashboardState.cpuTemperature.map { min($0, 120) / 120 * 100 } ?? 0
        cpuTempHistory.removeFirst(); cpuTempHistory.append(n)
    }

    private func refreshDashboardState() {
        dashboardState = DashboardState(
            hasSMCAccess: systemMonitor.hasSMCAccess, numberOfFans: systemMonitor.numberOfFans,
            fanSpeeds: systemMonitor.fanSpeeds, fanMinSpeeds: systemMonitor.fanMinSpeeds,
            fanMaxSpeeds: systemMonitor.fanMaxSpeeds, cpuUsagePercent: systemMonitor.cpuUsagePercent,
            cpuTemperature: systemMonitor.cpuTemperature, gpuTemperature: systemMonitor.gpuTemperature,
            memoryUsagePercent: systemMonitor.memoryUsagePercent, memoryUsedGB: systemMonitor.memoryUsedGB,
            totalMemoryGB: systemMonitor.totalMemoryGB, memoryPressure: systemMonitor.memoryPressure,
            batteryInfo: systemMonitor.batteryInfo, totalSystemWatts: systemMonitor.totalSystemWatts,
            diskReadBytesPerSec: systemMonitor.diskReadBytesPerSec, diskWriteBytesPerSec: systemMonitor.diskWriteBytesPerSec,
            netBytesInPerSec: systemMonitor.netBytesInPerSec, netBytesOutPerSec: systemMonitor.netBytesOutPerSec,
            currentVolume: systemMonitor.currentVolume, currentBrightness: systemMonitor.currentBrightness
        )
    }
}

// MARK: - Update sheet
private struct UpdateCheckSheet: View {
    @ObservedObject var updater: AppUpdater
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack {
            Color.bdSidebar.ignoresSafeArea()
            VStack(spacing: 20) {
                HStack {
                    Text("App Updater").font(.system(size: 16, weight: .bold))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 18)).foregroundStyle(.secondary)
                    }.buttonStyle(.plain).keyboardShortcut(.escape)
                }
                if updater.updateAvailable != nil {
                    UpdateBannerView(updater: updater)
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 36)).foregroundStyle(.green)
                        Text("You're up to date").font(.system(size: 15, weight: .semibold))
                        Text("Core Monitor \(updater.currentVersion)").font(.system(size: 11)).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity).padding(24).background(Color.bdCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Button { Task { await updater.checkForUpdates() } } label: {
                        HStack(spacing: 6) {
                            if updater.isChecking { ProgressView().scaleEffect(0.7).frame(width: 12, height: 12) }
                            else { Image(systemName: "arrow.clockwise") }
                            Text(updater.isChecking ? "Checking…" : "Check Now")
                        }.font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.bdCard).clipShape(Capsule())
                    }.buttonStyle(.plain).disabled(updater.isChecking)
                }
                if let err = updater.checkError {
                    Text(err).font(.system(size: 11)).foregroundStyle(.red).multilineTextAlignment(.center)
                }
                Spacer()
            }.padding(24)
        }
        .preferredColorScheme(.dark)
        .frame(width: 400, height: 300)
    }
}
