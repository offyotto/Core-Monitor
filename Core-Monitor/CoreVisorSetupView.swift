import SwiftUI

struct CoreVisorSetupView: View {
    @ObservedObject var manager: CoreVisorManager
    @Binding var hasOpenedCoreVisorSetup: Bool

    @State private var draft = CoreVisorDraft()
    @State private var step = 0
    @State private var showCreatePulse = false
    @State private var animateReveal = false
    @State private var showEntitlementGuide = false

    private let stepTitles = [
        "Template",
        "Backend",
        "Resources",
        "Display + USB",
        "Review"
    ]

    var body: some View {
        ZStack {
            HStack(spacing: 12) {
                machineSidebar
                    .frame(width: 280)
                    .panelReveal(index: 0, active: animateReveal)

                VStack(spacing: 12) {
                    header
                        .panelReveal(index: 1, active: animateReveal)

                    HStack(spacing: 8) {
                        ForEach(Array(stepTitles.enumerated()), id: \.offset) { idx, title in
                            stepChip(index: idx, title: title)
                        }
                    }
                    .panelReveal(index: 2, active: animateReveal)

                    ZStack {
                        activeStepView
                            .id(step)
                            .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.98)), removal: .opacity))
                    }
                    .animation(.spring(response: 0.45, dampingFraction: 0.86), value: step)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                    footer
                        .panelReveal(index: 3, active: animateReveal)
                }
            }

            if showEntitlementGuide {
                entitlementGuideOverlay
                    .transition(.opacity)
            }
        }
        .padding(14)
        .frame(minWidth: 1120, minHeight: 650)
        .onAppear {
            hasOpenedCoreVisorSetup = true
            animateReveal = true
            manager.refreshEntitlementStatus()
            showEntitlementGuide = !manager.hasVirtualizationEntitlement
        }
    }

    private var entitlementGuideOverlay: some View {
        ZStack {
            Color.black.opacity(0.34)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                Text("CoreVisor Setup Required")
                    .font(.system(size: 20, weight: .bold))
                Text("This build is missing required virtualization permission, so Apple Virtualization VMs cannot start.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    setupLine("1. Quit Core Monitor.")
                    setupLine("2. Open Terminal and run the commands below to inject the entitlement locally.")
                    setupLine("3. Reopen Core Monitor, then press Recheck below.")
                    setupLine("4. If it still fails, use QEMU backend as fallback.")
                }
                .padding(10)
                .compactPanel()

                Text("Run in Terminal (replace app path if needed):")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Text("""
cat > /tmp/corevisor-entitlements.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key><true/>
    <key>com.apple.security.virtualization</key><true/>
</dict>
</plist>
PLIST
codesign --force --deep --sign - --entitlements /tmp/corevisor-entitlements.plist "/Applications/Core-Monitor.app"
""")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
                    .compactPanel()

                HStack {
                    Button("Skip For Now") {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showEntitlementGuide = false
                        }
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Recheck") {
                        manager.refreshEntitlementStatus()
                        if manager.hasVirtualizationEntitlement {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                showEntitlementGuide = false
                            }
                        } else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                showEntitlementGuide = true
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(16)
            .frame(width: 720)
            .compactPanel()
        }
    }

    private func setupLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.accentColor.opacity(0.9))
                .frame(width: 6, height: 6)
                .padding(.top, 5)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var machineSidebar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image("CoreVisorIcon")
                    .resizable()
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                Text("CoreVisor")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
            }

            Text("Saved Machines")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            ScrollView {
                LazyVStack(spacing: 8) {
                    if manager.machines.isEmpty {
                        Text("No VMs yet")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .compactPanel()
                    } else {
                        ForEach(manager.machines) { machine in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(machine.name)
                                        .font(.system(size: 12, weight: .semibold))
                                        .lineLimit(1)
                                    Spacer()
                                    runtimeBadge(manager.runtimeState(for: machine))
                                }

                                Text("\(machine.guest.rawValue) • \(machine.backend.rawValue)")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 6) {
                                    Button("Start") {
                                        Task { await manager.startMachine(machine) }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                    .disabled(manager.runtimeState(for: machine) == .running || manager.runtimeState(for: machine) == .starting)

                                    Button("Stop") {
                                        manager.stopMachine(machine)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .disabled(manager.runtimeState(for: machine) == .stopped || manager.runtimeState(for: machine) == .error)

                                    Button("Delete") {
                                        manager.removeMachine(machine)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }

                                let logText = manager.runtimeLog(for: machine)
                                if !logText.isEmpty {
                                    ScrollView {
                                        Text(logText)
                                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                                            .textSelection(.enabled)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(8)
                                    }
                                    .frame(height: 95)
                                    .compactPanel()
                                }
                            }
                            .padding(10)
                            .compactPanel()
                        }
                    }
                }
            }
        }
        .padding(12)
        .compactPanel()
    }

    private func runtimeBadge(_ state: CoreVisorRuntimeState) -> some View {
        Text(state.rawValue.capitalized)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(colorForState(state).opacity(0.2), in: Capsule())
            .foregroundStyle(colorForState(state))
    }

    private func colorForState(_ state: CoreVisorRuntimeState) -> Color {
        switch state {
        case .stopped: .secondary
        case .starting, .stopping: .orange
        case .running: .green
        case .error: .red
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("CoreVisor Setup Manager")
                    .font(.system(size: 22, weight: .bold))
                Text("Build and run VMs with Apple Virtualization or QEMU")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if manager.isScanning {
                ProgressView()
                    .controlSize(.small)
            }

            Button("Refresh Runtime") {
                Task { await manager.refreshRuntimeData() }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .compactPanel()
    }

    private func stepChip(index: Int, title: String) -> some View {
        Text("\(index + 1). \(title)")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(index == step ? .primary : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(index == step ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08), in: Capsule())
            .onTapGesture {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.84)) {
                    step = index
                }
            }
    }

    @ViewBuilder
    private var activeStepView: some View {
        switch step {
        case 0: templateStep
        case 1: backendStep
        case 2: resourcesStep
        case 3: displayStep
        default: reviewStep
        }
    }

    private var templateStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Template")
                .font(.system(size: 14, weight: .semibold))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(manager.templates) { template in
                    Button {
                        manager.applyTemplate(template, to: &draft)
                        pulseCreateButton()
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(template.name)
                                .font(.system(size: 13, weight: .semibold))
                            Text(template.guest.rawValue)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text("\(template.cpuCores) cores • \(template.memoryGB) GB • \(template.diskGB) GB")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .compactPanel()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .compactPanel()
    }

    private var backendStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Guest + Backend")
                .font(.system(size: 14, weight: .semibold))

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Guest OS")
                        .font(.system(size: 12, weight: .semibold))
                    Picker("Guest", selection: $draft.guest) {
                        ForEach(VMGuestType.allCases) { guest in
                            Text(guest.rawValue).tag(guest)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Backend")
                        .font(.system(size: 12, weight: .semibold))
                    Picker("Backend", selection: $draft.backend) {
                        ForEach(VMBackend.allCases) { backend in
                            Text(backend.rawValue).tag(backend)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            Text(compatibilityText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isCompatible ? .green : .orange)

            if let qemuPath = manager.qemuBinaryPath {
                Text("QEMU: \(qemuPath)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if let lastError = manager.lastError {
                Text(lastError)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.orange)
            }
        }
        .padding(12)
        .compactPanel()
    }

    private var resourcesStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Resources + Boot")
                .font(.system(size: 14, weight: .semibold))

            LabeledContent("VM Name") {
                TextField("New VM", text: $draft.name)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 340)
            }

            LabeledContent("Installer ISO") {
                TextField("/path/to/installer.iso", text: $draft.isoPath)
                    .textFieldStyle(.roundedBorder)
            }

            LabeledContent("Linux Kernel (optional)") {
                TextField("/path/to/vmlinuz", text: $draft.kernelPath)
                    .textFieldStyle(.roundedBorder)
            }

            LabeledContent("Initrd (optional)") {
                TextField("/path/to/initrd.img", text: $draft.ramdiskPath)
                    .textFieldStyle(.roundedBorder)
            }

            LabeledContent("Kernel cmdline") {
                TextField("console=hvc0", text: $draft.kernelCommandLine)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 10) {
                sliderCard(title: "CPU", value: Binding(get: { Double(draft.cpuCores) }, set: { draft.cpuCores = Int($0) }), range: 1...16, format: "\(draft.cpuCores) cores")
                sliderCard(title: "Memory", value: Binding(get: { Double(draft.memoryGB) }, set: { draft.memoryGB = Int($0) }), range: 2...64, format: "\(draft.memoryGB) GB")
                sliderCard(title: "Disk", value: Binding(get: { Double(draft.diskGB) }, set: { draft.diskGB = Int($0) }), range: 20...512, format: "\(draft.diskGB) GB")
            }
        }
        .padding(12)
        .compactPanel()
    }

    private func sliderCard(title: String, value: Binding<Double>, range: ClosedRange<Double>, format: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
            Text(format)
                .font(.system(size: 14, weight: .bold))
            Slider(value: value, in: range, step: 1)
        }
        .padding(10)
        .compactPanel()
    }

    private var displayStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Display + USB")
                .font(.system(size: 14, weight: .semibold))

            Toggle("Enable VirGL (QEMU)", isOn: $draft.enableVirGL)
                .disabled(draft.backend != .qemu)

            Toggle("Enable audio", isOn: $draft.enableSound)

            Text("QEMU USB devices")
                .font(.system(size: 12, weight: .semibold))

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    if manager.usbDevices.isEmpty {
                        Text("No QEMU USB devices detected.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(manager.usbDevices) { device in
                            Toggle(isOn: Binding(
                                get: { draft.selectedUSBDeviceIDs.contains(device.id) },
                                set: { enabled in
                                    if enabled {
                                        draft.selectedUSBDeviceIDs.insert(device.id)
                                    } else {
                                        draft.selectedUSBDeviceIDs.remove(device.id)
                                    }
                                }
                            )) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(device.name)
                                        .font(.system(size: 12, weight: .semibold))
                                    if !device.detail.isEmpty {
                                        Text(device.detail)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .frame(height: 265)
            .padding(8)
            .compactPanel()
        }
        .padding(12)
        .compactPanel()
    }

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Review + Launch")
                .font(.system(size: 14, weight: .semibold))

            Text("Backend: \(draft.backend.rawValue) • Guest: \(draft.guest.rawValue)")
                .font(.system(size: 12, weight: .medium))

            Text("Command Preview")
                .font(.system(size: 12, weight: .semibold))

            ScrollView {
                Text(manager.commandPreview(for: draft))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(height: 220)
            .compactPanel()

            HStack(spacing: 10) {
                Button("Create VM") {
                    Task { await manager.createMachine(from: draft) }
                    pulseCreateButton()
                }
                .buttonStyle(.borderedProminent)
                .scaleEffect(showCreatePulse ? 1.06 : 1)
                .animation(.spring(response: 0.35, dampingFraction: 0.62), value: showCreatePulse)

                Text("Create once, then use Start in the sidebar.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .compactPanel()
    }

    private var footer: some View {
        HStack {
            Button("Back") {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.84)) {
                    step = max(0, step - 1)
                }
            }
            .buttonStyle(.bordered)
            .disabled(step == 0)

            Spacer()

            Button(step == stepTitles.count - 1 ? "Done" : "Next") {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.84)) {
                    if step < stepTitles.count - 1 {
                        step += 1
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var isCompatible: Bool {
        manager.isBackendSupported(draft.backend, for: draft.guest)
    }

    private var compatibilityText: String {
        if isCompatible {
            return "Selected backend supports this guest."
        }
        if draft.backend == .appleVirtualization && !manager.hasVirtualizationEntitlement {
            return "Enable `com.apple.security.virtualization` entitlement first."
        }
        if draft.backend == .appleVirtualization {
            return "Apple Virtualization supports Linux/macOS workflows only."
        }
        return "QEMU backend requires detected qemu-system binary."
    }

    private func pulseCreateButton() {
        showCreatePulse = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            showCreatePulse = false
        }
    }
}

private struct VisorPanelModifier: ViewModifier {
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
        modifier(VisorPanelModifier())
    }
}
