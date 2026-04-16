// WelcomeGuide.swift
// Core Monitor — first-launch onboarding guide
// Shown exactly once (keyed by AppStorage). No motion blur.

import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - View modifier entry-point
// ─────────────────────────────────────────────────────────────────────────────

extension View {
    /// Attaches the first-launch guide sheet. Call once on the root view.
    func welcomeGuide() -> some View {
        modifier(WelcomeGuideModifier())
    }
}

private struct WelcomeGuideModifier: ViewModifier {
    @AppStorage(WelcomeGuideProgress.hasSeenDefaultsKey) private var hasSeen = false
    @State private var presentation = WelcomeGuidePresentationController()

    func body(content: Content) -> some View {
        content
            .onAppear {
                presentation.syncStoredPreference(hasSeen: hasSeen)
            }
            .onChange(of: hasSeen) {
                presentation.syncStoredPreference(hasSeen: $0)
            }
            .sheet(isPresented: Binding(
                get: { presentation.isSheetPresented },
                set: { isPresented in
                    let dismissAction = presentation.handlePresentationChange(isPresented)
                    if dismissAction == .persistCompletion, hasSeen == false {
                        hasSeen = true
                    }
                }
            )) {
                WelcomeGuideSheet { hasSeen = true }
                    .interactiveDismissDisabled(true)
            }
    }
}

enum WelcomeGuideDismissAction: Equatable {
    case none
    case persistCompletion
}

struct WelcomeGuidePresentationController: Equatable {
    private(set) var didCompleteGuide = false
    private(set) var isSheetPresented = true

    init(hasSeen: Bool = false) {
        syncStoredPreference(hasSeen: hasSeen)
    }

    mutating func syncStoredPreference(hasSeen: Bool) {
        didCompleteGuide = hasSeen
        isSheetPresented = !hasSeen
    }

    mutating func handlePresentationChange(_ isPresented: Bool) -> WelcomeGuideDismissAction {
        if isPresented {
            isSheetPresented = true
            return .none
        }

        if didCompleteGuide {
            isSheetPresented = false
            return .persistCompletion
        }

        // SwiftUI can transiently dismiss the sheet while the first-launch
        // window is still being promoted. Keep the guide pending until the user
        // explicitly completes it.
        isSheetPresented = true
        return .none
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Design tokens (guide-local)
// ─────────────────────────────────────────────────────────────────────────────

private extension Color {
    static let wgBackground = Color(red: 0.055, green: 0.055, blue: 0.068)
    static let wgSurface    = Color(red: 0.10,  green: 0.10,  blue: 0.13)
    static let wgBorder     = Color(white: 1, opacity: 0.08)
    static let wgAmber      = Color(red: 1.0,  green: 0.72, blue: 0.18)
    static let wgGreen      = Color(red: 0.22, green: 0.92, blue: 0.55)
    static let wgBlue       = Color(red: 0.35, green: 0.72, blue: 1.0)
    static let wgPurple     = Color(red: 0.72, green: 0.40, blue: 1.0)
    static let wgRed        = Color(red: 1.0,  green: 0.34, blue: 0.34)
    static let wgText       = Color(white: 0.93)
    static let wgTextSub    = Color(white: 0.50)
    static let wgTextDim    = Color(white: 0.30)
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Step model
// ─────────────────────────────────────────────────────────────────────────────

private struct GuideStep: Identifiable {
    let id: Int
    let icon: String
    let iconColor: Color
    let headline: String
    let subheadline: String
    let body: String
    let bullets: [(icon: String, color: Color, text: String)]
}

private let guideSteps: [GuideStep] = [
    GuideStep(
        id: 0,
        icon: "cpu",
        iconColor: .wgAmber,
        headline: "Welcome to Core Monitor",
        subheadline: "Your M-series Mac, fully visible.",
        body: "Core Monitor gives you deep, real-time insight into your Apple Silicon Mac: thermals, memory pressure, fan behavior, power draw, and a customizable Touch Bar surface.",
        bullets: [
            ("thermometer.medium",    .wgAmber,  "Live CPU, GPU & memory readings"),
            ("fan.fill",              .wgBlue,   "Intelligent fan speed control"),
            ("rectangle.on.rectangle", .wgGreen, "Configurable Touch Bar widgets"),
            ("bolt.fill",             .wgPurple, "Power, battery, brightness and system controls"),
        ]
    ),
    GuideStep(
        id: 1,
        icon: "thermometer.medium",
        iconColor: .wgAmber,
        headline: "Thermals & Metrics",
        subheadline: "See what's really heating up.",
        body: "The dashboard streams CPU, GPU, and memory data at 1-second resolution. Spark-line histories let you spot transient spikes that Activity Monitor smooths over, and the Alerts screen turns those readings into actual warning rules.",
        bullets: [
            ("cpu.fill",              .wgAmber,  "P-core and E-core usage, plus CPU temperature"),
            ("memorychip",            .wgBlue,   "Memory pressure with wired/active breakdown"),
            ("chart.line.uptrend.xyaxis", .wgGreen, "60-second rolling history graphs"),
            ("thermometer.medium",    .wgRed,    "Live CPU, GPU, SSD, and battery temperatures when available"),
        ]
    ),
    GuideStep(
        id: 2,
        icon: "fan.fill",
        iconColor: .wgBlue,
        headline: "Fan Control",
        subheadline: "Quiet when idle. Aggressive when it counts.",
        body: "The fan controller supports Smart, Silent, Balanced, Performance, Max, Manual, and System Auto modes. It can re-apply active profiles after wake and sends write commands through the blessed helper.",
        bullets: [
            ("bolt.fill",             .wgAmber,  "Smart mode ramps earlier under sustained load"),
            ("fanblades.fill",        .wgBlue,   "Balanced / Performance / Max quick profiles"),
            ("arrow.clockwise",       .wgPurple, "Wake re-apply for active fan profiles"),
            ("lock.shield.fill",      .wgGreen,  "Helper install uses the macOS authorization sheet"),
        ]
    ),
    GuideStep(
        id: 3,
        icon: "display.2",
        iconColor: .wgPurple,
        headline: "Touch Bar",
        subheadline: "OLED space should look intentional.",
        body: "Core Monitor can replace the system Touch Bar with a full-width widget strip, including clocks, weather, network, combined stats, and hardware glyphs.",
        bullets: [
            ("rectangle.on.rectangle", .wgGreen, "Light and dark widget themes"),
            ("rectangle.3.group",     .wgBlue,   "Reorder or disable widgets in-app"),
            ("cloud.sun.rain.fill",   .wgAmber,  "Weather uses Apple's WeatherKit path"),
            ("location.fill",         .wgGreen,  "Allow location for accurate weather"),
            ("hand.tap",              .wgPurple, "On MacBook Touch Bar models, tap Weather for rain details"),
            ("wrench.and.screwdriver", .wgPurple, "Touch Bar presentation stays isolated"),
        ]
    ),
    GuideStep(
        id: 4,
        icon: "checkmark.seal.fill",
        iconColor: .wgGreen,
        headline: "You're all set.",
        subheadline: "Dive in whenever you're ready.",
        body: "Core Monitor starts reading hardware state on your Mac immediately. Hardware data stays local. Weather and support exports remain optional. Use the checklist below to confirm menu bar access, enable relaunch at login if you want persistent monitoring, and install the helper only if you want privileged fan control.",
        bullets: [
            ("sidebar.left",          .wgAmber,  "Dashboard sections collapse with a click"),
            ("bell.badge",            .wgGreen,  "Alerts combines local history, presets, and notification controls"),
            ("menubar.rectangle",     .wgBlue,   "Balanced menu bar mode keeps the app visible without adding clutter"),
            ("lock.shield",           .wgPurple, "Monitoring works without the helper; only fan writes need it"),
            ("hand.raised",           .wgAmber,  "Privacy Controls can keep alert history free of app names"),
            ("questionmark.circle",   .wgGreen,  "The Help tab can reopen this guide any time"),
        ]
    ),
]

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Sheet root
// ─────────────────────────────────────────────────────────────────────────────

private struct WelcomeGuideSheet: View {
    let onDismiss: () -> Void

    @StateObject private var startupManager = StartupManager()
    @ObservedObject private var helperManager = SMCHelperManager.shared
    @ObservedObject private var menuBarSettings = MenuBarSettings.shared

    @State private var currentStep   = 0
    @State private var stepVisible   = false     // drives per-step fade
    @State private var sheetVisible  = false     // drives initial sheet fade-in
    @State private var headerGlow    = false     // ambient pulse on icon
    @State private var progressPulse = false     // subtle dot pulse
    @State private var diagnosticsExportMessage: String?

    var body: some View {
        ZStack {
            // ── Background ──────────────────────────────────────────────────
            Color.wgBackground.ignoresSafeArea()
            noiseOverlay
            ambientGradient

            // ── Content ─────────────────────────────────────────────────────
            VStack(spacing: 0) {
                stepContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()
                    .background(Color.wgBorder)

                WelcomeGuideBottomBar(
                    steps: guideSteps,
                    currentStep: currentStep,
                    progressPulse: progressPulse,
                    accentColor: guideSteps[currentStep].iconColor,
                    goBack: goBack,
                    continueForward: advanceOrDismiss
                )
            }
        }
        .frame(width: 660, height: 520)
        .preferredColorScheme(.dark)
        .opacity(sheetVisible ? 1 : 0)
        .scaleEffect(sheetVisible ? 1 : 0.96)
        .onAppear(perform: prepareSheet)
    }

    // ── Step content ─────────────────────────────────────────────────────────

    private var stepContent: some View {
        let step = guideSteps[currentStep]
        return WelcomeGuideStepContent(
            step: step,
            stepVisible: stepVisible,
            usesCompactFeatureGrid: currentStep == guideSteps.count - 1,
            badge: { iconBadge(for: step) }
        ) {
            if currentStep == guideSteps.count - 1 {
                WelcomeGuideReadinessPanel(
                    menuBarStatus: menuBarStatus,
                    loginStatus: loginStatus,
                    helperStatus: helperStatus,
                    installHelper: installHelperIfNeeded,
                    enableLaunchAtLogin: enableLaunchAtLogin,
                    applyBalancedPreset: applyBalancedPreset,
                    refreshHelperDiagnostics: refreshHelperDiagnostics,
                    exportHelperDiagnostics: exportHelperDiagnostics,
                    diagnosticsExportMessage: diagnosticsExportMessage
                )
                .padding(.top, 12)
            }
        }
    }

    private func iconBadge(for step: GuideStep) -> some View {
        ZStack {
            // Outer glow ring — opacity animates, no blur
            Circle()
                .stroke(step.iconColor.opacity(headerGlow ? 0.25 : 0.08), lineWidth: 1.5)
                .frame(width: 80, height: 80)
                .scaleEffect(headerGlow ? 1.08 : 1.0)
                .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: headerGlow)

            // Mid ring
            Circle()
                .stroke(step.iconColor.opacity(0.18), lineWidth: 1)
                .frame(width: 64, height: 64)

            // Fill background
            Circle()
                .fill(step.iconColor.opacity(0.12))
                .frame(width: 56, height: 56)

            Image(systemName: step.icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(step.iconColor)
        }
    }

    // ── Decorative backgrounds ─────────────────────────────────────────────────

    private var ambientGradient: some View {
        ZStack {
            // Top-left orb
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [guideSteps[currentStep].iconColor.opacity(0.10), .clear],
                        center: .center, startRadius: 0, endRadius: 200
                    )
                )
                .frame(width: 380, height: 300)
                .offset(x: -160, y: -130)
                .animation(.easeInOut(duration: 0.55), value: currentStep)

            // Bottom-right orb
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.wgPurple.opacity(0.07), .clear],
                        center: .center, startRadius: 0, endRadius: 160
                    )
                )
                .frame(width: 300, height: 260)
                .offset(x: 180, y: 160)

            // Horizontal scan line accent (purely decorative, static)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, guideSteps[currentStep].iconColor.opacity(0.04), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .offset(y: -60)
                .animation(.easeInOut(duration: 0.55), value: currentStep)
        }
        .allowsHitTesting(false)
    }

    /// Subtle static noise texture via a symbol-less overlay
    private var noiseOverlay: some View {
        Canvas { context, size in
            var rng = WGRandom(seed: 0x4A3F)
            for _ in 0..<4000 {
                let x = CGFloat(rng.next() % UInt64(size.width))
                let y = CGFloat(rng.next() % UInt64(size.height))
                let alpha = Double(rng.next() % 18) / 1000.0
                context.fill(
                    Path(CGRect(x: x, y: y, width: 1, height: 1)),
                    with: .color(.white.opacity(alpha))
                )
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    // ── Navigation helper ─────────────────────────────────────────────────────

    private func transition(to index: Int) {
        withAnimation(.easeIn(duration: 0.16)) { stepVisible = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            currentStep = index
            withAnimation(.easeOut(duration: 0.28)) { stepVisible = true }
        }
    }

    private func prepareSheet() {
        currentStep = 0
        stepVisible = false
        sheetVisible = false
        headerGlow = false
        progressPulse = false
        diagnosticsExportMessage = nil

        startupManager.refreshState()
        refreshHelperDiagnostics()

        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
            sheetVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(.easeOut(duration: 0.35)) { stepVisible = true }
        }
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            headerGlow = true
        }
        withAnimation(.easeInOut(duration: 1.2).delay(0.6).repeatForever(autoreverses: true)) {
            progressPulse = true
        }
    }

    private func goBack() {
        guard currentStep > 0 else { return }
        transition(to: currentStep - 1)
    }

    private func advanceOrDismiss() {
        if currentStep < guideSteps.count - 1 {
            transition(to: currentStep + 1)
            return
        }
        dismissSheet()
    }

    private func dismissSheet() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.80)) {
            sheetVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onDismiss()
        }
    }

    private func enableLaunchAtLogin() {
        startupManager.setEnabled(true)
        startupManager.refreshState()
    }

    private func installHelperIfNeeded() {
        helperManager.installFromApp()
    }

    private func applyBalancedPreset() {
        menuBarSettings.applyPreset(.balanced)
    }

    private func refreshHelperDiagnostics() {
        helperManager.refreshStatus()
        helperManager.refreshDiagnostics()
    }

    private func exportHelperDiagnostics() {
        do {
            let savedURL = try HelperDiagnosticsExporter.exportReport(
                helperManager: helperManager,
                startupManager: startupManager,
                menuBarSettings: menuBarSettings
            )

            guard let savedURL else {
                diagnosticsExportMessage = nil
                return
            }

            diagnosticsExportMessage = "Saved helper diagnostics to \(savedURL.lastPathComponent)."
        } catch {
            diagnosticsExportMessage = "Could not export helper diagnostics: \(error.localizedDescription)"
        }
    }

    private var menuBarStatus: WelcomeGuideChecklistStatus {
        let presetTitle = menuBarSettings.activePreset?.title ?? "Custom"
        let itemLabel = menuBarSettings.enabledItemCount == 1 ? "item" : "items"
        let detail = "\(menuBarSettings.enabledItemCount) live \(itemLabel) • \(presetTitle) layout"
        let needsBalancedAction = menuBarSettings.activePreset != .balanced

        return WelcomeGuideChecklistStatus(
            title: "Menu Bar Access",
            symbol: "menubar.rectangle",
            tone: .positive,
            badge: presetTitle,
            detail: detail,
            actionTitle: needsBalancedAction ? "Use Balanced" : nil
        )
    }

    private var loginStatus: WelcomeGuideChecklistStatus {
        if startupManager.isEnabled {
            return WelcomeGuideChecklistStatus(
                title: "Launch at Login",
                symbol: "power.circle",
                tone: .positive,
                badge: "Enabled",
                detail: "Core Monitor will relaunch after sign-in so menu bar monitoring stays available."
            )
        }

        if let errorMessage = startupManager.errorMessage, errorMessage.isEmpty == false {
            let badge = errorMessage.localizedCaseInsensitiveContains("approval") ? "Approval Needed" : "Needs Attention"
            return WelcomeGuideChecklistStatus(
                title: "Launch at Login",
                symbol: "power.circle",
                tone: .caution,
                badge: badge,
                detail: errorMessage
            )
        }

        return WelcomeGuideChecklistStatus(
            title: "Launch at Login",
            symbol: "power.circle",
            tone: .neutral,
            badge: "Optional",
            detail: "Enable this if you rely on Core Monitor staying present in the menu bar after restart.",
            actionTitle: "Enable"
        )
    }

    private var helperStatus: WelcomeGuideChecklistStatus {
        switch helperManager.connectionState {
        case .reachable:
            return WelcomeGuideChecklistStatus(
                title: "Fan Control Helper",
                symbol: "lock.shield",
                tone: .positive,
                badge: "Ready",
                detail: "Privileged fan control is available for manual and profile-based fan writes."
            )

        case .checking, .unknown:
            return WelcomeGuideChecklistStatus(
                title: "Fan Control Helper",
                symbol: "lock.shield",
                tone: .neutral,
                badge: "Checking",
                detail: "Core Monitor is verifying helper connectivity in the background.",
                actionTitle: "Recheck"
            )

        case .unreachable:
            return WelcomeGuideChecklistStatus(
                title: "Fan Control Helper",
                symbol: "lock.shield",
                tone: .caution,
                badge: "Unavailable",
                detail: helperManager.statusMessage ?? "The helper is installed but not responding right now.",
                actionTitle: "Recheck"
            )

        case .missing:
            return WelcomeGuideChecklistStatus(
                title: "Fan Control Helper",
                symbol: "lock.shield",
                tone: .neutral,
                badge: "Optional",
                detail: "Monitoring, alerts, and menu bar metrics work immediately. Install the helper only if you want fan writes.",
                actionTitle: "Install Helper"
            )
        }
    }

}

private struct WelcomeGuideStepContent<TrailingContent: View, Badge: View>: View {
    let step: GuideStep
    let stepVisible: Bool
    let usesCompactFeatureGrid: Bool
    @ViewBuilder let badge: () -> Badge
    @ViewBuilder let trailingContent: () -> TrailingContent

    var body: some View {
        Group {
            if #available(macOS 13.0, *) {
                ViewThatFits(in: .vertical) {
                    contentLayout(includesSpacer: true)

                    scrollableContent
                }
            } else {
                scrollableContent
            }
        }
        .id(step.id)
        .opacity(stepVisible ? 1 : 0)
        .animation(.easeOut(duration: 0.28), value: stepVisible)
    }

    private var scrollableContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            contentLayout(includesSpacer: false)
                .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func contentLayout(includesSpacer: Bool) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: usesCompactFeatureGrid ? 12 : 14) {
                badge()
                    .padding(.top, usesCompactFeatureGrid ? 24 : 36)

                VStack(spacing: 6) {
                    Text(step.headline)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.wgText)
                        .multilineTextAlignment(.center)

                    Text(step.subheadline)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(step.iconColor)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.bottom, usesCompactFeatureGrid ? 14 : 20)

            Text(step.body)
                .font(.system(size: 13.5, weight: .regular, design: .default))
                .foregroundColor(.wgTextSub)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: 500)
                .padding(.horizontal, 40)
                .padding(.bottom, usesCompactFeatureGrid ? 10 : 22)

            bulletSection

            trailingContent()

            if includesSpacer {
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var bulletSection: some View {
        if usesCompactFeatureGrid {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(step.bullets.enumerated()), id: \.offset) { idx, bullet in
                    WelcomeGuideBulletRow(icon: bullet.icon, color: bullet.color, text: bullet.text)
                        .opacity(stepVisible ? 1 : 0)
                        .offset(x: stepVisible ? 0 : -18)
                        .animation(
                            .spring(response: 0.42, dampingFraction: 0.78)
                                .delay(0.08 + Double(idx) * 0.07),
                            value: stepVisible
                        )
                }
            }
            .frame(maxWidth: 500)
            .padding(.horizontal, 40)
        }
    }
}

private struct WelcomeGuideBulletRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(color)
            }
            Text(text)
                .font(.system(size: 13, weight: .regular, design: .default))
                .foregroundColor(.wgText)
            Spacer()
        }
    }
}

private struct WelcomeGuideChecklistStatus {
    let title: String
    let symbol: String
    let tone: WelcomeGuideChecklistTone
    let badge: String
    let detail: String
    var actionTitle: String? = nil
}

private enum WelcomeGuideChecklistTone {
    case positive
    case caution
    case neutral

    var badgeColor: Color {
        switch self {
        case .positive:
            return .wgGreen
        case .caution:
            return .wgAmber
        case .neutral:
            return .wgBlue
        }
    }
}

private struct WelcomeGuideReadinessPanel: View {
    let menuBarStatus: WelcomeGuideChecklistStatus
    let loginStatus: WelcomeGuideChecklistStatus
    let helperStatus: WelcomeGuideChecklistStatus
    let installHelper: () -> Void
    let enableLaunchAtLogin: () -> Void
    let applyBalancedPreset: () -> Void
    let refreshHelperDiagnostics: () -> Void
    let exportHelperDiagnostics: () -> Void
    let diagnosticsExportMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Quick Setup Checklist")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.wgText)
                Text("Everything below is optional except keeping one menu bar item visible.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.wgTextSub)
            }

            VStack(spacing: 8) {
                WelcomeGuideChecklistRow(status: menuBarStatus, action: applyBalancedPreset)
                WelcomeGuideChecklistRow(status: loginStatus, action: enableLaunchAtLogin)
                WelcomeGuideChecklistRow(
                    status: helperStatus,
                    action: helperStatus.actionTitle == "Install Helper" ? installHelper : refreshHelperDiagnostics
                )
            }

            WelcomeGuideDiagnosticsExportRow(
                message: diagnosticsExportMessage,
                exportHelperDiagnostics: exportHelperDiagnostics
            )
        }
        .padding(14)
        .frame(maxWidth: 520, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.wgSurface.opacity(0.86))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.wgBorder, lineWidth: 1)
                )
        )
        .padding(.horizontal, 40)
    }
}

private struct WelcomeGuideDiagnosticsExportRow: View {
    let message: String?
    let exportHelperDiagnostics: () -> Void

    private var messageColor: Color {
        guard let message else { return .wgTextSub }
        return message.localizedCaseInsensitiveContains("could not") ? .wgAmber : .wgGreen
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
                .background(Color.wgBorder)

            HStack(alignment: .top, spacing: 12) {
                Text("Need support or fan-control troubleshooting?")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.wgText)

                Button("Export Report", action: exportHelperDiagnostics)
                    .buttonStyle(.plain)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(.wgText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.wgBorder, lineWidth: 1)
                    )
            }

            if let message, message.isEmpty == false {
                Text(message)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(messageColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 2)
    }
}

private struct WelcomeGuideChecklistRow: View {
    let status: WelcomeGuideChecklistStatus
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(status.tone.badgeColor.opacity(0.14))
                    .frame(width: 30, height: 30)
                Image(systemName: status.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(status.tone.badgeColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(status.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.wgText)

                    Text(status.badge.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(status.tone.badgeColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(status.tone.badgeColor.opacity(0.16))
                        .clipShape(Capsule())
                }

                Text(status.detail)
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundColor(.wgTextSub)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            if let actionTitle = status.actionTitle {
                Button(actionTitle, action: action)
                    .buttonStyle(.plain)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(.wgText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.wgBorder, lineWidth: 1)
                    )
            }
        }
    }
}

private struct WelcomeGuideBottomBar: View {
    let steps: [GuideStep]
    let currentStep: Int
    let progressPulse: Bool
    let accentColor: Color
    let goBack: () -> Void
    let continueForward: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(steps) { step in
                    Capsule()
                        .fill(step.id == currentStep ? accentColor : Color.wgBorder)
                        .frame(width: step.id == currentStep ? 20 : 6, height: 6)
                        .opacity(progressPulse && step.id == currentStep ? 1 : (step.id == currentStep ? 0.85 : 0.4))
                        .animation(.spring(response: 0.38, dampingFraction: 0.72), value: currentStep)
                }
            }

            Spacer()

            if currentStep > 0 {
                Button(action: goBack) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.wgTextSub)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.wgSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.wgBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }

            Button(action: continueForward) {
                HStack(spacing: 6) {
                    Text(currentStep < steps.count - 1 ? "Next" : "Get Started")
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: currentStep < steps.count - 1 ? "chevron.right" : "checkmark")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(Color.wgBackground)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Minimal deterministic RNG (for noise canvas)
// ─────────────────────────────────────────────────────────────────────────────

private struct WGRandom {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
