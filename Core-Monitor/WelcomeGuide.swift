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
    @AppStorage("com.coremonitor.hasSeenWelcomeGuide.v1") private var hasSeen = false

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: Binding(
                get: { !hasSeen },
                set: { if !$0 { hasSeen = true } }
            )) {
                WelcomeGuideSheet { hasSeen = true }
                    .interactiveDismissDisabled(true)
            }
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
            ("thermometer.medium",    .wgAmber,  "Live CPU, GPU & memory telemetry"),
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
        body: "The dashboard streams CPU, GPU, and memory data at 1-second resolution. Spark-line histories let you spot transient spikes that Activity Monitor smooths over.",
        bullets: [
            ("cpu.fill",              .wgAmber,  "Per-cluster CPU usage & temperature"),
            ("memorychip",            .wgBlue,   "Memory pressure with wired/active breakdown"),
            ("chart.line.uptrend.xyaxis", .wgGreen, "60-second rolling history graphs"),
            ("exclamationmark.triangle", .wgRed, "Thermal alerts when SoC throttles"),
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
        body: "The dashboard is live and already collecting data. Explore the thermal, power, and fan panels, or switch to Basic Mode if you want the lightest possible UI.",
        bullets: [
            ("sidebar.left",          .wgAmber,  "Dashboard sections collapse with a click"),
            ("fan.fill",              .wgBlue,   "Fan Control — scroll down on dashboard"),
            ("lock.shield",           .wgPurple, "Fan writes require the blessed helper"),
            ("questionmark.circle",   .wgGreen,  "This guide lives in Help → Show Guide"),
        ]
    ),
]

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Sheet root
// ─────────────────────────────────────────────────────────────────────────────

private struct WelcomeGuideSheet: View {
    let onDismiss: () -> Void

    @State private var currentStep   = 0
    @State private var stepVisible   = false     // drives per-step fade
    @State private var sheetVisible  = false     // drives initial sheet fade-in
    @State private var headerGlow    = false     // ambient pulse on icon
    @State private var progressPulse = false     // subtle dot pulse
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

                bottomBar
            }
        }
        .frame(width: 660, height: 520)
        .preferredColorScheme(.dark)
        .opacity(sheetVisible ? 1 : 0)
        .scaleEffect(sheetVisible ? 1 : 0.96)
        .onAppear {
            // Sheet entrance
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                sheetVisible = true
            }
            // Stagger step content
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                withAnimation(.easeOut(duration: 0.35)) { stepVisible = true }
            }
            // Ambient glow pulse (runs indefinitely, no blur involved)
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                headerGlow = true
            }
            withAnimation(.easeInOut(duration: 1.2).delay(0.6).repeatForever(autoreverses: true)) {
                progressPulse = true
            }
        }
    }

    // ── Step content ─────────────────────────────────────────────────────────

    private var stepContent: some View {
        let step = guideSteps[currentStep]
        return VStack(spacing: 0) {
            // Icon + headline block
            VStack(spacing: 14) {
                iconBadge(for: step)
                    .padding(.top, 36)

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
            .padding(.bottom, 20)

            // Body text
            Text(step.body)
                .font(.system(size: 13.5, weight: .regular, design: .default))
                .foregroundColor(.wgTextSub)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: 480)
                .padding(.horizontal, 40)
                .padding(.bottom, 22)

            // Bullet list
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(step.bullets.enumerated()), id: \.offset) { idx, bullet in
                    bulletRow(icon: bullet.icon, color: bullet.color, text: bullet.text)
                        .opacity(stepVisible ? 1 : 0)
                        .offset(x: stepVisible ? 0 : -18)
                        .animation(
                            .spring(response: 0.42, dampingFraction: 0.78)
                                .delay(0.08 + Double(idx) * 0.07),
                            value: stepVisible
                        )
                }
            }
            .frame(maxWidth: 460)
            .padding(.horizontal, 40)

            Spacer()
        }
        .opacity(stepVisible ? 1 : 0)
        .animation(.easeOut(duration: 0.28), value: stepVisible)
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

    private func bulletRow(icon: String, color: Color, text: String) -> some View {
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

    // ── Bottom bar ────────────────────────────────────────────────────────────

    private var bottomBar: some View {
        HStack {
            // Step indicators
            HStack(spacing: 6) {
                ForEach(guideSteps) { step in
                    Capsule()
                        .fill(step.id == currentStep
                              ? guideSteps[currentStep].iconColor
                              : Color.wgBorder)
                        .frame(width: step.id == currentStep ? 20 : 6, height: 6)
                        .opacity(progressPulse && step.id == currentStep ? 1 : (step.id == currentStep ? 0.85 : 0.4))
                        .animation(.spring(response: 0.38, dampingFraction: 0.72), value: currentStep)
                }
            }

            Spacer()

            // Back
            if currentStep > 0 {
                Button {
                    transition(to: currentStep - 1)
                } label: {
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

            // Next / Done
            Button {
                if currentStep < guideSteps.count - 1 {
                    transition(to: currentStep + 1)
                } else {
                    // Dismiss with a slight scale-out
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.80)) {
                        sheetVisible = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        onDismiss()
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(currentStep < guideSteps.count - 1 ? "Next" : "Get Started")
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: currentStep < guideSteps.count - 1 ? "chevron.right" : "checkmark")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(Color.wgBackground)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(guideSteps[currentStep].iconColor)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
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
