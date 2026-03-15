import SwiftUI

// MARK: - Design tokens
// Industrial precision aesthetic: dark surfaces, amber/green accents,
// monospaced data readouts, tight information density.

private extension Color {
    static let cmBackground    = Color(red: 0.07, green: 0.07, blue: 0.08)
    static let cmSurface       = Color(red: 0.10, green: 0.10, blue: 0.12)
    static let cmSurfaceRaised = Color(red: 0.13, green: 0.13, blue: 0.15)
    static let cmBorder        = Color(white: 1, opacity: 0.07)
    static let cmBorderBright  = Color(white: 1, opacity: 0.14)
    static let cmAmber         = Color(red: 1.0,  green: 0.72, blue: 0.18)
    static let cmGreen         = Color(red: 0.22, green: 0.92, blue: 0.55)
    static let cmRed           = Color(red: 1.0,  green: 0.34, blue: 0.34)
    static let cmBlue          = Color(red: 0.35, green: 0.72, blue: 1.0)
    static let cmTextPrimary   = Color(white: 0.92)
    static let cmTextSecondary = Color(white: 0.50)
    static let cmTextDim       = Color(white: 0.32)
}

private extension Font {
    // Tight monospaced readouts
    static func cmMono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    // Rounded labels
    static func cmLabel(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Reusable panel modifier
private struct CMPanel: ViewModifier {
    var accent: Color = .clear
    func body(content: Content) -> some View {
        content
            .background(Color.cmSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(accent == .clear ? Color.cmBorder : accent.opacity(0.35), lineWidth: 1)
            )
    }
}

private extension View {
    func cmPanel(accent: Color = .clear) -> some View { modifier(CMPanel(accent: accent)) }
}

// MARK: - Gauge ring view
private struct GaugeRing: View {
    let value: Double      // 0–1
    let color: Color
    var lineWidth: CGFloat = 5
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.12), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: value)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: value)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Sparkline view
private struct Sparkline: View {
    let values: [Double]   // 0–100
    let color: Color
    var height: CGFloat = 28

    var body: some View {
        GeometryReader { geo in
            if values.count > 1 {
                Path { path in
                    let w = geo.size.width
                    let h = geo.size.height
                    let step = w / CGFloat(values.count - 1)
                    for (i, v) in values.enumerated() {
                        let x = CGFloat(i) * step
                        let y = h - (CGFloat(v) / 100.0) * h
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

                // Fill under the line
                Path { path in
                    let w = geo.size.width
                    let h = geo.size.height
                    let step = w / CGFloat(values.count - 1)
                    path.move(to: CGPoint(x: 0, y: h))
                    for (i, v) in values.enumerated() {
                        let x = CGFloat(i) * step
                        let y = h - (CGFloat(v) / 100.0) * h
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.22), color.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .frame(height: height)
        .clipped()
    }
}

// MARK: - Stat tile
private struct StatTile: View {
    let label: String
    let value: String
    let unit: String
    let color: Color
    var gauge: Double = 0
    var history: [Double] = []
    var wide: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label.uppercased())
                        .font(.cmMono(9, weight: .medium))
                        .foregroundStyle(Color.cmTextDim)
                        .kerning(1.2)

                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text(value)
                            .font(.cmMono(28, weight: .bold))
                            .foregroundStyle(color)
                            .contentTransition(.numericText())
                            .animation(.easeOut(duration: 0.3), value: value)
                        Text(unit)
                            .font(.cmMono(11, weight: .medium))
                            .foregroundStyle(color.opacity(0.6))
                    }
                }
                Spacer()
                GaugeRing(value: gauge, color: color, lineWidth: 4, size: 38)
            }

            if !history.isEmpty {
                Sparkline(values: history, color: color)
                    .padding(.top, 8)
            }
        }
        .padding(12)
        .cmPanel(accent: color)
        .frame(maxWidth: wide ? .infinity : nil)
    }
}

// MARK: - Section header
private struct SectionHeader: View {
    let title: String
    var trailing: String = ""
    var body: some View {
        HStack {
            Rectangle()
                .fill(Color.cmAmber)
                .frame(width: 2, height: 11)
            Text(title.uppercased())
                .font(.cmMono(10, weight: .bold))
                .foregroundStyle(Color.cmTextSecondary)
                .kerning(1.4)
            Spacer()
            if !trailing.isEmpty {
                Text(trailing)
                    .font(.cmMono(10))
                    .foregroundStyle(Color.cmTextDim)
            }
        }
    }
}

// MARK: - Fan bar
private struct FanBar: View {
    let index: Int
    let rpm: Int
    let minRPM: Int
    let maxRPM: Int

    private var fraction: Double {
        guard maxRPM > minRPM else { return 0 }
        return Double(rpm - minRPM) / Double(maxRPM - minRPM)
    }

    private var rpmColor: Color {
        fraction > 0.8 ? .cmRed : fraction > 0.5 ? .cmAmber : .cmGreen
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("FAN \(index + 1)")
                    .font(.cmMono(9, weight: .bold))
                    .foregroundStyle(Color.cmTextDim)
                    .kerning(1)
                Spacer()
                Text("\(rpm)")
                    .font(.cmMono(13, weight: .bold))
                    .foregroundStyle(rpmColor)
                    .contentTransition(.numericText())
                Text("RPM")
                    .font(.cmMono(9))
                    .foregroundStyle(Color.cmTextDim)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.cmSurfaceRaised)
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(rpmColor)
                        .frame(width: geo.size.width * fraction, height: 4)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: fraction)
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - Battery status bar
private struct BatteryStatusBar: View {
    let info: BatteryInfo

    private var chargeColor: Color {
        let pct = info.chargePercent ?? 100
        if pct < 15 { return .cmRed }
        if pct < 40 { return .cmAmber }
        return .cmGreen
    }

    var body: some View {
        HStack(spacing: 12) {
            // Battery outline
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.cmBorderBright, lineWidth: 1.5)
                    .frame(width: 40, height: 20)
                RoundedRectangle(cornerRadius: 2)
                    .fill(chargeColor)
                    .frame(width: 36 * Double(info.chargePercent ?? 0) / 100.0, height: 16)
                    .padding(.leading, 2)
                    .animation(.easeOut(duration: 0.4), value: info.chargePercent)
                // Nub
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.cmBorderBright)
                    .frame(width: 3, height: 9)
                    .offset(x: 42)
            }
            .frame(width: 47)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text("\(info.chargePercent ?? 0)%")
                        .font(.cmMono(13, weight: .bold))
                        .foregroundStyle(chargeColor)
                        .contentTransition(.numericText())
                    if info.isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.cmAmber)
                    }
                    Text(info.isCharging ? "CHARGING" : info.isPluggedIn ? "AC POWER" : "ON BATTERY")
                        .font(.cmMono(9, weight: .bold))
                        .foregroundStyle(Color.cmTextDim)
                        .kerning(0.8)
                }
                HStack(spacing: 8) {
                    if let watts = info.powerWatts {
                        metricPill(String(format: "%.1fW", abs(watts)))
                    }
                    if let health = info.healthPercent {
                        metricPill("HEALTH \(health)%")
                    }
                    if let cycles = info.cycleCount {
                        metricPill("\(cycles) CYCLES")
                    }
                }
            }

            Spacer()

            if let temp = info.temperatureC {
                VStack(spacing: 1) {
                    Text(String(format: "%.0f°", temp))
                        .font(.cmMono(13, weight: .bold))
                        .foregroundStyle(Color.cmTextSecondary)
                    Text("BATT")
                        .font(.cmMono(8))
                        .foregroundStyle(Color.cmTextDim)
                        .kerning(0.8)
                }
            }
        }
        .padding(12)
        .cmPanel()
    }

    private func metricPill(_ text: String) -> some View {
        Text(text)
            .font(.cmMono(8, weight: .medium))
            .foregroundStyle(Color.cmTextDim)
            .kerning(0.5)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.cmSurfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

// MARK: - Fan control panel
private struct FanControlPanel: View {
    @ObservedObject var fanController: FanController
    @ObservedObject var systemMonitor: SystemMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Fan Control", trailing: fanController.statusMessage)

            // Mode toggle
            HStack(spacing: 6) {
                ForEach(FanControlMode.allCases, id: \.self) { mode in
                    Button {
                        fanController.setMode(mode)
                    } label: {
                        Text(mode.rawValue.uppercased())
                            .font(.cmMono(10, weight: .bold))
                            .kerning(0.8)
                            .foregroundStyle(fanController.mode == mode ? Color.cmBackground : Color.cmTextSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(fanController.mode == mode ? Color.cmAmber : Color.cmSurfaceRaised)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .animation(.easeOut(duration: 0.15), value: fanController.mode)
                }
                Spacer()
                Button {
                    fanController.resetToSystemAutomatic()
                } label: {
                    Label("RESET AUTO", systemImage: "arrow.counterclockwise")
                        .font(.cmMono(9, weight: .bold))
                        .kerning(0.5)
                        .foregroundStyle(Color.cmTextDim)
                }
                .buttonStyle(.plain)
            }

            if fanController.mode == .manual {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("TARGET SPEED")
                            .font(.cmMono(9, weight: .bold))
                            .foregroundStyle(Color.cmTextDim)
                            .kerning(1)
                        Spacer()
                        Text("\(fanController.manualSpeed) RPM")
                            .font(.cmMono(13, weight: .bold))
                            .foregroundStyle(Color.cmAmber)
                            .contentTransition(.numericText())
                    }
                    Slider(
                        value: Binding(
                            get: { Double(fanController.manualSpeed) },
                            set: { fanController.setManualSpeed(Int($0)) }
                        ),
                        in: Double(fanController.minSpeed)...Double(fanController.maxSpeed),
                        step: 50
                    )
                    .tint(Color.cmAmber)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("AGGRESSIVENESS")
                            .font(.cmMono(9, weight: .bold))
                            .foregroundStyle(Color.cmTextDim)
                            .kerning(1)
                        Spacer()
                        Text(String(format: "%.1f×", fanController.autoAggressiveness))
                            .font(.cmMono(13, weight: .bold))
                            .foregroundStyle(Color.cmGreen)
                    }
                    Slider(
                        value: Binding(
                            get: { fanController.autoAggressiveness },
                            set: { fanController.setAutoAggressiveness($0) }
                        ),
                        in: 0...3,
                        step: 0.1
                    )
                    .tint(Color.cmGreen)
                }
            }

            // Fan bars
            if !systemMonitor.fanSpeeds.isEmpty {
                VStack(spacing: 8) {
                    ForEach(systemMonitor.fanSpeeds.indices, id: \.self) { i in
                        FanBar(
                            index: i,
                            rpm: systemMonitor.fanSpeeds[i],
                            minRPM: i < systemMonitor.fanMinSpeeds.count ? systemMonitor.fanMinSpeeds[i] : 1000,
                            maxRPM: i < systemMonitor.fanMaxSpeeds.count ? systemMonitor.fanMaxSpeeds[i] : 6500
                        )
                    }
                }
                .padding(10)
                .cmPanel()
            }
        }
        .padding(14)
        .cmPanel()
    }
}

// MARK: - Main dashboard content view
struct ContentView: View {
    @ObservedObject var systemMonitor: SystemMonitor
    @ObservedObject var fanController: FanController
    @ObservedObject var startupManager: StartupManager
    @StateObject private var coreVisorManager = CoreVisorManager()

    // Rolling history for sparklines — maintained in view state
    @State private var cpuHistory: [Double] = Array(repeating: 0, count: 60)
    @State private var memHistory: [Double] = Array(repeating: 0, count: 60)
    @State private var cpuTempHistory: [Double] = Array(repeating: 0, count: 60)
    @State private var showCoreVisorSetup = false
    @State private var hasOpenedCoreVisorSetup = false

    var body: some View {
        dashboardRoot
            .preferredColorScheme(.dark)
            .onReceive(systemMonitor.$cpuUsagePercent, perform: updateCPUHistory)
            .onReceive(systemMonitor.$memoryUsagePercent, perform: updateMemoryHistory)
            .onReceive(systemMonitor.$cpuTemperature, perform: updateCPUTempHistory)
            .sheet(isPresented: $showCoreVisorSetup) {
                CoreVisorSetupView(
                    manager: coreVisorManager,
                    hasOpenedCoreVisorSetup: $hasOpenedCoreVisorSetup
                )
            }
    }

    private var dashboardRoot: some View {
        ZStack {
            backgroundLayer
            scanLineOverlay
            dashboardScrollContent
        }
    }

    private var backgroundLayer: some View {
        // Subtle scan-line texture overlay
        Color.cmBackground.ignoresSafeArea()
    }

    private var dashboardScrollContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            dashboardStack
        }
    }

    private var dashboardStack: some View {
        VStack(alignment: .leading, spacing: 16) {
            dashboardHeader
            primaryMetricsRow
            temperatureRow
            memoryAndPowerRow
            FanControlPanel(fanController: fanController, systemMonitor: systemMonitor)
            batteryPanel
            startupPanel
            Spacer(minLength: 20)
        }
        .padding(16)
    }

    @ViewBuilder
    private var batteryPanel: some View {
        if systemMonitor.batteryInfo.hasBattery {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Power")
                BatteryStatusBar(info: systemMonitor.batteryInfo)
            }
        }
    }

    private func updateCPUHistory(_ value: Double) {
        cpuHistory = Array(cpuHistory.dropFirst()) + [value]
    }

    private func updateMemoryHistory(_ value: Double) {
        memHistory = Array(memHistory.dropFirst()) + [value]
    }

    private func updateCPUTempHistory(_ value: Double?) {
        let normalizedValue = value.map { min($0, 120) / 120 * 100 } ?? 0
        cpuTempHistory = Array(cpuTempHistory.dropFirst()) + [normalizedValue]
    }

    // MARK: - Scan-line overlay (pure Canvas, GPU-rasterised)
    private var scanLineOverlay: some View {
        Canvas { ctx, size in
            var y: CGFloat = 0
            while y < size.height {
                ctx.fill(
                    Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                    with: .color(.white.opacity(0.018))
                )
                y += 3
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .drawingGroup()
    }

    // MARK: - Header
    private var dashboardHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.cmAmber)
                    Text("CORE MONITOR")
                        .font(.cmMono(11, weight: .bold))
                        .foregroundStyle(Color.cmAmber)
                        .kerning(2)
                }
                Text(hostModelName())
                    .font(.cmMono(13, weight: .bold))
                    .foregroundStyle(Color.cmTextPrimary)
                Text(currentDateString())
                    .font(.cmMono(10))
                    .foregroundStyle(Color.cmTextDim)
            }
            Spacer()
            // Status indicators
            HStack(spacing: 6) {
                statusDot(
                    label: "SMC",
                    active: systemMonitor.hasSMCAccess,
                    activeColor: .cmGreen
                )
                statusDot(
                    label: "FAN",
                    active: systemMonitor.numberOfFans > 0,
                    activeColor: .cmGreen
                )
                if systemMonitor.batteryInfo.hasBattery {
                    statusDot(
                        label: "BAT",
                        active: true,
                        activeColor: systemMonitor.batteryInfo.isCharging ? .cmAmber : .cmGreen
                    )
                }
            }
        }
    }

    private func statusDot(label: String, active: Bool, activeColor: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(active ? activeColor : Color.cmTextDim.opacity(0.4))
                .frame(width: 6, height: 6)
                .overlay(
                    active ?
                    Circle().fill(activeColor.opacity(0.3)).frame(width: 10, height: 10).animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: active)
                    : nil
                )
            Text(label)
                .font(.cmMono(8, weight: .bold))
                .foregroundStyle(active ? activeColor.opacity(0.8) : Color.cmTextDim)
                .kerning(0.8)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Color.cmSurfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    // MARK: - Primary metrics
    private var primaryMetricsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Processor")
            HStack(spacing: 10) {
                StatTile(
                    label: "CPU Load",
                    value: "\(Int(systemMonitor.cpuUsagePercent.rounded()))",
                    unit: "%",
                    color: cpuLoadColor,
                    gauge: systemMonitor.cpuUsagePercent / 100,
                    history: cpuHistory,
                    wide: true
                )
                StatTile(
                    label: "Memory",
                    value: "\(Int(systemMonitor.memoryUsagePercent.rounded()))",
                    unit: "%",
                    color: memColor,
                    gauge: systemMonitor.memoryUsagePercent / 100,
                    history: memHistory,
                    wide: true
                )
            }
        }
    }

    // MARK: - Temperature row
    private var temperatureRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Thermals")
            HStack(spacing: 10) {
                if let cpuTemp = systemMonitor.cpuTemperature {
                    StatTile(
                        label: "CPU Temp",
                        value: "\(Int(cpuTemp.rounded()))",
                        unit: "°C",
                        color: tempColor(cpuTemp),
                        gauge: min(cpuTemp, 110) / 110,
                        history: cpuTempHistory,
                        wide: true
                    )
                }
                if let gpuTemp = systemMonitor.gpuTemperature {
                    StatTile(
                        label: "GPU Temp",
                        value: "\(Int(gpuTemp.rounded()))",
                        unit: "°C",
                        color: tempColor(gpuTemp),
                        gauge: min(gpuTemp, 110) / 110,
                        wide: true
                    )
                }
                if systemMonitor.cpuTemperature == nil && systemMonitor.gpuTemperature == nil {
                    Text("No thermal sensors available")
                        .font(.cmMono(11))
                        .foregroundStyle(Color.cmTextDim)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .cmPanel()
                }
            }
        }
    }

    // MARK: - Memory + power row
    private var memoryAndPowerRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Memory Detail")
            HStack(spacing: 10) {
                // Used / Total
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("USED")
                            .font(.cmMono(9, weight: .bold))
                            .foregroundStyle(Color.cmTextDim)
                            .kerning(1)
                        Spacer()
                        HStack(alignment: .lastTextBaseline, spacing: 0) {
                            Text(String(format: "%.1f", systemMonitor.memoryUsedGB))
                                .font(.cmMono(13, weight: .bold))
                                .foregroundStyle(memColor)
                                .contentTransition(.numericText())
                            Text(" GB")
                                .font(.cmMono(9))
                                .foregroundStyle(memColor.opacity(0.6))
                        }
                    }
                    HStack {
                        Text("TOTAL")
                            .font(.cmMono(9, weight: .bold))
                            .foregroundStyle(Color.cmTextDim)
                            .kerning(1)
                        Spacer()
                        HStack(alignment: .lastTextBaseline, spacing: 0) {
                            Text(String(format: "%.0f", systemMonitor.totalMemoryGB))
                                .font(.cmMono(13, weight: .bold))
                                .foregroundStyle(Color.cmTextSecondary)
                            Text(" GB")
                                .font(.cmMono(9))
                                .foregroundStyle(Color.cmTextDim)
                        }
                    }
                    HStack {
                        Text("PRESSURE")
                            .font(.cmMono(9, weight: .bold))
                            .foregroundStyle(Color.cmTextDim)
                            .kerning(1)
                        Spacer()
                        Text(pressureLabel)
                            .font(.cmMono(10, weight: .bold))
                            .foregroundStyle(pressureColor)
                            .kerning(0.5)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .cmPanel(accent: memColor)

                // Power
                if let watts = systemMonitor.totalSystemWatts {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SYSTEM POWER")
                            .font(.cmMono(9, weight: .bold))
                            .foregroundStyle(Color.cmTextDim)
                            .kerning(1)
                        HStack(alignment: .lastTextBaseline, spacing: 3) {
                            Text(String(format: "%.1f", abs(watts)))
                                .font(.cmMono(28, weight: .bold))
                                .foregroundStyle(Color.cmBlue)
                                .contentTransition(.numericText())
                            Text("W")
                                .font(.cmMono(11))
                                .foregroundStyle(Color.cmBlue.opacity(0.6))
                        }
                        Sparkline(values: Array(repeating: 50, count: 30), color: .cmBlue)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .cmPanel(accent: .cmBlue)
                }
            }
        }
    }

    // MARK: - Startup panel
    private var startupPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "System")

            HStack(spacing: 14) {
                // Icon
                Image(systemName: "power")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(startupManager.isEnabled ? Color.cmAmber : Color.cmTextDim)
                    .frame(width: 32, height: 32)
                    .background(
                        (startupManager.isEnabled ? Color.cmAmber : Color.cmTextDim).opacity(0.10)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .animation(.easeOut(duration: 0.2), value: startupManager.isEnabled)

                // Label + status
                VStack(alignment: .leading, spacing: 3) {
                    Text("LAUNCH AT LOGIN")
                        .font(.cmMono(10, weight: .bold))
                        .foregroundStyle(Color.cmTextPrimary)
                        .kerning(0.8)
                    Text(startupManager.isEnabled ? "ENABLED — starts with macOS" : "DISABLED — start manually")
                        .font(.cmMono(9))
                        .foregroundStyle(startupManager.isEnabled ? Color.cmAmber.opacity(0.8) : Color.cmTextDim)
                        .animation(.easeOut(duration: 0.2), value: startupManager.isEnabled)
                }

                Spacer()

                // Toggle pill
                Button {
                    startupManager.setEnabled(!startupManager.isEnabled)
                } label: {
                    ZStack(alignment: startupManager.isEnabled ? .trailing : .leading) {
                        Capsule()
                            .fill(startupManager.isEnabled ? Color.cmAmber : Color.cmSurfaceRaised)
                            .frame(width: 44, height: 24)
                            .overlay(
                                Capsule()
                                    .stroke(startupManager.isEnabled ? Color.cmAmber.opacity(0.5) : Color.cmBorderBright, lineWidth: 1)
                            )
                            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: startupManager.isEnabled)
                        Circle()
                            .fill(startupManager.isEnabled ? Color.cmBackground : Color.cmTextSecondary)
                            .frame(width: 18, height: 18)
                            .padding(3)
                            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: startupManager.isEnabled)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .cmPanel(accent: startupManager.isEnabled ? .cmAmber : .clear)

            Button {
                showCoreVisorSetup = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.cmAmber)
                    Text("START COREVISOR")
                        .font(.cmMono(10, weight: .bold))
                        .foregroundStyle(Color.cmAmber)
                        .kerning(0.8)
                    Spacer()
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.cmAmber.opacity(0.75))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.cmAmber.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.cmAmber.opacity(0.30), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .cmPanel(accent: .cmAmber)

            // Error / approval note if present
            if let msg = startupManager.errorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.cmAmber)
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(msg)
                            .font(.cmMono(9))
                            .foregroundStyle(Color.cmAmber)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Open System Settings → General → Login Items to approve.")
                            .font(.cmMono(8))
                            .foregroundStyle(Color.cmTextDim)
                    }
                }
                .padding(10)
                .background(Color.cmAmber.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.cmAmber.opacity(0.20), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Helpers
    private var cpuLoadColor: Color {
        let pct = systemMonitor.cpuUsagePercent
        if pct > 80 { return .cmRed }
        if pct > 50 { return .cmAmber }
        return .cmGreen
    }

    private var memColor: Color {
        switch systemMonitor.memoryPressure {
        case .green: return .cmGreen
        case .yellow: return .cmAmber
        case .red: return .cmRed
        }
    }

    private var pressureLabel: String {
        switch systemMonitor.memoryPressure {
        case .green: return "NORMAL"
        case .yellow: return "ELEVATED"
        case .red: return "CRITICAL"
        }
    }

    private var pressureColor: Color {
        switch systemMonitor.memoryPressure {
        case .green: return .cmGreen
        case .yellow: return .cmAmber
        case .red: return .cmRed
        }
    }

    private func tempColor(_ temp: Double) -> Color {
        if temp > 90 { return .cmRed }
        if temp > 70 { return .cmAmber }
        return .cmGreen
    }

    private func hostModelName() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }

    private func currentDateString() -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE dd MMM yyyy  HH:mm"
        return f.string(from: Date()).uppercased()
    }
}
