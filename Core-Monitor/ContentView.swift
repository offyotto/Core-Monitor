import SwiftUI
import Darwin
import AVFoundation
import Combine

// MARK: - App-wide mode state (persisted)
final class AppModeState: ObservableObject {
    @Published var isBasicMode: Bool {
        didSet { UserDefaults.standard.set(isBasicMode, forKey: "basicMode") }
    }
    init() {
        isBasicMode = UserDefaults.standard.bool(forKey: "basicMode")
    }
}

// MARK: - Design tokens (Normal mode)
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
    static let cmPurple        = Color(red: 0.72, green: 0.40, blue: 1.0)
    static let cmTextPrimary   = Color(white: 0.92)
    static let cmTextSecondary = Color(white: 0.50)
    static let cmTextDim       = Color(white: 0.32)
}

// MARK: - Basic mode tokens
private extension Color {
    static let bBackground = Color(red: 0.05, green: 0.05, blue: 0.05)
    static let bSurface    = Color(red: 0.09, green: 0.09, blue: 0.09)
    static let bBorder     = Color(white: 1, opacity: 0.10)
    static let bText       = Color(white: 0.80)
    static let bDim        = Color(white: 0.40)
}

private extension Font {
    static func cmMono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Panel modifiers
private struct CMPanel: ViewModifier {
    var accent: Color = .clear
    func body(content: Content) -> some View {
        content
            .background(Color.cmSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(accent == .clear ? Color.cmBorder : accent.opacity(0.35), lineWidth: 1))
    }
}

private struct BasicPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.bSurface)
            .overlay(Rectangle().stroke(Color.bBorder, lineWidth: 1))
    }
}

private extension View {
    func cmPanel(accent: Color = .clear) -> some View { modifier(CMPanel(accent: accent)) }
    func basicPanel() -> some View { modifier(BasicPanel()) }
}

// MARK: - Copy-on-click modifier
private struct CopyOnTap: ViewModifier {
    let text: String
    @State private var flashed = false
    func body(content: Content) -> some View {
        content
            .opacity(flashed ? 0.45 : 1.0)
            .onTapGesture {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                withAnimation(.easeOut(duration: 0.1)) { flashed = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    withAnimation(.easeIn(duration: 0.15)) { flashed = false }
                }
            }
            .onHover { inside in inside ? NSCursor.pointingHand.push() : NSCursor.pop() }
            .help("Click to copy")
    }
}
private extension View {
    func copyOnTap(_ text: String) -> some View { modifier(CopyOnTap(text: text)) }
}

// MARK: - Collapsible section
private struct CollapsibleSection<Content: View>: View {
    let title: String
    var trailing: String = ""
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 10 : 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Rectangle().fill(Color.cmAmber).frame(width: 2, height: 11)
                    Text(title.uppercased())
                        .font(.cmMono(10, weight: .bold))
                        .foregroundStyle(Color.cmTextSecondary)
                        .cmKerning(1.4)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.cmTextDim)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.spring(response: 0.25), value: isExpanded)
                    Spacer()
                    if !trailing.isEmpty {
                        Text(trailing).font(.cmMono(10)).foregroundStyle(Color.cmTextDim)
                    }
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Gauge ring
private struct GaugeRing: View {
    let value: Double
    let color: Color
    var lineWidth: CGFloat = 5
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.12), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: value)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: value)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Sparkline
private struct Sparkline: View {
    let values: [Double]
    let color: Color
    var height: CGFloat = 28

    var body: some View {
        GeometryReader { geo in
            if values.count > 1 {
                let w = geo.size.width
                let h = geo.size.height
                let step = w / CGFloat(values.count - 1)
                Path { path in
                    for (i, v) in values.enumerated() {
                        let pt = CGPoint(x: CGFloat(i) * step, y: h - (CGFloat(v) / 100.0) * h)
                        if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

                Path { path in
                    path.move(to: CGPoint(x: 0, y: h))
                    for (i, v) in values.enumerated() {
                        path.addLine(to: CGPoint(x: CGFloat(i) * step, y: h - (CGFloat(v) / 100.0) * h))
                    }
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.closeSubpath()
                }
                .fill(LinearGradient(colors: [color.opacity(0.22), .clear], startPoint: .top, endPoint: .bottom))
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
                        .cmKerning(1.2)
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text(value)
                            .font(.cmMono(28, weight: .bold))
                            .foregroundStyle(color)
                            .cmNumericTextTransition()
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
                Sparkline(values: history, color: color).padding(.top, 8)
            }
        }
        .padding(12)
        .cmPanel(accent: color)
        .frame(maxWidth: wide ? .infinity : nil)
        .copyOnTap("\(value)\(unit)")
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
        return max(0, min(1, Double(rpm - minRPM) / Double(maxRPM - minRPM)))
    }
    private var rpmColor: Color { fraction > 0.8 ? .cmRed : fraction > 0.5 ? .cmAmber : .cmGreen }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("FAN \(index + 1)").font(.cmMono(9, weight: .bold)).foregroundStyle(Color.cmTextDim).cmKerning(1)
                Spacer()
                Text("\(rpm)").font(.cmMono(13, weight: .bold)).foregroundStyle(rpmColor).cmNumericTextTransition()
                Text("RPM").font(.cmMono(9)).foregroundStyle(Color.cmTextDim)
            }
            GeometryReader { geo in
                let safeWidth = geo.size.width.isFinite ? max(0, geo.size.width) : 0
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.cmSurfaceRaised).frame(height: 4)
                    RoundedRectangle(cornerRadius: 2).fill(rpmColor)
                        .frame(width: safeWidth * fraction, height: 4)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: fraction)
                }
            }
            .frame(height: 4)
        }
        .copyOnTap("\(rpm) RPM")
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
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3).stroke(Color.cmBorderBright, lineWidth: 1.5).frame(width: 40, height: 20)
                RoundedRectangle(cornerRadius: 2).fill(chargeColor)
                    .frame(width: 36 * Double(info.chargePercent ?? 0) / 100.0, height: 16)
                    .padding(.leading, 2)
                    .animation(.easeOut(duration: 0.4), value: info.chargePercent)
                RoundedRectangle(cornerRadius: 1.5).fill(Color.cmBorderBright).frame(width: 3, height: 9).offset(x: 42)
            }
            .frame(width: 47)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text("\(info.chargePercent ?? 0)%")
                        .font(.cmMono(13, weight: .bold)).foregroundStyle(chargeColor).cmNumericTextTransition()
                    if info.isCharging {
                        Image(systemName: "bolt.fill").font(.system(size: 9, weight: .bold)).foregroundStyle(Color.cmAmber)
                    }
                    Text(info.isCharging ? "CHARGING" : info.isPluggedIn ? "AC POWER" : "ON BATTERY")
                        .font(.cmMono(9, weight: .bold)).foregroundStyle(Color.cmTextDim).cmKerning(0.8)
                }
                HStack(spacing: 8) {
                    if let watts  = info.powerWatts    { metricPill(String(format: "%.1fW", abs(watts)))   }
                    if let health = info.healthPercent  { metricPill("HEALTH \(health)%")                  }
                    if let cycles = info.cycleCount     { metricPill("\(cycles) CYCLES")                   }
                    if let mins   = info.timeRemainingMinutes, mins > 0 { metricPill("\(mins / 60)h \(mins % 60)m") }
                }
            }
            Spacer()
            if let temp = info.temperatureC {
                VStack(spacing: 1) {
                    Text(String(format: "%.0f°", temp)).font(.cmMono(13, weight: .bold)).foregroundStyle(Color.cmTextSecondary)
                    Text("BATT").font(.cmMono(8)).foregroundStyle(Color.cmTextDim).cmKerning(0.8)
                }
            }
        }
        .padding(12)
        .cmPanel()
        .copyOnTap("\(info.chargePercent ?? 0)% \(info.isCharging ? "Charging" : info.isPluggedIn ? "AC" : "Battery")")
    }

    private func metricPill(_ text: String) -> some View {
        Text(text).font(.cmMono(8, weight: .medium)).foregroundStyle(Color.cmTextDim).cmKerning(0.5)
            .padding(.horizontal, 5).padding(.vertical, 2)
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
            HStack {
                if fanController.vmBoostActive {
                    HStack(spacing: 4) {
                        Image(systemName: "server.rack").font(.system(size: 8, weight: .bold)).foregroundStyle(Color.cmGreen)
                        Text("VM BOOST").font(.cmMono(8, weight: .bold)).foregroundStyle(Color.cmGreen).cmKerning(0.5)
                    }
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Color.cmGreen.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.cmGreen.opacity(0.25)))
                }
                Spacer()
                Text(fanController.statusMessage).font(.cmMono(10)).foregroundStyle(Color.cmTextDim)
            }

            HStack(spacing: 6) {
                ForEach(FanControlMode.allCases, id: \.self) { mode in
                    Button { fanController.setMode(mode) } label: {
                        Text(mode.rawValue.uppercased())
                            .font(.cmMono(10, weight: .bold)).cmKerning(0.8)
                            .foregroundStyle(fanController.mode == mode ? Color.cmBackground : Color.cmTextSecondary)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(fanController.mode == mode ? Color.cmAmber : Color.cmSurfaceRaised)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .animation(.easeOut(duration: 0.15), value: fanController.mode)
                }
                Spacer()
                Button { fanController.resetToSystemAutomatic() } label: {
                    Label("RESET AUTO", systemImage: "arrow.counterclockwise")
                        .font(.cmMono(9, weight: .bold)).cmKerning(0.5).foregroundStyle(Color.cmTextDim)
                }
                .buttonStyle(.plain)
                .help("Reset fans to system automatic (⌘⇧R)")
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }

            if fanController.mode == .manual {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("TARGET SPEED").font(.cmMono(9, weight: .bold)).foregroundStyle(Color.cmTextDim).cmKerning(1)
                        Spacer()
                        Text("\(fanController.manualSpeed) RPM")
                            .font(.cmMono(13, weight: .bold)).foregroundStyle(Color.cmAmber)
                            .cmNumericTextTransition()
                            .copyOnTap("\(fanController.manualSpeed) RPM")
                    }
                    Slider(value: Binding(get: { Double(fanController.manualSpeed) }, set: { fanController.setManualSpeed(Int($0)) }),
                           in: Double(fanController.minSpeed)...Double(fanController.maxSpeed), step: 50)
                        .tint(Color.cmAmber)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("AGGRESSIVENESS").font(.cmMono(9, weight: .bold)).foregroundStyle(Color.cmTextDim).cmKerning(1)
                        Spacer()
                        Text(String(format: "%.1f×", fanController.autoAggressiveness))
                            .font(.cmMono(13, weight: .bold)).foregroundStyle(Color.cmGreen)
                    }
                    Slider(value: Binding(get: { fanController.autoAggressiveness }, set: { fanController.setAutoAggressiveness($0) }), in: 0...3, step: 0.1)
                        .tint(Color.cmGreen)
                }
            }

            if !systemMonitor.fanSpeeds.isEmpty {
                VStack(spacing: 8) {
                    ForEach(systemMonitor.fanSpeeds.indices, id: \.self) { i in
                        FanBar(index: i, rpm: systemMonitor.fanSpeeds[i],
                               minRPM: i < systemMonitor.fanMinSpeeds.count ? systemMonitor.fanMinSpeeds[i] : 1000,
                               maxRPM: i < systemMonitor.fanMaxSpeeds.count ? systemMonitor.fanMaxSpeeds[i] : 6500)
                    }
                }
                .padding(10).cmPanel()
            }
        }
        .padding(14).cmPanel()
    }
}

// MARK: ═══════════════════════════════════════
// MARK:   BASIC MODE VIEW
// MARK: ═══════════════════════════════════════
struct BasicModeView: View {
    @ObservedObject var systemMonitor: SystemMonitor
    @ObservedObject var fanController: FanController
    @ObservedObject var modeState: AppModeState

    var body: some View {
        ZStack {
            Color.bBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                basicHeader
                Divider().background(Color.bBorder)
                basicMetrics
                Divider().background(Color.bBorder)
                basicFanControls
                Spacer()
                basicFooter
            }
        }
        .preferredColorScheme(.dark)
    }

    private var basicHeader: some View {
        HStack {
            Text("CORE MONITOR")
                .font(.cmMono(10, weight: .bold))
                .foregroundStyle(Color.bText)
                .cmKerning(2)
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { modeState.isBasicMode = false }
            } label: {
                Text("FULL UI")
                    .font(.cmMono(9, weight: .bold))
                    .foregroundStyle(Color.bDim)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .overlay(Rectangle().stroke(Color.bBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("Switch to full UI")
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private var basicMetrics: some View {
        HStack(spacing: 0) {
            basicMetricCell(label: "CPU",
                            value: "\(Int(systemMonitor.cpuUsagePercent.rounded()))%",
                            sub: systemMonitor.cpuTemperature.map { String(format: "%.0f°C", $0) })
            Divider().background(Color.bBorder)
            basicMetricCell(label: "MEM",
                            value: "\(Int(systemMonitor.memoryUsagePercent.rounded()))%",
                            sub: String(format: "%.1f/%.0f GB", systemMonitor.memoryUsedGB, systemMonitor.totalMemoryGB))
            if let gpu = systemMonitor.gpuTemperature {
                Divider().background(Color.bBorder)
                basicMetricCell(label: "GPU", value: String(format: "%.0f°C", gpu), sub: nil)
            }
            if systemMonitor.batteryInfo.hasBattery {
                Divider().background(Color.bBorder)
                basicMetricCell(label: "BAT",
                                value: "\(systemMonitor.batteryInfo.chargePercent ?? 0)%",
                                sub: systemMonitor.batteryInfo.isCharging ? "CHARGING" : "BATTERY")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func basicMetricCell(label: String, value: String, sub: String?) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.cmMono(8, weight: .bold))
                .foregroundStyle(Color.bDim)
                .cmKerning(1.2)
            Text(value)
                .font(.cmMono(22, weight: .bold))
                .foregroundStyle(Color.bText)
                .cmNumericTextTransition()
                .animation(.easeOut(duration: 0.3), value: value)
            if let sub {
                Text(sub).font(.cmMono(8)).foregroundStyle(Color.bDim)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .copyOnTap("\(label): \(value)")
    }

    // MARK: Fan controls — 3 buttons: Cool Down / Boost / Auto
    private var basicFanControls: some View {
        VStack(spacing: 0) {
            if let rpm = systemMonitor.fanSpeeds.first {
                HStack {
                    Text("FAN").font(.cmMono(8, weight: .bold)).foregroundStyle(Color.bDim).cmKerning(1.2)
                    Spacer()
                    Text("\(rpm) RPM")
                        .font(.cmMono(13, weight: .bold))
                        .foregroundStyle(Color.bText)
                        .cmNumericTextTransition()
                        .copyOnTap("\(rpm) RPM")
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 10)
            } else {
                Spacer().frame(height: 12)
            }

            HStack(spacing: 10) {
                basicFanButton(label: "COOL DOWN", subLabel: "\(fanController.minSpeed) RPM", icon: "wind",
                               active: fanController.mode == .manual && fanController.manualSpeed == fanController.minSpeed) {
                    fanController.setMode(.manual)
                    fanController.setManualSpeed(fanController.minSpeed)
                }
                basicFanButton(label: "BOOST", subLabel: "\(fanController.maxSpeed) RPM", icon: "tornado",
                               active: fanController.mode == .manual && fanController.manualSpeed == fanController.maxSpeed) {
                    fanController.setMode(.manual)
                    fanController.setManualSpeed(fanController.maxSpeed)
                }
            }
            .padding(.horizontal, 14)

            Button {
                fanController.resetToSystemAutomatic()
                fanController.setMode(.automatic)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.counterclockwise").font(.system(size: 9, weight: .bold))
                    Text("AUTO").font(.cmMono(9, weight: .bold)).cmKerning(0.8)
                }
                .foregroundStyle(fanController.mode == .automatic ? Color.bText : Color.bDim)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .overlay(Rectangle().stroke(fanController.mode == .automatic ? Color.bText.opacity(0.5) : Color.bBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .background(Color.bSurface)
    }

    private func basicFanButton(label: String, subLabel: String, icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 18, weight: .light)).foregroundStyle(active ? Color.bText : Color.bDim)
                Text(label).font(.cmMono(10, weight: .bold)).foregroundStyle(active ? Color.bText : Color.bDim).cmKerning(0.5)
                Text(subLabel).font(.cmMono(8)).foregroundStyle(Color.bDim)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(active ? Color(white: 0.13) : Color.bSurface)
            .overlay(Rectangle().stroke(active ? Color.bText.opacity(0.4) : Color.bBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var basicFooter: some View {
        HStack {
            Circle()
                .fill(systemMonitor.hasSMCAccess ? Color.bText.opacity(0.5) : Color.bDim.opacity(0.3))
                .frame(width: 4, height: 4)
            Text(systemMonitor.hasSMCAccess ? "SMC OK" : "NO SMC")
                .font(.cmMono(7)).foregroundStyle(Color.bDim)
            Spacer()
            Text("BASIC MODE  ·  LOW RESOURCE")
                .font(.cmMono(7)).foregroundStyle(Color.bDim.opacity(0.5)).cmKerning(0.5)
        }
        .padding(.horizontal, 14).padding(.vertical, 7)
        .background(Color.bBackground)
    }
}

// MARK: - Main ContentView
struct ContentView: View {
    @ObservedObject var systemMonitor: SystemMonitor
    @ObservedObject var fanController: FanController
    @ObservedObject var startupManager: StartupManager
    @ObservedObject var coreVisorManager: CoreVisorManager
    @StateObject private var updater = AppUpdater.shared
    @StateObject private var modeState = AppModeState()

    @State private var cpuHistory:     [Double] = Array(repeating: 0, count: 60)
    @State private var memHistory:     [Double] = Array(repeating: 0, count: 60)
    @State private var cpuTempHistory: [Double] = Array(repeating: 0, count: 60)

    // Collapse states
    @State private var procExpanded    = true
    @State private var thermalExpanded = true
    @State private var memExpanded     = true
    @State private var netExpanded     = true
    @State private var diskExpanded    = true
    @State private var fanExpanded     = true
    @State private var battExpanded    = true
    @State private var sysExpanded     = true

    @State private var showCoreVisorSetup      = false
    @State private var hasOpenedCoreVisorSetup = false
    @State private var showUpdateCheck         = false

    var body: some View {
        Group {
            if modeState.isBasicMode {
                BasicModeView(systemMonitor: systemMonitor, fanController: fanController, modeState: modeState)
            } else {
                fullDashboard
            }
        }
        .onReceive(systemMonitor.$cpuUsagePercent,    perform: updateCPUHistory)
        .onReceive(systemMonitor.$memoryUsagePercent, perform: updateMemoryHistory)
        .onReceive(systemMonitor.$cpuTemperature,     perform: updateCPUTempHistory)
        .onReceive(NotificationCenter.default.publisher(for: .openCoreVisorSheet)) { _ in
            showCoreVisorSetup = true
        }
        .onChange(of: modeState.isBasicMode) { newValue in
            systemMonitor.setBasicMode(newValue)
        }
        .onAppear {
            systemMonitor.setBasicMode(modeState.isBasicMode)
        }
    }

    // MARK: - Full Dashboard
    private var fullDashboard: some View {
        ZStack {
            dashboardRoot
                .sheet(isPresented: $showCoreVisorSetup) {
                    CoreVisorSetupView(manager: coreVisorManager, hasOpenedCoreVisorSetup: $hasOpenedCoreVisorSetup)
                }
                .sheet(isPresented: $showUpdateCheck) {
                    UpdateCheckSheet(updater: updater)
                }
        }
        .preferredColorScheme(.dark)
        .welcomeGuide()
        .cmHandleSpaceKeyPress {
            let allExpanded = procExpanded && thermalExpanded && memExpanded &&
                              netExpanded && diskExpanded && fanExpanded && battExpanded && sysExpanded
            let target = !allExpanded
            withAnimation(.spring(response: 0.3)) {
                procExpanded = target; thermalExpanded = target; memExpanded = target
                netExpanded = target; diskExpanded = target; fanExpanded = target
                battExpanded = target; sysExpanded = target
            }
        }
    }

    private var dashboardRoot: some View {
        ZStack {
            Color.cmBackground.ignoresSafeArea()
            scanLineOverlay
            dashboardScrollContent
        }
    }

    private var dashboardScrollContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                dashboardHeader

                if updater.updateAvailable != nil {
                    UpdateBannerView(updater: updater)
                        .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .move(edge: .bottom).combined(with: .opacity)))
                }

                CollapsibleSection(title: "Processor", isExpanded: $procExpanded) { primaryMetricsRow }
                CollapsibleSection(title: "Thermals", isExpanded: $thermalExpanded) { temperatureRow }
                CollapsibleSection(title: "Memory Detail", isExpanded: $memExpanded) { memoryAndPowerRow }
                CollapsibleSection(title: "Network", isExpanded: $netExpanded) { networkContent }
                CollapsibleSection(title: "Disk I/O", isExpanded: $diskExpanded) { diskContent }
                CollapsibleSection(title: "Fan Control", trailing: fanController.statusMessage, isExpanded: $fanExpanded) {
                    FanControlPanel(fanController: fanController, systemMonitor: systemMonitor)
                }
                if systemMonitor.batteryInfo.hasBattery {
                    CollapsibleSection(title: "Power", isExpanded: $battExpanded) {
                        BatteryStatusBar(info: systemMonitor.batteryInfo)
                    }
                }
                CollapsibleSection(title: "System", isExpanded: $sysExpanded) { startupContent }
                Spacer(minLength: 20)
            }
            .padding(16)
        }
    }

    private var scanLineOverlay: some View {
        Canvas { ctx, size in
            var y: CGFloat = 0
            while y < size.height {
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(.white.opacity(0.018)))
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
                    Image(systemName: "cpu.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.cmAmber)
                    Text("CORE MONITOR").font(.cmMono(11, weight: .bold)).foregroundStyle(Color.cmAmber).cmKerning(2)
                }
                Text(hostModelName()).font(.cmMono(13, weight: .bold)).foregroundStyle(Color.cmTextPrimary)
                Text(currentDateString()).font(.cmMono(10)).foregroundStyle(Color.cmTextDim)
            }
            Spacer()
            HStack(spacing: 6) {
                statusDot(label: "SMC", active: systemMonitor.hasSMCAccess, activeColor: .cmGreen)
                statusDot(label: "FAN", active: systemMonitor.numberOfFans > 0, activeColor: .cmGreen)
                if systemMonitor.batteryInfo.hasBattery {
                    statusDot(label: "BAT", active: true,
                              activeColor: systemMonitor.batteryInfo.isCharging ? .cmAmber : .cmGreen)
                }
                // Basic mode toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { modeState.isBasicMode = true }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.grid.2x2.fill").font(.system(size: 8, weight: .bold))
                        Text("BASIC").font(.cmMono(8, weight: .bold)).cmKerning(0.8)
                    }
                    .foregroundStyle(Color.cmTextDim)
                    .padding(.horizontal, 7).padding(.vertical, 4)
                    .background(Color.cmSurfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help("Switch to Basic Mode (low resource)")

                Button {
                    if updater.updateAvailable != nil { showUpdateCheck = true }
                    else { Task { await updater.checkForUpdates() } }
                } label: {
                    HStack(spacing: 4) {
                        if updater.isChecking {
                            ProgressView().scaleEffect(0.6).frame(width: 8, height: 8)
                        } else {
                            Circle()
                                .fill(updater.updateAvailable != nil ? Color.cmBlue : Color.cmTextDim.opacity(0.4))
                                .frame(width: 6, height: 6)
                        }
                        Text(updater.updateAvailable != nil ? "UPDATE" : "v\(updater.currentVersion)")
                            .font(.cmMono(8, weight: .bold))
                            .foregroundStyle(updater.updateAvailable != nil ? Color.cmBlue : Color.cmTextDim)
                            .cmKerning(0.8)
                    }
                    .padding(.horizontal, 7).padding(.vertical, 4)
                    .background(Color.cmSurfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func statusDot(label: String, active: Bool, activeColor: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(active ? activeColor : Color.cmTextDim.opacity(0.4))
                .frame(width: 6, height: 6)
                .overlay(
                    active ? Circle().fill(activeColor.opacity(0.3)).frame(width: 10, height: 10)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: active) : nil
                )
            Text(label).font(.cmMono(8, weight: .bold))
                .foregroundStyle(active ? activeColor.opacity(0.8) : Color.cmTextDim).cmKerning(0.8)
        }
        .padding(.horizontal, 7).padding(.vertical, 4)
        .background(Color.cmSurfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    // MARK: - Sections
    private var primaryMetricsRow: some View {
        HStack(spacing: 10) {
            StatTile(label: "CPU Load", value: "\(Int(systemMonitor.cpuUsagePercent.rounded()))", unit: "%",
                     color: cpuLoadColor, gauge: systemMonitor.cpuUsagePercent / 100, history: cpuHistory, wide: true)
            StatTile(label: "Memory",  value: "\(Int(systemMonitor.memoryUsagePercent.rounded()))", unit: "%",
                     color: memColor,     gauge: systemMonitor.memoryUsagePercent / 100, history: memHistory, wide: true)
        }
    }

    private var temperatureRow: some View {
        HStack(spacing: 10) {
            if let cpuTemp = systemMonitor.cpuTemperature {
                StatTile(label: "CPU Temp", value: "\(Int(cpuTemp.rounded()))", unit: "°C",
                         color: tempColor(cpuTemp), gauge: min(cpuTemp, 110) / 110, history: cpuTempHistory, wide: true)
            }
            if let gpuTemp = systemMonitor.gpuTemperature {
                StatTile(label: "GPU Temp", value: "\(Int(gpuTemp.rounded()))", unit: "°C",
                         color: tempColor(gpuTemp), gauge: min(gpuTemp, 110) / 110, wide: true)
            }
            if systemMonitor.cpuTemperature == nil && systemMonitor.gpuTemperature == nil {
                Text("No thermal sensors available").font(.cmMono(11)).foregroundStyle(Color.cmTextDim)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(14).cmPanel()
            }
        }
    }

    private var memoryAndPowerRow: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                memoryRow(label: "USED",     value: String(format: "%.1f", systemMonitor.memoryUsedGB), unit: "GB", color: memColor)
                memoryRow(label: "TOTAL",    value: String(format: "%.0f", systemMonitor.totalMemoryGB), unit: "GB", color: .cmTextSecondary)
                memoryRow(label: "PRESSURE", value: pressureLabel, unit: "", color: pressureColor)
            }
            .padding(12).frame(maxWidth: .infinity).cmPanel(accent: memColor)

            if let watts = systemMonitor.totalSystemWatts {
                VStack(alignment: .leading, spacing: 6) {
                    Text("SYSTEM POWER").font(.cmMono(9, weight: .bold)).foregroundStyle(Color.cmTextDim).cmKerning(1)
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text(String(format: "%.1f", abs(watts)))
                            .font(.cmMono(28, weight: .bold)).foregroundStyle(Color.cmBlue).cmNumericTextTransition()
                        Text("W").font(.cmMono(11)).foregroundStyle(Color.cmBlue.opacity(0.6))
                    }
                    Sparkline(values: Array(repeating: 50, count: 30), color: .cmBlue)
                }
                .padding(12).frame(maxWidth: .infinity).cmPanel(accent: .cmBlue)
                .copyOnTap(String(format: "%.1f W", abs(watts)))
            }
        }
    }

    private func memoryRow(label: String, value: String, unit: String, color: Color) -> some View {
        HStack {
            Text(label).font(.cmMono(9, weight: .bold)).foregroundStyle(Color.cmTextDim).cmKerning(1)
            Spacer()
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value).font(.cmMono(13, weight: .bold)).foregroundStyle(color).cmNumericTextTransition()
                if !unit.isEmpty { Text(unit).font(.cmMono(9)).foregroundStyle(color.opacity(0.6)) }
            }
        }
        .copyOnTap("\(label): \(value)\(unit)")
    }

    @ViewBuilder
    private var networkContent: some View {
        if systemMonitor.netBytesInPerSec > 0 || systemMonitor.netBytesOutPerSec > 0 {
            HStack(spacing: 10) {
                ioTile(label: "RX", value: formatBytes(systemMonitor.netBytesInPerSec),  color: .cmGreen,  icon: "arrow.down.circle.fill")
                ioTile(label: "TX", value: formatBytes(systemMonitor.netBytesOutPerSec), color: .cmBlue,   icon: "arrow.up.circle.fill")
            }
        } else {
            Text("No network activity").font(.cmMono(11)).foregroundStyle(Color.cmTextDim)
                .frame(maxWidth: .infinity, alignment: .leading).padding(14).cmPanel()
        }
    }

    @ViewBuilder
    private var diskContent: some View {
        if systemMonitor.diskReadBytesPerSec > 0 || systemMonitor.diskWriteBytesPerSec > 0 {
            HStack(spacing: 10) {
                ioTile(label: "READ",  value: formatBytes(systemMonitor.diskReadBytesPerSec),  color: .cmAmber,  icon: "arrow.down.circle.fill")
                ioTile(label: "WRITE", value: formatBytes(systemMonitor.diskWriteBytesPerSec), color: .cmPurple, icon: "arrow.up.circle.fill")
            }
        } else {
            Text("No disk activity").font(.cmMono(11)).foregroundStyle(Color.cmTextDim)
                .frame(maxWidth: .infinity, alignment: .leading).padding(14).cmPanel()
        }
    }

    private func ioTile(label: String, value: String, color: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 12, weight: .bold)).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.cmMono(8, weight: .bold)).foregroundStyle(Color.cmTextDim).cmKerning(1)
                Text(value).font(.cmMono(13, weight: .bold)).foregroundStyle(color).cmNumericTextTransition()
            }
            Spacer()
        }
        .padding(10).frame(maxWidth: .infinity).cmPanel(accent: color)
        .copyOnTap("\(label): \(value)")
    }

    @ViewBuilder
    private var startupContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                systemLevelTile(label: "VOLUME",
                                icon: systemMonitor.currentVolume < 0.01 ? "speaker.slash.fill" : "speaker.wave.2.fill",
                                fraction: Double(systemMonitor.currentVolume), color: .cmAmber)
                systemLevelTile(label: "BRIGHTNESS", icon: "sun.max.fill",
                                fraction: Double(systemMonitor.currentBrightness), color: .cmBlue)
            }

            HStack(spacing: 14) {
                Image(systemName: "power")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(startupManager.isEnabled ? Color.cmAmber : Color.cmTextDim)
                    .frame(width: 32, height: 32)
                    .background((startupManager.isEnabled ? Color.cmAmber : Color.cmTextDim).opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .animation(.easeOut(duration: 0.2), value: startupManager.isEnabled)
                VStack(alignment: .leading, spacing: 3) {
                    Text("LAUNCH AT LOGIN").font(.cmMono(10, weight: .bold)).foregroundStyle(Color.cmTextPrimary).cmKerning(0.8)
                    Text(startupManager.isEnabled ? "ENABLED — starts with macOS" : "DISABLED — start manually")
                        .font(.cmMono(9))
                        .foregroundStyle(startupManager.isEnabled ? Color.cmAmber.opacity(0.8) : Color.cmTextDim)
                        .animation(.easeOut(duration: 0.2), value: startupManager.isEnabled)
                }
                Spacer()
                Button { startupManager.setEnabled(!startupManager.isEnabled) } label: {
                    ZStack(alignment: startupManager.isEnabled ? .trailing : .leading) {
                        Capsule()
                            .fill(startupManager.isEnabled ? Color.cmAmber : Color.cmSurfaceRaised)
                            .frame(width: 44, height: 24)
                            .overlay(Capsule().stroke(startupManager.isEnabled ? Color.cmAmber.opacity(0.5) : Color.cmBorderBright, lineWidth: 1))
                            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: startupManager.isEnabled)
                        Circle()
                            .fill(startupManager.isEnabled ? Color.cmBackground : Color.cmTextSecondary)
                            .frame(width: 18, height: 18).padding(3)
                            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: startupManager.isEnabled)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(12).cmPanel(accent: startupManager.isEnabled ? .cmAmber : .clear)

            Button { showCoreVisorSetup = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "server.rack").font(.system(size: 12, weight: .bold)).foregroundStyle(Color.cmAmber)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("START COREVISOR").font(.cmMono(10, weight: .bold)).foregroundStyle(Color.cmAmber).cmKerning(0.8)
                        if !coreVisorManager.machines.isEmpty {
                            let running = coreVisorManager.machines.filter { coreVisorManager.runtimeState(for: $0) == .running }.count
                            let total = coreVisorManager.machines.count
                            Text("\(total) VM\(total == 1 ? "" : "s") · \(running) running")
                                .font(.cmMono(8))
                                .foregroundStyle(running > 0 ? Color.cmGreen.opacity(0.8) : Color.cmTextDim)
                        }
                    }
                    Spacer()
                    if coreVisorManager.hasAnyRunningMachine {
                        HStack(spacing: 4) {
                            Circle().fill(Color.cmGreen).frame(width: 6, height: 6)
                                .overlay(Circle().fill(Color.cmGreen.opacity(0.3)).frame(width: 10, height: 10))
                            let runCount = coreVisorManager.machines.filter { coreVisorManager.runtimeState(for: $0) == .running }.count
                            Text("\(runCount) RUNNING").font(.cmMono(8, weight: .bold)).foregroundStyle(Color.cmGreen).cmKerning(0.5)
                        }
                    } else if coreVisorManager.isDownloadingVirtioISO {
                        HStack(spacing: 5) {
                            ProgressView().scaleEffect(0.6).frame(width: 10, height: 10)
                            Text("DOWNLOADING ISO").font(.cmMono(8, weight: .bold)).foregroundStyle(Color.cmAmber).cmKerning(0.5)
                        }
                    } else {
                        Image(systemName: "arrow.up.forward.app").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.cmAmber.opacity(0.75))
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Color.cmAmber.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cmAmber.opacity(0.30), lineWidth: 1))
            }
            .buttonStyle(.plain)

            if let msg = startupManager.errorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10, weight: .bold)).foregroundStyle(Color.cmAmber).padding(.top, 1)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(msg).font(.cmMono(9)).foregroundStyle(Color.cmAmber).fixedSize(horizontal: false, vertical: true)
                        Text("Open System Settings → General → Login Items to approve.")
                            .font(.cmMono(8)).foregroundStyle(Color.cmTextDim)
                    }
                }
                .padding(10)
                .background(Color.cmAmber.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cmAmber.opacity(0.20), lineWidth: 1))
            }
        }
        .onAppear { startupManager.refreshState() }
    }

    private func systemLevelTile(label: String, icon: String, fraction: Double, color: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon).font(.system(size: 11, weight: .medium)).foregroundStyle(color).frame(width: 16)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(label).font(.cmMono(8, weight: .bold)).foregroundStyle(Color.cmTextDim).cmKerning(0.8)
                    Spacer()
                    Text("\(Int((fraction * 100).rounded()))%").font(.cmMono(10, weight: .bold)).foregroundStyle(color).cmNumericTextTransition()
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.cmSurfaceRaised).frame(height: 3)
                        RoundedRectangle(cornerRadius: 2).fill(color)
                            .frame(width: max(0, geo.size.width * fraction), height: 3)
                            .animation(.easeOut(duration: 0.3), value: fraction)
                    }
                }
                .frame(height: 3)
            }
        }
        .padding(10).frame(maxWidth: .infinity).cmPanel(accent: color)
        .copyOnTap("\(label): \(Int((fraction * 100).rounded()))%")
    }

    // MARK: - History
    private func updateCPUHistory(_ value: Double) {
        cpuHistory.removeFirst(); cpuHistory.append(value)
    }
    private func updateMemoryHistory(_ value: Double) {
        memHistory.removeFirst(); memHistory.append(value)
    }
    private func updateCPUTempHistory(_ value: Double?) {
        let v = value.map { min($0, 120) / 120 * 100 } ?? 0
        cpuTempHistory.removeFirst(); cpuTempHistory.append(v)
    }

    // MARK: - Colors
    private var cpuLoadColor: Color {
        let p = systemMonitor.cpuUsagePercent
        if p > 80 { return .cmRed }; if p > 50 { return .cmAmber }; return .cmGreen
    }
    private var memColor: Color {
        switch systemMonitor.memoryPressure { case .green: return .cmGreen; case .yellow: return .cmAmber; case .red: return .cmRed }
    }
    private var pressureLabel: String {
        switch systemMonitor.memoryPressure { case .green: return "NORMAL"; case .yellow: return "ELEVATED"; case .red: return "CRITICAL" }
    }
    private var pressureColor: Color {
        switch systemMonitor.memoryPressure { case .green: return .cmGreen; case .yellow: return .cmAmber; case .red: return .cmRed }
    }
    private func tempColor(_ temp: Double) -> Color {
        if temp > 90 { return .cmRed }; if temp > 70 { return .cmAmber }; return .cmGreen
    }

    // MARK: - Utility
    private func hostModelName() -> String {
        var size = 0; sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }
    private func currentDateString() -> String {
        let f = DateFormatter(); f.dateFormat = "EEE dd MMM yyyy  HH:mm"
        return f.string(from: Date()).uppercased()
    }
    private func formatBytes(_ bps: Double) -> String {
        if bps >= 1_000_000 { return String(format: "%.1f MB/s", bps / 1_000_000) }
        if bps >= 1_000     { return String(format: "%.0f KB/s", bps / 1_000) }
        return String(format: "%.0f B/s", bps)
    }
}

// MARK: - Update check sheet
private struct UpdateCheckSheet: View {
    @ObservedObject var updater: AppUpdater
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.08).ignoresSafeArea()
            VStack(spacing: 20) {
                HStack {
                    Text("APP UPDATER")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(red: 0.35, green: 0.72, blue: 1.0)).cmKerning(1.5)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Color(white: 0.4))
                    }
                    .buttonStyle(.plain).keyboardShortcut(.escape)
                }
                if updater.updateAvailable != nil {
                    UpdateBannerView(updater: updater)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 32, weight: .medium))
                            .foregroundStyle(Color(red: 0.22, green: 0.92, blue: 0.55))
                        Text("You're up to date").font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color(white: 0.75))
                        Text("Core Monitor v\(updater.currentVersion)").font(.system(size: 10, design: .monospaced)).foregroundStyle(Color(white: 0.35))
                        if let checked = updater.lastChecked {
                            Text("Last checked: \(checked, style: .relative) ago").font(.system(size: 9, design: .monospaced)).foregroundStyle(Color(white: 0.3))
                        }
                    }
                    .frame(maxWidth: .infinity).padding(24)
                    .background(Color(red: 0.10, green: 0.10, blue: 0.12)).clipShape(RoundedRectangle(cornerRadius: 10))
                    Button { Task { await updater.checkForUpdates() } } label: {
                        HStack(spacing: 6) {
                            if updater.isChecking { ProgressView().scaleEffect(0.7).frame(width: 12, height: 12) }
                            else { Image(systemName: "arrow.clockwise").font(.system(size: 10, weight: .bold)) }
                            Text(updater.isChecking ? "CHECKING..." : "CHECK NOW").font(.system(size: 10, weight: .bold, design: .monospaced)).cmKerning(0.5)
                        }
                        .foregroundStyle(Color(white: 0.55)).padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Color(white: 0.12)).clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(white: 1, opacity: 0.08), lineWidth: 1))
                    }
                    .buttonStyle(.plain).disabled(updater.isChecking)
                }
                if let err = updater.checkError {
                    Text(err).font(.system(size: 9, design: .monospaced)).foregroundStyle(Color(red: 1, green: 0.34, blue: 0.34)).multilineTextAlignment(.center)
                }
                Spacer()
            }
            .padding(20)
        }
        .preferredColorScheme(.dark).frame(width: 400, height: 320)
    }
}
