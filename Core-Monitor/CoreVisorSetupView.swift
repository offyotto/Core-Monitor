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
                .cmKerning(1.4)
            Spacer()
        }
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
    @State private var showEntitlementGuide = false
    @State private var customQEMUPathInput = ""
    @State private var pendingDeleteMachine: CoreVisorMachine?
    @State private var machineSearchQuery = ""
    @State private var editWindowControllers: [UUID: NSWindowController] = [:]
    @State private var editWindowCloseObservers: [UUID: NSObjectProtocol] = [:]
    @State private var wizardVirtioDownloading = false
    @State private var wizardVirtioProgress: Double = 0
    @State private var showDoItForMe = false
    // Lazily populated on first use so we can pass the real manager reference
    @State private var doItForMeMgr: DoItForMeManager? = nil

    private let stepTitles = ["Template", "Backend", "Resources", "Display", "Review"]
    private var direction: Int { step > previousStep ? 1 : -1 }
    private var stepTransition: AnyTransition {
        let insertionEdge: Edge = direction > 0 ? .trailing : .leading
        let removalEdge: Edge = direction > 0 ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: insertionEdge)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.985, anchor: .center)),
            removal: .move(edge: removalEdge)
                .combined(with: .opacity)
        )
    }

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
                        ZStack {
                            ForEach([step], id: \.self) { idx in
                                stepPage(for: idx)
                                    .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                                    .id(idx)
                                    .transition(stepTransition)
                            }
                        }
                        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: step)
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
        .onChange(of: manager.customQEMUBinaryPath) { v in customQEMUPathInput = v }
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
        CVScanLinePattern()
            .stroke(Color.white.opacity(0.016), lineWidth: 1)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Navigation
    private func advance() {
        guard step < stepTitles.count - 1 else { return }
        goTo(step + 1)
    }

    private func goTo(_ idx: Int) {
        guard idx != step else { return }
        previousStep = step
        withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
            step = idx
        }
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
                        .cmKerning(2)
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
            cvActionButton("Import Disk Image", icon: "externaldrive.badge.plus") { importDiskImageFromPicker() }
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
                    .cmKerning(0.3)
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
                            Text("\(idx + 1)")
                                .font(.cvMono(8, weight: .bold))
                                .foregroundStyle(idx == step ? Color.cvBackground : Color.cvDim)
                        }
                        Text(title.uppercased())
                            .font(.cvMono(9, weight: .bold))
                            .foregroundStyle(idx == step ? Color.cvPrimary : Color.cvDim)
                            .cmKerning(0.6)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(idx == step ? Color.cvAmber.opacity(0.10) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(idx == step ? Color.cvAmber.opacity(0.30) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                if idx < stepTitles.count - 1 {
                    Rectangle()
                        .fill(idx < step ? Color.cvAmber.opacity(0.4) : Color.cvBorder)
                        .frame(width: 16, height: 1)
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
                    .cmKerning(0.8)
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

            // ── Do It For Me — top-level CTA ────────────────────────────────────
            Button {
                if doItForMeMgr == nil {
                    doItForMeMgr = DoItForMeManager(coreVisorManager: manager)
                }
                showDoItForMe = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.18))
                            .frame(width: 44, height: 44)
                        Image(systemName: "wand.and.stars.inverse")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.85))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("DO IT FOR ME — WINDOWS 11 ARM")
                            .font(.cvMono(9, weight: .bold))
                            .cmKerning(0.7)
                        Text("CoreVisor auto-downloads Windows 11 ARM + VirtIO drivers, creates the VM, and guides you through every setup step")
                            .font(.cvMono(8))
                            .opacity(0.75)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 22))
                        .opacity(0.7)
                }
                .foregroundStyle(Color.cvBackground)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.22, green: 0.92, blue: 0.55),
                                 Color(red: 0.18, green: 0.72, blue: 1.0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(CVScaleButtonStyle())
            .sheet(isPresented: $showDoItForMe) {
                if let mgr = doItForMeMgr {
                    DoItForMeView(doItMgr: mgr, manager: manager, isPresented: $showDoItForMe)
                        .frame(minWidth: 680, minHeight: 420)
                }
            }

            Text("— or pick a template to configure manually —")
                .font(.cvMono(8))
                .foregroundStyle(Color.cvDim)
                .frame(maxWidth: .infinity, alignment: .center)

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
                                .cmKerning(0.8)
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
            .cmKerning(0.5)
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
                .cmKerning(1)
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

            // ── Do It For Me — full-width banner for Windows QEMU guests ─────────
            if draft.guest == .windows && draft.backend == .qemu {
                Button {
                    if doItForMeMgr == nil {
                        doItForMeMgr = DoItForMeManager(coreVisorManager: manager)
                    }
                    showDoItForMe = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "wand.and.stars.inverse")
                            .font(.system(size: 18, weight: .semibold))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("DO IT FOR ME")
                                .font(.cvMono(10, weight: .bold))
                                .cmKerning(0.8)
                            Text("CoreVisor downloads Windows 11 ARM + VirtIO drivers,\ncreates the VM, and walks you through setup step by step")
                                .font(.cvMono(8))
                                .opacity(0.8)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 20))
                            .opacity(0.7)
                    }
                    .foregroundStyle(Color.cvBackground)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.22, green: 0.92, blue: 0.55),
                                     Color(red: 0.18, green: 0.72, blue: 1.0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(CVScaleButtonStyle())
                .sheet(isPresented: $showDoItForMe) {
                    if let mgr = doItForMeMgr {
                        DoItForMeView(doItMgr: mgr, manager: manager, isPresented: $showDoItForMe)
                            .frame(minWidth: 680, minHeight: 420)
                    }
                }

                Text("— or configure manually below —")
                    .font(.cvMono(8))
                    .foregroundStyle(Color.cvDim)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            CVSectionHeader(title: "VM Identity & Boot")
            VStack(spacing: 7) {
                cvField(label: "VM NAME", placeholder: "My Virtual Machine", text: $draft.name)
                cvField(label: "INSTALLER ISO", placeholder: "/path/to/installer.iso", text: $draft.isoPath) {
                    if let p = pickFilePath(title: "Select Installer", allowedExtensions: ["iso","img"]) { draft.isoPath = p }
                }

                // VirtIO drivers ISO — shown for all QEMU guests but highlighted for Windows ARM
                HStack(alignment: .top, spacing: 0) {
                    cvField(label: "VIRTIO DRIVERS", placeholder: "/path/to/virtio-win.iso (Windows ARM)", text: $draft.virtioDriversISOPath) {
                        if let p = pickFilePath(title: "Select VirtIO Drivers ISO", allowedExtensions: ["iso"]) { draft.virtioDriversISOPath = p }
                    }
                }
                if draft.guest == .windows && draft.backend == .qemu && draft.virtioDriversISOPath.isEmpty {
                    virtioDriversBanner
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
                            .cmKerning(0.8)
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
                .cmKerning(0.8)
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
                Text(label).font(.cvMono(8, weight: .bold)).foregroundStyle(Color.cvDim).cmKerning(0.8)
            }
            Text(display)
                .font(.cvMono(20, weight: .bold))
                .foregroundStyle(color)
                .cmNumericTextTransition()
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

            // VirtIO GPU — Windows-only, post-install WDDM 2D acceleration
            if draft.guest == .windows && draft.backend == .qemu {
                HStack(spacing: 8) {
                    toggleTile(
                        title: "VirtIO GPU",
                        subtitle: "WDDM 2D — Aero Glass,\nrounded corners, DWM",
                        icon: "rectangle.3.group",
                        isOn: $draft.enableVirtioGPU,
                        disabled: false
                    )
                    toggleTile(
                        title: "TPM 2.0",
                        subtitle: manager.swtpmAvailable
                            ? "Emulated via swtpm\nSeed in Keychain"
                            : "Install: brew install swtpm",
                        icon: "lock.shield",
                        isOn: $draft.enableTPM,
                        disabled: !manager.swtpmAvailable
                    )
                }
                if draft.enableVirtioGPU {
                    cvInfoNote("VirtIO GPU requires the viogpudo driver from virtio-win. Install after Windows is running via Device Manager → viogpudo\\w11\\ARM64. During setup, keep this OFF — switch to VirtIO GPU once Windows is on the desktop.")
                }
                if draft.enableTPM && !manager.swtpmAvailable {
                    cvInfoNote("⚠︎ swtpm not found. Run: brew install swtpm — then restart CoreVisor.")
                }
            }

            CVSectionHeader(title: "Storage")
            toggleTile(
                title: "Use virtio-blk Storage",
                subtitle: draft.guest == .windows
                    ? "Faster I/O — only safe post-install on Windows ARM (WinPE has no inbox virtio driver)"
                    : "virtio-blk for faster guest I/O",
                icon: "internaldrive",
                isOn: $draft.useVirtioStorage,
                disabled: draft.backend != .qemu
            )
            if draft.guest == .windows && draft.useVirtioStorage {
                cvInfoNote("⚠︎ Windows ARM WinPE has no inbox virtio-blk driver. Enable this only after Windows is fully installed, or driver injection will be needed during setup.")
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
                        .cmKerning(0.8)
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
                            .cmKerning(0.5)
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
                            .cmKerning(1)
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
                            .cmKerning(0.5)
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
                .cmKerning(0.5)
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
                        Text("BACK").font(.cvMono(9, weight: .bold)).cmKerning(0.8)
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
                        .cmKerning(1)
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
                    .cmKerning(1.5)
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
                        .font(.cvMono(8, weight: .bold)).cmKerning(0.5)
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
                                .cmKerning(1)
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
                    .cmKerning(0.6)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(stateColor(state).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            Text("\(machine.guest.rawValue.uppercased())  ·  \(machine.backend.rawValue.uppercased())")
                .font(.cvMono(8, weight: .bold))
                .foregroundStyle(Color.cvDim)
                .cmKerning(0.5)

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
                if state == .running {
                    Button("SNAP") {
                        Task {
                            let tag = "snap-\(Int(Date().timeIntervalSince1970))"
                            await manager.saveSnapshot(name: tag, for: machine)
                        }
                    }
                    .foregroundStyle(Color.cvBlue)
                }
            }
            .font(.cvMono(8, weight: .bold))
            .foregroundStyle(Color.cvDim)
            .buttonStyle(.plain)

            // Snapshot panel (shown when snapshots exist or VM is running)
            snapshotPanel(for: machine, state: state)

            // VirtIO drivers warning for Windows VMs without a drivers ISO
            if machine.guest == .windows && machine.backend == .qemu && machine.virtioDriversISOPath.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 5) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.cvAmber)
                        Text("NO VIRTIO DRIVERS ISO")
                            .font(.cvMono(8, weight: .bold))
                            .foregroundStyle(Color.cvAmber)
                            .cmKerning(0.6)
                    }

                    if let progress = manager.virtioDownloadProgress[machine.id] {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                ProgressView(value: progress)
                                    .tint(Color.cvAmber)
                                    .frame(maxWidth: .infinity)
                                Text("\(Int(progress * 100))%")
                                    .font(.cvMono(8, weight: .bold))
                                    .foregroundStyle(Color.cvAmber)
                                    .frame(width: 32, alignment: .trailing)
                            }
                            Text("Downloading virtio-win.iso…")
                                .font(.cvMono(8))
                                .foregroundStyle(Color.cvSecondary)
                        }
                    } else {
                        Text("WinPE will report \"media driver missing\" without the VirtIO ISO attached. The app can download and mount it automatically on next start.")
                            .font(.cvMono(8))
                            .foregroundStyle(Color.cvSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 5) {
                            Button {
                                Task { await manager.downloadVirtioISO(for: machine) }
                            } label: {
                                Label("AUTO-DOWNLOAD", systemImage: "arrow.down.circle")
                                    .font(.cvMono(7, weight: .bold))
                                    .foregroundStyle(Color.cvAmber)
                            }
                            .buttonStyle(.plain)
                            Button { openEditVMWindow(for: machine) } label: {
                                Label("SET PATH", systemImage: "pencil")
                                    .font(.cvMono(7, weight: .bold))
                                    .foregroundStyle(Color.cvSecondary)
                            }
                            .buttonStyle(.plain)
                            .disabled([.running, .starting, .stopping].contains(state))
                        }
                    }
                }
                .padding(8)
                .background(Color.cvAmber.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.cvAmber.opacity(0.20)))
            }

            // ── Do It For Me — shown for all Windows QEMU VMs when stopped ────────
            if machine.guest == .windows && machine.backend == .qemu
                && [.stopped, .error].contains(state) {
                Button {
                    if doItForMeMgr == nil {
                        doItForMeMgr = DoItForMeManager(coreVisorManager: manager)
                    }
                    showDoItForMe = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars.inverse")
                            .font(.system(size: 11, weight: .semibold))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("DO IT FOR ME")
                                .font(.cvMono(8, weight: .bold))
                                .cmKerning(0.6)
                            Text("Download Win 11 ARM + drivers & guided setup")
                                .font(.cvMono(7))
                                .opacity(0.75)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .opacity(0.5)
                    }
                    .foregroundStyle(Color.cvBackground)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.22, green: 0.92, blue: 0.55),
                                     Color(red: 0.18, green: 0.72, blue: 1.0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(CVScaleButtonStyle())
                .sheet(isPresented: $showDoItForMe) {
                    if let mgr = doItForMeMgr {
                        DoItForMeView(doItMgr: mgr, manager: manager, isPresented: $showDoItForMe)
                            .frame(minWidth: 680, minHeight: 420)
                    }
                }
            }

            // VirtIO drivers ISO mounted + VM running → show step-by-step install guide
            if machine.guest == .windows && machine.backend == .qemu
                && !machine.virtioDriversISOPath.isEmpty && state == .running {
                vioscsiInstallGuide(machine: machine)
            }

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
                            .cmKerning(1)
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

    // MARK: - Snapshot panel
    @ViewBuilder
    private func snapshotPanel(for machine: CoreVisorMachine, state: CoreVisorRuntimeState) -> some View {
        let snapshots = manager.snapshotList(for: machine)
        let busy      = manager.snapshotInProgress[machine.id] == true
        let isRunning = state == .running

        if !snapshots.isEmpty || isRunning {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.cvBlue)
                    Text("SNAPSHOTS")
                        .font(.cvMono(8, weight: .bold))
                        .foregroundStyle(Color.cvBlue)
                        .cmKerning(0.6)
                    Spacer()
                    if busy {
                        ProgressView().scaleEffect(0.55).frame(width: 12, height: 12)
                    }
                    if isRunning && !busy {
                        Button {
                            Task {
                                let tag = "snap-\(Int(Date().timeIntervalSince1970))"
                                await manager.saveSnapshot(name: tag, for: machine)
                            }
                        } label: {
                            Label("SAVE NOW", systemImage: "camera")
                                .font(.cvMono(7, weight: .bold))
                                .foregroundStyle(Color.cvBlue)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if snapshots.isEmpty {
                    Text("No snapshots yet. Click Save Now while VM is running.")
                        .font(.cvMono(8))
                        .foregroundStyle(Color.cvDim)
                } else {
                    ForEach(snapshots, id: \.self) { snap in
                        HStack(spacing: 6) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 8))
                                .foregroundStyle(Color.cvDim)
                            Text(snap)
                                .font(.cvMono(8, weight: .bold))
                                .foregroundStyle(Color.cvPrimary)
                                .lineLimit(1)
                            Spacer()
                            if isRunning && !busy {
                                Button("LOAD") {
                                    Task { await manager.loadSnapshot(name: snap, for: machine) }
                                }
                                .font(.cvMono(7, weight: .bold))
                                .foregroundStyle(Color.cvGreen)
                                .buttonStyle(.plain)
                            }
                            Button("DEL") {
                                Task { await manager.deleteSnapshot(name: snap, for: machine) }
                            }
                            .font(.cvMono(7, weight: .bold))
                            .foregroundStyle(Color.cvRed)
                            .buttonStyle(.plain)
                            .disabled(busy)
                        }
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Color.cvSurfaceRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
            .padding(8)
            .background(Color.cvBlue.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.cvBlue.opacity(0.18)))
            .onAppear {
                Task { await manager.refreshSnapshots(for: machine) }
            }
        }
    }

    // MARK: - vioscsi in-VM install guide (shown while Windows VM is running)
    @ViewBuilder
    private func vioscsiInstallGuide(machine: CoreVisorMachine) -> some View {
        let steps: [(String, String)] = [
            ("1", "When Windows Setup shows \"A media driver your computer needs is missing\" — click Browse."),
            ("2", "In the file browser, find the USB drive (virtio-win). Open it."),
            ("3", "Navigate to  vioscsi › w10 › ARM64  and click OK."),
            ("4", "Select  vioscsi.inf  from the list and click Next."),
            ("5", "The disk now appears. Continue the installation normally."),
            ("6", "After install completes and Windows boots: open Device Manager, find any yellow-flagged devices, and install drivers from the same USB drive."),
        ]
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Image(systemName: "checklist")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.cvGreen)
                Text("VIOSCSI INSTALL GUIDE")
                    .font(.cvMono(8, weight: .bold))
                    .foregroundStyle(Color.cvGreen)
                    .cmKerning(0.6)
                Spacer()
                Button {
                    copyToPasteboard("""
                    vioscsi ARM64 driver path (inside VirtIO USB drive):
                    vioscsi\\w10\\ARM64\\vioscsi.inf

                    Post-install recommended drivers (same USB drive):
                    NetKVM\\w10\\ARM64   (network)
                    Balloon\\w10\\ARM64  (memory balloon)
                    viostor\\w10\\ARM64  (block storage, if using virtio-blk)
                    """)
                } label: {
                    Label("COPY PATHS", systemImage: "doc.on.doc")
                        .font(.cvMono(7, weight: .bold))
                        .foregroundStyle(Color.cvSecondary)
                }
                .buttonStyle(.plain)
            }

            ForEach(steps, id: \.0) { step in
                HStack(alignment: .top, spacing: 7) {
                    Text(step.0)
                        .font(.cvMono(7, weight: .bold))
                        .foregroundStyle(Color.cvGreen)
                        .frame(width: 10, alignment: .center)
                        .padding(.top, 1)
                    Text(step.1)
                        .font(.cvMono(8))
                        .foregroundStyle(Color.cvSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Reveal the ISO in Finder
            Button {
                NSWorkspace.shared.selectFile(machine.virtioDriversISOPath, inFileViewerRootedAtPath: "")
            } label: {
                Label("SHOW ISO IN FINDER", systemImage: "folder")
                    .font(.cvMono(7, weight: .bold))
                    .foregroundStyle(Color.cvSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(9)
        .background(Color.cvGreen.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.cvGreen.opacity(0.18)))
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

    // MARK: - VirtIO drivers banner (Windows guests without a drivers ISO set)
    private var virtioDriversBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.cvAmber)
                Text("VIRTIO DRIVERS REQUIRED FOR WINDOWS ARM")
                    .font(.cvMono(9, weight: .bold))
                    .foregroundStyle(Color.cvAmber)
                    .cmKerning(0.6)
            }
            Text("Windows ARM WinPE has no inbox virtio-scsi or virtio-blk driver. Without the VirtIO ISO mounted, Setup will show \"A media driver your computer needs is missing\" and fail to see the disk.")
                .font(.cvMono(9))
                .foregroundStyle(Color.cvSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("During setup, when the driver dialog appears: click Browse → select the VirtIO CD drive → open the vioscsi\\w10\\ARM64 folder → load vioscsi.inf. The disk will become visible immediately.")
                .font(.cvMono(9))
                .foregroundStyle(Color.cvSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 7) {
                if wizardVirtioDownloading {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            ProgressView(value: wizardVirtioProgress)
                                .tint(Color.cvAmber)
                                .frame(maxWidth: .infinity)
                            Text("\(Int(wizardVirtioProgress * 100))%")
                                .font(.cvMono(9, weight: .bold))
                                .foregroundStyle(Color.cvAmber)
                                .frame(width: 36, alignment: .trailing)
                        }
                        Text("Downloading virtio-win.iso…")
                            .font(.cvMono(8))
                            .foregroundStyle(Color.cvSecondary)
                    }
                } else {
                    Button {
                        let dest = manager.libraryRootURL().appendingPathComponent("virtio-win.iso")
                        wizardVirtioDownloading = true
                        wizardVirtioProgress = 0
                        Task {
                            do {
                                // Use a wrapper that streams progress back
                                let downloaded = try await manager.downloadVirtioISOToURLWithProgress(dest) { p in
                                    wizardVirtioProgress = p
                                }
                                draft.virtioDriversISOPath = downloaded.path
                            } catch {
                                manager.lastError = "Download failed: \(error.localizedDescription)"
                            }
                            wizardVirtioDownloading = false
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text("AUTO-DOWNLOAD VIRTIO-WIN.ISO")
                                .font(.cvMono(9, weight: .bold))
                                .cmKerning(0.4)
                        }
                        .foregroundStyle(Color.cvBackground)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.cvAmber)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(CVScaleButtonStyle())
                    Button {
                        if let p = pickFilePath(title: "Select VirtIO Drivers ISO", allowedExtensions: ["iso"]) {
                            draft.virtioDriversISOPath = p
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "folder")
                                .font(.system(size: 10, weight: .semibold))
                            Text("BROWSE…")
                                .font(.cvMono(9, weight: .bold))
                                .cmKerning(0.4)
                        }
                        .foregroundStyle(Color.cvSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.cvSurfaceRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.cvBorder))
                    }
                    .buttonStyle(CVScaleButtonStyle())

                    Spacer()

                    // ── Do It For Me ─────────────────────────────────────────
                    Button {
                        if doItForMeMgr == nil { doItForMeMgr = DoItForMeManager(coreVisorManager: manager) }
                        showDoItForMe = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 10, weight: .bold))
                            Text("DO IT FOR ME")
                                .font(.cvMono(9, weight: .bold))
                                .cmKerning(0.5)
                        }
                        .foregroundStyle(Color.cvBackground)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                colors: [Color(red:0.22,green:0.92,blue:0.55), Color(red:0.18,green:0.72,blue:1.0)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(CVScaleButtonStyle())
                    .help("CoreVisor will download Windows 11 ARM and all drivers automatically, then guide you through setup step by step.")
                }
            }
        }
        .padding(11)
        .background(Color.cvAmber.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.cvAmber.opacity(0.28), lineWidth: 1))
        .sheet(isPresented: $showDoItForMe) {
            if let mgr = doItForMeMgr {
                DoItForMeView(doItMgr: mgr, manager: manager, isPresented: $showDoItForMe)
                    .frame(minWidth: 680, minHeight: 420)
            }
        }
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
    private var hasValidPathInputs: Bool { isPathOK(draft.isoPath) && isPathOK(draft.virtioDriversISOPath) && isPathOK(draft.kernelPath) && isPathOK(draft.ramdiskPath) }
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

    private func importDiskImageFromPicker() {
        let panel = NSOpenPanel()
        panel.title       = "Import Pre-Built Disk Image"
        panel.prompt      = "Import"
        panel.message     = "Select a pre-installed disk image (qcow2, vhdx, vmdk, img, raw, vhd).\nNo installer ISO is needed — the VM will boot directly."
        panel.canChooseFiles           = true
        panel.canChooseDirectories     = false
        panel.allowsMultipleSelection  = false
        let exts  = ["qcow2", "vhdx", "vmdk", "img", "raw", "vhd"]
        let types = exts.compactMap { UTType(filenameExtension: $0) }
        if !types.isEmpty { panel.allowedContentTypes = types }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await manager.importDiskImage(at: url) }
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

private struct CVScanLinePattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        var y: CGFloat = 0
        while y < rect.height {
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += 3
        }
        return path
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
    @State private var isDownloadingISO = false
    @State private var isoDownloadProgress: Double = 0

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
                            .cmKerning(1.5)
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
                                    Text("GUEST OS").font(.cvMono(8, weight: .bold)).foregroundStyle(Color.cvDim).cmKerning(1)
                                    Picker("Guest", selection: $draft.guest) {
                                        ForEach(VMGuestType.allCases.filter { $0 != .macOS }) { Text($0.rawValue).tag($0) }
                                    }.pickerStyle(.segmented)
                                }
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("BACKEND").font(.cvMono(8, weight: .bold)).foregroundStyle(Color.cvDim).cmKerning(1)
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
                            editField("VIRTIO DRIVERS", placeholder: "/path/to/virtio-win.iso (Windows ARM)", text: $draft.virtioDriversISOPath) {
                                pickFile(title: "Select VirtIO Drivers ISO", exts: ["iso"]) { draft.virtioDriversISOPath = $0 }
                            }
                            if draft.guest == .windows && draft.backend == .qemu && draft.virtioDriversISOPath.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(Color.cvAmber)
                                    Text("No VirtIO drivers ISO — WinPE will show \"media driver missing\". Download virtio-win.iso and set the path above.")
                                        .font(.cvMono(8))
                                        .foregroundStyle(Color.cvAmber)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer()
                                    if isDownloadingISO {
                                        VStack(alignment: .trailing, spacing: 3) {
                                            ProgressView(value: isoDownloadProgress)
                                                .tint(Color.cvAmber)
                                                .frame(width: 80)
                                            Text("\(Int(isoDownloadProgress * 100))%")
                                                .font(.cvMono(7, weight: .bold))
                                                .foregroundStyle(Color.cvAmber)
                                        }
                                    } else {
                                        Button("AUTO-DOWNLOAD") {
                                            let dest = manager.libraryRootURL().appendingPathComponent("virtio-win.iso")
                                            isDownloadingISO = true
                                            isoDownloadProgress = 0
                                            Task {
                                                if let url = try? await manager.downloadVirtioISOToURLWithProgress(dest, progress: { p in
                                                    isoDownloadProgress = p
                                                }) {
                                                    draft.virtioDriversISOPath = url.path
                                                }
                                                isDownloadingISO = false
                                            }
                                        }
                                        .font(.cvMono(8, weight: .bold))
                                        .foregroundStyle(Color.cvAmber)
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(7)
                                .background(Color.cvAmber.opacity(0.07))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.cvAmber.opacity(0.22)))
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
                                    Text("DISK").font(.cvMono(8, weight: .bold)).foregroundStyle(Color.cvDim).cmKerning(1)
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

                            if draft.guest == .windows && draft.backend == .qemu {
                                VStack(alignment: .leading, spacing: 5) {
                                    Toggle("VirtIO GPU — WDDM 2D acceleration", isOn: $draft.enableVirtioGPU)
                                        .tint(Color.cvGreen)
                                        .font(.cvRound(12))
                                        .foregroundStyle(Color.cvPrimary)
                                    if draft.enableVirtioGPU {
                                        Text("Aero Glass, DWM compositing, rounded corners. Requires viogpudo driver installed in the guest (viogpudo\\w11\\ARM64 on the VirtIO ISO). Keep OFF during Windows setup — enable after.")
                                            .font(.cvMono(8))
                                            .foregroundStyle(Color.cvSecondary)
                                            .padding(.leading, 4)
                                    }
                                }
                                VStack(alignment: .leading, spacing: 5) {
                                    Toggle("TPM 2.0 (emulated via swtpm)", isOn: $draft.enableTPM)
                                        .disabled(!manager.swtpmAvailable)
                                        .tint(Color.cvGreen)
                                        .font(.cvRound(12))
                                        .foregroundStyle(manager.swtpmAvailable ? Color.cvPrimary : Color.cvDim)
                                    if !manager.swtpmAvailable {
                                        Text("swtpm not found. Install with: brew install swtpm")
                                            .font(.cvMono(8))
                                            .foregroundStyle(Color.cvAmber)
                                            .padding(.leading, 4)
                                    } else if draft.enableTPM {
                                        Text("TPM seed stored in macOS Keychain. Required for Windows 11 Secure Boot.")
                                            .font(.cvMono(8))
                                            .foregroundStyle(Color.cvSecondary)
                                            .padding(.leading, 4)
                                    }
                                }
                            }

                            Toggle("Enable audio", isOn: $draft.enableSound)
                                .tint(Color.cvAmber)
                                .font(.cvRound(12))
                                .foregroundStyle(Color.cvPrimary)

                            VStack(alignment: .leading, spacing: 5) {
                                Toggle("Use virtio-blk storage", isOn: $draft.useVirtioStorage)
                                    .disabled(draft.backend != .qemu)
                                    .tint(Color.cvAmber)
                                    .font(.cvRound(12))
                                    .foregroundStyle(Color.cvPrimary)
                                if draft.guest == .windows && draft.useVirtioStorage {
                                    Text("⚠︎ Only safe after Windows is fully installed. WinPE has no inbox virtio-blk driver.")
                                        .font(.cvMono(8))
                                        .foregroundStyle(Color.cvAmber)
                                        .padding(.leading, 4)
                                }
                            }

                            Text("USB DEVICES").font(.cvMono(8, weight: .bold)).foregroundStyle(Color.cvDim).cmKerning(1)
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
                .font(.cvMono(7, weight: .bold)).foregroundStyle(Color.cvDim).cmKerning(0.8)
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
            Text(label).font(.cvMono(8, weight: .bold)).foregroundStyle(Color.cvDim).cmKerning(0.8)
            Text(display).font(.cvMono(16, weight: .bold)).foregroundStyle(color).cmNumericTextTransition()
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
