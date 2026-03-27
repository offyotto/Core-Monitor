// DoItForMeView.swift
// CoreVisor — "Do It For Me" Windows 11 ARM automated installer UI
//
// Parallels-inspired design:
//   - Idle/error: clean card with options
//   - Active: step-by-step pipeline progress with animated stage indicators
//   - Done: launch button + confetti-style completion

import SwiftUI
import AppKit

// MARK: - Pipeline step descriptor (for the visual step list)

private struct PipelineStep {
    let icon: String
    let title: String
    let subtitle: String
}

private let pipelineSteps: [PipelineStep] = [
    .init(icon: "arrow.down.circle",        title: "Downloading Windows 11",    subtitle: "~5 GB from Microsoft CDN"),
    .init(icon: "cpu",                      title: "Downloading VirtIO drivers", subtitle: "Network, GPU, storage drivers"),
    .init(icon: "doc.badge.gearshape",      title: "Preparing installer",        subtitle: "Injecting drivers & bypass keys"),
    .init(icon: "externaldrive.badge.plus", title: "Creating virtual machine",   subtitle: "Disk, CPU, memory configuration"),
    .init(icon: "lock.shield",              title: "Initializing TPM 2.0",       subtitle: "Required for Windows 11"),
    .init(icon: "play.circle",              title: "Launching",                  subtitle: "Booting the VM"),
]

private func stepIndex(for phase: DoItForMePhase) -> Int {
    switch phase {
    case .downloadingISO:    return 0
    case .downloadingVirtIO: return 1
    case .injectingISO:      return 2
    case .creatingDisk:      return 3
    case .initializingTPM:   return 4
    case .preparingLaunch:   return 5
    default:                 return -1
    }
}

// MARK: - Main view

struct DoItForMeView: View {
    @ObservedObject var doItMgr: DoItForMeManager
    @ObservedObject var manager: CoreVisorManager
    @Binding var isPresented: Bool

    @State private var showOptions   = false
    @State private var cpuCores      = 6
    @State private var memoryGB      = 8
    @State private var diskGB        = 80
    @State private var manualISOPath = ""
    @State private var vmName        = "Windows 11 ARM"
    @State private var showDriverInstallGuide = false

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.07, blue: 0.09).ignoresSafeArea()

            switch doItMgr.phase {
            case .idle:
                idleView.transition(.opacity)
            case .failed:
                idleView.transition(.opacity)
            case .done(let m):
                doneView(machine: m).transition(.opacity)
            default:
                progressView.transition(.opacity)
            }
        }
        .frame(minWidth: 700, minHeight: 480)
        .animation(.easeInOut(duration: 0.3), value: doItMgr.phase.label)
        .sheet(isPresented: $showDriverInstallGuide) {
            driverInstallGuideSheet
        }
    }

    // MARK: Idle view

    private var idleView: some View {
        HStack(spacing: 0) {
            // Left panel — hero
            VStack(spacing: 20) {
                Spacer()
                ZStack {
                    Circle()
                        .fill(Color(red:0.22,green:0.92,blue:0.55).opacity(0.08))
                        .frame(width: 100, height: 100)
                    Image(systemName: "desktopcomputer.and.arrow.down")
                        .font(.system(size: 44, weight: .thin))
                        .foregroundStyle(Color(red:0.22,green:0.92,blue:0.55))
                }
                VStack(spacing: 8) {
                    Text("Do It For Me")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Fully automated Windows 11 ARM setup.\nNo steps. No clicks. Just boot.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                Spacer()

                // Step preview pills
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(pipelineSteps.enumerated()), id: \.offset) { _, step in
                        HStack(spacing: 10) {
                            Image(systemName: step.icon)
                                .font(.system(size: 12))
                                .foregroundStyle(Color(red:0.22,green:0.92,blue:0.55).opacity(0.8))
                                .frame(width: 20)
                            Text(step.title)
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
                .padding(16)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.bottom, 8)

                Spacer()
            }
            .frame(width: 240)
            .padding(.horizontal, 24)

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 1)
                .padding(.vertical, 32)

            // Right panel — config + error + actions
            VStack(alignment: .leading, spacing: 0) {
                // Error banner
                if case .failed(let msg) = doItMgr.phase {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .padding(.top, 1)
                            ScrollView {
                                Text(msg)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.orange)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                            .frame(maxHeight: 120)
                        }
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(msg, forType: .string)
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "doc.on.doc").font(.system(size: 10))
                                Text("Copy error")
                            }
                        }
                        .buttonStyle(CVGhostButton())
                    }
                    .padding(14)
                    .background(Color.orange.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 28)
                    .padding(.top, 28)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 20) {
                    // VM Name
                    VStack(alignment: .leading, spacing: 6) {
                        Text("VM Name")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                        TextField("Windows 11 ARM", text: $vmName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .foregroundStyle(.white)
                            .padding(9)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Resources row
                    HStack(spacing: 16) {
                        resourceStepper(label: "CPU Cores", value: $cpuCores, range: 2...14, step: 2, unit: "cores")
                        resourceStepper(label: "RAM",       value: $memoryGB, range: 2...32, step: 2, unit: "GB")
                        resourceStepper(label: "Disk",      value: $diskGB,   range: 40...512, step: 10, unit: "GB")
                    }

                    // Advanced — manual ISO
                    DisclosureGroup(isExpanded: $showOptions) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Use my own ISO (skips download)")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.4))
                            HStack(spacing: 8) {
                                TextField("Path to Windows 11 ARM .iso", text: $manualISOPath)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .padding(7)
                                    .background(Color.white.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                Button("Browse") {
                                    let panel = NSOpenPanel()
                                    panel.allowsOtherFileTypes = true
                                    panel.title = "Select Windows 11 ARM ISO"
                                    if panel.runModal() == .OK, let url = panel.url {
                                        manualISOPath = url.path
                                    }
                                }
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.5))
                                .buttonStyle(.plain)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Color.white.opacity(0.07))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                        .padding(.top, 10)
                    } label: {
                        Text("Advanced options")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    .tint(.white.opacity(0.4))
                }
                .padding(.horizontal, 28)

                Spacer()

                // TPM indicator + action buttons
                VStack(spacing: 14) {
                    HStack(spacing: 6) {
                        Image(systemName: doItMgr.swtpmAvailable ? "lock.shield.fill" : "lock.shield")
                            .foregroundStyle(doItMgr.swtpmAvailable
                                             ? Color(red:0.22,green:0.92,blue:0.55) : .orange)
                            .font(.system(size: 11))
                        Text(doItMgr.swtpmAvailable
                             ? "TPM 2.0 available — seed stored in Keychain"
                             : "swtpm not found — brew install swtpm (required for Win 11)")
                            .font(.system(size: 11))
                            .foregroundStyle(doItMgr.swtpmAvailable
                                             ? .white.opacity(0.4) : .orange.opacity(0.85))
                    }

                    HStack(spacing: 12) {
                        Button("Cancel") { isPresented = false }
                            .buttonStyle(CVGhostButton())

                        Button(action: {
                            doItMgr.manualISOPath   = manualISOPath
                            doItMgr.windowsUsername = "User"
                            doItMgr.computerName    = "COREVISOR-WIN"
                            doItMgr.run(
                                vmName:    vmName.isEmpty ? "Windows 11 ARM" : vmName,
                                cpuCores:  cpuCores,
                                memoryGB:  memoryGB,
                                diskGB:    diskGB
                            )
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                Text({
                                    if case .failed = doItMgr.phase { return "Retry" }
                                    return "Start"
                                }())
                            }
                        }
                        .buttonStyle(CVPrimaryButton())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Resource stepper

    private func resourceStepper(
        label: String, value: Binding<Int>,
        range: ClosedRange<Int>, step: Int, unit: String
    ) -> some View {
        let canDec = value.wrappedValue > range.lowerBound
        let canInc = value.wrappedValue < range.upperBound
        let accent  = Color(red: 0.22, green: 0.92, blue: 0.55)
        let btnBg   = Color.white.opacity(0.08)

        return VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))

            HStack(spacing: 1) {
                // ── Minus ──────────────────────────────────────────────────
                Button(action: {
                    if canDec { value.wrappedValue -= step }
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(canDec ? Color.white.opacity(0.8) : Color.white.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .background(btnBg)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // ── Value + unit ────────────────────────────────────────────
                VStack(spacing: 1) {
                    Text("\(value.wrappedValue)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Text(unit)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .frame(minWidth: 48, minHeight: 44)
                .background(Color.white.opacity(0.04))

                // ── Plus ────────────────────────────────────────────────────
                Button(action: {
                    if canInc { value.wrappedValue += step }
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(canInc ? accent : Color.white.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .background(btnBg)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    // MARK: Progress view (Parallels-style)

    private var progressView: some View {
        HStack(spacing: 0) {
            // Left: step list
            VStack(alignment: .leading, spacing: 0) {
                Text("Installing Windows 11")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    .padding(.bottom, 20)

                ForEach(Array(pipelineSteps.enumerated()), id: \.offset) { idx, step in
                    stepRow(step: step, index: idx,
                            currentIndex: stepIndex(for: doItMgr.phase))
                }

                Spacer()

                Button("Cancel") { doItMgr.cancel() }
                    .buttonStyle(CVGhostButton())
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
            .frame(width: 240)
            .background(Color(red: 0.05, green: 0.05, blue: 0.07))

            // Right: current step detail
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 28) {
                    // Animated icon
                    ZStack {
                        Circle()
                            .fill(Color(red:0.22,green:0.92,blue:0.55).opacity(0.08))
                            .frame(width: 80, height: 80)
                        Circle()
                            .stroke(Color(red:0.22,green:0.92,blue:0.55).opacity(0.2), lineWidth: 1.5)
                            .frame(width: 80, height: 80)
                        Image(systemName: doItMgr.phase.icon)
                            .font(.system(size: 32, weight: .thin))
                            .foregroundStyle(Color(red:0.22,green:0.92,blue:0.55))
                            .cmPulseSymbolEffect()
                    }

                    // Label
                    VStack(spacing: 8) {
                        Text(doItMgr.phase.label)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .animation(.easeInOut(duration: 0.25), value: doItMgr.phase.label)

                        Text(stepSubtitle(for: doItMgr.phase))
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.35))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)

                    // Progress bar
                    VStack(spacing: 6) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(height: 4)
                                Capsule()
                                    .fill(LinearGradient(
                                        colors: [Color(red:0.22,green:0.92,blue:0.55),
                                                 Color(red:0.18,green:0.72,blue:1.0)],
                                        startPoint: .leading, endPoint: .trailing
                                    ))
                                    .frame(
                                        width: max(6, geo.size.width * doItMgr.phase.progressFraction),
                                        height: 4
                                    )
                                    .animation(.spring(response: 0.6, dampingFraction: 0.85),
                                               value: doItMgr.phase.progressFraction)
                            }
                        }
                        .frame(height: 4)

                        HStack {
                            Text(String(format: "%.0f%%", doItMgr.phase.progressFraction * 100))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.25))
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 40)
                }

                Spacer()

                Text("Windows will install automatically. This takes 15–20 minutes.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.25))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // Single step row for the left sidebar
    @ViewBuilder
    private func stepRow(step: PipelineStep, index: Int, currentIndex: Int) -> some View {
        let isDone   = index < currentIndex
        let isActive = index == currentIndex

        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isDone    ? Color(red:0.22,green:0.92,blue:0.55).opacity(0.15) :
                          isActive  ? Color(red:0.22,green:0.92,blue:0.55).opacity(0.12) :
                          Color.white.opacity(0.04))
                    .frame(width: 32, height: 32)
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(red:0.22,green:0.92,blue:0.55))
                } else if isActive {
                    Image(systemName: step.icon)
                        .font(.system(size: 13))
                        .foregroundStyle(Color(red:0.22,green:0.92,blue:0.55))
                        .cmPulseSymbolEffect()
                } else {
                    Image(systemName: step.icon)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.2))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isDone  ? .white.opacity(0.5) :
                                     isActive ? .white :
                                     .white.opacity(0.25))
                if isActive {
                    Text(step.subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }

            Spacer()

            if isDone {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(red:0.22,green:0.92,blue:0.55).opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isActive ? Color.white.opacity(0.05) : Color.clear)
        .overlay(alignment: .leading) {
            if isActive {
                Rectangle()
                    .fill(Color(red:0.22,green:0.92,blue:0.55))
                    .frame(width: 2)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: currentIndex)
    }

    private func stepSubtitle(for phase: DoItForMePhase) -> String {
        switch phase {
        case .downloadingISO:    return "Downloading directly from Microsoft"
        case .downloadingVirtIO: return "VirtIO network, GPU & storage drivers"
        case .injectingISO:      return "Building fully unattended installer ISO"
        case .creatingDisk:      return "Setting up virtual hardware"
        case .initializingTPM:   return "Emulated TPM 2.0 via swtpm"
        case .preparingLaunch:   return "Starting the virtual machine"
        default:                 return ""
        }
    }

    // MARK: Done view

    private func doneView(machine: CoreVisorMachine) -> some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color(red:0.22,green:0.92,blue:0.55).opacity(0.1))
                        .frame(width: 90, height: 90)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(Color(red:0.22,green:0.92,blue:0.55))
                        .cmBounceSymbolEffect()
                }

                VStack(spacing: 8) {
                    Text("Windows 11 ARM is ready")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Your VM will install Windows automatically.\nOne manual storage-driver step is required in Windows Setup.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }

                // Feature chips
                HStack(spacing: 10) {
                    featureChip(icon: "shield.fill",        label: "TPM 2.0")
                    featureChip(icon: "display",            label: "VirtIO GPU")
                    featureChip(icon: "network",            label: "VirtIO Net")
                    featureChip(icon: "person.crop.circle", label: "Local account")
                }

                HStack(spacing: 14) {
                    Button("Close") { isPresented = false }
                        .buttonStyle(CVGhostButton())

                    Button(action: {
                        Task { await manager.startMachine(machine) }
                        showDriverInstallGuide = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                            Text("Launch VM")
                        }
                    }
                    .buttonStyle(CVPrimaryButton())
                }
            }

            Spacer()

            Text("Only manual step: load the VirtIO storage driver in Windows Setup.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.2))
                .padding(.bottom, 20)
        }
    }

    private var driverInstallGuideSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Manual Step: Install Storage Driver")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            Text("This is the only manual part of the Windows install.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(red: 0.22, green: 0.92, blue: 0.55))

            VStack(alignment: .leading, spacing: 8) {
                Text("1. In Windows Setup, click Browse when prompted to load a driver.")
                Text("2. Open the VirtIO CD drive.")
                Text("3. Go to vioscsi -> w11 -> ARM64.")
                Text("4. Select the driver file and click Install (or Next).")
                Text("5. The disk will appear, then Windows installation continues.")
            }
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.85))

            HStack {
                Spacer()
                Button("Close") { showDriverInstallGuide = false }
                    .buttonStyle(CVPrimaryButton())
            }
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 250)
        .background(Color(red: 0.06, green: 0.07, blue: 0.09))
    }

    private func featureChip(icon: String, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(label)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(Color(red:0.22,green:0.92,blue:0.55).opacity(0.8))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(red:0.22,green:0.92,blue:0.55).opacity(0.08))
        .clipShape(Capsule())
    }
}

// MARK: - Button styles

private struct CVPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, 18).padding(.vertical, 9)
            .background(configuration.isPressed
                        ? Color(red:0.15,green:0.75,blue:0.42)
                        : Color(red:0.22,green:0.92,blue:0.55))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct CVGhostButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.4 : 0.55))
            .padding(.horizontal, 16).padding(.vertical, 9)
            .background(Color.white.opacity(configuration.isPressed ? 0.04 : 0.07))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
