import SwiftUI
import AppKit
import Darwin

private let kProcPidPathMaxSize = max(Int(PATH_MAX), 1024)

private extension View {
    @ViewBuilder
    func mbTracking(_ value: CGFloat) -> some View {
        if #available(macOS 13.0, *) {
            self.tracking(value)
        } else {
            // Fallback for older macOS: use kerning as an approximation
            if #available(macOS 13.0, *) {
                self.kerning(value)
            } else {
                // Fallback on earlier versions
            }
        }
    }
}

// MARK: - Shared colours (dark popover palette)
private extension Color {
    static let mbBG     = Color.clear
    static let mbCard   = Color.white.opacity(0.06)
    static let mbDiv    = Color.white.opacity(0.10)
    static let mbAccent = Color.white.opacity(0.92)
    static let mbTint   = Color(red: 0.66, green: 0.72, blue: 0.96)
    static let mbBlue   = Color(red: 0.39, green: 0.66, blue: 1.00)
    static let mbGreen  = Color(red: 0.25, green: 0.90, blue: 0.58)
    static let mbOrange = Color(red: 1.00, green: 0.62, blue: 0.20)
    static let mbPurple = Color(red: 0.72, green: 0.52, blue: 1.00)
}

// MARK: - Shared surface (used by all popovers)
private struct MenuPopoverSurface<Content: View>: View {
    @ObservedObject private var appearanceSettings = AppAppearanceSettings.shared
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            VisualEffectView(material: .underWindowBackground,
                             blendingMode: .behindWindow,
                             opacity: appearanceSettings.surfaceOpacity)

            LinearGradient(
                colors: [
                    Color(red: 0.22, green: 0.24, blue: 0.33).opacity(0.06 * appearanceSettings.surfaceOpacity),
                    Color(red: 0.11, green: 0.12, blue: 0.19).opacity(0.07 * appearanceSettings.surfaceOpacity)
                ],
                startPoint: .topLeading, endPoint: .bottom
            )

            VStack(spacing: 0) {
                LinearGradient(colors: [Color.white.opacity(0.03 * appearanceSettings.surfaceOpacity), Color.clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 1)
                Spacer()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(Color.white.opacity(0.05 * appearanceSettings.surfaceOpacity), lineWidth: 1))
        .overlay(content())
        .shadow(color: .black.opacity(0.10), radius: 18, y: 10)
    }
}

// MARK: - Shared sub-views

private struct MBRow: View {
    let icon: String; let label: String; let value: String; let color: Color
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(color.opacity(0.85)).frame(width: 16)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.68)).frame(width: 80, alignment: .leading)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(color).monospacedDigit()
        }
        .padding(.horizontal, 14).padding(.vertical, 4)
    }
}

private struct MBSectionHeader: View {
    let title: String
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.mbTint)
                .mbTracking(1.2)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 2)
    }
}

private struct MBDivider: View {
    var body: some View { Rectangle().fill(Color.mbDiv).frame(height: 1) }
}

private struct MenuBarAlertSummarySection: View {
    @ObservedObject var systemMonitor: SystemMonitor
    @ObservedObject var alertManager: AlertManager
    @ObservedObject private var helperManager = SMCHelperManager.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let health = systemMonitor.snapshotHealth(now: context.date)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(alertManager.highestActiveSeverity == .none ? "STATUS" : "ALERTS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.mbTint)
                        .mbTracking(1.2)
                    Spacer()
                    Text(alertManager.highestActiveSeverity.title.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(severityColor(alertManager.highestActiveSeverity))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(severityColor(alertManager.highestActiveSeverity).opacity(0.18))
                        .clipShape(Capsule())
                }

                Text(alertManager.summaryLine)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.84))
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(health.ageDescription) • \(health.cadenceDescription)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(freshnessColor(health))
                    .monospacedDigit()

                HStack(spacing: 8) {
                    summaryPill(health.statusLabel, color: freshnessColor(health))
                    summaryPill("Thermal \(AlertEvaluator.thermalStateLabel(systemMonitor.thermalState))", color: thermalColor(systemMonitor.thermalState))
                    summaryPill(systemMonitor.hasSMCAccess ? "SMC Ready" : "SMC Unavailable", color: systemMonitor.hasSMCAccess ? Color.mbGreen : .red)
                }

                HStack(spacing: 8) {
                    summaryPill(helperSummaryLabel, color: helperSummaryColor)
                    if let recent = alertManager.history.first {
                        summaryPill(recent.kind.title, color: severityColor(recent.severity))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private func summaryPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color.opacity(0.16))
            .clipShape(Capsule())
    }

    private func severityColor(_ severity: AlertSeverity) -> Color {
        switch severity {
        case .none: return .white.opacity(0.55)
        case .info: return Color.mbBlue
        case .warning: return Color.mbOrange
        case .critical: return .red
        }
    }

    private func thermalColor(_ thermalState: ProcessInfo.ThermalState) -> Color {
        switch thermalState {
        case .nominal: return Color.mbGreen
        case .fair: return Color.mbBlue
        case .serious: return Color.mbOrange
        case .critical: return .red
        @unknown default: return .white.opacity(0.55)
        }
    }

    private func freshnessColor(_ health: MonitoringSnapshotHealth) -> Color {
        switch health.freshness {
        case .waiting:
            return Color.mbTint
        case .live:
            return Color.mbGreen
        case .delayed:
            return Color.mbOrange
        case .stale:
            return .red
        }
    }

    private var helperSummaryLabel: String {
        switch helperManager.connectionState {
        case .reachable:
            return "Helper Ready"
        case .checking:
            return "Helper Checking"
        case .unreachable:
            return "Helper Attention"
        case .unknown where helperManager.isInstalled:
            return "Helper Pending"
        case .unknown, .missing:
            return "Helper Missing"
        }
    }

    private var helperSummaryColor: Color {
        switch helperManager.connectionState {
        case .reachable:
            return Color.mbBlue
        case .checking:
            return Color.mbTint
        case .unreachable:
            return .red
        case .unknown where helperManager.isInstalled:
            return Color.mbOrange
        case .unknown, .missing:
            return Color.mbOrange
        }
    }
}

private struct MBActionButton: View {
    let label: String; let icon: String; let action: () -> Void
    @State private var hovered = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 11, weight: .medium))
                    .foregroundStyle(hovered ? Color.white : Color.white.opacity(0.72)).frame(width: 16)
                Text(label).font(.system(size: 12, weight: .medium))
                    .foregroundStyle(hovered ? Color.white : Color.white.opacity(0.78))
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(hovered ? Color.white.opacity(0.07) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).onHover { hovered = $0 }
    }
}

private struct BigRing: View {
    let value: Double   // 0–100
    let label: String
    let color: Color
    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.18), lineWidth: 8)
            Circle().trim(from: 0, to: value / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: value)
            VStack(spacing: 2) {
                Text("\(Int(value.rounded()))%")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
                    .mbTracking(0.8)
            }
        }
        .frame(width: 70, height: 70)
    }
}

private struct MiniSparkline: View {
    let values: [Double]
    let color: Color
    var height: CGFloat = 32
    var body: some View {
        GeometryReader { geo in
            if values.count > 1 {
                let w = geo.size.width, h = geo.size.height
                let step = w / CGFloat(values.count - 1)
                Path { p in
                    for (i, v) in values.enumerated() {
                        let pt = CGPoint(x: CGFloat(i) * step, y: h - CGFloat(v) / 100 * h)
                        i == 0 ? p.move(to: pt) : p.addLine(to: pt)
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h))
                    for (i, v) in values.enumerated() {
                        p.addLine(to: CGPoint(x: CGFloat(i) * step, y: h - CGFloat(v) / 100 * h))
                    }
                    p.addLine(to: CGPoint(x: w, y: h)); p.closeSubpath()
                }
                .fill(LinearGradient(colors: [color.opacity(0.22), .clear], startPoint: .top, endPoint: .bottom))
            }
        }
        .frame(height: height)
    }
}

// MARK: - Core gauge (like the 8 circles in iStat for per-core CPU)
private struct CoreCircle: View {
    let fraction: Double
    let isPerformance: Bool
    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.12), lineWidth: 2.5)
            Circle().trim(from: 0, to: fraction)
                .stroke(isPerformance ? Color.mbBlue : Color.mbGreen,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: fraction)
        }
        .frame(width: 18, height: 18)
    }
}

// MARK: - Donut chart for disk
private struct DonutChart: View {
    let used: Double; let purgeable: Double; let free: Double
    var body: some View {
        let total = used + purgeable + free
        guard total > 0 else { return AnyView(EmptyView()) }
        return AnyView(
            ZStack {
                Circle().stroke(Color.white.opacity(0.08), lineWidth: 14)
                // Free (gray)
                Circle()
                    .trim(from: 0, to: 1)
                    .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 14, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
                // Purgeable (pink)
                Circle()
                    .trim(from: 0, to: (used + purgeable) / total)
                    .stroke(Color.pink.opacity(0.75), style: StrokeStyle(lineWidth: 14, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
                // Used (blue)
                Circle()
                    .trim(from: 0, to: used / total)
                    .stroke(Color.mbBlue, style: StrokeStyle(lineWidth: 14, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
                // Center label
                VStack(spacing: 2) {
                    Text(String(format: "%.0f", used))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.mbBlue)
                    Text("GB USED")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white.opacity(0.45))
                        .mbTracking(0.8)
                }
            }
            .frame(width: 100, height: 100)
        )
    }
}

// MARK: - ═══════════════════════════════════════════
// MARK: - CPU Popover View
// MARK: - ═══════════════════════════════════════════

struct CPUMenuPopoverView: View {
    @ObservedObject var systemMonitor: SystemMonitor
    @ObservedObject var alertManager: AlertManager
    var openDashboardAction: () -> Void = {}

    private var pCores: Int { SystemMonitor.performanceCoreCount() }
    private var eCores: Int { SystemMonitor.efficiencyCoreCount() }

    var body: some View {
        MenuPopoverSurface {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    cpuHeader
                    MBDivider()
                    MenuBarAlertSummarySection(systemMonitor: systemMonitor, alertManager: alertManager)
                    MBDivider()
                    graphSection
                    MBDivider()
                    if eCores > 0 || pCores > 0 { coreSection; MBDivider() }
                    gpuSection
                    MBDivider()
                    systemInfoSection
                    MBDivider()
                    MBActionButton(label: "Open Dashboard", icon: "gauge.medium") { openDashboardAction() }
                        .padding(.vertical, 4)
                }
            }
        }
        .preferredColorScheme(.dark)
        .frame(width: 320)
    }

    // Header
    private var cpuHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.mbBlue.opacity(0.15)).frame(width: 34, height: 34)
                Image(systemName: "cpu.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.mbBlue)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("CPU").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.92))
                if let temp = systemMonitor.cpuTemperature {
                    Text(String(format: "%.0f°C", temp))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(tempColor(temp))
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(systemMonitor.cpuUsagePercent.rounded()))%")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(loadColor(systemMonitor.cpuUsagePercent))
                Text("LOAD").font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45)).mbTracking(0.8)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    // Graph
    private var graphSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("User", systemImage: "circle.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.mbBlue)
                Spacer()
                Label("System", systemImage: "circle.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.mbOrange)
            }
            MiniSparkline(values: systemMonitor.cpuHistory, color: Color.mbBlue)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    // Core breakdown
    private var coreSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // E-core circles
            if eCores > 0 {
                HStack(spacing: 6) {
                    ForEach(0..<min(eCores, 8), id: \.self) { _ in
                        CoreCircle(fraction: (systemMonitor.efficiencyCoreUsagePercent ?? 0) / 100,
                                   isPerformance: false)
                    }
                    Spacer()
                    Text(systemMonitor.efficiencyCoreUsagePercent.map { "\(Int($0.rounded()))%" } ?? "—")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.mbGreen)
                }
                HStack {
                    Circle().fill(Color.mbGreen).frame(width: 6, height: 6)
                    Text("Efficiency Cores").font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.65))
                }
            }
            // P-core circles
            if pCores > 0 {
                HStack(spacing: 6) {
                    ForEach(0..<min(pCores, 8), id: \.self) { _ in
                        CoreCircle(fraction: (systemMonitor.performanceCoreUsagePercent ?? 0) / 100,
                                   isPerformance: true)
                    }
                    Spacer()
                    Text(systemMonitor.performanceCoreUsagePercent.map { "\(Int($0.rounded()))%" } ?? "—")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.mbBlue)
                }
                HStack {
                    Circle().fill(Color.mbBlue).frame(width: 6, height: 6)
                    Text("Performance Cores").font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.65))
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    // GPU
    private var gpuSection: some View {
        VStack(spacing: 0) {
            MBSectionHeader(title: "GPU")
            HStack(spacing: 16) {
                if let gt = systemMonitor.gpuTemperature {
                    gpuRing(value: min(gt, 110) / 110 * 100, label: "TEMP", color: Color.mbOrange)
                }
                if let gpuW = systemMonitor.gpuPowerWatts {
                    gpuRing(value: min(abs(gpuW) / 30.0 * 100, 100), label: "PWR", color: Color.mbPurple)
                }
                if systemMonitor.gpuTemperature == nil && systemMonitor.gpuPowerWatts == nil {
                    Text("GPU data unavailable")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.horizontal, 14)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
        }
    }

    private func gpuRing(value: Double, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().stroke(color.opacity(0.18), lineWidth: 5)
                Circle().trim(from: 0, to: min(value / 100, 1))
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 44, height: 44)
            Text(label).font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.55)).mbTracking(0.5)
        }
    }

    // System info
    private var systemInfoSection: some View {
        VStack(spacing: 0) {
            MBSectionHeader(title: "SYSTEM")
            MBRow(icon: "chart.bar.fill",      label: "Load Avg",  value: loadAvgString(),     color: .white.opacity(0.7))
            MBRow(icon: "clock.fill",           label: "Uptime",    value: uptimeString(),      color: .white.opacity(0.7))
        }
    }

    private func loadAvgString() -> String {
        var load = [Double](repeating: 0, count: 3)
        getloadavg(&load, 3)
        return String(format: "%.2f  %.2f  %.2f", load[0], load[1], load[2])
    }

    private func uptimeString() -> String {
        let s = Int(ProcessInfo.processInfo.systemUptime)
        let d = s / 86400; let h = (s % 86400) / 3600
        if d > 0 { return "\(d)d \(h)h" }
        return "\(h)h \((s % 3600) / 60)m"
    }

    private func tempColor(_ t: Double) -> Color { t > 90 ? .red : t > 70 ? .orange : .green }
    private func loadColor(_ l: Double) -> Color { l > 80 ? .red : l > 50 ? .orange : Color.mbBlue }
}

// MARK: - ═══════════════════════════════════════════
// MARK: - Memory Popover View
// MARK: - ═══════════════════════════════════════════

struct MemoryMenuPopoverView: View {
    @ObservedObject var systemMonitor: SystemMonitor
    @ObservedObject var alertManager: AlertManager
    @ObservedObject private var privacySettings = PrivacySettings.shared
    var openDashboardAction: () -> Void = {}

    var body: some View {
        MenuPopoverSurface {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    memHeader
                    MBDivider()
                    MenuBarAlertSummarySection(systemMonitor: systemMonitor, alertManager: alertManager)
                    MBDivider()
                    breakdownSection
                    MBDivider()
                    processesSection
                    MBDivider()
                    pageSection
                    MBDivider()
                    swapSection
                    MBDivider()
                    MBActionButton(label: "Open Dashboard", icon: "gauge.medium") { openDashboardAction() }
                        .padding(.vertical, 4)
                }
            }
        }
        .preferredColorScheme(.dark)
        .frame(width: 320)
        .onAppear {
            systemMonitor.setDetailedSamplingEnabled(true, reason: "menubar.memory")
        }
        .onDisappear {
            systemMonitor.setDetailedSamplingEnabled(false, reason: "menubar.memory")
        }
    }

    private var memHeader: some View {
        HStack(spacing: 20) {
            BigRing(value: freeMemoryPercent,
                    label: "FREE",
                    color: Color.white.opacity(0.72))
            BigRing(value: systemMonitor.memoryUsagePercent,
                    label: "USED",
                    color: memColor)
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.1f GB", systemMonitor.memoryUsedGB))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(memColor)
                Text(String(format: "of %.0f GB", systemMonitor.totalMemoryGB))
                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 14)
    }

    private var breakdownSection: some View {
        VStack(spacing: 0) {
            MBRow(
                icon: "waveform.path.ecg",
                label: "Pressure",
                value: pressureLabel,
                color: pressureColor
            )
            MBRow(icon: "circle.fill", label: "App",        value: String(format: "%.1f GB", systemMonitor.appMemoryGB), color: Color.mbBlue)
            MBRow(icon: "circle.fill", label: "Wired",      value: String(format: "%.1f GB", systemMonitor.wiredMemoryGB), color: .pink)
            MBRow(icon: "circle.fill", label: "Compressed", value: String(format: "%.0f MB", systemMonitor.compressedMemoryGB * 1024), color: Color.mbOrange)
            MBRow(icon: "circle.fill", label: "Free",       value: String(format: "%.1f GB", systemMonitor.freeMemoryGB), color: Color.white.opacity(0.4))
        }
    }

    private var processesSection: some View {
        VStack(spacing: 0) {
            MBSectionHeader(title: "PROCESSES")
            let topProcesses = Array(systemMonitor.snapshot.topProcesses.topMemory.prefix(4))
            if privacySettings.processInsightsEnabled == false {
                MBRow(icon: "lock.shield", label: "Processes", value: "Private", color: Color.mbTint)
            } else if topProcesses.isEmpty {
                MBRow(icon: "app.fill", label: "Processes", value: "Unavailable", color: .white.opacity(0.5))
            } else {
                ForEach(Array(topProcesses.enumerated()), id: \.offset) { _, process in
                    memProcessRow(process.name, gb: process.memoryGB, color: memoryProcessColor(process.memoryBytes))
                }
            }
        }
    }

    private func memProcessRow(_ name: String, gb: Double, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "app.fill").font(.system(size: 10)).foregroundStyle(color.opacity(0.8)).frame(width: 14)
            Text(name).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.78))
            Spacer()
            Text(String(format: "%.1f GB", gb))
                .font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(color)
        }
        .padding(.horizontal, 14).padding(.vertical, 4)
    }

    private var pageSection: some View {
        VStack(spacing: 0) {
            MBRow(icon: "arrow.down.circle", label: "Page Ins",  value: formatByteCount(systemMonitor.pageInsBytes), color: .white.opacity(0.5))
            MBRow(icon: "arrow.up.circle",   label: "Page Outs", value: formatByteCount(systemMonitor.pageOutsBytes), color: .white.opacity(0.5))
        }
    }

    private var swapSection: some View {
        let swapRatio = systemMonitor.swapTotalBytes > 0
            ? min(1, CGFloat(Double(systemMonitor.swapUsedBytes) / Double(systemMonitor.swapTotalBytes)))
            : 0

        return VStack(alignment: .leading, spacing: 6) {
            MBSectionHeader(title: "SWAP")
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08)).frame(height: 6)
                    Capsule().fill(Color.mbBlue)
                        .frame(width: max(0, geo.size.width * swapRatio), height: 6)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, 14)
            HStack {
                Text("\(formatByteCount(systemMonitor.swapUsedBytes)) of \(systemMonitor.swapTotalBytes > 0 ? formatByteCount(systemMonitor.swapTotalBytes) : "0 B")")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.62))
                Spacer()
            }
            .padding(.horizontal, 14).padding(.bottom, 8)
        }
    }

    private var memColor: Color {
        switch systemMonitor.memoryPressure {
        case .green: return Color.mbGreen
        case .yellow: return Color.mbOrange
        case .red: return .red
        }
    }
    private var pressureColor: Color { memColor }
    private var pressureLabel: String {
        switch systemMonitor.memoryPressure {
        case .green:
            return "Normal"
        case .yellow:
            return "Elevated"
        case .red:
            return "Critical"
        }
    }
    private var freeMemoryPercent: Double {
        guard systemMonitor.totalMemoryGB > 0 else { return 0 }
        return min(max((systemMonitor.freeMemoryGB / systemMonitor.totalMemoryGB) * 100, 0), 100)
    }

    private func memoryProcessColor(_ memoryBytes: UInt64) -> Color {
        if memoryBytes > 2_000_000_000 {
            return .red
        }
        if memoryBytes > 1_000_000_000 {
            return Color.mbOrange
        }
        return Color.mbBlue
    }

    private func formatByteCount(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .binary
        formatter.includesUnit = true
        formatter.isAdaptive = false
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - ═══════════════════════════════════════════
// MARK: - Disk Popover View
// MARK: - ═══════════════════════════════════════════

struct DiskMenuPopoverView: View {
    @ObservedObject var systemMonitor: SystemMonitor
    @ObservedObject var alertManager: AlertManager
    @ObservedObject private var privacySettings = PrivacySettings.shared
    var openDashboardAction: () -> Void = {}

    var body: some View {
        MenuPopoverSurface {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    diskHeader
                    MBDivider()
                    MenuBarAlertSummarySection(systemMonitor: systemMonitor, alertManager: alertManager)
                    MBDivider()
                    diskDonutSection
                    MBDivider()
                    driveStatusSection
                    MBDivider()
                    processesSection
                    MBDivider()
                    MBActionButton(label: "Open Dashboard", icon: "gauge.medium") { openDashboardAction() }
                        .padding(.vertical, 4)
                }
            }
        }
        .preferredColorScheme(.dark)
        .frame(width: 320)
    }

    private var diskHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.mbBlue.opacity(0.15)).frame(width: 34, height: 34)
                Image(systemName: "internaldrive.fill")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.mbBlue)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Macintosh HD").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.92))
                Text(String(format: "%.1f GB available", systemMonitor.diskStats.freeGB))
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            if let ssdTemp = systemMonitor.ssdTemperature {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(ssdTemp.rounded()))°").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(Color.mbOrange)
                    Text("TEMP").font(.system(size: 8, weight: .bold)).foregroundStyle(.white.opacity(0.45)).mbTracking(0.8)
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    private var diskDonutSection: some View {
        HStack(spacing: 20) {
            DonutChart(
                used:      systemMonitor.diskStats.usedGB,
                purgeable: systemMonitor.diskStats.purgeableGB,
                free:      systemMonitor.diskStats.freeGB
            )
            VStack(alignment: .leading, spacing: 8) {
                diskLegendRow(color: Color.mbBlue, label: "Used",
                              value: String(format: "%.1f GB", systemMonitor.diskStats.usedGB))
                diskLegendRow(color: .pink, label: "Purgeable",
                              value: String(format: "%.1f GB", systemMonitor.diskStats.purgeableGB))
                diskLegendRow(color: Color.white.opacity(0.35), label: "Free",
                              value: String(format: "%.1f GB", systemMonitor.diskStats.freeGB))
                Divider().opacity(0.3)
                diskLegendRow(color: .white.opacity(0.6), label: "Total",
                              value: String(format: "%.1f GB", systemMonitor.diskStats.totalGB))
            }
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    private func diskLegendRow(color: Color, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.65))
            Spacer()
            Text(value).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(color)
        }
    }

    private var driveStatusSection: some View {
        VStack(spacing: 0) {
            MBSectionHeader(title: "DRIVE STATUS")
            MBRow(
                icon: "chart.pie.fill",
                label: "Used",
                value: String(format: "%.0f%%", systemMonitor.diskStats.usagePercent),
                color: systemMonitor.diskStats.usagePercent > 90 ? .red : systemMonitor.diskStats.usagePercent > 75 ? Color.mbOrange : Color.mbBlue
            )
            MBRow(icon: "internaldrive.fill", label: "Available",   value: String(format: "%.1f GB", systemMonitor.diskStats.freeGB), color: .white.opacity(0.72))
            MBRow(icon: "trash.slash.fill",   label: "Purgeable",   value: String(format: "%.1f GB", systemMonitor.diskStats.purgeableGB), color: .pink)
            MBRow(icon: "thermometer",        label: "Temperature", value: systemMonitor.ssdTemperature.map { "\(Int($0.rounded()))°C" } ?? "—", color: Color.mbOrange)
        }
    }

    private var processesSection: some View {
        VStack(spacing: 0) {
            MBSectionHeader(title: "PROCESS TOTALS  R / W")
            let topProcesses = privacySettings.processInsightsEnabled ? topDiskProcesses(limit: 4) : []
            if privacySettings.processInsightsEnabled == false {
                MBRow(icon: "lock.shield", label: "Processes", value: "Private", color: Color.mbTint)
            } else if topProcesses.isEmpty {
                MBRow(icon: "app.fill", label: "Processes", value: "Unavailable", color: .white.opacity(0.5))
            } else {
                ForEach(Array(topProcesses.enumerated()), id: \.offset) { _, process in
                    diskProcessRow(process.name, r: process.readLabel, w: process.writeLabel, color: process.color)
                }
            }
        }
    }

    private func diskProcessRow(_ name: String, r: String, w: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "app.fill").font(.system(size: 10)).foregroundStyle(color.opacity(0.8)).frame(width: 14)
            Text(name).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.78))
            Spacer()
            Text(r).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.pink).frame(width: 44, alignment: .trailing)
            Text(w).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(color).frame(width: 44, alignment: .trailing)
        }
        .padding(.horizontal, 14).padding(.vertical, 4)
    }

    private struct DiskProcess: Identifiable {
        let pid: pid_t
        let name: String
        let readBytes: UInt64
        let writtenBytes: UInt64

        var id: pid_t { pid }
        var totalBytes: UInt64 { readBytes + writtenBytes }
        var readLabel: String { Self.formatBytes(readBytes) }
        var writeLabel: String { Self.formatBytes(writtenBytes) }
        var color: Color { totalBytes > 250_000_000 ? .red : totalBytes > 100_000_000 ? Color.mbOrange : Color.mbBlue }

        private static func formatBytes(_ bytes: UInt64) -> String {
            switch bytes {
            case 0..<1024:
                return "\(bytes)B"
            case 1024..<1_048_576:
                return String(format: "%.0fK", Double(bytes) / 1024.0)
            case 1_048_576..<1_073_741_824:
                return String(format: "%.1fM", Double(bytes) / 1_048_576.0)
            default:
                return String(format: "%.1fG", Double(bytes) / 1_073_741_824.0)
            }
        }
    }

    private func topDiskProcesses(limit: Int) -> [DiskProcess] {
        let estimatedCount = Int(proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0))
        guard estimatedCount > 0 else { return [] }

        var pids = Array(repeating: pid_t(0), count: estimatedCount)
        let bytesWritten = pids.withUnsafeMutableBytes { buffer -> Int32 in
            guard let baseAddress = buffer.baseAddress else { return 0 }
            return proc_listpids(UInt32(PROC_ALL_PIDS), 0, baseAddress, Int32(buffer.count))
        }

        guard bytesWritten > 0 else { return [] }

        let actualCount = Int(bytesWritten) / MemoryLayout<pid_t>.stride
        let validPIDs = pids.prefix(actualCount).filter { $0 > 0 }
        var processes: [DiskProcess] = []

        for pid in validPIDs {
            let name = diskDisplayName(for: pid)

            var usage = rusage_info_current()
            let status = withUnsafeMutablePointer(to: &usage) { pointer -> Int32 in
                pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { rebounded in
                    proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, rebounded)
                }
            }

            guard status == 0 else { continue }
            processes.append(
                DiskProcess(
                    pid: pid,
                    name: name,
                    readBytes: usage.ri_diskio_bytesread,
                    writtenBytes: usage.ri_diskio_byteswritten
                )
            )
        }

        return processes
            .sorted { $0.totalBytes > $1.totalBytes }
            .prefix(limit)
            .map { $0 }
    }

    private func diskDisplayName(for pid: pid_t) -> String {
        if let runningApp = NSRunningApplication(processIdentifier: pid) {
            let localizedName = runningApp.localizedName ?? ""
            if !localizedName.isEmpty {
                return localizedName
            }
        }

        var nameBuffer = [CChar](repeating: 0, count: Int(MAXCOMLEN) + 1)
        let procNameLength = proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
        if procNameLength > 0 {
            let name = String(cString: nameBuffer).trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                return name
            }
        }

        var pathBuffer = [CChar](repeating: 0, count: kProcPidPathMaxSize)
        let pathLength = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
        if pathLength > 0 {
            let path = String(cString: pathBuffer)
            let lastPathComponent = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            if !lastPathComponent.isEmpty {
                return lastPathComponent
            }
        }

        return "PID \(pid)"
    }
}

// MARK: - ═══════════════════════════════════════════
// MARK: - Temperature Popover View
// MARK: - ═══════════════════════════════════════════

struct TemperatureMenuPopoverView: View {
    @ObservedObject var systemMonitor: SystemMonitor
    @ObservedObject var fanController: FanController
    @ObservedObject var alertManager: AlertManager
    var openDashboardAction: () -> Void = {}

    var body: some View {
        MenuPopoverSurface {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    tempHeader
                    MBDivider()
                    MenuBarAlertSummarySection(systemMonitor: systemMonitor, alertManager: alertManager)
                    MBDivider()
                    temperatureSection
                    MBDivider()
                    powerSection
                    MBDivider()
                    fanSection
                    MBDivider()
                    frequencySection
                    MBDivider()
                    MBActionButton(label: "Open Dashboard", icon: "gauge.medium") { openDashboardAction() }
                        .padding(.vertical, 4)
                }
            }
        }
        .preferredColorScheme(.dark)
        .frame(width: 320)
    }

    private var tempHeader: some View {
        HStack(spacing: 16) {
            // CPU ring
            tempCircle(
                value:  systemMonitor.cpuTemperature ?? 0,
                label:  "CPU",
                range:  0...110,
                color:  cpuTempColor
            )
            // GPU ring
            tempCircle(
                value:  systemMonitor.gpuTemperature ?? 0,
                label:  "GPU",
                range:  0...110,
                color:  gpuTempColor
            )
            // Fan
            VStack(spacing: 6) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.12), lineWidth: 5)
                        .frame(width: 44, height: 44)
                    Image(systemName: systemMonitor.fanSpeeds.first.map { $0 > 0 ? "fanblades.fill" : "fanblades" } ?? "fanblades")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(systemMonitor.fanSpeeds.first.map { $0 > 0 ? Color.mbGreen : Color.white.opacity(0.4) } ?? Color.white.opacity(0.4))
                }
                Text("FANS")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45)).mbTracking(0.5)
                Text(systemMonitor.fanSpeeds.first.map { $0 > 0 ? "\($0)" : "OFF" } ?? "OFF")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(systemMonitor.fanSpeeds.first.map { $0 > 0 ? Color.mbGreen : Color.white.opacity(0.4) } ?? Color.white.opacity(0.4))
            }
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 14)
    }

    private func tempCircle(value: Double, label: String, range: ClosedRange<Double>, color: Color) -> some View {
        let fraction = range.upperBound > 0 ? min(value, range.upperBound) / range.upperBound : 0
        return VStack(spacing: 4) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.12), lineWidth: 5)
                Circle().trim(from: 0, to: fraction)
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 1) {
                    Text("\(Int(value.rounded()))°")
                        .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(color)
                }
            }
            .frame(width: 52, height: 52)
            Text(label).font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.55)).mbTracking(0.5)
        }
    }

    private var temperatureSection: some View {
        VStack(spacing: 0) {
            MBSectionHeader(title: "TEMPERATURE")
            if let batt = systemMonitor.batteryInfo.temperatureC {
                tempRow("Battery",                  value: batt,  icon: "battery.75")
            }
            if let t = systemMonitor.cpuTemperature {
                tempRow("CPU Package",              value: t,     icon: "cpu.fill")
            }
            if let gt = systemMonitor.gpuTemperature {
                tempRow("Graphics",                 value: gt,    icon: "display")
            }
            if let st = systemMonitor.ssdTemperature {
                tempRow("SSD",                      value: st,    icon: "internaldrive.fill")
            }
            if systemMonitor.cpuTemperature == nil && systemMonitor.gpuTemperature == nil && systemMonitor.batteryInfo.temperatureC == nil {
                MBRow(icon: "thermometer.slash", label: "Sensors", value: "No SMC access", color: .white.opacity(0.4))
            }
        }
    }

    private func tempRow(_ label: String, value: Double, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 10, weight: .medium))
                .foregroundStyle(tempColor(value).opacity(0.85)).frame(width: 16)
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.72))
            Spacer()
            Text("\(Int(value.rounded()))°")
                .font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(tempColor(value))
            Circle().fill(tempColor(value)).frame(width: 8, height: 8)
        }
        .padding(.horizontal, 14).padding(.vertical, 4)
    }

    private var powerSection: some View {
        VStack(spacing: 0) {
            MBSectionHeader(title: "POWER")
            if let cpuW = systemMonitor.cpuPowerWatts {
                MBRow(icon: "cpu.fill",   label: "CPU",      value: String(format: "%.0f mW", cpuW * 1000), color: Color.mbBlue)
            }
            if let gpuW = systemMonitor.gpuPowerWatts {
                MBRow(icon: "display",   label: "Graphics", value: String(format: "%.0f mW", gpuW * 1000), color: Color.mbPurple)
            }
            if let sysW = systemMonitor.totalSystemWatts {
                MBRow(icon: "bolt.fill", label: "Total",    value: String(format: "%.1f W", abs(sysW)),     color: Color.mbGreen)
            }
            if systemMonitor.cpuPowerWatts == nil && systemMonitor.gpuPowerWatts == nil && systemMonitor.totalSystemWatts == nil {
                MBRow(icon: "bolt.slash", label: "Power", value: "No data", color: .white.opacity(0.4))
            }
        }
    }

    private var fanSection: some View {
        VStack(spacing: 0) {
            MBSectionHeader(title: "FANS")
            if systemMonitor.fanSpeeds.isEmpty {
                MBRow(icon: "fanblades", label: "Fan", value: "Off", color: .white.opacity(0.4))
            } else {
                ForEach(systemMonitor.fanSpeeds.indices, id: \.self) { i in
                    let rpm = systemMonitor.fanSpeeds[i]
                    MBRow(icon: "fanblades.fill",
                          label: "Fan \(i + 1)",
                          value: rpm > 0 ? "\(rpm) RPM" : "Off",
                          color: rpm > 0 ? Color.mbGreen : .white.opacity(0.4))
                }
            }
        }
    }

    private var frequencySection: some View {
        VStack(spacing: 0) {
            MBSectionHeader(title: "CORE LAYOUT")
            MBRow(icon: "cpu.fill",    label: "P-Cores",    value: "\(SystemMonitor.performanceCoreCount()) cores", color: Color.mbBlue)
            MBRow(icon: "leaf.fill",   label: "E-Cores",    value: "\(SystemMonitor.efficiencyCoreCount()) cores", color: Color.mbGreen)
        }
    }

    private var cpuTempColor: Color { tempColor(systemMonitor.cpuTemperature ?? 0) }
    private var gpuTempColor: Color { tempColor(systemMonitor.gpuTemperature ?? 0) }
    private func tempColor(_ t: Double) -> Color { t > 90 ? .red : t > 70 ? Color.mbOrange : Color.mbGreen }
}

// MARK: - ═══════════════════════════════════════════
// MARK: - Legacy overview popover (kept for compatibility)
// MARK: - ═══════════════════════════════════════════

struct MenuBarStatusLabel: View {
    @ObservedObject var systemMonitor: SystemMonitor
    @State private var angle: Double = 0

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "fanblades.fill")
                .symbolRenderingMode(.monochrome)
                .imageScale(.small)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(fanColor)
                .frame(width: 12, height: 12, alignment: .center)
                .fixedSize()
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

struct MenuBarMenuView: View {
    @ObservedObject var systemMonitor: SystemMonitor
    @ObservedObject var fanController: FanController
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
            statusPill(dot: systemMonitor.hasSMCAccess ? .green : .red,
                       label: systemMonitor.hasSMCAccess ? "SMC OK" : "No SMC",
                       tint: nil)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Color.white.opacity(0.025))
    }

    private var metricsSection: some View {
        VStack(spacing: 0) {
            metricRow(icon: "thermometer.medium", label: "CPU Temp",
                      value: systemMonitor.cpuTemperature.map { "\(Int($0.rounded()))°C" } ?? "—",
                      color: tempColor(systemMonitor.cpuTemperature))
            metricRow(icon: "cpu.fill", label: "CPU Load",
                      value: "\(Int(systemMonitor.cpuUsagePercent.rounded()))%",
                      color: loadColor(systemMonitor.cpuUsagePercent))
            if let pUsage = systemMonitor.performanceCoreUsagePercent {
                metricRow(icon: "bolt.fill", label: "P-Cores",
                          value: "\(Int(pUsage.rounded()))% / \(SystemMonitor.performanceCoreCount())",
                          color: loadColor(pUsage))
            }
            if let eUsage = systemMonitor.efficiencyCoreUsagePercent {
                metricRow(icon: "leaf.fill", label: "E-Cores",
                          value: "\(Int(eUsage.rounded()))% / \(SystemMonitor.efficiencyCoreCount())",
                          color: loadColor(eUsage))
            }
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
            metricRow(icon: systemMonitor.currentVolume < 0.01 ? "speaker.slash.fill" : "speaker.wave.2.fill",
                      label: "Volume", value: "\(Int((systemMonitor.currentVolume * 100).rounded()))%", color: .yellow)
            metricRow(icon: "sun.max.fill", label: "Brightness",
                      value: "\(Int((systemMonitor.currentBrightness * 100).rounded()))%", color: Color.mbAccent)
        }
        .padding(.vertical, 4)
    }

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

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            actionRow("Open Dashboard",             icon: "gauge.medium")     { openDashboardAction() }
            actionRow("Reset Fan to System Auto",   icon: "arrow.counterclockwise") { fanController.resetToSystemAutomatic() }
            actionRow("Restore App Touch Bar",      icon: "rectangle.on.rectangle") { restoreAppTouchBarAction() }
            actionRow("Revert to System Touch Bar", icon: "rectangle.3.group") { revertTouchBarAction() }
            mbDivider.padding(.horizontal, 14).padding(.vertical, 2)

            Button(action: { NSApp.terminate(nil) }) {
                HStack(spacing: 10) {
                    Image(systemName: "power")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(width: 18)
                    Text("Quit Core Monitor")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color.red.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.red.opacity(0.18), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.top, 6)

            Text("Hardware readings stay on your Mac. Weather and exported support reports stay opt in.")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.top, 8)
        }
        .padding(.vertical, 4)
    }

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
        MBLegacyActionButton(label: label, icon: icon, tint: tint, action: action)
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

    private func tempColor(_ t: Double?) -> Color {
        guard let t else { return .secondary }; return t > 90 ? .red : t > 70 ? .orange : .green
    }
    private func loadColor(_ l: Double) -> Color { l > 80 ? .red : l > 50 ? .orange : Color.mbAccent }
}

private struct MBLegacyActionButton: View {
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

 
