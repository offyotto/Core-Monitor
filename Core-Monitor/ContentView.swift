import SwiftUI
import Darwin
import AVFoundation
import Combine
import AppKit

// MARK: - App-wide mode state
final class AppModeState: ObservableObject {
    @Published var isBasicMode: Bool {
        didSet { UserDefaults.standard.set(isBasicMode, forKey: "basicMode") }
    }
    init() { isBasicMode = UserDefaults.standard.bool(forKey: "basicMode") }
}

@MainActor
final class AppAppearanceSettings: ObservableObject {
    static let shared = AppAppearanceSettings()
    private static let defaultSurfaceOpacity = 1.0

    @Published var surfaceOpacity: Double {
        didSet {
            UserDefaults.standard.set(surfaceOpacity, forKey: Self.surfaceOpacityKey)
        }
    }

    private static let surfaceOpacityKey = "coremonitor.surfaceOpacity"

    private init() {
        if let stored = UserDefaults.standard.object(forKey: Self.surfaceOpacityKey) as? Double {
            surfaceOpacity = min(max(stored, 0.0), 1.0)
        } else {
            surfaceOpacity = Self.defaultSurfaceOpacity
        }
    }
}

// MARK: - Colours (BetterDisplay-matched dark palette)
extension Color {
    static let bdSidebar = Color(red: 0.16, green: 0.17, blue: 0.22).opacity(0.90)
    static let bdContent = Color.clear
    static let bdCard = Color(red: 0.24, green: 0.25, blue: 0.31).opacity(0.78)
    static let bdDivider = Color.white.opacity(0.08)
    static let bdAccent = Color(red: 0.39, green: 0.66, blue: 1.00)
    static let bdSelected = Color(red: 0.22, green: 0.40, blue: 0.90)
    static let bdShellShadow = Color.black.opacity(0.14)
    static let bdSidebarStroke = Color.white.opacity(0.16)
    static let bdSidebarInner = Color.white.opacity(0.05)
}

struct CoreMonBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.31, green: 0.31, blue: 0.34),
                    Color(red: 0.29, green: 0.29, blue: 0.32)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

struct CoreMonWindowShell<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.16, green: 0.10, blue: 0.53),
                            Color(red: 0.11, green: 0.16, blue: 0.46)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)

            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.24, green: 0.26, blue: 0.33).opacity(0.98),
                            Color(red: 0.17, green: 0.19, blue: 0.27).opacity(0.99),
                            Color(red: 0.12, green: 0.13, blue: 0.21)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(1)

            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color.white.opacity(0.08), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 1)
                Spacer()
            }

            content()
                .padding(24)
        }
        .shadow(color: .black.opacity(0.34), radius: 24, y: 14)
    }
}

struct CoreMonGlassBackground: View {
    @ObservedObject private var appearanceSettings = AppAppearanceSettings.shared
    var cornerRadius: CGFloat = 24
    var tintOpacity: Double = 0.18
    var strokeOpacity: Double = 0.14
    var shadowRadius: CGFloat = 10
    var fillColor: Color = .bdCard

    var body: some View {
        ZStack {
            VisualEffectView(
                material: .underWindowBackground,
                blendingMode: .behindWindow,
                opacity: appearanceSettings.surfaceOpacity
            )
            fillColor.opacity((0.025 * appearanceSettings.surfaceOpacity) + (tintOpacity * 0.006 * appearanceSettings.surfaceOpacity))
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(strokeOpacity * appearanceSettings.surfaceOpacity), lineWidth: 1)
        )
        .shadow(color: Color.bdShellShadow.opacity(appearanceSettings.surfaceOpacity), radius: shadowRadius, y: 8)
    }
}

private struct SidebarShellBackground: View {
    @ObservedObject private var appearanceSettings = AppAppearanceSettings.shared
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .fill(Color.bdSidebar.opacity(0.03 * appearanceSettings.surfaceOpacity))

            VisualEffectView(
                material: .sidebar,
                blendingMode: .behindWindow,
                opacity: appearanceSettings.surfaceOpacity
            )
                .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))

            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .stroke(Color.white.opacity(0.05 * appearanceSettings.surfaceOpacity), lineWidth: 1)

            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .stroke(Color.white.opacity(0.01 * appearanceSettings.surfaceOpacity), lineWidth: 1)
                .padding(1)
        }
    }
}

struct CoreMonGlassPanel<Content: View>: View {
    var cornerRadius: CGFloat = 28
    var tintOpacity: Double = 0.18
    var strokeOpacity: Double = 0.2
    var shadowRadius: CGFloat = 18
    var contentPadding: CGFloat = 18
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            CoreMonGlassBackground(
                cornerRadius: cornerRadius,
                tintOpacity: tintOpacity,
                strokeOpacity: strokeOpacity,
                shadowRadius: shadowRadius,
                fillColor: cornerRadius > 24 ? .bdSidebar : .bdCard
            )
            content()
                .padding(contentPadding)
        }
    }
}

// MARK: - Copy-on-click
private struct CopyOnTap: ViewModifier {
    let text: String
    @State private var flashed = false
    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .overlay {
                Rectangle()
                    .fill(Color.white.opacity(flashed ? 0.045 : 0))
                    .allowsHitTesting(false)
            }
            .animation(.easeOut(duration: 0.14), value: flashed)
            .onTapGesture {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                flashed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { flashed = false }
            }
    }
}
private extension View {
    func copyOnTap(_ text: String) -> some View { modifier(CopyOnTap(text: text)) }
}

private struct SoftPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .overlay {
                Rectangle()
                    .fill(Color.white.opacity(configuration.isPressed ? 0.05 : 0))
                    .allowsHitTesting(false)
            }
            .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.86), value: configuration.isPressed)
    }
}

// MARK: - Dark card (BetterDisplay style)
private struct DarkCard<Content: View>: View {
    var padding: CGFloat = 14
    @ViewBuilder let content: () -> Content
    var body: some View {
        content()
            .padding(padding)
            .background(
                CoreMonGlassBackground(
                    cornerRadius: 18,
                    tintOpacity: 0.11,
                    strokeOpacity: 0.14,
                    shadowRadius: 10
                )
            )
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
            CoreMonGlassBackground(
                cornerRadius: 22,
                tintOpacity: 0.14,
                strokeOpacity: 0.18,
                shadowRadius: 12
            )
        )
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
                        .buttonStyle(SoftPressButtonStyle())
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
            }.buttonStyle(SoftPressButtonStyle())

            Button { fanController.calibrateFanControl() } label: {
                HStack(spacing: 8) {
                    if fanController.isCalibrating {
                        ProgressView()
                            .scaleEffect(0.62)
                            .frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "wrench.and.screwdriver.fill")
                    }
                    Text(fanController.isCalibrating ? fanController.calibrationStatus : "Calibrate Fan Control")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(fanController.isCalibrating ? Color.bdAccent : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(SoftPressButtonStyle())
            .disabled(fanController.isCalibrating)

            if !fanController.calibrationStatus.isEmpty, fanController.calibrationStatus != "Not calibrated" {
                Text(fanController.calibrationStatus)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
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
    case battery="Battery"
    case system="System", touchBar="Touch Bar", about="About"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .overview: return "gauge.medium"; case .thermals: return "thermometer.medium"
        case .memory: return "memorychip"; case .fans: return "fanblades.fill"
        case .battery: return "battery.75"; case .system: return "gearshape"
        case .touchBar: return "rectangle.3.group"
        case .about: return "info.circle"
        }
    }
}

// MARK: - Sidebar row
private struct SidebarRow: View {
    @ObservedObject private var appearanceSettings = AppAppearanceSettings.shared
    let item: SidebarItem; let isSelected: Bool
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white.opacity(0.96) : Color.white.opacity(0.58))
                .frame(width: 20, alignment: .center)
                .scaleEffect(isSelected ? 1.04 : 1.0)
            Text(item.rawValue)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Color.white.opacity(0.98) : Color.white.opacity(0.72))
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .offset(x: isSelected ? 2 : 0)
        .background(backgroundFill)
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.03 * appearanceSettings.surfaceOpacity), lineWidth: 1)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(.interactiveSpring(response: 0.24, dampingFraction: 0.82), value: isSelected)
    }

    @ViewBuilder
    private var backgroundFill: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.bdSelected.opacity(0.18 * appearanceSettings.surfaceOpacity))
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.clear)
        }
    }
}

// MARK: - Sidebar
private struct Sidebar: View {
    @ObservedObject private var appearanceSettings = AppAppearanceSettings.shared
    @Binding var selection: SidebarItem
    let hasBattery: Bool
    let modeState: AppModeState

    var visibleItems: [SidebarItem] {
        var items: [SidebarItem] = [.overview, .thermals, .memory, .fans]
        if hasBattery {
            items.append(.battery)
        }
        items.append(contentsOf: [.system, .touchBar, .about])
        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 5) {
                    ForEach(visibleItems) { item in
                        Button {
                            selection = item
                        } label: {
                            SidebarRow(item: item, isSelected: selection == item)
                        }
                        .buttonStyle(SoftPressButtonStyle())
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 34)
                .padding(.bottom, 10)
            }

            Spacer()

            Rectangle()
                .fill(Color.white.opacity(0.03 * appearanceSettings.surfaceOpacity))
                .frame(height: 1)
                .padding(.horizontal, 10)

            Button { modeState.isBasicMode = true } label: {
                Label("Basic Mode", systemImage: "square.grid.2x2.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14).padding(.vertical, 9)
            }
            .buttonStyle(SoftPressButtonStyle())
            .padding(.horizontal, 10)
            .padding(.vertical, 14)
        }
        .frame(width: 228)
        .frame(maxHeight: .infinity)
        .background {
            ZStack {
                VisualEffectView(
                    material: .underWindowBackground,
                    blendingMode: .behindWindow,
                    opacity: appearanceSettings.surfaceOpacity
                )
                Color.bdSidebar.opacity(0.015 * appearanceSettings.surfaceOpacity)
            }
        }
    }
}

// MARK: - why do i even mark stuff, looks like ai made it. eww.
private struct DetailPane: View {
    let selection: SidebarItem
    let state: ContentView.DashboardState
    let cpuHistory: [Double]; let memHistory: [Double]; let cpuTempHistory: [Double]
    let fanController: FanController; let systemMonitor: SystemMonitor
    let startupManager: StartupManager

    @ViewBuilder
    private var selectedContent: some View {
        switch selection {
        case .overview:  overviewContent
        case .thermals:  thermalsContent
        case .memory:    memoryContent
        case .fans:      fansContent
        case .battery:   batteryContent
        case .system:    systemContent
        case .touchBar:  touchBarContent
        case .about:     aboutContent
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                selectedContent
                    .id(selection)
                Spacer(minLength: 24)
            }
            .padding(.top, 28)
            .padding(.leading, 24)
            .padding(.trailing, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Overview
    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            header("Overview", subtitle: hostModelName())
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricTile(label: "CPU Load",  value: "\(Int(state.cpuUsagePercent.rounded()))", unit: "%",
                           color: cpuColor, gauge: state.cpuUsagePercent / 100, history: cpuHistory)
                if let pUsage = state.performanceCoreUsagePercent {
                    MetricTile(label: "P-Core Load (\(state.performanceCoreCount) cores)",
                               value: "\(Int(pUsage.rounded()))", unit: "%",
                               color: loadColor(pUsage), gauge: pUsage / 100)
                }
                if let eUsage = state.efficiencyCoreUsagePercent {
                    MetricTile(label: "E-Core Load (\(state.efficiencyCoreCount) cores)",
                               value: "\(Int(eUsage.rounded()))", unit: "%",
                               color: loadColor(eUsage), gauge: eUsage / 100)
                }
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

    private var touchBarContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            header("Touch Bar", subtitle: "Widgets and layout control")
            TouchBarCustomizationPanel()
        }
    }

    private var aboutContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            header("About", subtitle: "App details and appearance")
            BetterDisplayInspiredHero()
            AboutDetailsPanel()
        }
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
        HStack(spacing: 0) {
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
    private func loadColor(_ usage: Double) -> Color { usage > 80 ? .red : usage > 50 ? .orange : .green }
    private func tempColor(_ t: Double) -> Color { t > 90 ? .red : t > 70 ? .orange : .green }
    private func hostModelName() -> String {
        var size = 0; sysctlbyname("hw.model", nil, &size, nil, 0)
        var m = [CChar](repeating: 0, count: size); sysctlbyname("hw.model", &m, &size, nil, 0)
        return String(cString: m)
    }
}

private struct AboutDetailsPanel: View {
    @ObservedObject private var appearanceSettings = AppAppearanceSettings.shared

    var body: some View {
        DarkCard(padding: 18) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("App details")
                            .font(.system(size: 18, weight: .bold))
                        Text("Version, identity and global surface appearance.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(AppVersion.current)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                        Text(Bundle.main.bundleIdentifier ?? "com.coremonitor.app")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Global Transparency", systemImage: "circle.lefthalf.filled")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text("\(Int((appearanceSettings.surfaceOpacity * 100).rounded()))%")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.bdAccent)
                    }
                    Slider(value: $appearanceSettings.surfaceOpacity, in: 0.0...1.0, step: 0.01)
                        .tint(Color.bdAccent)
                    Text("Changes dashboard and card translucency across the app.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    aboutPill("Core Monitor")
                    aboutPill("macOS Dashboard")
                    aboutPill("Build \(AppVersion.current)")
                }
            }
        }
    }

    private func aboutPill(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.06))
            .clipShape(Capsule())
    }
}

private struct TouchBarPreviewStrip: View {
    @ObservedObject private var settings = TouchBarCustomizationSettings.shared

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TB.groupGap) {
                ForEach(settings.widgets) { kind in
                    TouchBarWidgetPreview(kind: kind, theme: settings.theme)
                        .frame(width: kind.estimatedWidth, height: TB.stripH)
                        .id("\(kind.id)-\(settings.theme.id)")
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
        .frame(height: TB.stripH + 6)
        .background(Color.black.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct TouchBarWidgetPreview: View {
    let kind: TouchBarWidgetKind
    let theme: TouchBarTheme

    var body: some View {
        Image(nsImage: renderPreview())
            .interpolation(.none)
            .antialiased(true)
            .frame(width: kind.estimatedWidth, height: TB.stripH)
    }

    private func renderPreview() -> NSImage {
        let snapshot = TouchBarPreviewFixture.snapshot
        let weatherState = WeatherState.loaded(TouchBarPreviewFixture.weather)

        if let item = PKWidgetTouchBarItem(widget: kind.widgetInfo),
           let widget = item.widget {
            PKCoreMonWidgetState.apply(
                theme: theme,
                weatherState: weatherState,
                snapshot: snapshot,
                clockTitle: TouchBarPreviewFixture.clockTitle,
                clockSubtitle: TouchBarPreviewFixture.clockSubtitle,
                to: widget
            )

            let view = item.view
            let renderBounds = NSRect(x: 0, y: 0, width: kind.estimatedWidth, height: TB.stripH)
            view.frame = renderBounds

            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: renderBounds) else {
                return NSImage(size: renderBounds.size)
            }

            view.cacheDisplay(in: renderBounds, to: bitmap)
            let image = NSImage(size: renderBounds.size)
            image.addRepresentation(bitmap)
            return image
        }

        return NSImage(size: NSSize(width: kind.estimatedWidth, height: TB.stripH))
    }
}

private enum TouchBarPreviewFixture {
    static let weather = WeatherSnapshot(
        locationName: "Karachi",
        symbolName: "cloud.bolt.rain.fill",
        temperature: 22,
        condition: "Partly Cloudy",
        nextRainSummary: "Rain likely at 4:00 PM (40%)",
        high: 26,
        low: 18,
        feelsLike: 21,
        humidity: 63,
        updatedAt: Date()
    )

    static let snapshot = TouchBarSystemSnapshot(
        memPct: 13,
        ssdPct: 27,
        cpuPct: 45,
        cpuTempC: 45,
        batPct: 62,
        batCharging: false,
        netUpKBs: 13,
        netDownMBs: 1.6,
        fps: 0,
        wifiName: "",
        detailedClockTitle: "9:20",
        detailedClockSubtitle: "Apr 11th"
    )

    static let clockTitle = "9:20"
    static let clockSubtitle = "Apr 11th"
}

private struct TouchBarWidgetRow: View {
    @ObservedObject private var settings = TouchBarCustomizationSettings.shared
    let kind: TouchBarWidgetKind

    var isEnabled: Bool { settings.contains(kind) }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                settings.toggle(kind)
            } label: {
                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isEnabled ? Color.bdAccent : .secondary)
            }
            .buttonStyle(SoftPressButtonStyle())

            VStack(alignment: .leading, spacing: 3) {
                Text(kind.title)
                    .font(.system(size: 13, weight: .semibold))
                Text(kind.subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(Int(kind.estimatedWidth)) pt")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)

            if isEnabled {
                HStack(spacing: 6) {
                    Button {
                        settings.moveUp(kind)
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(SoftPressButtonStyle())
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Button {
                        settings.moveDown(kind)
                    } label: {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(SoftPressButtonStyle())
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct TouchBarCustomizationPanel: View {
    @StateObject private var settings = TouchBarCustomizationSettings.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var weatherAttribution: WeatherAttributionSnapshot?
    @State private var weatherAttributionError: String?

    private var widthFraction: Double {
        min(max(settings.estimatedWidth / TouchBarCustomizationSettings.recommendedTouchBarWidth, 0), 1)
    }

    private var widthColor: Color {
        settings.widthOverflow > 0 ? .orange : .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DarkCard(padding: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Live layout preview")
                        .font(.system(size: 14, weight: .bold))
                    TouchBarPreviewStrip()

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Estimated width")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Text("\(Int(settings.estimatedWidth.rounded())) / \(Int(TouchBarCustomizationSettings.recommendedTouchBarWidth)) pt")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(widthColor)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.08))
                                Capsule().fill(widthColor)
                                    .frame(width: geo.size.width * widthFraction)
                            }
                        }
                        .frame(height: 8)

                        if settings.widthOverflow > 0 {
                            Text("The active widget stack is wider than a full Touch Bar. Trim or reorder widgets to avoid clipping.")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }

            DarkCard(padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Presets")
                        .font(.system(size: 14, weight: .bold))
                    ForEach(TouchBarPreset.all) { preset in
                        Button {
                            settings.applyPreset(preset)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(preset.title)
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(preset.subtitle)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(preset.theme.displayName)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(Capsule())
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(SoftPressButtonStyle())
                    }
                }
            }

            DarkCard(padding: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Theme")
                        .font(.system(size: 14, weight: .bold))
                    Picker("Theme", selection: $settings.theme) {
                        ForEach(TouchBarTheme.allCases) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("Weather uses Apple WeatherKit. Allow location access for Core Monitor so the live weather widget can show accurate conditions and rain timing.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)

                    if let attribution = weatherAttribution {
                        VStack(alignment: .leading, spacing: 10) {
                            AsyncImage(url: attribution.markURL) { image in
                                image
                                    .resizable()
                                    .interpolation(.high)
                                    .scaledToFit()
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    )
                            }
                            .frame(maxWidth: 164, minHeight: 24, maxHeight: 26, alignment: .leading)

                            if let legalText = attribution.legalText, !legalText.isEmpty {
                                Text(legalText)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }

                            Link(destination: attribution.legalPageURL) {
                                Label("Open \(attribution.serviceName) legal attribution", systemImage: "arrow.up.right.square")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                        }
                    } else if let weatherAttributionError {
                        Text(weatherAttributionError)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            DarkCard(padding: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Widgets")
                        .font(.system(size: 14, weight: .bold))
                    ForEach(TouchBarWidgetKind.allCases) { kind in
                        TouchBarWidgetRow(kind: kind)
                        if kind != TouchBarWidgetKind.allCases.last {
                            Rectangle()
                                .fill(Color.bdDivider)
                                .frame(height: 1)
                        }
                    }
                }
            }
        }
        .task(id: colorScheme) {
            guard #available(macOS 13.0, *) else { return }
            do {
                weatherAttribution = try await loadWeatherAttribution(isDarkAppearance: colorScheme == .dark)
                weatherAttributionError = nil
            } catch {
                weatherAttribution = nil
                weatherAttributionError = "Weather attribution is unavailable until WeatherKit is enabled for the signed app."
            }
        }
    }
}

private struct BetterDisplayInspiredHero: View {
    @State private var revealBackdrop = false
    @State private var showLogo = false
    @State private var logoScale: CGFloat = 2.9
    @State private var logoOffsetY: CGFloat = -34
    @State private var logoBlur: CGFloat = 8
    @State private var logoOpacity = 0.0

    var body: some View {
        CoreMonGlassPanel(cornerRadius: 26, tintOpacity: 0.12, strokeOpacity: 0.16, shadowRadius: 14, contentPadding: 28) {
            VStack(spacing: 18) {
                ZStack {
                    if revealBackdrop {
                        heroLogo
                            .transition(.opacity)
                    }
                }
                .frame(height: 360)

                VStack(spacing: 6) {
                    Text("Core Monitor")
                        .font(.system(size: 22, weight: .bold))
                    Text("Thermals, fans and live hardware telemetry.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            guard !showLogo else { return }
            revealBackdrop = false
            showLogo = false
            logoScale = 2.9
            logoOffsetY = -34
            logoBlur = 8
            logoOpacity = 0

            try? await Task.sleep(nanoseconds: 120_000_000)
            withAnimation(.easeOut(duration: 0.16)) {
                revealBackdrop = true
            }

            showLogo = true
            withAnimation(.interactiveSpring(response: 0.82, dampingFraction: 0.82, blendDuration: 0.16)) {
                logoScale = 1
                logoOffsetY = 0
                logoBlur = 0
                logoOpacity = 1
            }
        }
    }

    private var heroLogo: some View {
        Image(nsImage: NSImage(named: "AppIcon") ?? NSApp.applicationIconImage)
            .resizable()
            .interpolation(.high)
            .frame(width: 370, height: 370)
            .shadow(color: .black.opacity(0.18), radius: 14, y: 10)
        .scaleEffect(showLogo ? logoScale : 2.8)
        .offset(y: showLogo ? logoOffsetY : -18)
        .blur(radius: showLogo ? logoBlur : 12)
        .opacity(showLogo ? logoOpacity : 0)
    }
}

// MARK: - Basic mode
struct BasicModeView: View {
    @ObservedObject var systemMonitor: SystemMonitor
    @ObservedObject var fanController: FanController
    @ObservedObject var modeState: AppModeState

    var body: some View {
        VStack(spacing: 0) {
            basicHeader; Rectangle().fill(Color.bdDivider).frame(height: 1)
            basicMetrics; Rectangle().fill(Color.bdDivider).frame(height: 1)
            basicFans; Spacer(); basicFooter
        }
        .background {
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()
        }
        .overlay {
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                .ignoresSafeArea()
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
            }.buttonStyle(SoftPressButtonStyle())
        }.padding(.horizontal, 16).padding(.vertical, 12)
    }

    private var basicMetrics: some View {
        HStack(spacing: 0) {
            basicCell("CPU", "\(Int(systemMonitor.cpuUsagePercent.rounded()))%",
                      systemMonitor.cpuTemperature.map { String(format: "%.0f°C", $0) })
            if let pUsage = systemMonitor.performanceCoreUsagePercent {
                Rectangle().fill(Color.bdDivider).frame(width: 1)
                basicCell("P", "\(Int(pUsage.rounded()))%",
                          "\(SystemMonitor.performanceCoreCount()) cores")
            }
            if let eUsage = systemMonitor.efficiencyCoreUsagePercent {
                Rectangle().fill(Color.bdDivider).frame(width: 1)
                basicCell("E", "\(Int(eUsage.rounded()))%",
                          "\(SystemMonitor.efficiencyCoreCount()) cores")
            }
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
            }.buttonStyle(SoftPressButtonStyle()).padding(.horizontal, 16).padding(.bottom, 12)
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
        }.buttonStyle(SoftPressButtonStyle())
    }

    private var basicFooter: some View {
        HStack {
            Circle().fill(systemMonitor.hasSMCAccess ? Color.green : .secondary).frame(width: 5, height: 5)
            Text(systemMonitor.hasSMCAccess ? "SMC OK" : "No SMC").font(.system(size: 9)).foregroundStyle(.secondary)
            Spacer()
        }.padding(.horizontal, 16).padding(.vertical, 8)
    }
}

// MARK: - VisualEffectView (NSVisualEffectView wrapper) THIS ISNT AI SLOP BTW:/ btw this will STAY open source foEVAA
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    var opacity: Double = 1.0
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        v.alphaValue = opacity
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
        nsView.alphaValue = opacity
    }
}

// MARK: - ContentView
struct ContentView: View {
    @StateObject private var appearanceSettings = AppAppearanceSettings.shared
    struct DashboardState {
        var hasSMCAccess = false; var numberOfFans = 0
        var fanSpeeds: [Int] = []; var fanMinSpeeds: [Int] = []; var fanMaxSpeeds: [Int] = []
        var cpuUsagePercent: Double = 0; var cpuTemperature: Double?; var gpuTemperature: Double?
        var performanceCoreUsagePercent: Double?; var efficiencyCoreUsagePercent: Double?
        var performanceCoreCount: Int = SystemMonitor.performanceCoreCount()
        var efficiencyCoreCount: Int = SystemMonitor.efficiencyCoreCount()
        var memoryUsagePercent: Double = 0; var memoryUsedGB: Double = 0; var totalMemoryGB: Double = 0
        var memoryPressure: MemoryPressureLevel = .green
        var batteryInfo = BatteryInfo(); var totalSystemWatts: Double?
        var currentVolume: Float = 0.5; var currentBrightness: Float = 1.0
    }

    let systemMonitor: SystemMonitor
    @ObservedObject var fanController: FanController
    @ObservedObject var startupManager: StartupManager

    @StateObject private var modeState      = AppModeState()

    @State private var cpuHistory:     [Double] = Array(repeating: 0, count: 60)
    @State private var memHistory:     [Double] = Array(repeating: 0, count: 60)
    @State private var cpuTempHistory: [Double] = Array(repeating: 0, count: 60)
    @State private var sidebarSelection: SidebarItem = .overview
    @State private var dashboardState = DashboardState()

    var body: some View {
        Group {
            if modeState.isBasicMode {
                BasicModeView(systemMonitor: systemMonitor, fanController: fanController, modeState: modeState)
            } else {
                fullDashboard
            }
        }
        .cmHideWindowToolbarBackground()
        .cmRemoveWindowToolbarTitle()
        .onReceive(NotificationCenter.default.publisher(for: .systemMonitorDidUpdate)) { _ in
            DispatchQueue.main.async {
                refreshDashboardState()
                updateHistories()
            }
        }
        .onChange(of: modeState.isBasicMode) { systemMonitor.setBasicMode($0) }
        .onAppear {
            DispatchQueue.main.async {
                systemMonitor.setBasicMode(modeState.isBasicMode)
                refreshDashboardState()
            }
        }
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
                startupManager: startupManager
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, 10)
        .padding(.top, 0)
        .padding(.bottom, 10)
        .ignoresSafeArea(.container, edges: .top)
        .background {
            ZStack {
                VisualEffectView(
                    material: .underWindowBackground,
                    blendingMode: .behindWindow,
                    opacity: appearanceSettings.surfaceOpacity
                )
                    .ignoresSafeArea()
                Color(red: 0.24, green: 0.25, blue: 0.31)
                    .opacity(0.008 * appearanceSettings.surfaceOpacity)
                    .ignoresSafeArea()
            }
        }
        .preferredColorScheme(.dark)
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
            performanceCoreUsagePercent: systemMonitor.performanceCoreUsagePercent,
            efficiencyCoreUsagePercent: systemMonitor.efficiencyCoreUsagePercent,
            performanceCoreCount: SystemMonitor.performanceCoreCount(),
            efficiencyCoreCount: SystemMonitor.efficiencyCoreCount(),
            memoryUsagePercent: systemMonitor.memoryUsagePercent, memoryUsedGB: systemMonitor.memoryUsedGB,
            totalMemoryGB: systemMonitor.totalMemoryGB, memoryPressure: systemMonitor.memoryPressure,
            batteryInfo: systemMonitor.batteryInfo, totalSystemWatts: systemMonitor.totalSystemWatts,
            currentVolume: systemMonitor.currentVolume, currentBrightness: systemMonitor.currentBrightness
        )
    }
}
