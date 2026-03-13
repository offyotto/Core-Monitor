import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var systemMonitor: SystemMonitor
    @ObservedObject var fanController: FanController

    @StateObject private var startupManager = StartupManager()
    @StateObject private var coreVisorManager = CoreVisorManager()
    @StateObject private var smcHelperManager = SMCHelperManager.shared
    @AppStorage("didCompleteStartupGuide") private var didCompleteStartupGuide = false
    @AppStorage("didOpenCoreVisorSetup") private var didOpenCoreVisorSetup = false

    @State private var reveal = false
    @State private var showStartupGuide = false
    @State private var showCoreVisorSetup = false

    private var fanSpeed: Int { systemMonitor.fanSpeeds.first ?? 0 }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                topBar
                    .panelReveal(index: 0, active: reveal)

                HStack(alignment: .top, spacing: 10) {
                    leftColumn
                        .frame(width: 248)
                        .panelReveal(index: 1, active: reveal)

                    rightColumn
                        .panelReveal(index: 2, active: reveal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(12)

            if showStartupGuide {
                startupGuideOverlay
            }
        }
        .onAppear {
            reveal = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first?.makeKeyAndOrderFront(nil)
            }
            if !didCompleteStartupGuide {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                    showStartupGuide = true
                }
            }
            coreVisorManager.refreshEntitlementStatus()
        }
        .sheet(isPresented: $showCoreVisorSetup) {
            CoreVisorSetupView(manager: coreVisorManager, hasOpenedCoreVisorSetup: $didOpenCoreVisorSetup)
        }
    }

    private var topBar: some View {
        HStack {
            Label("Core Monitor", systemImage: "waveform.path.ecg")
                .font(.system(size: 15, weight: .semibold))

            Spacer()

            Button("CoreVisor") {
                showCoreVisorSetup = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("Setup Guide") {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                    showStartupGuide = true
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .compactPanel()
    }

    private var leftColumn: some View {
        VStack(spacing: 8) {
            metricTile("CPU Temp", value: cpuTempText, index: 3)
            metricTile("CPU Load", value: String(format: "%.0f%%", systemMonitor.cpuUsagePercent), index: 4)
            metricTile("System Power", value: wattsText, index: 5)
            metricTile("Fan Speed", value: "\(fanSpeed) RPM", index: 6)

            VStack(alignment: .leading, spacing: 7) {
                Text("Startup")
                    .font(.system(size: 11, weight: .semibold))

                Toggle("Launch at login", isOn: Binding(
                    get: { startupManager.isEnabled },
                    set: { startupManager.setEnabled($0) }
                ))
                .toggleStyle(.switch)

                if let error = startupManager.errorMessage {
                    Text(error)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
            .compactPanel()
            .panelReveal(index: 7, active: reveal)
        }
    }

    private var rightColumn: some View {
        VStack(spacing: 8) {
            fanPanel
                .panelReveal(index: 8, active: reveal)

            if systemMonitor.batteryInfo.hasBattery {
                batteryPanel
                    .panelReveal(index: 9, active: reveal)
            }
        }
    }

    private var fanPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Cooling")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(fanController.mode == .manual ? "Manual" : "Auto")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 8)
                        .frame(width: 88, height: 88)

                    Circle()
                        .trim(from: 0, to: fanPercent)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 88, height: 88)

                    Text("\(Int((fanPercent * 100).rounded()))%")
                        .font(.system(size: 15, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("\(fanSpeed) RPM")
                        .font(.system(size: 28, weight: .bold, design: .rounded))

                    Picker("Mode", selection: Binding(
                        get: { fanController.mode },
                        set: { fanController.setMode($0) }
                    )) {
                        Text("Manual").tag(FanControlMode.manual)
                        Text("Auto").tag(FanControlMode.automatic)
                    }
                    .pickerStyle(.segmented)
                }
            }

            Slider(value: Binding(
                get: { Double(fanController.manualSpeed) },
                set: { fanController.setManualSpeed(Int($0)) }
            ), in: Double(fanController.minSpeed)...Double(fanController.maxSpeed), step: 50)
            .disabled(fanController.mode != .manual)

            HStack {
                Text("\(fanController.minSpeed)")
                Spacer()
                Text("Target \(fanController.manualSpeed)")
                Spacer()
                Text("\(fanController.maxSpeed)")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Auto Aggressiveness")
                    Spacer()
                    Text(String(format: "%.1fx", fanController.autoAggressiveness))
                        .monospacedDigit()
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

                Slider(value: Binding(
                    get: { fanController.autoAggressiveness },
                    set: { fanController.setAutoAggressiveness($0) }
                ), in: 0.0...3.0, step: 0.1)
                .disabled(fanController.mode != .automatic)
            }

            Button("Return Control To System") {
                fanController.resetToSystemAutomatic()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(10)
        .compactPanel()
    }

    private var batteryPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Power / Battery")
                .font(.system(size: 13, weight: .semibold))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                kv("Charge", "\(systemMonitor.batteryInfo.chargePercent ?? 0)%")
                kv("Health", systemMonitor.batteryInfo.healthPercent.map { "\($0)%" } ?? "--")
                kv("Cycles", systemMonitor.batteryInfo.cycleCount.map { "\($0)" } ?? "--")
                kv("Status", systemMonitor.batteryInfo.status ?? "--")
                kv("Power", wattsText)
                kv("Source", systemMonitor.batteryInfo.isPluggedIn ? "AC" : "Battery")
                kv("Temp", systemMonitor.batteryInfo.temperatureC.map { String(format: "%.1f C", $0) } ?? "--")
                kv("Voltage", systemMonitor.batteryInfo.voltageV.map { String(format: "%.2f V", $0) } ?? "--")
                kv("Remaining", timeRemainingText)
            }
        }
        .padding(10)
        .compactPanel()
    }

    private var startupGuideOverlay: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                        showStartupGuide = false
                    }
                }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("All-in-One Startup Guide")
                            .font(.system(size: 18, weight: .bold))
                        Text("Complete monitor, permissions, and CoreVisor runtime setup.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(completedStepCount)/\(guideSteps.count)")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .compactPill()
                }

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(guideSteps.enumerated()), id: \.element.id) { index, step in
                            StartupGuideStepRow(step: step)
                                .panelReveal(index: index + 1, active: reveal)
                        }
                    }
                }
                .frame(maxHeight: 360)

                HStack {
                    Button("Later") {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                            showStartupGuide = false
                        }
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Mark Complete") {
                        didCompleteStartupGuide = true
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                            showStartupGuide = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(16)
            .frame(width: 700)
            .compactPanel()
            .panelReveal(index: 0, active: showStartupGuide)
        }
        .transition(.opacity)
        .animation(.spring(response: 0.46, dampingFraction: 0.88), value: showStartupGuide)
    }

    private var guideSteps: [StartupGuideStep] {
        let hasApprovalIssue = (startupManager.errorMessage ?? "").localizedCaseInsensitiveContains("approval")
        return [
            StartupGuideStep(
                id: 1,
                title: "Allow login item in System Settings",
                detail: "Open Login Items and approve Core Monitor when macOS asks.",
                isComplete: !hasApprovalIssue,
                actionTitle: "Open Settings",
                action: openLoginItemsSettings
            ),
            StartupGuideStep(
                id: 2,
                title: "Enable launch at login",
                detail: "Turn on startup so fan control and Touch Bar widgets are ready immediately.",
                isComplete: startupManager.isEnabled,
                actionTitle: "Enable",
                action: { startupManager.setEnabled(true) }
            ),
            StartupGuideStep(
                id: 3,
                title: "Install SMC helper (SMJobBless)",
                detail: "Install privileged helper so fan control works with sandbox restrictions.",
                isComplete: smcHelperManager.isInstalled,
                actionTitle: "Install Helper",
                action: { smcHelperManager.installViaSMJobBless() }
            ),
            StartupGuideStep(
                id: 4,
                title: "Verify SMC and sensor access",
                detail: "CPU temp and fan data should show live values instead of --.",
                isComplete: systemMonitor.hasSMCAccess && systemMonitor.cpuTemperature != nil,
                actionTitle: "Retry",
                action: { systemMonitor.startMonitoring() }
            ),
            StartupGuideStep(
                id: 5,
                title: "Open CoreVisor setup",
                detail: "Initialize VM templates and detect QEMU devices for virtualization workflows.",
                isComplete: didOpenCoreVisorSetup,
                actionTitle: "Open CoreVisor",
                action: { showCoreVisorSetup = true }
            ),
            StartupGuideStep(
                id: 6,
                title: "Install QEMU runtime",
                detail: "Install qemu (qemu-system + qemu-img) to run Windows/NetBSD/UNIX VMs and USB passthrough.",
                isComplete: coreVisorManager.qemuBinaryPath != nil,
                actionTitle: "Recheck",
                action: { Task { await coreVisorManager.refreshRuntimeData() } }
            ),
            StartupGuideStep(
                id: 7,
                title: "Create your first VM",
                detail: "Use CoreVisor setup wizard Review step and press Create VM.",
                isComplete: !coreVisorManager.machines.isEmpty,
                actionTitle: "Open CoreVisor",
                action: { showCoreVisorSetup = true }
            ),
            StartupGuideStep(
                id: 8,
                title: "Start one VM and verify logs",
                detail: "Start from sidebar and confirm runtime log is updating.",
                isComplete: coreVisorManager.machines.contains { coreVisorManager.runtimeState(for: $0) == .running || !coreVisorManager.runtimeLog(for: $0).isEmpty },
                actionTitle: "Open CoreVisor",
                action: { showCoreVisorSetup = true }
            ),
            StartupGuideStep(
                id: 9,
                title: "Confirm Touch Bar stream",
                detail: "Touch Bar should display CPU, memory pressure, fan RPM, and sparklines.",
                isComplete: systemMonitor.cpuUsagePercent > 0,
                actionTitle: nil,
                action: nil
            )
        ]
    }

    private var completedStepCount: Int {
        guideSteps.filter(\.isComplete).count
    }

    private func openLoginItemsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        } else if let fallback = URL(string: "x-apple.systempreferences:") {
            NSWorkspace.shared.open(fallback)
        }
    }

    private func metricTile(_ title: String, value: String, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .compactPanel()
        .panelReveal(index: index, active: reveal)
    }

    private func kv(_ key: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(key)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fanPercent: Double {
        let span = max(1, fanController.maxSpeed - fanController.minSpeed)
        return max(0.0, min(1.0, Double(fanSpeed - fanController.minSpeed) / Double(span)))
    }

    private var cpuTempText: String {
        systemMonitor.cpuTemperature.map { String(format: "%.0f C", $0) } ?? "--"
    }

    private var wattsText: String {
        systemMonitor.totalSystemWatts.map { String(format: "%.1f W", $0) } ?? "--"
    }

    private var timeRemainingText: String {
        guard let minutes = systemMonitor.batteryInfo.timeRemainingMinutes, minutes >= 0 else { return "--" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

private struct StartupGuideStep: Identifiable {
    let id: Int
    let title: String
    let detail: String
    let isComplete: Bool
    let actionTitle: String?
    let action: (() -> Void)?
}

private struct StartupGuideStepRow: View {
    let step: StartupGuideStep

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: step.isComplete ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(step.isComplete ? .green : .secondary)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.system(size: 13, weight: .semibold))
                Text(step.detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if let actionTitle = step.actionTitle, let action = step.action {
                Button(actionTitle) {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .compactPanel()
    }
}

private struct CompactPanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private extension View {
    func compactPanel() -> some View {
        modifier(CompactPanelModifier())
    }

    func compactPill() -> some View {
        background(.regularMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }
}

private struct ContentViewPreviewHost: View {
    @StateObject private var app = AppCoordinator()

    var body: some View {
        ContentView(systemMonitor: app.systemMonitor, fanController: app.fanController)
    }
}

#Preview {
    ContentViewPreviewHost()
}
