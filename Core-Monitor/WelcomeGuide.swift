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
        subheadline: CoreMonitorPlatformCopy.welcomeIntroSubheadline(),
        body: CoreMonitorPlatformCopy.welcomeIntroBody(),
        bullets: [
            ("thermometer.medium",    .wgAmber,  "Live CPU, GPU & memory readings"),
            ("menubar.rectangle",     .wgBlue,   "Readable menu bar monitoring"),
            ("lock.shield",           .wgGreen,  "Helper-optional fan control"),
            ("hand.raised",           .wgPurple, "Local diagnostics and privacy controls"),
        ]
    ),
    GuideStep(
        id: 1,
        icon: "thermometer.medium",
        iconColor: .wgAmber,
        headline: "Thermals & Metrics",
        subheadline: "See what's really heating up.",
        body: "The dashboard streams CPU, GPU, and memory data at 1-second resolution. Spark-line histories let you spot transient spikes that Activity Monitor smooths over, and the system status cards keep monitoring freshness, helper health, and privacy controls visible in one place.",
        bullets: [
            ("cpu.fill",              .wgAmber,  CoreMonitorPlatformCopy.thermalMetricsBullet()),
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
        body: "The fan controller supports Smart, Balanced, Performance, Max, Manual, Custom, and System Auto modes. It can re-apply active profiles after wake and sends write commands through the blessed helper.",
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
        body: "Core Monitor can replace the system Touch Bar with a full-width widget strip for weather, status, network, dock shortcuts, and dense system widgets. Tap the weather widget to flip between compact and expanded conditions, swipe sideways on the trackpad to move between onboarding cards, and open the Touch Bar tab to reorder, remove, or add widgets with live width guidance.",
        bullets: [
            ("hand.tap.fill",         .wgAmber,  "Tap Weather to expand conditions and rain timing"),
            ("rectangle.3.group",     .wgBlue,   "Swipe sideways on the trackpad to move between guide cards"),
            ("slider.horizontal.3",   .wgGreen,  "Touch Bar > Active Items lets you reorder, remove, and add widgets"),
            ("cloud.sun.rain.fill",   .wgAmber,  "Weather uses Apple's WeatherKit path and gets better with location access"),
            ("command.circle.fill",   .wgPurple, "Command-Shift-6 switches back to the system Touch Bar"),
            ("power",                 .wgRed,    "Quitting Core Monitor also dismisses the HUD"),
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
            ("waveform.path.ecg.rectangle", .wgGreen, "System status cards surface monitoring freshness, helper state, and privacy"),
            ("menubar.rectangle",     .wgBlue,   "Balanced menu bar mode keeps the app visible without adding clutter"),
            ("lock.shield",           .wgPurple, "Monitoring works without the helper; only fan writes need it"),
            ("hand.raised",           .wgAmber,  "Privacy Controls can keep notifications and memory views free of app names"),
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
    @ObservedObject private var dashboardShortcutManager = DashboardShortcutManager.shared

    @State private var currentStep   = 0
    @State private var stepVisible   = false     // drives per-step fade
    @State private var sheetVisible  = false     // drives initial sheet fade-in
    @State private var headerGlow    = false     // ambient pulse on icon
    @State private var progressPulse = false     // subtle dot pulse
    @State private var diagnosticsExportMessage: String?
    @State private var scrollMonitor: Any?
    @State private var horizontalScrollAccumulator: CGFloat = 0
    @State private var scrollNavigationLocked = false

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
        .onDisappear(perform: tearDownSheet)
    }

    // ── Step content ─────────────────────────────────────────────────────────

    private var stepContent: some View {
        let step = guideSteps[currentStep]
        return WelcomeGuideStepContent(
            step: step,
            stepVisible: stepVisible,
            usesCompactFeatureGrid: currentStep == guideSteps.count - 1 || currentStep == 3,
            badge: { iconBadge(for: step) }
        ) {
            if currentStep == 3 {
                WelcomeGuideTouchBarShowcase(accentColor: step.iconColor)
                    .padding(.top, 12)
            } else if currentStep == guideSteps.count - 1 {
                WelcomeGuideReadinessPanel(
                    menuBarStatus: menuBarStatus,
                    dashboardShortcutStatus: dashboardShortcutStatus,
                    loginStatus: loginStatus,
                    helperStatus: helperStatus,
                    installHelper: installHelperIfNeeded,
                    performLaunchAtLoginAction: performLaunchAtLoginAction,
                    enableDashboardShortcut: enableDashboardShortcut,
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
        horizontalScrollAccumulator = 0
        scrollNavigationLocked = false
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
        horizontalScrollAccumulator = 0
        scrollNavigationLocked = false

        startupManager.refreshState()
        refreshHelperDiagnostics()
        installScrollMonitor()

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

    private func tearDownSheet() {
        if let scrollMonitor {
            NSEvent.removeMonitor(scrollMonitor)
            self.scrollMonitor = nil
        }
    }

    private func goBack() {
        guard currentStep > 0 else { return }
        transition(to: currentStep - 1)
    }

    private func goForwardStep() {
        guard currentStep < guideSteps.count - 1 else { return }
        transition(to: currentStep + 1)
    }

    private func advanceOrDismiss() {
        if currentStep < guideSteps.count - 1 {
            goForwardStep()
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

    private func installScrollMonitor() {
        guard scrollMonitor == nil else { return }

        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .swipe]) { event in
            guard sheetVisible else {
                return event
            }

            if handleNavigationGesture(event) {
                return nil
            }

            return event
        }
    }

    private func handleNavigationGesture(_ event: NSEvent) -> Bool {
        switch event.type {
        case .swipe:
            return handleSwipeGesture(event)

        case .scrollWheel:
            guard event.hasPreciseScrollingDeltas else {
                return false
            }
            return handleHorizontalScroll(event)

        default:
            return false
        }
    }

    private func handleSwipeGesture(_ event: NSEvent) -> Bool {
        let horizontalDelta = event.deltaX
        let verticalDelta = event.deltaY

        guard abs(horizontalDelta) > abs(verticalDelta), abs(horizontalDelta) >= 0.5 else {
            return false
        }

        if horizontalDelta > 0 {
            goForwardStep()
            return true
        }

        if horizontalDelta < 0 {
            goBack()
            return true
        }

        return false
    }

    private func handleHorizontalScroll(_ event: NSEvent) -> Bool {
        let horizontalMagnitude = abs(event.scrollingDeltaX)
        let verticalMagnitude = abs(event.scrollingDeltaY)

        if horizontalMagnitude <= verticalMagnitude || horizontalMagnitude < 1.5 {
            if event.phase == .ended || event.momentumPhase == .ended {
                horizontalScrollAccumulator = 0
                scrollNavigationLocked = false
            }
            return false
        }

        if event.phase == .began || event.phase == .mayBegin {
            horizontalScrollAccumulator = 0
            scrollNavigationLocked = false
        }

        let fingerDeltaX = event.isDirectionInvertedFromDevice
            ? -event.scrollingDeltaX
            : event.scrollingDeltaX

        horizontalScrollAccumulator += fingerDeltaX

        let threshold: CGFloat = 56
        guard scrollNavigationLocked == false else {
            if event.phase == .ended || event.momentumPhase == .ended {
                horizontalScrollAccumulator = 0
                scrollNavigationLocked = false
            }
            return false
        }

        if horizontalScrollAccumulator <= -threshold {
            scrollNavigationLocked = true
            goForwardStep()
            return true
        }

        if horizontalScrollAccumulator >= threshold {
            scrollNavigationLocked = true
            goBack()
            return true
        }

        if event.phase == .ended || event.momentumPhase == .ended {
            horizontalScrollAccumulator = 0
            scrollNavigationLocked = false
        }

        return false
    }

    private func enableLaunchAtLogin() {
        startupManager.setEnabled(true)
        startupManager.refreshState()
    }

    private func performLaunchAtLoginAction() {
        switch startupManager.statusSummary.action {
        case .openSystemSettings:
            startupManager.openLoginItemsSettings()
        case .enable, nil:
            enableLaunchAtLogin()
        }
    }

    private func enableDashboardShortcut() {
        dashboardShortcutManager.setEnabled(true)
    }

    private func installHelperIfNeeded() {
        helperManager.installFromApp(forceReinstall: helperManager.connectionState == .unreachable)
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
        let summary = startupManager.statusSummary
        return WelcomeGuideChecklistStatus(
            title: "Launch at Login",
            symbol: "power.circle",
            tone: checklistTone(for: summary.tone),
            badge: summary.badge,
            detail: summary.detail,
            actionTitle: summary.actionTitle
        )
    }

    private func checklistTone(for tone: LaunchAtLoginStatusTone) -> WelcomeGuideChecklistTone {
        switch tone {
        case .positive:
            return .positive
        case .neutral:
            return .neutral
        case .caution:
            return .caution
        }
    }

    private var dashboardShortcutStatus: WelcomeGuideChecklistStatus {
        if dashboardShortcutManager.isEnabled {
            return WelcomeGuideChecklistStatus(
                title: "Dashboard Shortcut",
                symbol: "command",
                tone: .positive,
                badge: "Enabled",
                detail: "\(DashboardShortcutConfiguration.displayLabel) can reopen Core Monitor even if menu bar items are hidden or hard to reach."
            )
        }

        if let registrationError = dashboardShortcutManager.registrationError, registrationError.isEmpty == false {
            return WelcomeGuideChecklistStatus(
                title: "Dashboard Shortcut",
                symbol: "command",
                tone: .caution,
                badge: "Unavailable",
                detail: registrationError
            )
        }

        return WelcomeGuideChecklistStatus(
            title: "Dashboard Shortcut",
            symbol: "command",
            tone: .neutral,
            badge: "Optional",
            detail: "Enable this if you want a fallback path back into the dashboard without depending on menu bar visibility.",
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
                actionTitle: "Reinstall Helper"
            )

        case .missing:
            return WelcomeGuideChecklistStatus(
                title: "Fan Control Helper",
                symbol: "lock.shield",
                tone: .neutral,
                badge: "Optional",
                detail: "Monitoring and menu bar metrics work immediately. Install the helper only if you want fan writes.",
                actionTitle: "Install Helper"
            )
        }
    }

}

private struct WelcomeGuideTouchBarShowcase: View {
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label("Touch Bar Interaction Demos", systemImage: "sparkles.rectangle.stack")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.wgText)

                Spacer()

                Text("LIVE LOOP")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(accentColor.opacity(0.14))
                    .clipShape(Capsule())
            }

            HStack(alignment: .top, spacing: 12) {
                WelcomeGuideTouchBarDemoPanel(
                    title: "Tap Weather",
                    subtitle: "Tap the weather widget to expand the forecast line and rain summary.",
                    accentColor: .wgAmber,
                    symbol: "hand.tap.fill"
                ) {
                    WelcomeGuideWeatherTouchBarDemo()
                }

                WelcomeGuideTouchBarDemoPanel(
                    title: "Swipe Cards",
                    subtitle: "Use a sideways trackpad swipe to move across the onboarding cards.",
                    accentColor: .wgBlue,
                    symbol: "rectangle.3.group.fill"
                ) {
                    WelcomeGuideCardSwipeDemo()
                }
            }

            WelcomeGuideTouchBarDemoPanel(
                title: "Change Widgets",
                subtitle: "Open Touch Bar to reorder active widgets or add new ones from the library.",
                accentColor: .wgGreen,
                symbol: "slider.horizontal.3"
            ) {
                WelcomeGuideTouchBarEditDemo()
            }
        }
        .padding(14)
        .frame(maxWidth: 520, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.wgSurface.opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.wgBorder, lineWidth: 1)
                )
        )
        .padding(.horizontal, 40)
    }
}

private struct WelcomeGuideTouchBarDemoPanel<Content: View>: View {
    let title: String
    let subtitle: String
    let accentColor: Color
    let symbol: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(accentColor.opacity(0.12))
                        .frame(width: 28, height: 28)

                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(accentColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(.wgText)

                    Text(subtitle)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.wgTextSub)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.wgBorder.opacity(0.9), lineWidth: 1)
                )
        )
    }
}

private struct WelcomeGuideWeatherTouchBarDemo: View {
    @State private var startedAt = Date()

    var body: some View {
        TimelineView(.animation) { context in
            let cycle = context.date.timeIntervalSince(startedAt).truncatingRemainder(dividingBy: 4.8)
            let expansion = wgLoopEnvelope(time: cycle, fadeIn: 0.55...1.25, fadeOut: 3.1...3.9)
            let tapPulse = wgPulse(time: cycle, start: 0.35, peak: 0.78, end: 1.2)
            let weatherWidth = CGFloat(wgMix(124, 210, expansion))

            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.black.opacity(0.78))
                        .frame(height: 58)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )

                    HStack(spacing: 8) {
                        WelcomeGuideTouchBarPill(
                            width: 84,
                            accent: .wgBlue,
                            icon: "wifi",
                            title: "9:41",
                            detail: "73%"
                        )

                        ZStack {
                            WelcomeGuideTouchBarPill(
                                width: weatherWidth,
                                accent: .wgAmber,
                                icon: "cloud.sun.fill",
                                title: "Karachi",
                                detail: expansion > 0.55 ? "22° • Partly Cloudy • Rain 4 PM" : "22° • Partly Cloudy"
                            )

                            Circle()
                                .stroke(Color.wgAmber.opacity(1 - tapPulse * 0.8), lineWidth: 1.4)
                                .frame(width: 24, height: 24)
                                .scaleEffect(1 + tapPulse * 0.7)
                                .opacity(tapPulse > 0 ? 1 : 0)
                                .offset(x: min(42, weatherWidth * 0.22), y: -4)

                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.wgAmber)
                                .offset(x: min(42, weatherWidth * 0.22), y: -18 - tapPulse * 4)
                                .opacity(0.35 + tapPulse * 0.65)
                        }

                        WelcomeGuideTouchBarPill(
                            width: 78,
                            accent: .wgGreen,
                            icon: "cpu.fill",
                            title: "CPU",
                            detail: "44°"
                        )
                    }
                    .padding(.horizontal, 10)
                }

                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.forward.circle.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.wgAmber)
                    Text(expansion > 0.55 ? "Expanded weather view is showing the longer condition line." : "Compact weather view is showing the default summary.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.wgTextSub)
                }
            }
        }
        .frame(height: 94)
        .onAppear { startedAt = Date() }
    }
}

private struct WelcomeGuideCardSwipeDemo: View {
    @State private var startedAt = Date()

    private let cardWidth: CGFloat = 104
    private let cardSpacing: CGFloat = 10

    var body: some View {
        TimelineView(.animation) { context in
            let cycle = context.date.timeIntervalSince(startedAt).truncatingRemainder(dividingBy: 6.4)
            let progressIndex = cardProgressIndex(for: cycle)
            let stripOffset = -progressIndex * Double(cardWidth + cardSpacing)
            let fingerTravel = wgMix(-28, 26, wgLoopEnvelope(time: cycle, fadeIn: 1.0...2.0, fadeOut: 4.7...5.8))

            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.black.opacity(0.28))
                        .frame(height: 78)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.wgBorder, lineWidth: 1)
                        )

                    HStack(spacing: cardSpacing) {
                        WelcomeGuideCardPreview(title: "Overview", accent: .wgAmber, symbol: "gauge.medium")
                        WelcomeGuideCardPreview(title: "Touch Bar", accent: .wgPurple, symbol: "display.2")
                        WelcomeGuideCardPreview(title: "Ready", accent: .wgGreen, symbol: "checkmark.seal.fill")
                    }
                    .padding(.horizontal, 10)
                    .offset(x: stripOffset)
                }
                .clipped()

                HStack(spacing: 10) {
                    Text("3-FINGER SWIPE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.wgBlue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.wgBlue.opacity(0.14))
                        .clipShape(Capsule())

                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 78, height: 22)

                        HStack(spacing: 5) {
                            ForEach(0..<3, id: \.self) { _ in
                                Circle()
                                    .fill(Color.wgBlue.opacity(0.92))
                                    .frame(width: 5, height: 5)
                            }
                        }
                        .offset(x: fingerTravel)
                    }

                    Text("Swipe sideways to move between guide cards.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.wgTextSub)
                }
            }
        }
        .frame(height: 94)
        .onAppear { startedAt = Date() }
    }

    private func cardProgressIndex(for cycle: TimeInterval) -> Double {
        switch cycle {
        case ..<1.0:
            return 0
        case 1.0..<2.0:
            return wgSmoothProgress(cycle, start: 1.0, end: 2.0)
        case 2.0..<3.4:
            return 1
        case 3.4..<4.4:
            return 1 + wgSmoothProgress(cycle, start: 3.4, end: 4.4)
        case 4.4..<5.8:
            return 2
        default:
            return 2 - wgSmoothProgress(cycle, start: 5.8, end: 6.4) * 2
        }
    }
}

private struct WelcomeGuideTouchBarEditDemo: View {
    @State private var startedAt = Date()

    var body: some View {
        TimelineView(.animation) { context in
            let cycle = context.date.timeIntervalSince(startedAt).truncatingRemainder(dividingBy: 6.8)
            let reorderProgress = wgLoopEnvelope(time: cycle, fadeIn: 1.1...2.1, fadeOut: 4.2...5.2)
            let addProgress = wgLoopEnvelope(time: cycle, fadeIn: 3.4...4.2, fadeOut: 5.8...6.6)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text("Touch Bar")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(.wgText)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.wgTextDim)
                    Text("Active Items")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.wgTextSub)
                }

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.black.opacity(0.28))
                        .frame(height: 94)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.wgBorder, lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            WelcomeGuideActiveWidgetChip(title: "Status", accent: .wgBlue)

                            WelcomeGuideActiveWidgetChip(title: "CPU", accent: .wgGreen)
                                .offset(x: CGFloat(wgMix(0, 60, reorderProgress)))

                            WelcomeGuideActiveWidgetChip(title: "Weather", accent: .wgAmber)
                                .offset(x: CGFloat(wgMix(0, -60, reorderProgress)))

                            WelcomeGuideActiveWidgetChip(title: "Network", accent: .wgPurple)
                                .opacity(addProgress)
                                .offset(y: CGFloat(wgMix(8, 0, addProgress)))
                        }

                        HStack(spacing: 8) {
                            WelcomeGuideLibraryWidgetChip(title: "Weather")
                            WelcomeGuideLibraryWidgetChip(title: "Network")
                                .overlay(alignment: .topTrailing) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.wgGreen)
                                        .background(Color.wgBackground, in: Circle())
                                        .scaleEffect(0.9 + addProgress * 0.25)
                                        .opacity(0.45 + addProgress * 0.55)
                                        .offset(x: 6, y: -6)
                                }
                            WelcomeGuideLibraryWidgetChip(title: "Hardware")
                        }

                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.wgGreen)
                                .scaleEffect(0.95 + reorderProgress * 0.2)
                                .opacity(0.45 + reorderProgress * 0.55)

                            Text("Reorder with the arrows, remove what you do not need, and add widgets from the library below.")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.wgTextSub)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .frame(height: 138)
        .onAppear { startedAt = Date() }
    }
}

private struct WelcomeGuideTouchBarPill: View {
    let width: CGFloat
    let accent: Color
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(accent)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(.wgText)
                    .lineLimit(1)

                Text(detail)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.wgTextSub)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .frame(width: width, height: 38, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }
}

private struct WelcomeGuideCardPreview: View {
    let title: String
    let accent: Color
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(accent)
                Spacer()
                Circle()
                    .fill(accent.opacity(0.92))
                    .frame(width: 6, height: 6)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.wgText)
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 6)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                            .fill(accent.opacity(0.92))
                            .frame(width: 42, height: 6)
                    }
            }
        }
        .padding(12)
        .frame(width: 104, height: 58, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.wgSurface.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.wgBorder, lineWidth: 1)
                )
        )
    }
}

private struct WelcomeGuideActiveWidgetChip: View {
    let title: String
    let accent: Color

    var body: some View {
        Text(title)
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundColor(.wgText)
            .frame(width: 52, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(accent.opacity(0.16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(accent.opacity(0.35), lineWidth: 1)
                    )
            )
    }
}

private struct WelcomeGuideLibraryWidgetChip: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(.wgTextSub)
            .frame(width: 58, height: 20)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(Color.wgBorder, lineWidth: 1)
                    )
            )
    }
}

private func wgMix(_ from: Double, _ to: Double, _ progress: Double) -> Double {
    from + (to - from) * progress
}

private func wgSmoothProgress(_ time: TimeInterval, start: TimeInterval, end: TimeInterval) -> Double {
    guard end > start else { return time >= end ? 1 : 0 }
    let raw = max(0, min(1, (time - start) / (end - start)))
    return raw * raw * (3 - 2 * raw)
}

private func wgLoopEnvelope(
    time: TimeInterval,
    fadeIn: ClosedRange<TimeInterval>,
    fadeOut: ClosedRange<TimeInterval>
) -> Double {
    if time <= fadeIn.lowerBound {
        return 0
    }
    if time < fadeIn.upperBound {
        return wgSmoothProgress(time, start: fadeIn.lowerBound, end: fadeIn.upperBound)
    }
    if time <= fadeOut.lowerBound {
        return 1
    }
    if time < fadeOut.upperBound {
        return 1 - wgSmoothProgress(time, start: fadeOut.lowerBound, end: fadeOut.upperBound)
    }
    return 0
}

private func wgPulse(time: TimeInterval, start: TimeInterval, peak: TimeInterval, end: TimeInterval) -> Double {
    if time <= start || time >= end {
        return 0
    }
    if time <= peak {
        return wgSmoothProgress(time, start: start, end: peak)
    }
    return 1 - wgSmoothProgress(time, start: peak, end: end)
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
    let dashboardShortcutStatus: WelcomeGuideChecklistStatus
    let loginStatus: WelcomeGuideChecklistStatus
    let helperStatus: WelcomeGuideChecklistStatus
    let installHelper: () -> Void
    let performLaunchAtLoginAction: () -> Void
    let enableDashboardShortcut: () -> Void
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
                Text("Keep at least one menu bar item visible, or enable the dashboard shortcut as a fallback.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.wgTextSub)
            }

            VStack(spacing: 8) {
                WelcomeGuideChecklistRow(status: menuBarStatus, action: applyBalancedPreset)
                WelcomeGuideChecklistRow(status: dashboardShortcutStatus, action: enableDashboardShortcut)
                WelcomeGuideChecklistRow(status: loginStatus, action: performLaunchAtLoginAction)
                WelcomeGuideChecklistRow(
                    status: helperStatus,
                    action: helperStatus.actionTitle == "Install Helper" || helperStatus.actionTitle == "Reinstall Helper"
                        ? installHelper
                        : refreshHelperDiagnostics
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
