import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Darwin

// MARK: - CoreVisor design tokens (dark industrial theme matching ContentView)
private extension Color {
    static let cvBackground    = Color(red: 0.07, green: 0.07, blue: 0.08)
    static let cvSurface       = Color(red: 0.10, green: 0.10, blue: 0.12)
    static let cvSurfaceRaised = Color(red: 0.13, green: 0.13, blue: 0.15)
    static let cvBorder        = Color(white: 1, opacity: 0.07)
    static let cvBorderBright  = Color(white: 1, opacity: 0.14)
    static let cvAmber         = Color(red: 1.0,  green: 0.72, blue: 0.18)
    static let cvGreen         = Color(red: 0.22, green: 0.92, blue: 0.55)
    static let cvRed           = Color(red: 1.0,  green: 0.34, blue: 0.34)
    static let cvBlue          = Color(red: 0.35, green: 0.72, blue: 1.0)
    static let cvPrimary       = Color(white: 0.92)
    static let cvSecondary     = Color(white: 0.50)
    static let cvDim           = Color(white: 0.28)
}

private extension Font {
    static func cvMono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static func cvRound(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Panel modifier
private struct CVPanel: ViewModifier {
    var accent: Color = .clear
    var padding: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.cvSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(accent == .clear ? Color.cvBorder : accent.opacity(0.30), lineWidth: 1)
            )
    }
}

private extension View {
    func cvPanel(accent: Color = .clear, padding: CGFloat = 0) -> some View {
        modifier(CVPanel(accent: accent, padding: padding))
    }
}

// MARK: - Section header (matches ContentView style)
private struct CVSectionHeader: View {
    let title: String
    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color.cvAmber)
                .frame(width: 2, height: 11)
            Text(title.uppercased())
                .font(.cvMono(9, weight: .bold))
                .foregroundStyle(Color.cvSecondary)
                .kerning(1.4)
            Spacer()
        }
    }
}

// MARK: - Motion blur modifier
private struct MotionBlurModifier: ViewModifier {
    let active: Bool
    let direction: Int
    func body(content: Content) -> some View {
        content
            .blur(radius: active ? 3.5 : 0)
            .offset(x: active ? CGFloat(direction) * -5 : 0)
            .opacity(active ? 0.80 : 1)
            .animation(.easeOut(duration: 0.16), value: active)
    }
}

private extension View {
    func cvMotionBlur(active: Bool, direction: Int) -> some View {
        modifier(MotionBlurModifier(active: active, direction: direction))
    }
}

// MARK: - Scale button style
private struct CVScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - CoreVisorSetupView
struct CoreVisorSetupView: View {
    @ObservedObject var manager: CoreVisorManager
    @Binding var hasOpenedCoreVisorSetup: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var draft = CoreVisorDraft()
    @State private var step = 0
    @State private var previousStep = 0
    @State private var isTransitioning = false
    @State private var showEntitlementGuide = false
    @State private var customQEMUPathInput = ""
    @State private var pendingDeleteMachine: CoreVisorMachine?
    @State private var machineSearchQuery = ""
    @State private var editWindowControllers: [UUID: NSWindowController] = [:]
    @State private var editWindowCloseObservers: [UUID: NSObjectProtocol] = [:]

    private let stepTitles = ["Template", "Backend", "Resources", "Display", "Review"]
    private var direction: Int { step > previousStep ? 1 : -1 }

    var body: some View {
        ZStack {
            Color.cvBackground.ignoresSafeArea()
            scanLines

            HStack(spacing: 0) {
                sidebar.frame(width: 268)

                Rectangle()
                    .fill(Color.cvBorder)
                    .frame(width: 1)
                    .padding(.vertical, 14)

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 18)
                        .padding(.top, 16)
                        .padding(.bottom, 10)

                    stepPillBar
                        .padding(.horizontal, 18)
                        .padding(.bottom, 10)

                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            ForEach(0..<5, id: \.self) { idx in
                                stepPage(for: idx)
                                    .frame(width: geo.size.width)
                                    .cvMotionBlur(active: isTransitioning && idx == step, direction: direction)
                            }
                        }
                        .offset(x: -CGFloat(step) * geo.size.width)
                        .animation(.interpolatingSpring(stiffness: 340, damping: 38), value: step)
                    }
                    .clipped()

                    bottomBar
                        .padding(.horizontal, 18)
                        .padding(.bottom, 14)
                        .padding(.top, 8)
                }
            }

            if showEntitlementGuide {
                entitlementOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    .zIndex(10)
            }
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 980, minHeight: 650)
        .onAppear {
            hasOpenedCoreVisorSetup = true
            manager.refreshEntitlementStatus()
            showEntitlementGuide = manager.requiresVirtualizationEntitlement
            customQEMUPathInput = manager.customQEMUBinaryPath
        }
        .onChange(of: manager.customQEMUBinaryPath) { _, v in customQEMUPathInput = v }
        .onDisappear {
            for o in editWindowCloseObservers.values { NotificationCenter.default.removeObserver(o) }
            editWindowCloseObservers.removeAll()
            for c in editWindowControllers.values { c.close() }
            editWindowControllers.removeAll()
        }
        .confirmationDialog(
            "Delete VM?",
            isPresented: Binding(get: { pendingDeleteMachine != nil }, set: { if !$0 { pendingDeleteMachine = nil } }),
            titleVisibility: .visible,
            presenting: pendingDeleteMachine
        ) { machine in
            Button("Delete \(machine.name)", role: .destructive) {
                Task { await manager.removeMachine(machine) }
                pendingDeleteMachine = nil
            }
            Button("Cancel", role: .cancel) { pendingDeleteMachine = nil }
        } message: { machine in
            Text("This removes \(machine.name) and its bundle from disk.")
        }
    }

    // MARK: - Scan-line overlay
    private var scanLines: some View {
        Canvas { ctx, size in
            var y: CGFloat = 0
            while y < size.height {
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(.white.opacity(0.016)))
                y += 3
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .drawingGroup()
    }

    // MARK: - Navigation
    private func advance() {
        guard step < stepTitles.count - 1 else { return }
        goTo(step + 1)
    }

    private func goTo(_ idx: Int) {
        guard idx != step else { return }
        previousStep = step
        isTransitioning = true
        step = idx
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { isTransitioning = false }
    }

    // MARK: - Header
    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.cvAmber)
                    Text("COREVISOR")
                        .font(.cvMono(10, weight: .bold))
                        .foregroundStyle(Color.cvAmber)
                        .kerning(2)
                }
                Text("Virtual Machine Setup")
                    .font(.cvRound(16, weight: .bold))
                    .foregroundStyle(Color.cvPrimary)
            }
            Spacer()
            if manager.isScanning {
                ProgressView()
                    .controlSize(.small)
                    .tint(Color.cvAmber)
            }
            cvActionButton("Import UTM", icon: "square.and.arrow.down") { importUTMBundleFromPicker() }
            cvActionButton("Refresh", icon: "arrow.clockwise") { Task { await manager.refreshRuntimeData() } }
        }
    }

    private func cvActionButton(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .font(.cvMono(10, weight: .bold))
                    .kerning(0.3)
            }
            .foregroundStyle(Color.cvSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.cvSurfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.cvBorder, lineWidth: 1))
        }
        .buttonStyle(CVScaleButtonStyle())
        .disabled(manager.isScanning)
    }

    // MARK: - Step pill bar
    private var stepPillBar: some View {
        HStack(spacing: 4) {
            ForEach(Array(stepTitles.enumerated()), id: \.offset) { idx, title in
                Button { goTo(idx) } label: {
                    HStack(spacing: 5) {
                        ZStack {
                            Circle()
                                .fill(idx == step ? Color.cvAmber : Color.cvSurfaceRaised)
                                .frame(width: 16, height: 16)
                                .animation(.spring(response: 0.28), value: step)
                            Text("\(idx + 1)")
                                .font(.cvMono(8, weight: .bold))
                                .foregroundStyle(idx == step ? Color.cvBackground : Color.cvDim)
                        }
                        Text(title.uppercased())
                            .font(.cvMono(9, weight: .bold))
                            .foregroundStyle(idx == step ? Color.cvPrimary : Color.cvDim)
                            .kerning(0.6)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(idx == step ? Color.cvAmber.opacity(0.10) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(idx == step ? Color.cvAmber.opacity(0.30) : Color.clear, lineWidth: 1)
                            .animation(.easeOut(duration: 0.18), value: step)
                    )
                }
                .buttonStyle(.plain)

                if idx < stepTitles.count - 1 {
                    Rectangle()
                        .fill(idx < step ? Color.cvAmber.opacity(0.4) : Color.cvBorder)
                        .frame(width: 16, height: 1)
                        .animation(.easeOut(duration: 0.22), value: step)
                }
            }
            Spacer()
        }
    }

    // MARK: - Step pages
    @ViewBuilder
    private func stepPage(for idx: Int) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                guideCard(for: idx).padding(.top, 2)
                switch idx {
                case 0: templateStep
                case 1: backendStep
                case 2: resourcesStep
                case 3: displayStep
                default: reviewStep
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Guide card
    private func guideCard(for idx: Int) -> some View {
        let info = guideInfo(for: idx)
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: info.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.cvAmber)
                .frame(width: 32, height: 32)
                .background(Color.cvAmber.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 3) {
                Text(info.title.uppercased())
                    .font(.cvMono(9, weight: .bold))
                    .foregroundStyle(Color.cvAmber)
                    .kerning(0.8)
                Text(info.subtitle)
                    .font(.cvRound(11, weight: .medium))
                    .foregroundStyle(Color.cvSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(11)
        .cvPanel(accent: .cvAmber)
    }

    private func guideInfo(for idx: Int) -> (title: String, subtitle: String, icon: String) {
        switch idx {
        case 0: return ("Step 1 — Template", "Pick a preset to prefill defaults. Tapping a card advances automatically.", "square.grid.2x2")
        case 1: return ("Step 2 — Backend", "Choose guest OS then select a backend. Selecting a backend advances automatically.", "gearshape.2")
        case 2: return ("Step 3 — Resources", "Name the VM, set boot paths, configure CPU and memory, then press Continue.", "slider.horizontal.3")
        case 3: return ("Step 4 — Display & USB", "Enable GPU acceleration, audio, and USB passthrough, then press Review.", "display")
        default: return ("Step 5 — Review", "Verify the command preview, then create the VM. Use Start in the sidebar to run it.", "checkmark.seal")
        }
    }

    // MARK: - Template step
    private var templateStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            CVSectionHeader(title: "Starting Template")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(manager.templates) { tmpl in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                            manager.applyTemplate(tmpl, to: &draft)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { advance() }
                    } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Text(tmpl.name)
                                    .font(.cvRound(12, weight: .bold))
                                    .foregroundStyle(Color.cvPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Color.cvDim)
                            }
                            Text(tmpl.guest.rawValue.uppercased())
                                .font(.cvMono(8, weight: .bold))
                                .foregroundStyle(Color.cvAmber.opacity(0.7))
                                .kerning(0.8)
                            HStack(spacing: 5) {
                                specTag("\(tmpl.cpuCores) CORE")
                                specTag("\(tmpl.memoryGB) GB")
                                specTag("\(tmpl.diskGB) GB")
                            }
                        }
                        .padding(12)
                        .cvPanel()
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(CVScaleButtonStyle())
                }
            }
        }
    }

    private func specTag(_ text: String) -> some View {
        Text(text)
            .font(.cvMono(8, weight: .bold))
            .foregroundStyle(Color.cvAmber)
            .kerning(0.5)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.cvAmber.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Backend step
    private var backendStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                CVSectionHeader(title: "Guest OS")
                HStack(spacing: 8) {
                    ForEach(VMGuestType.allCases.filter { $0 != .macOS }) { guest in
                        optionCard(
                            title: guest.rawValue,
                            icon: iconFor(guest: guest),
                            selected: draft.guest == guest
                        ) {
                            withAnimation(.spring(response: 0.26)) { draft.guest = guest }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                CVSectionHeader(title: "Backend")
                HStack(spacing: 8) {
                    ForEach(VMBackend.allCases) { backend in
                        optionCard(
                            title: backend.rawValue,
                            icon: backend == .appleVirtualization ? "apple.logo" : "gearshape.2",
                            selected: draft.backend == backend
                        ) {
                            withAnimation(.spring(response: 0.26)) { draft.backend = backend }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { advance() }
                        }
                    }
                }
            }

            // Compatibility note
            HStack(spacing: 6) {
                Image(systemName: isCompatible ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(isCompatible ? Color.cvGreen : Color.cvAmber)
                Text(compatibilityText)
                    .font(.cvMono(10))
                    .foregroundStyle(isCompatible ? Color.cvGreen : Color.cvAmber)
            }
            .animation(.easeInOut(duration: 0.18), value: isCompatible)

            customQEMUSection
        }
    }

    private func optionCard(title: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(selected ? Color.cvAmber : Color.cvSecondary)
                    .frame(height: 26)
                    .animation(.spring(response: 0.22), value: selected)
                Text(title)
                    .font(.cvRound(11, weight: .semibold))
                    .foregroundStyle(selected ? Color.cvPrimary : Color.cvSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(selected ? Color.cvAmber.opacity(0.10) : Color.cvSurface)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(selected ? Color.cvAmber.opacity(0.45) : Color.cvBorder, lineWidth: selected ? 1.5 : 1)
                    .animation(.spring(response: 0.22), value: selected)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(CVScaleButtonStyle())
    }

    private var customQEMUSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CUSTOM QEMU BINARY")
                .font(.cvMono(8, weight: .bold))
                .foregroundStyle(Color.cvDim)
                .kerning(1)
            HStack(spacing: 7) {
                TextField("/path/to/qemu-system-aarch64", text: $customQEMUPathInput)
                    .font(.cvMono(10))
                    .foregroundStyle(Color.cvPrimary)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color.cvSurfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.cvBorder))
                Button("Browse") {
                    if let p = pickFilePath(title: "Select QEMU Binary") { customQEMUPathInput = p }
                }.font(.cvMono(9, weight: .bold)).buttonStyle(CVScaleButtonStyle()).foregroundStyle(Color.cvSecondary)
            }
            HStack(spacing: 6) {
                Button("Set") {
                    manager.setCustomQEMUBinaryPath(customQEMUPathInput)
                    Task { await manager.refreshRuntimeData() }
                }
                .disabled(customQEMUPathInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Clear") {
                    customQEMUPathInput = ""
                    manager.clearCustomQEMUBinaryPath()
                    Task { await manager.refreshRuntimeData() }
                }
                .disabled(manager.customQEMUBinaryPath.isEmpty)
                Button("Install VirGL…") { installVirGLBundleFromPicker() }
            }
            .font(.cvMono(9, weight: .bold))
            .foregroundStyle(Color.cvSecondary)
            .buttonStyle(CVScaleButtonStyle())
            .disabled(manager.isScanning)

            if let err = manager.lastError {
                cvErrorBanner(err)
            }
        }
        .padding(11)
        .cvPanel()
    }

    // MARK: - Resources step
    private var resourcesStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            CVSectionHeader(title: "VM Identity & Boot")
            VStack(spacing: 7) {
                cvField(label: "VM NAME", placeholder: "My Virtual Machine", text: $draft.name)
                cvField(label: "INSTALLER ISO", placeholder: "/path/to/installer.iso", text: $draft.isoPath) {
                    if let p = pickFilePath(title: "Select Installer", allowedExtensions: ["iso","img"]) { draft.isoPath = p }
                }
                cvField(label: "LINUX KERNEL", placeholder: "/path/to/vmlinuz (optional)", text: $draft.kernelPath) {
                    if let p = pickFilePath(title: "Select Kernel") { draft.kernelPath = p }
                }
                cvField(label: "INITRD", placeholder: "/path/to/initrd.img (optional)", text: $draft.ramdiskPath) {
                    if let p = pickFilePath(title: "Select Initrd") { draft.ramdiskPath = p }
                }
                cvField(label: "KERNEL CMDLINE", placeholder: "console=hvc0", text: $draft.kernelCommandLine)
            }
            .padding(11)
            .cvPanel()

            CVSectionHeader(title: "Resources")
            HStack(spacing: 8) {
                resourceSlider(
                    label: "CPU CORES", icon: "cpu",
                    value: Binding(get: { Double(draft.cpuCores) }, set: { draft.cpuCores = Int($0) }),
                    range: 1...Double(hostCPUCoreLimit),
                    display: "\(draft.cpuCores)",
                    color: .cvAmber
                )
                resourceSlider(
                    label: "MEMORY", icon: "memorychip",
                    value: Binding(get: { Double(draft.memoryGB) }, set: { draft.memoryGB = Int($0) }),
                    range: 2...64, display: "\(draft.memoryGB) GB",
                    color: .cvBlue
                )
                resourceSlider(
                    label: "DISK", icon: "internaldrive",
                    value: Binding(get: { Double(draft.diskGB) }, set: { draft.diskGB = Int($0) }),
                    range: 20...512, display: "\(draft.diskGB) GB",
                    color: .cvGreen
                )
            }

            if !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    advance()
                } label: {
                    HStack(spacing: 7) {
                        Text("CONTINUE TO DISPLAY")
                            .font(.cvMono(10, weight: .bold))
                            .kerning(0.8)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(Color.cvBackground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.cvAmber)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(CVScaleButtonStyle())
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: draft.name.isEmpty)
            }
        }
    }

    private func cvField(label: String, placeholder: String, text: Binding<String>, browse: (() -> Void)? = nil) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.cvMono(8, weight: .bold))
                .foregroundStyle(Color.cvDim)
                .kerning(0.8)
                .frame(width: 96, alignment: .trailing)
            HStack(spacing: 6) {
                TextField(placeholder, text: text)
                    .font(.cvMono(10))
                    .foregroundStyle(Color.cvPrimary)
                    .textFieldStyle(.plain)
                if let browse {
                    Button("…", action: browse)
                        .font(.cvMono(11, weight: .bold))
                        .foregroundStyle(Color.cvSecondary)
                        .buttonStyle(CVScaleButtonStyle())
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.cvSurfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.cvBorder))
        }
    }

    private func resourceSlider(label: String, icon: String, value: Binding<Double>, range: ClosedRange<Double>, display: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.cvDim)
                Text(label).font(.cvMono(8, weight: .bold)).foregroundStyle(Color.cvDim).kerning(0.8)
            }
            Text(display)
                .font(.cvMono(20, weight: .bold))
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Slider(value: value, in: range, step: 1).tint(color)
        }
        .padding(11)
        .frame(maxWidth: .infinity)
        .cvPanel(accent: color)
    }

    // MARK: - Display step
    private var displayStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            CVSectionHeader(title: "Display & Audio")
            HStack(spacing: 8) {
                toggleTile(title: "VirGL GPU", subtitle: "OpenGL acceleration", icon: "display",
                           isOn: $draft.enableVirGL, disabled: draft.backend != .qemu)
                toggleTile(title: "Audio", subtitle: "Sound output", icon: "speaker.wave.2",
                           isOn: $draft.enableSound, disabled: false)
            }
            if draft.backend == .qemu && !manager.qemuSupportsOpenGL {
                cvInfoNote("OpenGL not detected for this QEMU build. VirGL may fail at launch.")
            }

            CVSectionHeader(title: "USB Passthrough")
            if manager.usbDevices.isEmpty {
                cvInfoNote("No QEMU USB devices detected.")
            } else {
                LazyVStack(spacing: 5) {
                    ForEach(manager.usbDevices) { device in
                        usbDeviceRow(device)
                    }
                }
                .padding(8)
                .cvPanel()
            }

            Button {
                advance()
            } label: {
                HStack(spacing: 7) {
                    Text("REVIEW & CREATE")
                        .font(.cvMono(10, weight: .bold))
                        .kerning(0.8)
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Color.cvBackground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.cvGreen)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(CVScaleButtonStyle())
        }
    }

    private func toggleTile(title: String, subtitle: String, icon: String, isOn: Binding<Bool>, disabled: Bool) -> some View {
        Button {
            if !disabled { withAnimation(.spring(response: 0.24)) { isOn.wrappedValue.toggle() } }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isOn.wrappedValue && !disabled ? Color.cvAmber : Color.cvSecondary)
                    .frame(width: 24)
                    .animation(.spring(response: 0.2), value: isOn.wrappedValue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.cvRound(12, weight: .semibold))
                        .foregroundStyle(disabled ? Color.cvDim : Color.cvPrimary)
                    Text(subtitle)
                        .font(.cvMono(9))
                        .foregroundStyle(Color.cvDim)
                }
                Spacer()
                Toggle("", isOn: isOn).labelsHidden().disabled(disabled).allowsHitTesting(false)
                    .tint(Color.cvAmber)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(isOn.wrappedValue && !disabled ? Color.cvAmber.opacity(0.09) : Color.cvSurface)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(isOn.wrappedValue && !disabled ? Color.cvAmber.opacity(0.38) : Color.cvBorder, lineWidth: isOn.wrappedValue ? 1.5 : 1)
            )
        }
        .buttonStyle(CVScaleButtonStyle())
        .disabled(disabled)
    }

    private func usbDeviceRow(_ device: QEMUUSBDevice) -> some View {
        let selected = draft.selectedUSBDeviceIDs.contains(device.id)
        return Button {
            withAnimation(.spring(response: 0.22)) {
                if selected { draft.selectedUSBDeviceIDs.remove(device.id) }
                else { draft.selectedUSBDeviceIDs.insert(device.id) }
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(selected ? Color.cvAmber : Color.cvDim)
                    .animation(.spring(response: 0.2), value: selected)
                VStack(alignment: .leading, spacing: 1) {
                    Text(device.name).font(.cvMono(10, weight: .bold)).foregroundStyle(Color.cvPrimary)
                    if !device.detail.isEmpty {
                        Text(device.detail).font(.cvMono(8)).foregroundStyle(Color.cvDim)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(selected ? Color.cvAmber.opacity(0.07) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Review step
    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Summary chips
            HStack(spacing: 6) {
                reviewChip(label: "GUEST", value: draft.guest.rawValue.uppercased(), color: .cvAmber)
                reviewChip(label: "BACKEND", value: draft.backend.rawValue == "QEMU" ? "QEMU" : "APPLE VIRT", color: .cvBlue)
                reviewChip(label: "CPU", value: "\(draft.cpuCores) CORE", color: .cvGreen)
                reviewChip(label: "RAM", value: "\(draft.memoryGB) GB", color: .cvGreen)
                reviewChip(label: "DISK", value: "\(draft.diskGB) GB", color: .cvGreen)
            }

            CVSectionHeader(title: "Command Preview")
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Spacer()
                    Button {
                        copyToPasteboard(manager.commandPreview(for: draft))
                    } label: {
                        Label("COPY", systemImage: "doc.on.doc")
                            .font(.cvMono(8, weight: .bold))
                            .kerning(0.5)
                    }
                    .foregroundStyle(Color.cvSecondary)
                    .buttonStyle(CVScaleButtonStyle())
                }
                ScrollView {
                    Text(manager.commandPreview(for: draft))
                        .font(.cvMono(9))
                        .foregroundStyle(Color.cvGreen)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(height: 140)
                .background(Color.black.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cvGreen.opacity(0.20)))
            }

            if let reason = createBlockedReason {
                cvErrorBanner(reason)
            }

            HStack(spacing: 8) {
                Button {
                    Task { await manager.createMachine(from: draft) }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("CREATE VM")
                            .font(.cvMono(10, weight: .bold))
                            .kerning(1)
                    }
                    .foregroundStyle(canCreateVM ? Color.cvBackground : Color.cvDim)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(canCreateVM ? Color.cvAmber : Color.cvSurfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(CVScaleButtonStyle())
                .disabled(!canCreateVM)
                .keyboardShortcut(.return, modifiers: [.command])

                if let script = manager.guestPasteScript(for: draft.guest) {
                    Button {
                        copyToPasteboard(script)
                    } label: {
                        Label("COPY GUEST SCRIPT", systemImage: "doc.text")
                            .font(.cvMono(9, weight: .bold))
                            .kerning(0.5)
                    }
                    .foregroundStyle(Color.cvSecondary)
                    .buttonStyle(CVScaleButtonStyle())
                }
            }
        }
    }

    private func reviewChip(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.cvMono(10, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.cvMono(7, weight: .bold))
                .foregroundStyle(Color.cvDim)
                .kerning(0.5)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(color.opacity(0.22)))
    }

    // MARK: - Bottom bar
    private var bottomBar: some View {
        HStack {
            if step > 0 {
                Button {
                    goTo(step - 1)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left").font(.system(size: 9, weight: .bold))
                        Text("BACK").font(.cvMono(9, weight: .bold)).kerning(0.8)
                    }
                    .foregroundStyle(Color.cvSecondary)
                    .padding(.horizontal, 11).padding(.vertical, 6)
                    .background(Color.cvSurfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.cvBorder))
                }
                .buttonStyle(CVScaleButtonStyle())
                .disabled(manager.isScanning)
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
            Spacer()
            if step == stepTitles.count - 1 {
                Button {
                    dismiss()
                } label: {
                    Text("DONE")
                        .font(.cvMono(9, weight: .bold))
                        .kerning(1)
                        .foregroundStyle(Color.cvBackground)
                        .padding(.horizontal, 16).padding(.vertical, 6)
                        .background(Color.cvAmber)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(CVScaleButtonStyle())
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: step)
    }

    // MARK: - Sidebar
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Logo strip
            HStack(spacing: 7) {
                Image(systemName: "server.rack")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.cvAmber)
                Text("SAVED MACHINES")
                    .font(.cvMono(9, weight: .bold))
                    .foregroundStyle(Color.cvAmber)
                    .kerning(1.5)
                Spacer()
                if manager.isScanning {
                    ProgressView().controlSize(.mini).tint(Color.cvAmber)
                }
            }

            // Search
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass").font(.system(size: 10)).foregroundStyle(Color.cvDim)
                TextField("Filter", text: $machineSearchQuery)
                    .font(.cvMono(10))
                    .foregroundStyle(Color.cvPrimary)
                    .textFieldStyle(.plain)
                if !machineSearchQuery.isEmpty {
                    Button { machineSearchQuery = "" } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 11)).foregroundStyle(Color.cvDim)
                    }.buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.cvSurfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.cvBorder))

            // Start All / Stop All
            if manager.machines.contains(where: { [.stopped, .error].contains(manager.runtimeState(for: $0)) }) {
                Button {
                    Task {
                        await manager.startAllMachines()
                    }
                } label: {
                    Label("START ALL", systemImage: "play.fill")
                        .font(.cvMono(8, weight: .bold)).kerning(0.5)
                        .foregroundStyle(Color.cvBackground)
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                        .background(Color.cvGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(CVScaleButtonStyle()).disabled(manager.isScanning)
            }

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 6) {
                    if filteredMachines.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "server.rack")
                                .font(.system(size: 22, weight: .ultraLight))
                                .foregroundStyle(Color.cvDim)
                            Text("NO VMS YET")
                                .font(.cvMono(9, weight: .bold))
                                .foregroundStyle(Color.cvDim)
                                .kerning(1)
                        }
                        .frame(maxWidth: .infinity).padding(.top, 28)
                    } else {
                        ForEach(filteredMachines) { machine in
                            sidebarCard(machine)
                        }
                    }
                }
            }
        }
        .padding(13)
        .background(Color.cvBackground)
    }

    private func sidebarCard(_ machine: CoreVisorMachine) -> some View {
        let state = manager.runtimeState(for: machine)
        return VStack(alignment: .leading, spacing: 8) {
            // Name + state
            HStack(spacing: 6) {
                Circle()
                    .fill(stateColor(state))
                    .frame(width: 6, height: 6)
                Text(machine.name)
                    .font(.cvRound(11, weight: .bold))
                    .foregroundStyle(Color.cvPrimary)
                    .lineLimit(1)
                Spacer()
                Text(state.rawValue.uppercased())
                    .font(.cvMono(7, weight: .bold))
                    .foregroundStyle(stateColor(state))
                    .kerning(0.6)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(stateColor(state).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            Text("\(machine.guest.rawValue.uppercased())  ·  \(machine.backend.rawValue.uppercased())")
                .font(.cvMono(8, weight: .bold))
                .foregroundStyle(Color.cvDim)
                .kerning(0.5)

            // Primary actions
            HStack(spacing: 5) {
                Button("EDIT") { openEditVMWindow(for: machine) }
                    .disabled(manager.isScanning || [.running, .starting, .stopping].contains(state))

                if [.running, .starting].contains(state) {
                    Button("STOP") { manager.stopMachine(machine) }
                        .foregroundStyle(Color.cvAmber)
                        .disabled(state == .stopping)
                } else {
                    Button("START") {
                        Task { await manager.startMachine(machine) }
                    }
                    .foregroundStyle(Color.cvGreen)
                    .disabled(manager.isScanning)
                }

                Button("DEL") { pendingDeleteMachine = machine }
                    .foregroundStyle(Color.cvRed)
                    .disabled(manager.isScanning)
            }
            .font(.cvMono(8, weight: .bold))
            .buttonStyle(.plain)
            .padding(.horizontal, 7).padding(.vertical, 5)
            .background(Color.cvSurfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.cvBorder))

            // Secondary actions
            HStack(spacing: 5) {
                Button("DUP") { Task { await manager.duplicateMachine(machine) } }
                    .disabled(manager.isScanning || [.running, .starting, .stopping].contains(state))
                Button("BUNDLE") { manager.openMachineBundle(machine) }
                if let script = manager.guestPasteScript(for: machine.guest) {
                    Button("SCRIPT") { copyToPasteboard(script) }
                }
            }
            .font(.cvMono(8, weight: .bold))
            .foregroundStyle(Color.cvDim)
            .buttonStyle(.plain)

            // Error banner
            if let err = manager.lastError {
                HStack(alignment: .top, spacing: 5) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Color.cvAmber)
                        .padding(.top, 1)
                    Text(err)
                        .font(.cvMono(8))
                        .foregroundStyle(Color.cvAmber)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(7)
                .background(Color.cvAmber.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.cvAmber.opacity(0.18)))
            }

            // Log
            let log = manager.runtimeLog(for: machine)
            if !log.isEmpty {
                HStack(spacing: 5) {
                    Button("COPY LOG") { copyToPasteboard(log) }
                    Button("CLEAR") { manager.clearRuntimeLog(for: machine) }
                        .disabled([.running, .starting].contains(state))
                }
                .font(.cvMono(7, weight: .bold))
                .foregroundStyle(Color.cvDim)
                .buttonStyle(.plain)

                ScrollView {
                    Text(log)
                        .font(.cvMono(8))
                        .foregroundStyle(Color.cvGreen.opacity(0.8))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(7)
                }
                .frame(height: 70)
                .background(Color.black.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.cvGreen.opacity(0.14)))
            }
        }
        .padding(10)
        .background(Color.cvSurface)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(stateColor(state).opacity(state == .running ? 0.25 : 0.0).combined(with: Color.cvBorder.opacity(0.9)), lineWidth: 1))
    }

    private func stateColor(_ state: CoreVisorRuntimeState) -> Color {
        switch state {
        case .stopped: return Color.cvDim
        case .starting, .stopping: return Color.cvAmber
        case .running: return Color.cvGreen
        case .error: return Color.cvRed
        }
    }

    // MARK: - Entitlement overlay
    private var entitlementOverlay: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.shield.fill").font(.system(size: 20)).foregroundStyle(Color.cvAmber)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ENTITLEMENT MISSING")
                            .font(.cvMono(12, weight: .bold))
                            .foregroundStyle(Color.cvAmber)
                            .kerning(1)
                        Text("Apple Virtualization VMs cannot start without com.apple.security.virtualization.")
                            .font(.cvRound(11))
                            .foregroundStyle(Color.cvSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    ForEach([
                        "1. Quit Core Monitor.",
                        "2. In Xcode, open Signing & Capabilities.",
                        "3. Enable App Sandbox, add com.apple.security.virtualization.",
                        "4. Rebuild and reinstall, then press Recheck.",
                        "5. Or use QEMU backend as a fallback."
                    ], id: \.self) { step in
                        HStack(alignment: .top, spacing: 8) {
                            Rectangle().fill(Color.cvAmber).frame(width: 2, height: 11).padding(.top, 3)
                            Text(step).font(.cvRound(11)).foregroundStyle(Color.cvSecondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(11)
                .background(Color.cvSurfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.cvBorder))

                Text("Sandbox: \(manager.isAppSandboxed ? "ON" : "OFF")  ·  Virtualization: \(manager.hasVirtualizationEntitlement ? "PRESENT" : "MISSING")")
                    .font(.cvMono(9))
                    .foregroundStyle(Color.cvDim)
                    .padding(8)
                    .background(Color.black.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                HStack {
                    Button("SKIP") {
                        withAnimation(.spring(response: 0.3)) { showEntitlementGuide = false }
                    }
                    .font(.cvMono(9, weight: .bold)).foregroundStyle(Color.cvSecondary)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Color.cvSurfaceRaised).clipShape(RoundedRectangle(cornerRadius: 6))
                    .buttonStyle(CVScaleButtonStyle())

                    Spacer()

                    Button("RECHECK") {
                        manager.refreshEntitlementStatus()
                        withAnimation(.spring(response: 0.3)) {
                            showEntitlementGuide = manager.requiresVirtualizationEntitlement
                        }
                    }
                    .font(.cvMono(9, weight: .bold)).foregroundStyle(Color.cvBackground)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Color.cvAmber).clipShape(RoundedRectangle(cornerRadius: 6))
                    .buttonStyle(CVScaleButtonStyle())
                }
            }
            .padding(18)
            .frame(width: 520)
            .background(Color.cvSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cvAmber.opacity(0.25)))
        }
    }

    // MARK: - Shared UI helpers
    private func cvErrorBanner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(Color.cvAmber)
                .padding(.top, 1)
            Text(text)
                .font(.cvMono(9))
                .foregroundStyle(Color.cvAmber)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(9)
        .background(Color.cvAmber.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.cvAmber.opacity(0.22)))
    }

    private func cvInfoNote(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle").font(.system(size: 10)).foregroundStyle(Color.cvDim)
            Text(text).font(.cvMono(9)).foregroundStyle(Color.cvDim)
        }
        .padding(9)
        .background(Color.cvSurfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.cvBorder))
    }

    // MARK: - Validation
    private var isCompatible: Bool { manager.isBackendSupported(draft.backend, for: draft.guest) }
    private var filteredMachines: [CoreVisorMachine] {
        let q = machineSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return manager.machines }
        return manager.machines.filter { $0.name.lowercased().contains(q) || $0.guest.rawValue.lowercased().contains(q) }
    }
    private var canCreateVM: Bool { createBlockedReason == nil }
    private var createBlockedReason: String? {
        if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Enter a VM name." }
        if !isCompatible { return compatibilityText }
        if !hasValidPathInputs { return "One or more file paths do not exist." }
        if requiresLinuxBootInputs && !hasAnyLinuxBootInput { return "Linux boot requires a kernel path or ISO." }
        if draft.cpuCores > hostCPUCoreLimit { return "CPU cores exceed host limit (\(hostCPUCoreLimit))." }
        if draft.memoryGB > hostMemoryLimitGB { return "Memory exceeds safe host limit (\(hostMemoryLimitGB) GB)." }
        return nil
    }
    private var hostCPUCoreLimit: Int { max(1, ProcessInfo.processInfo.activeProcessorCount) }
    private var hostMemoryLimitGB: Int { let gb = Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824); return max(2, gb - 1) }
    private var requiresLinuxBootInputs: Bool { draft.backend == .appleVirtualization && draft.guest == .linux }
    private var hasAnyLinuxBootInput: Bool {
        !draft.kernelPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !draft.isoPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var hasValidPathInputs: Bool { isPathOK(draft.isoPath) && isPathOK(draft.kernelPath) && isPathOK(draft.ramdiskPath) }
    private func isPathOK(_ path: String) -> Bool {
        let t = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return true }
        return FileManager.default.fileExists(atPath: t)
    }
    private var compatibilityText: String {
        if isCompatible { return "Backend supports this guest." }
        if draft.backend == .appleVirtualization && manager.requiresVirtualizationEntitlement { return "Enable com.apple.security.virtualization." }
        if draft.backend == .appleVirtualization { return "Apple Virtualization supports Linux only." }
        return "QEMU backend requires a detected binary."
    }
    private func iconFor(guest: VMGuestType) -> String {
        switch guest {
        case .linux: return "terminal"
        case .windows: return "window.casement"
        case .macOS: return "apple.logo"
        case .netBSD, .unix: return "server.rack"
        }
    }

    // MARK: - Pasteboard + file pickers
    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    private func pickFilePath(title: String, prompt: String = "Choose", allowedExtensions: [String] = []) -> String? {
        let panel = NSOpenPanel()
        panel.title = title; panel.prompt = prompt
        panel.canChooseFiles = true; panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false; panel.treatsFilePackagesAsDirectories = false
        if !allowedExtensions.isEmpty {
            let types = allowedExtensions.compactMap { UTType(filenameExtension: $0) }
            if !types.isEmpty { panel.allowedContentTypes = types }
        }
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return url.path
    }
    private func importUTMBundleFromPicker() {
        let panel = NSOpenPanel()
        panel.title = "Import UTM VM"; panel.prompt = "Import"
        panel.canChooseFiles = true; panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false; panel.treatsFilePackagesAsDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard url.pathExtension.lowercased() == "utm" else { manager.lastError = "Please select a .utm bundle."; return }
        Task { await manager.importUTMBundle(at: url) }
    }
    private func installVirGLBundleFromPicker() {
        let panel = NSOpenPanel()
        panel.title = "Install VirGL Bundle"; panel.prompt = "Install"
        panel.canChooseFiles = false; panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false; panel.treatsFilePackagesAsDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await manager.installVirGLBundle(from: url) }
    }
    private func openEditVMWindow(for machine: CoreVisorMachine) {
        if let existing = editWindowControllers[machine.id] {
            existing.showWindow(nil); existing.window?.makeKeyAndOrderFront(nil); return
        }
        var controller: NSWindowController?
        let rootView = CoreVisorEditVMWindowView(manager: manager, machineID: machine.id) { controller?.close() }
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 220, y: 160, width: 780, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = "Edit VM — \(machine.name)"
        window.contentViewController = hostingController
        window.minSize = NSSize(width: 700, height: 540)
        window.appearance = NSAppearance(named: .darkAqua)
        let newController = NSWindowController(window: window)
        controller = newController
        editWindowControllers[machine.id] = newController
        editWindowCloseObservers[machine.id] = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { _ in
            if let o = editWindowCloseObservers[machine.id] { NotificationCenter.default.removeObserver(o); editWindowCloseObservers[machine.id] = nil }
            editWindowControllers[machine.id] = nil
        }
        newController.showWindow(nil); newController.window?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Color stroke combined helper
private extension Color {
    func combined(with other: Color) -> Color { self }  // placeholder — use actual color in overlay
}

// MARK: - Edit VM Window (same industrial aesthetic)
private struct CoreVisorEditVMWindowView: View {
    @ObservedObject var manager: CoreVisorManager
    let machineID: UUID
    let onClose: () -> Void

    @State private var draft = CoreVisorDraft()
    @State private var loadedMachine: CoreVisorMachine?
    @State private var isSaving = false

    var body: some View {
        ZStack {
            Color.cvBackground.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("EDIT VIRTUAL MACHINE")
                            .font(.cvMono(9, weight: .bold))
                            .foregroundStyle(Color.cvAmber)
                            .kerning(1.5)
                        Text(loadedMachine?.name ?? "")
                            .font(.cvRound(16, weight: .bold))
                            .foregroundStyle(Color.cvPrimary)
                    }
                    Spacer()
                    Button("RELOAD") { loadMachine() }
                        .font(.cvMono(8, weight: .bold))
                        .foregroundStyle(Color.cvSecondary)
                        .disabled(isSaving)
                }
                .padding(12)
                .background(Color.cvSurface)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.cvBorder))

                if loadedMachine == nil {
                    Text("VM not found.")
                        .font(.cvMono(10))
                        .foregroundStyle(Color.cvAmber)
                        .padding(12)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 11) {
                            editField("VM NAME", placeholder: "VM Name", text: $draft.name)

                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("GUEST OS").font(.cvMono(8, weight: .bold)).foregroundStyle(Color.cvDim).kerning(1)
                                    Picker("Guest", selection: $draft.guest) {
                                        ForEach(VMGuestType.allCases.filter { $0 != .macOS }) { Text($0.rawValue).tag($0) }
                                    }.pickerStyle(.segmented)
                                }
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("BACKEND").font(.cvMono(8, weight: .bold)).foregroundStyle(Color.cvDim).kerning(1)
                                    Picker("Backend", selection: $draft.backend) {
                                        ForEach(VMBackend.allCases) { Text($0.rawValue).tag($0) }
                                    }.pickerStyle(.segmented)
                                }
                            }

                            Text(compatibilityText)
                                .font(.cvMono(9))
                                .foregroundStyle(isCompatible ? Color.cvGreen : Color.cvAmber)

                            editField("INSTALLER ISO", placeholder: "/path/to/installer.iso", text: $draft.isoPath) {
                                pickFile(title: "Select Installer", exts: ["iso","img"]) { draft.isoPath = $0 }
                            }
                            editField("LINUX KERNEL", placeholder: "/path/to/vmlinuz (optional)", text: $draft.kernelPath) {
                                pickFile(title: "Select Kernel") { draft.kernelPath = $0 }
                            }
                            editField("INITRD", placeholder: "/path/to/initrd.img (optional)", text: $draft.ramdiskPath) {
                                pickFile(title: "Select Initrd") { draft.ramdiskPath = $0 }
                            }
                            editField("KERNEL CMDLINE", placeholder: "console=hvc0", text: $draft.kernelCommandLine)

                            HStack(spacing: 8) {
                                editSlider("CPU", value: Binding(get: { Double(draft.cpuCores) }, set: { draft.cpuCores = Int($0) }), range: 1...16, display: "\(draft.cpuCores) cores", color: .cvAmber)
                                editSlider("RAM", value: Binding(get: { Double(draft.memoryGB) }, set: { draft.memoryGB = Int($0) }), range: 2...64, display: "\(draft.memoryGB) GB", color: .cvBlue)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("DISK").font(.cvMono(8, weight: .bold)).foregroundStyle(Color.cvDim).kerning(1)
                                    Text("\(loadedMachine?.diskGB ?? draft.diskGB) GB").font(.cvMono(16, weight: .bold)).foregroundStyle(Color.cvGreen)
                                    Text("Resize disabled").font(.cvMono(8)).foregroundStyle(Color.cvDim)
                                }
                                .padding(10).frame(maxWidth: .infinity).background(Color.cvSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.cvBorder))
                            }

                            Toggle("Enable VirGL (QEMU)", isOn: $draft.enableVirGL)
                                .disabled(draft.backend != .qemu)
                                .tint(Color.cvAmber)
                                .font(.cvRound(12))
                                .foregroundStyle(Color.cvPrimary)

                            Toggle("Enable audio", isOn: $draft.enableSound)
                                .tint(Color.cvAmber)
                                .font(.cvRound(12))
                                .foregroundStyle(Color.cvPrimary)

                            Text("USB DEVICES").font(.cvMono(8, weight: .bold)).foregroundStyle(Color.cvDim).kerning(1)
                            LazyVStack(spacing: 5) {
                                if manager.usbDevices.isEmpty {
                                    Text("No QEMU USB devices detected.").font(.cvMono(9)).foregroundStyle(Color.cvDim)
                                } else {
                                    ForEach(manager.usbDevices) { device in
                                        Toggle(isOn: Binding(
                                            get: { draft.selectedUSBDeviceIDs.contains(device.id) },
                                            set: { on in if on { draft.selectedUSBDeviceIDs.insert(device.id) } else { draft.selectedUSBDeviceIDs.remove(device.id) } }
                                        )) {
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(device.name).font(.cvMono(10, weight: .bold)).foregroundStyle(Color.cvPrimary)
                                                if !device.detail.isEmpty { Text(device.detail).font(.cvMono(8)).foregroundStyle(Color.cvDim) }
                                            }
                                        }
                                        .tint(Color.cvAmber)
                                    }
                                }
                            }
                            .padding(8)
                            .background(Color.cvSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.cvBorder))
                        }
                        .padding(12)
                    }
                    .background(Color.cvSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.cvBorder))

                    HStack {
                        Button("CANCEL") { onClose() }
                            .font(.cvMono(9, weight: .bold)).foregroundStyle(Color.cvSecondary)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Color.cvSurfaceRaised).clipShape(RoundedRectangle(cornerRadius: 6))
                            .disabled(isSaving)

                        Spacer()

                        Button("SAVE CHANGES") { saveChanges() }
                            .font(.cvMono(9, weight: .bold)).foregroundStyle(Color.cvBackground)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(canSave && !isSaving ? Color.cvAmber : Color.cvDim)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .disabled(!canSave || isSaving)
                    }
                }

                if let err = manager.lastError {
                    Text(err).font(.cvMono(9)).foregroundStyle(Color.cvAmber)
                        .padding(8).background(Color.cvAmber.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
            }
            .padding(14)
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 700, minHeight: 540)
        .onAppear { loadMachine() }
    }

    private func editField(_ label: String, placeholder: String, text: Binding<String>, browse: (() -> Void)? = nil) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.cvMono(7, weight: .bold)).foregroundStyle(Color.cvDim).kerning(0.8)
                .frame(width: 88, alignment: .trailing)
            HStack(spacing: 5) {
                TextField(placeholder, text: text)
                    .font(.cvMono(9)).foregroundStyle(Color.cvPrimary).textFieldStyle(.plain)
                if let browse {
                    Button("…", action: browse).font(.cvMono(11, weight: .bold)).foregroundStyle(Color.cvSecondary).buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 7).padding(.vertical, 5)
            .background(Color.cvSurfaceRaised).clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.cvBorder))
        }
    }

    private func editSlider(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, display: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).font(.cvMono(8, weight: .bold)).foregroundStyle(Color.cvDim).kerning(0.8)
            Text(display).font(.cvMono(16, weight: .bold)).foregroundStyle(color).contentTransition(.numericText())
            Slider(value: value, in: range, step: 1).tint(color)
        }
        .padding(10).frame(maxWidth: .infinity)
        .background(Color.cvSurface).clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.cvBorder))
    }

    private func pickFile(title: String, exts: [String] = [], completion: (String) -> Void) {
        let panel = NSOpenPanel()
        panel.title = title; panel.canChooseFiles = true; panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false; panel.treatsFilePackagesAsDirectories = false
        if !exts.isEmpty, let types = Optional(exts.compactMap { UTType(filenameExtension: $0) }), !types.isEmpty {
            panel.allowedContentTypes = types
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        completion(url.path)
    }

    private var isCompatible: Bool { manager.isBackendSupported(draft.backend, for: draft.guest) }
    private var canSave: Bool { validationError == nil }
    private var validationError: String? {
        if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Enter a VM name." }
        if !isCompatible { return compatibilityText }
        return nil
    }
    private var compatibilityText: String {
        if isCompatible { return "Backend supports this guest." }
        if draft.backend == .appleVirtualization { return "Apple Virtualization supports Linux only." }
        return "QEMU requires a detected binary."
    }
    private func saveChanges() {
        guard let machine = manager.machines.first(where: { $0.id == machineID }), validationError == nil else { return }
        isSaving = true
        Task {
            await manager.updateMachine(machine, from: draft)
            let failed = manager.lastError != nil
            await MainActor.run { isSaving = false; if !failed { onClose() } }
        }
    }
    private func loadMachine() {
        guard let machine = manager.machines.first(where: { $0.id == machineID }) else { loadedMachine = nil; return }
        loadedMachine = machine; draft = manager.draft(from: machine)
    }
}

// MARK: - Font helpers available in extension scope
private func cvMono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
    .system(size: size, weight: weight, design: .monospaced)
}
private func cvRound(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
    .system(size: size, weight: weight, design: .rounded)
}
