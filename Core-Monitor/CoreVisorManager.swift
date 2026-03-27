import Foundation
import Combine
import Security
import Darwin
#if canImport(AppKit)
import AppKit
#endif
#if canImport(Virtualization)
import Virtualization
#endif

enum VMGuestType: String, CaseIterable, Identifiable, Codable {
    case linux   = "Linux"
    case windows = "Windows"
    case macOS   = "macOS"
    case netBSD  = "NetBSD"
    case unix    = "UNIX"

    var id: String { rawValue }
}

enum VMBackend: String, CaseIterable, Identifiable, Codable {
    case appleVirtualization = "Apple Virtualization"
    case qemu                = "QEMU"

    var id: String { rawValue }
}

enum CoreVisorRuntimeState: String, Codable {
    case stopped
    case starting
    case running
    case stopping
    case error
}

struct CoreVisorTemplate: Identifiable {
    let id = UUID()
    let guest: VMGuestType
    let name: String
    let cpuCores: Int
    let memoryGB: Int
    let diskGB: Int
}

struct QEMUUSBDevice: Identifiable, Hashable {
    let id: String
    let name: String
    let detail: String
}

struct CoreVisorDraft {
    var name: String             = "New VM"
    var guest: VMGuestType       = .linux
    var backend: VMBackend       = .qemu
    var cpuCores: Int            = 4
    var memoryGB: Int            = 8
    var diskGB: Int              = 64
    var enableVirGL: Bool        = false
    var enableSound: Bool        = true
    var useVirtioStorage: Bool   = false
    var enableTPM: Bool          = false
    var enableVirtioGPU: Bool    = false   // post-install WDDM 2D accel via virtio-gpu-pci
    var selectedUSBDeviceIDs: Set<String> = []
    var isoPath: String          = ""
    var virtioDriversISOPath: String = ""
    var kernelPath: String       = ""
    var ramdiskPath: String      = ""
    var kernelCommandLine: String = "console=hvc0"
}

struct CoreVisorMachine: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let guest: VMGuestType
    let backend: VMBackend
    let cpuCores: Int
    let memoryGB: Int
    let diskGB: Int
    let enableVirGL: Bool
    let enableSound: Bool
    let useVirtioStorage: Bool
    let enableTPM: Bool
    let enableVirtioGPU: Bool
    let isoPath: String
    let virtioDriversISOPath: String
    let kernelPath: String
    let ramdiskPath: String
    let kernelCommandLine: String
    let selectedUSBDeviceIDs: [String]
    let bundlePath: String
    let diskPath: String
    let createdAt: Date
}

private struct CoreVisorLibrary: Codable {
    var machines: [CoreVisorMachine]
}

@MainActor
final class CoreVisorManager: ObservableObject {
    @Published private(set) var qemuBinaryPath: String?
    @Published var customQEMUBinaryPath: String = ""
    @Published private(set) var usbDevices: [QEMUUSBDevice] = []
    @Published private(set) var qemuSupportsOpenGL = false
    @Published private(set) var isScanning = false
    @Published private(set) var hasVirtualizationEntitlement = false
    @Published private(set) var isAppSandboxed = false
    @Published private(set) var machines: [CoreVisorMachine] = []
    @Published private(set) var machineStates: [UUID: CoreVisorRuntimeState] = [:]
    @Published private(set) var machineLogs: [UUID: String] = [:]
    @Published var lastError: String?

    /// Per-machine download progress for the VirtIO ISO auto-fetch (0.0–1.0, nil = not downloading).
    @Published private(set) var virtioDownloadProgress: [UUID: Double] = [:]
    /// True while the VirtIO ISO is being downloaded for at least one machine.
    var isDownloadingVirtioISO: Bool { !virtioDownloadProgress.isEmpty }

    // Stable direct-download URL for the latest virtio-win stable ISO.
    static let virtioWinISOURL = URL(string: "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso")!

    /// Per-machine snapshot names, keyed by VM UUID. Populated after a successful savevm.
    @Published private(set) var machineSnapshots: [UUID: [String]] = [:]
    /// True while a snapshot operation is in progress.
    @Published private(set) var snapshotInProgress: [UUID: Bool] = [:]
    /// True when swtpm is installed and TPM emulation is available.
    @Published private(set) var swtpmAvailable: Bool = false
    /// Active swtpm daemon processes, keyed by machine UUID.
    private var swtpmProcesses: [UUID: Process] = [:]

    let templates: [CoreVisorTemplate] = [
        CoreVisorTemplate(guest: .linux,   name: "Linux Desktop",  cpuCores: 4, memoryGB: 8,  diskGB: 64),
        CoreVisorTemplate(guest: .windows, name: "Windows XP",     cpuCores: 1, memoryGB: 2,  diskGB: 32),
        CoreVisorTemplate(guest: .windows, name: "Windows 7",      cpuCores: 2, memoryGB: 4,  diskGB: 64),
        CoreVisorTemplate(guest: .windows, name: "Windows 8.1",    cpuCores: 2, memoryGB: 4,  diskGB: 64),
        CoreVisorTemplate(guest: .windows, name: "Windows 10",     cpuCores: 4, memoryGB: 8,  diskGB: 96),
        CoreVisorTemplate(guest: .windows, name: "Windows 11",     cpuCores: 6, memoryGB: 12, diskGB: 128),
        CoreVisorTemplate(guest: .netBSD,  name: "NetBSD",         cpuCores: 2, memoryGB: 4,  diskGB: 32),
        CoreVisorTemplate(guest: .unix,    name: "UNIX",           cpuCores: 2, memoryGB: 4,  diskGB: 32),
    ]

    private var qemuProcesses: [UUID: Process] = [:]
    private var userInitiatedStops: Set<UUID> = []
#if canImport(Virtualization)
    private var appleSessions: [UUID: AppleVMSession] = [:]
    private var appleDisplayWindows: [UUID: NSWindowController] = [:]
    private var appleWindowCloseObservers: [UUID: NSObjectProtocol] = [:]
#endif

    private let customQEMUBinaryPathKey         = "corevisor.customQEMUBinaryPath"
    private let runtimeStopTimeoutSeconds: TimeInterval = 12.0
    private let runtimeLogLimit                 = 120_000
    private let runtimeLogFlushInterval: TimeInterval = 0.15
    private let managedEmbeddedQEMUFolderName   = "EmbeddedQEMU"
    private let machineConfigFileName           = "machine.json"
    private let genericMachineIdentifierFileName = "machine-identifier.bin"
    private let efiVariableStoreFileName        = "efi-variable-store"
    private var pendingLogBuffers: [UUID: String] = [:]
    private var pendingLogFlushWorkItems: [UUID: DispatchWorkItem] = [:]

    init() {
        customQEMUBinaryPath = UserDefaults.standard.string(forKey: customQEMUBinaryPathKey) ?? ""
        loadMachines()
        refreshEntitlementStatus()
        swtpmAvailable = SwtpmController.binaryPath() != nil
        Task {
            bootstrapVirGLRuntimeOnStartup()
            await refreshRuntimeData()
        }
    }

    // MARK: - Public configuration helpers

    func setCustomQEMUBinaryPath(_ path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard customQEMUBinaryPath != trimmed else { return }
        customQEMUBinaryPath = trimmed
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: customQEMUBinaryPathKey)
        } else {
            UserDefaults.standard.set(trimmed, forKey: customQEMUBinaryPathKey)
        }
    }

    func clearCustomQEMUBinaryPath() { setCustomQEMUBinaryPath("") }

    /// Returns a diskpart + DISM setup script for Windows ARM (AArch64) guests.
    /// This improved version handles both GPT setup and proper DISM index selection.
    func guestPasteScript(for guest: VMGuestType) -> String? {
        switch guest {
        case .windows:
            return """
diskpart
list disk
select disk 0
clean
convert gpt
create part efi size=100
format quick fs=fat32 label=EFI
assign letter=S
create part msr size=16
create part primary
format quick fs=ntfs label=Windows
assign letter=W
exit

:: Check available WIM indexes first
dism /Get-WimInfo /WimFile:D:\\sources\\install.wim

:: Apply the correct index (usually 1 for ARM ISOs, 6 for x64 multi-edition)
dism /Apply-Image /ImageFile:D:\\sources\\install.wim /Index:1 /ApplyDir:W:\\
bcdboot W:\\Windows /s S: /f UEFI
wpeinit
wpeutil reboot
"""
        default:
            return nil
        }
    }

    func refreshRuntimeData() async {
        isScanning = true
        defer { isScanning = false }
        refreshEntitlementStatus()

        qemuBinaryPath = findQEMUBinary()
        guard let qemuBinaryPath else {
            usbDevices = []
            qemuSupportsOpenGL = false
            if customQEMUBinaryPath.isEmpty {
                lastError = "Bundled QEMU not found in app resources (EmbeddedQEMU)."
            } else {
                lastError = "Custom QEMU path is invalid or not executable: \(customQEMUBinaryPath)"
            }
            return
        }

        qemuSupportsOpenGL = await qemuHasOpenGLDisplaySupport(qemuBinaryPath: qemuBinaryPath)

        let parsedUSB = await loadQEMUUSBDevices(qemuBinaryPath: qemuBinaryPath)
        usbDevices = parsedUSB
        if parsedUSB.isEmpty, lastError == nil {
            lastError = "No QEMU USB devices reported by qemu -device help."
        } else {
            lastError = nil
        }
    }

    func applyTemplate(_ template: CoreVisorTemplate, to draft: inout CoreVisorDraft) {
        draft.name    = template.name
        draft.guest   = template.guest
        draft.cpuCores = template.cpuCores
        draft.memoryGB = template.memoryGB
        draft.diskGB  = template.diskGB
        if template.guest == .macOS {
            draft.backend   = .appleVirtualization
            draft.enableVirGL = false
        } else if !isBackendSupported(draft.backend, for: template.guest) {
            draft.backend = qemuBinaryPath != nil ? .qemu : .appleVirtualization
        }
    }

    func draft(from machine: CoreVisorMachine) -> CoreVisorDraft {
        CoreVisorDraft(
            name: machine.name, guest: machine.guest, backend: machine.backend,
            cpuCores: machine.cpuCores, memoryGB: machine.memoryGB, diskGB: machine.diskGB,
            enableVirGL: machine.enableVirGL, enableSound: machine.enableSound,
            useVirtioStorage: machine.useVirtioStorage,
            selectedUSBDeviceIDs: Set(machine.selectedUSBDeviceIDs),
            isoPath: machine.isoPath, virtioDriversISOPath: machine.virtioDriversISOPath,
            kernelPath: machine.kernelPath,
            ramdiskPath: machine.ramdiskPath, kernelCommandLine: machine.kernelCommandLine
        )
    }

    func duplicateMachine(_ machine: CoreVisorMachine) async {
        var d = draft(from: machine)
        d.name    = makeDuplicateName(from: machine.name)
        d.isoPath = ""; d.kernelPath = ""; d.ramdiskPath = ""
        await createMachine(from: d)
    }

    func openMachineBundle(_ machine: CoreVisorMachine) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: machine.bundlePath)
    }

    // MARK: - Snapshot support

    /// Short UNIX socket directory for a machine — lives in /tmp to stay under
    /// the 104-byte macOS UNIX socket path limit.
    /// Returns e.g. /tmp/corevm-3f2a1b/
    private func socketDir(for machine: CoreVisorMachine) -> String {
        "/tmp/corevm-\(machine.id.uuidString.prefix(8).lowercased())"
    }

    /// Path of the UNIX monitor socket for a given machine.
    private func monitorSocketPath(for machine: CoreVisorMachine) -> String {
        socketDir(for: machine) + "/monitor.sock"
    }

    /// Path of the TPM UNIX socket for a given machine.
    private func tpmSocketPath(for machine: CoreVisorMachine) -> String {
        socketDir(for: machine) + "/tpm.sock"
    }

    /// Sends a HMP command to the running QEMU monitor socket and returns the response.
    private func sendMonitorCommand(_ command: String, to machine: CoreVisorMachine) async -> String? {
        let sockPath = monitorSocketPath(for: machine)
        guard FileManager.default.fileExists(atPath: sockPath) else { return nil }
        return await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
            DispatchQueue.global(qos: .utility).async {
                let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
                guard fd >= 0 else { continuation.resume(returning: nil); return }
                defer { Darwin.close(fd) }

                var addr = sockaddr_un()
                addr.sun_family = sa_family_t(AF_UNIX)
                let pathBytes = sockPath.utf8CString
                withUnsafeMutableBytes(of: &addr.sun_path) { ptr in
                    pathBytes.withUnsafeBytes { src in
                        guard let dstBase = ptr.baseAddress, let srcBase = src.baseAddress else { return }
                        let copyCount = min(ptr.count, src.count)
                        memcpy(dstBase, srcBase, copyCount)
                    }
                }
                let addrLen = socklen_t(MemoryLayout<sockaddr_un>.stride)
                let connectResult = withUnsafePointer(to: &addr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        Darwin.connect(fd, $0, addrLen)
                    }
                }
                guard connectResult == 0 else { continuation.resume(returning: nil); return }

                // Read the initial prompt
                var buf = [UInt8](repeating: 0, count: 4096)
                _ = Darwin.read(fd, &buf, buf.count)

                // Send command
                let cmdData = (command + "\n").data(using: .utf8)!
                _ = cmdData.withUnsafeBytes { Darwin.write(fd, $0.baseAddress!, cmdData.count) }

                // Read response (with short timeout via non-blocking)
                Thread.sleep(forTimeInterval: 0.4)
                var respBuf = [UInt8](repeating: 0, count: 8192)
                let n = Darwin.read(fd, &respBuf, respBuf.count)
                let response = n > 0 ? String(bytes: respBuf.prefix(n), encoding: .utf8) : nil
                continuation.resume(returning: response)
            }
        }
    }

    /// Saves a named snapshot of the running VM (QEMU HMP savevm).
    func saveSnapshot(name: String, for machine: CoreVisorMachine) async {
        guard machineStates[machine.id] == .running else {
            appendLog("Snapshot save requires a running VM.\n", for: machine.id); return
        }
        snapshotInProgress[machine.id] = true
        appendLog("Saving snapshot '\(name)'…\n", for: machine.id)
        let tag = name.isEmpty ? "snap-\(Int(Date().timeIntervalSince1970))" : name
        _ = await sendMonitorCommand("savevm \(tag)", to: machine)
        // Give QEMU a moment then refresh the list
        try? await Task.sleep(nanoseconds: 800_000_000)
        await refreshSnapshots(for: machine)
        snapshotInProgress[machine.id] = false
        appendLog("Snapshot '\(tag)' saved.\n", for: machine.id)
    }

    /// Loads a named snapshot (VM must be running; QEMU pauses, restores, resumes).
    func loadSnapshot(name: String, for machine: CoreVisorMachine) async {
        guard machineStates[machine.id] == .running else {
            appendLog("Snapshot load requires a running VM.\n", for: machine.id); return
        }
        snapshotInProgress[machine.id] = true
        appendLog("Loading snapshot '\(name)'…\n", for: machine.id)
        _ = await sendMonitorCommand("loadvm \(name)", to: machine)
        snapshotInProgress[machine.id] = false
        appendLog("Snapshot '\(name)' loaded.\n", for: machine.id)
    }

    /// Deletes a named snapshot from the disk image.
    func deleteSnapshot(name: String, for machine: CoreVisorMachine) async {
        snapshotInProgress[machine.id] = true
        appendLog("Deleting snapshot '\(name)'…\n", for: machine.id)
        _ = await sendMonitorCommand("delvm \(name)", to: machine)
        try? await Task.sleep(nanoseconds: 400_000_000)
        await refreshSnapshots(for: machine)
        snapshotInProgress[machine.id] = false
        appendLog("Snapshot '\(name)' deleted.\n", for: machine.id)
    }

    /// Queries QEMU for available snapshots using qemu-img snapshot -l.
    func refreshSnapshots(for machine: CoreVisorMachine) async {
        guard let qemuBinaryPath,
              let qemuImg = findQEMUImgBinary(qemuSystemPath: qemuBinaryPath) else { return }
        let result = await runProcess(
            executable: qemuImg,
            arguments: ["snapshot", "-l", machine.diskPath],
            timeoutSeconds: 10
        )
        var names: [String] = []
        for line in result.output.split(separator: "\n").dropFirst(2) {
            let cols = line.split(separator: " ", omittingEmptySubsequences: true)
            if cols.count >= 2, let tag = cols.dropFirst().first {
                names.append(String(tag))
            }
        }
        machineSnapshots[machine.id] = names
    }

    func snapshotList(for machine: CoreVisorMachine) -> [String] {
        machineSnapshots[machine.id] ?? []
    }

    // MARK: - VirtIO ISO auto-download

    /// Downloads the stable virtio-win ISO into the VM's bundle folder (if not already present),
    /// updates the machine record with the new path, and returns the path on success.
    @discardableResult
    func downloadVirtioISO(for machine: CoreVisorMachine) async -> String? {
        guard machine.guest == .windows, machine.backend == .qemu else { return nil }

        // Shared cache: if any machine already has the ISO at a valid path, reuse it.
        if let existing = findCachedVirtioISO(preferring: machine) {
            return await assignVirtioISO(existing, to: machine)
        }

        let destURL = URL(fileURLWithPath: machine.bundlePath).appendingPathComponent("virtio-win.iso")
        if FileManager.default.fileExists(atPath: destURL.path) {
            return await assignVirtioISO(destURL.path, to: machine)
        }

        appendLog("Auto-downloading virtio-win.iso…\n", for: machine.id)
        virtioDownloadProgress[machine.id] = 0.0

        do {
            let downloaded = try await downloadFile(from: Self.virtioWinISOURL, to: destURL) { [weak self] progress in
                DispatchQueue.main.async { self?.virtioDownloadProgress[machine.id] = progress }
            }
            virtioDownloadProgress[machine.id] = nil
            appendLog("virtio-win.iso downloaded to \(downloaded.path)\n", for: machine.id)
            return await assignVirtioISO(downloaded.path, to: machine)
        } catch {
            virtioDownloadProgress[machine.id] = nil
            appendLog("VirtIO ISO download failed: \(error.localizedDescription)\n", for: machine.id)
            lastError = "VirtIO ISO download failed: \(error.localizedDescription)"
            return nil
        }
    }

    /// Downloads the virtio-win ISO to a specific destination URL (used by the setup wizard
    /// before a VM exists). Returns the destination URL on success.
    func downloadVirtioISOToURL(_ destURL: URL) async throws -> URL {
        try await downloadVirtioISOToURLWithProgress(destURL) { _ in }
    }

    /// Downloads the virtio-win ISO with progress callback. Reuses any cached copy.
    func downloadVirtioISOToURLWithProgress(_ destURL: URL, progress: @escaping (Double) -> Void) async throws -> URL {
        if FileManager.default.fileExists(atPath: destURL.path) { return destURL }
        // Reuse from any existing machine
        for m in machines where !m.virtioDriversISOPath.isEmpty {
            if FileManager.default.fileExists(atPath: m.virtioDriversISOPath) {
                try? FileManager.default.copyItem(atPath: m.virtioDriversISOPath, toPath: destURL.path)
                if FileManager.default.fileExists(atPath: destURL.path) { return destURL }
            }
        }
        return try await downloadFile(from: Self.virtioWinISOURL, to: destURL, progress: progress)
    }

    /// Checks all existing machines and the shared cache folder for a valid virtio-win.iso.
    private func findCachedVirtioISO(preferring machine: CoreVisorMachine) -> String? {
        // Check other VMs first
        for m in machines where m.id != machine.id {
            let p = m.virtioDriversISOPath
            if !p.isEmpty && FileManager.default.fileExists(atPath: p) && p.hasSuffix(".iso") { return p }
        }
        // Check shared cache dir
        let shared = libraryRootURL().appendingPathComponent("virtio-win.iso")
        if FileManager.default.fileExists(atPath: shared.path) { return shared.path }
        return nil
    }

    /// Updates the in-memory machine record and persists it with the new virtioDriversISOPath.
    private func assignVirtioISO(_ path: String, to machine: CoreVisorMachine) async -> String? {
        guard let index = machines.firstIndex(where: { $0.id == machine.id }) else { return path }
        guard machines[index].virtioDriversISOPath != path else { return path }
        let updated = CoreVisorMachine(
            id: machine.id, name: machine.name, guest: machine.guest, backend: machine.backend,
            cpuCores: machine.cpuCores, memoryGB: machine.memoryGB, diskGB: machine.diskGB,
            enableVirGL: machine.enableVirGL, enableSound: machine.enableSound,
            useVirtioStorage: machine.useVirtioStorage,
            enableTPM: machine.enableTPM, enableVirtioGPU: machine.enableVirtioGPU,
            isoPath: machine.isoPath, virtioDriversISOPath: path,
            kernelPath: machine.kernelPath, ramdiskPath: machine.ramdiskPath,
            kernelCommandLine: machine.kernelCommandLine,
            selectedUSBDeviceIDs: machine.selectedUSBDeviceIDs,
            bundlePath: machine.bundlePath, diskPath: machine.diskPath, createdAt: machine.createdAt
        )
        machines[index] = updated
        try? persistMachineConfiguration(updated)
        saveMachines()
        return path
    }

    /// Downloads a remote file to a local destination, reporting fractional progress via the callback.
    private func downloadFile(from remoteURL: URL, to destURL: URL, progress: @escaping (Double) -> Void) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            let session = URLSession(configuration: .default)
            var observation: NSKeyValueObservation?
            let task = session.downloadTask(with: remoteURL) { tempURL, response, error in
                observation?.invalidate()
                if let error {
                    continuation.resume(throwing: error); return
                }
                guard let tempURL else {
                    continuation.resume(throwing: self.coreVisorError(40, "Download produced no file.")); return
                }
                do {
                    if FileManager.default.fileExists(atPath: destURL.path) {
                        try FileManager.default.removeItem(at: destURL)
                    }
                    try FileManager.default.moveItem(at: tempURL, to: destURL)
                    continuation.resume(returning: destURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            observation = task.progress.observe(\.fractionCompleted, options: [.new]) { progressValue, _ in
                progress(progressValue.fractionCompleted)
            }
            task.resume()
        }
    }


    func startAllMachines() async {
        for m in machines where runtimeState(for: m) == .stopped || runtimeState(for: m) == .error {
            await startMachine(m)
        }
    }

    func stopAllMachines() {
        for m in machines where runtimeState(for: m) == .running || runtimeState(for: m) == .starting {
            stopMachine(m)
        }
    }

    func createMachine(from draft: CoreVisorDraft) async {
        let d = normalizedDraft(draft)
        do {
            let machine = try await createMachineInternal(from: d)
            machines.append(machine)
            machineStates[machine.id] = .stopped
            machineLogs[machine.id]   = "Created VM bundle at \(machine.bundlePath)\n"
            saveMachines()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Throwing variant used by DoItForMeManager so it can propagate errors.
    func createMachinePublic(from draft: CoreVisorDraft) async throws -> CoreVisorMachine {
        let d = normalizedDraft(draft)
        let machine = try await createMachineInternal(from: d)
        machines.append(machine)
        machineStates[machine.id] = .stopped
        machineLogs[machine.id]   = "Created by Do It For Me pipeline.\n"
        saveMachines()
        lastError = nil
        return machine
    }

    func updateMachine(_ machine: CoreVisorMachine, from draft: CoreVisorDraft) async {
        let d = normalizedDraft(draft)
        guard let index = machines.firstIndex(where: { $0.id == machine.id }) else {
            lastError = "Could not update \(machine.name): VM not found."
            return
        }
        let state = machineStates[machine.id] ?? .stopped
        if state == .running || state == .starting || state == .stopping || isMachineRuntimeActive(machineID: machine.id) {
            lastError = "Stop \(machine.name) before editing its configuration."
            appendLog("Update aborted: VM is currently active.\n", for: machine.id)
            return
        }
        guard isBackendSupported(d.backend, for: d.guest) else {
            lastError = "Selected backend is not supported for this guest."
            return
        }

        let updated = CoreVisorMachine(
            id: machine.id, name: d.name, guest: d.guest, backend: d.backend,
            cpuCores: d.cpuCores, memoryGB: d.memoryGB, diskGB: machine.diskGB,
            enableVirGL: d.enableVirGL, enableSound: d.enableSound,
            useVirtioStorage: d.useVirtioStorage,
            enableTPM: d.enableTPM, enableVirtioGPU: d.enableVirtioGPU,
            isoPath: d.isoPath, virtioDriversISOPath: d.virtioDriversISOPath,
            kernelPath: d.kernelPath, ramdiskPath: d.ramdiskPath,
            kernelCommandLine: d.kernelCommandLine,
            selectedUSBDeviceIDs: Array(d.selectedUSBDeviceIDs).sorted(),
            bundlePath: machine.bundlePath, diskPath: machine.diskPath, createdAt: machine.createdAt
        )

        do {
            try persistMachineConfiguration(updated)
            try ensureMachineRuntimeArtifacts(updated)
            machines[index] = updated
            saveMachines()
            appendLog("Configuration updated.\n", for: machine.id)
            lastError = nil
        } catch {
            lastError = "Failed to update \(machine.name): \(error.localizedDescription)"
            appendLog("Update failed: \(error.localizedDescription)\n", for: machine.id)
        }
    }

    func importUTMBundle(at bundleURL: URL) async {
        isScanning = true
        defer { isScanning = false }
        do {
            let machine = try await importUTMBundleInternal(bundleURL)
            machines.append(machine)
            machineStates[machine.id] = .stopped
            machineLogs[machine.id]   = "Imported from \(bundleURL.path)\n"
            saveMachines()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Import pre-built disk image (qcow2 / vhdx / vmdk / img / raw / vhd)
    /// Imports a pre-made disk image directly as a VM — no installer ISO needed.
    /// Non-qcow2 formats are converted via `qemu-img convert` before registering.
    func importDiskImage(at imageURL: URL) async {
        isScanning = true
        defer { isScanning = false }
        do {
            let machine = try await importDiskImageInternal(imageURL)
            machines.append(machine)
            machineStates[machine.id] = .stopped
            machineLogs[machine.id]   = "Imported pre-built image from \(imageURL.path)\n"
            saveMachines()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func importDiskImageInternal(_ imageURL: URL) async throws -> CoreVisorMachine {
        let allowed: Set<String> = ["qcow2", "img", "raw", "vmdk", "vhd", "vhdx"]
        let ext = imageURL.pathExtension.lowercased()
        guard allowed.contains(ext) else {
            throw coreVisorError(30, "Unsupported image format '\(ext)'. Supported: \(allowed.sorted().joined(separator: ", ")).")
        }
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            throw coreVisorError(31, "Image file not found at \(imageURL.path).")
        }

        let displayName  = imageURL.deletingPathExtension().lastPathComponent
        let safeName     = sanitizeName(displayName)
        let targetBundle = uniqueBundleURL(for: safeName)
        let targetDisk   = targetBundle.appendingPathComponent("disk.qcow2")

        do {
            try FileManager.default.createDirectory(at: targetBundle, withIntermediateDirectories: true)

            if ext == "qcow2" {
                // Direct copy — no conversion needed.
                try FileManager.default.copyItem(at: imageURL, to: targetDisk)
            } else {
                // Convert to qcow2 so QEMU and the Apple Virtualization backend
                // can both use it natively. vhdx in particular is common for
                // pre-built Windows ARM images from UUP dump.
                guard let qemuSys = qemuBinaryPath ?? findQEMUBinary(),
                      let qemuImg = findQEMUImgBinary(qemuSystemPath: qemuSys) else {
                    throw coreVisorError(32, "qemu-img is required to convert \(ext) images.")
                }
                let result = await runProcess(
                    executable: qemuImg,
                    arguments: ["convert", "-p", "-O", "qcow2", imageURL.path, targetDisk.path],
                    timeoutSeconds: 1800   // large images can take a while
                )
                if result.exitCode != 0 {
                    throw coreVisorError(33, "qemu-img convert failed: \(result.output)")
                }
            }

            let attrs  = try FileManager.default.attributesOfItem(atPath: targetDisk.path)
            let bytes  = (attrs[.size] as? NSNumber)?.int64Value ?? 0
            let diskGB = max(4, Int(ceil(Double(bytes) / 1_073_741_824)))

            let guestType = inferredGuestType(from: displayName)

            let machine = CoreVisorMachine(
                id: UUID(), name: displayName, guest: guestType, backend: .qemu,
                cpuCores: guestType == .windows ? 6 : 4,
                memoryGB: guestType == .windows ? 12 : 8,
                diskGB: diskGB,
                enableVirGL: false, enableSound: true,
                useVirtioStorage: false,
                enableTPM: false, enableVirtioGPU: false,
                // No ISO or kernel — this image already has an OS installed.
                isoPath: "", virtioDriversISOPath: "", kernelPath: "", ramdiskPath: "", kernelCommandLine: "",
                selectedUSBDeviceIDs: [],
                bundlePath: targetBundle.path, diskPath: targetDisk.path, createdAt: Date()
            )
            try persistMachineConfiguration(machine)
            try ensureMachineRuntimeArtifacts(machine)
            return machine
        } catch {
            try? FileManager.default.removeItem(at: targetBundle)
            throw error
        }
    }

    func installVirGLBundle(from directoryURL: URL) async {
        isScanning = true
        defer { isScanning = false }
        do {
            let installed = try installVirGLBundleInternal(from: directoryURL)
            setCustomQEMUBinaryPath(installed)
            await refreshRuntimeData()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func removeMachine(_ machine: CoreVisorMachine) async {
        stopMachine(machine)
        await waitForMachineToStop(machineID: machine.id, timeoutSeconds: runtimeStopTimeoutSeconds)

        guard !isMachineRuntimeActive(machineID: machine.id) else {
            lastError = "Could not delete \(machine.name): VM is still running."
            return
        }
        do {
            if FileManager.default.fileExists(atPath: machine.bundlePath) {
                try FileManager.default.removeItem(atPath: machine.bundlePath)
            }
        } catch {
            lastError = "Failed to delete \(machine.name): \(error.localizedDescription)"
            return
        }

        machines.removeAll { $0.id == machine.id }
        machineStates[machine.id] = nil
        machineLogs[machine.id]   = nil
        userInitiatedStops.remove(machine.id)
#if canImport(Virtualization)
        if let observer = appleWindowCloseObservers[machine.id] {
            NotificationCenter.default.removeObserver(observer)
            appleWindowCloseObservers[machine.id] = nil
        }
#endif
        saveMachines()
        lastError = nil
    }

    func startMachine(_ machine: CoreVisorMachine) async {
        guard machineStates[machine.id] != .running, machineStates[machine.id] != .starting else { return }
        lastError = nil

        // Windows must use QEMU (Apple Virtualization doesn't support Windows)
        if machine.guest == .windows && machine.backend != .qemu {
            machineStates[machine.id] = .error
            lastError = "Windows guests must run on QEMU in this build."
            appendLog("Blocked launch: Windows guests are QEMU-only.\n", for: machine.id)
            return
        }
        guard FileManager.default.fileExists(atPath: machine.bundlePath) else {
            machineStates[machine.id] = .error
            lastError = "VM bundle missing for \(machine.name)."
            appendLog("VM bundle not found at \(machine.bundlePath)\n", for: machine.id)
            return
        }
        guard FileManager.default.fileExists(atPath: machine.diskPath) else {
            machineStates[machine.id] = .error
            lastError = "VM disk missing for \(machine.name)."
            appendLog("VM disk not found at \(machine.diskPath)\n", for: machine.id)
            return
        }
        do {
            try prepareRuntimeArtifacts(for: machine)
        } catch {
            machineStates[machine.id] = .error
            lastError = "Failed to prepare VM runtime assets: \(error.localizedDescription)"
            appendLog("Runtime preflight failed: \(error.localizedDescription)\n", for: machine.id)
            return
        }

        machineStates[machine.id] = .starting
        appendLog("Starting \(machine.name)\n", for: machine.id)

        // Auto-download & mount VirtIO ISO for Windows QEMU VMs that don't have one set.
        // We fetch a fresh copy of the machine from the array because assignVirtioISO may
        // have updated it while we awaited the download.
        var effectiveMachine = machine
        if machine.guest == .windows && machine.backend == .qemu && machine.virtioDriversISOPath.isEmpty {
            appendLog("No VirtIO drivers ISO set — attempting auto-download.\n", for: machine.id)
            if let isoPath = await downloadVirtioISO(for: machine) {
                effectiveMachine = machines.first(where: { $0.id == machine.id }) ?? machine
                appendLog("VirtIO ISO ready at \(isoPath)\n", for: machine.id)
            } else {
                appendLog("VirtIO ISO unavailable — continuing without it. Setup may show 'media driver missing'.\n", for: machine.id)
            }
        }

        switch effectiveMachine.backend {
        case .qemu:              await startQEMUMachine(effectiveMachine)
        case .appleVirtualization: await startAppleVirtualizationMachine(effectiveMachine)
        }
    }

    func stopMachine(_ machine: CoreVisorMachine) {
        guard machineStates[machine.id] == .running || machineStates[machine.id] == .starting else { return }
        machineStates[machine.id] = .stopping
        userInitiatedStops.insert(machine.id)
        appendLog("Stop requested by user.\n", for: machine.id)

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            guard let self else { return }
            if self.machineStates[machine.id] == .stopping && !self.isMachineRuntimeActive(machineID: machine.id) {
                self.machineStates[machine.id] = .stopped
                self.userInitiatedStops.remove(machine.id)
            }
        }

        if let process = qemuProcesses[machine.id] { process.terminate(); return }
#if canImport(Virtualization)
        if let session = appleSessions[machine.id] {
            Task { await stopAppleSession(session, machineID: machine.id) }
            return
        }
#endif
        machineStates[machine.id] = .stopped
        userInitiatedStops.remove(machine.id)
    }

    func runtimeState(for machine: CoreVisorMachine) -> CoreVisorRuntimeState {
        machineStates[machine.id] ?? .stopped
    }

    func runtimeLog(for machine: CoreVisorMachine) -> String {
        machineLogs[machine.id] ?? ""
    }

    func clearRuntimeLog(for machine: CoreVisorMachine)  {
        machineLogs[machine.id] = ""
        pendingLogBuffers[machine.id] = nil
        pendingLogFlushWorkItems[machine.id]?.cancel()
        pendingLogFlushWorkItems[machine.id] = nil
    }
    func clearAllRuntimeLogs() {
        for m in machines { machineLogs[m.id] = "" }
        pendingLogBuffers.removeAll()
        pendingLogFlushWorkItems.values.forEach { $0.cancel() }
        pendingLogFlushWorkItems.removeAll()
    }

    var hasAnyRunningMachine: Bool {
        machineStates.values.contains { $0 == .running || $0 == .starting || $0 == .stopping }
    }

    var requiresVirtualizationEntitlement: Bool {
        isAppSandboxed && !hasVirtualizationEntitlement
    }

    // MARK: - QEMU argument builder (fixed Windows boot)

    func qemuArguments(for machine: CoreVisorMachine) -> [String] {
        let qemuName = URL(fileURLWithPath: qemuBinaryPath ?? "").lastPathComponent.lowercased()
#if arch(arm64)
        let hostIsAArch64 = true
#else
        let hostIsAArch64 = false
#endif
        let isAArch64       = qemuName.contains("aarch64") || qemuName.contains("arm") || (qemuName.isEmpty && hostIsAArch64)
        let isWindowsGuest  = machine.guest == .windows
        let isWinAArch64    = isAArch64 && isWindowsGuest
        let hasISO          = !machine.isoPath.isEmpty
        let effectiveMem    = max(1, machine.memoryGB)
        let effectiveCores  = max(1, machine.cpuCores)

        var args: [String] = [
            "-smp",  "\(effectiveCores)",
            "-m",    "\(effectiveMem)G",
            "-accel", "hvf",
            "-accel", "tcg",
        ]

        // ── Machine type ─────────────────────────────────────────────────────────
        if isAArch64 {
            if isWinAArch64 {
                // highmem=on: HVF on Apple Silicon supports it fully and Windows ARM boots fine.
                // highmem=off caps the physical address space to 32 bits (~3 GB), so
                // HVF hard-fails if memoryGB >= 4. The old restriction was TCG-only.
                // gic-version=3 is required for Windows ARM >= 10.
                args += ["-machine", "virt,highmem=on,gic-version=3"]
            } else {
                args += ["-machine", "virt,highmem=on"]
            }
            args += ["-cpu", "host"]

            if let efi = findAArch64UEFIFirmware() {
                if let vars = ensureAArch64UEFIVars(for: machine) {
                    args += [
                        "-drive", "if=pflash,format=raw,readonly=on,file=\(efi)",
                        "-drive", "if=pflash,format=raw,file=\(vars)",
                    ]
                } else {
                    args += ["-bios", efi]
                }
            }
        } else {
            args += ["-machine", "q35", "-cpu", "host"]
        }

        // ── HMP monitor socket (for snapshot save/load/del) ──────────────────────
        // Use /tmp/corevm-{uuid8}/ to stay under the 104-byte UNIX socket path limit.
        let sockDir = socketDir(for: machine)
        try? FileManager.default.createDirectory(atPath: sockDir, withIntermediateDirectories: true)
        let monSock = monitorSocketPath(for: machine)
        args += ["-monitor", "unix:\(monSock),server=on,wait=off"]

        // ── Network & USB ─────────────────────────────────────────────────────────
        args += [
            "-device", "virtio-net-pci",
            "-device", "qemu-xhci,id=xhci",
            "-device", "usb-kbd",
            "-device", "usb-mouse",
            "-device", "usb-tablet",
        ]

        // ── Storage controller + system disk ─────────────────────────────────────
        //
        // All AArch64 guests use virtio-scsi-pci for the system disk.
        // The installer ISO is on usb-storage (not SCSI — see below), so the SCSI
        // bus is dedicated to storage only.
        //
        // Windows ARM WinPE has no vioscsi driver built in, so it can't see the
        // SCSI disk at install time. That's fine: vioscsi lives on the VirtIO USB
        // drive which WinPE enumerates immediately via its built-in USB stack.
        // $WinpeDriver$ in the patched ISO also pre-loads vioscsi automatically.

        if isAArch64 {
            args += ["-device", "virtio-scsi-pci,id=scsi0"]
            if isWinAArch64 && !machine.useVirtioStorage {
                // Use NVMe for Windows ARM installs to avoid relying on injected
                // VirtIO storage drivers during WinPE.
                args += [
                    "-drive",  "if=none,id=system,file=\(machine.diskPath),format=qcow2,cache=writeback",
                    "-device", "nvme,serial=corevisor0,drive=system,bootindex=\(hasISO ? 2 : 1)",
                ]
            } else {
                // virtio-blk-pci for non-Windows AArch64 or post-install Windows.
                args += [
                    "-drive",  "if=none,id=system,file=\(machine.diskPath),format=qcow2",
                    "-device", "virtio-blk-pci,drive=system,bootindex=\(hasISO ? 2 : 1)",
                ]
            }
        } else {
            args += ["-drive", "if=virtio,file=\(machine.diskPath),format=qcow2"]
        }

        // ── Installer ISO ─────────────────────────────────────────────────────────
        // Use a canonical CD-ROM path for installer media on the SCSI bus.
        // This keeps El Torito/UEFI optical boot semantics intact.
        if hasISO {
            if isAArch64 {
                if isWinAArch64 {
                    args += [
                        "-drive",  "if=none,id=cdrom,file=\(machine.isoPath),media=cdrom,readonly=on,file.locking=off",
                        "-device", "scsi-cd,bus=scsi0.0,scsi-id=1,lun=0,drive=cdrom,bootindex=1",
                        "-boot",   "order=d",
                    ]
                } else {
                    args += [
                        "-drive",  "if=none,id=cdrom,file=\(machine.isoPath),media=cdrom,readonly=on,file.locking=off",
                        "-device", "usb-storage,bus=xhci.0,drive=cdrom,removable=true,bootindex=1",
                        "-boot",   "order=d",
                    ]
                }
            } else {
                args += ["-cdrom", machine.isoPath, "-boot", "order=d"]
            }
        } else {
            args += ["-boot", "order=c"]
        }

        // ── VirtIO drivers ISO ────────────────────────────────────────────────────
        //
        // Also on usb-storage, same as the installer ISO. Two USB mass storage
        // devices are fine — EDK2 and WinPE enumerate all of them.
        //
        // WinPE boots from installer media (bootindex=1). The VirtIO USB device
        // appears as an additional drive (no bootindex = not bootable).
        // WinPE's built-in USB stack enumerates it immediately, no extra driver
        // needed, so vioscsi can be loaded from it before the disk/partition screen.
        //
        // Inside Windows the VirtIO ISO will appear as a USB drive at whatever
        // letter Windows assigns. The FirstLogonCommands script in autounattend.xml
        // scans all drive letters by volume content rather than assuming a fixed
        // letter, so driver installation works regardless of enumeration order.
        let hasVirtioISO = !machine.virtioDriversISOPath.isEmpty
        if hasVirtioISO {
            args += [
                "-drive",  "if=none,id=virtiodrv,file=\(machine.virtioDriversISOPath),media=cdrom,readonly=on,file.locking=off",
                "-device", "usb-storage,bus=xhci.0,drive=virtiodrv,removable=true",
            ]
        }

        // Unattend image generated by Do It For Me:
        // FAT32 disk image containing autounattend.xml + $WinpeDriver$/NetKVM.
        // Attached as usb-storage so Windows Setup finds it during its drive scan.
        // Also supports legacy setup-support.iso from older pipeline versions.
        let unattendImg = URL(fileURLWithPath: machine.bundlePath).appendingPathComponent("unattend.img").path
        let setupSupportISO = URL(fileURLWithPath: machine.bundlePath).appendingPathComponent("setup-support.iso").path
        if FileManager.default.fileExists(atPath: unattendImg) {
            let unattendFormat = qemuUnattendImageFormat(at: unattendImg)
            args += [
                "-drive",  "if=none,id=unattend,file=\(unattendImg),format=\(unattendFormat),readonly=on,file.locking=off",
                "-device", "usb-storage,bus=xhci.0,drive=unattend,removable=true",
            ]
            appendLog("Attached unattend image (\(unattendFormat)): \(unattendImg)\n", for: machine.id)
        } else if FileManager.default.fileExists(atPath: setupSupportISO) {
            args += [
                "-drive",  "if=none,id=setupsupport,file=\(setupSupportISO),media=cdrom,readonly=on,file.locking=off",
                "-device", "usb-storage,bus=xhci.0,drive=setupsupport,removable=true",
            ]
            appendLog("Attached setup-support media: \(setupSupportISO)\n", for: machine.id)
        }


        // Windows ARM + HDA crashes reliably; skip sound entirely for those guests.
        if machine.enableSound && !isWinAArch64 {
            args += [
                "-audiodev", "coreaudio,id=ca",
                "-device",   "ich9-intel-hda",
                "-device",   "hda-output,audiodev=ca",
            ]
        }

        // ── Display / GPU ─────────────────────────────────────────────────────────
        //
        // Three display modes for Windows ARM:
        //   ramfb          — safe UEFI framebuffer, no in-guest driver needed.
        //                    Used during install and as the default until the user
        //                    flips enableVirtioGPU after installing the driver.
        //   virtio-gpu-pci — WDDM 2.x driver (viogpudo from virtio-win ISO) gives
        //                    2D acceleration, Aero Glass, DWM compositing, rounded
        //                    corners, transparency. No 3D/DirectX due to Apple
        //                    Silicon vGPU limitations.
        //   virtio-gpu-gl-pci — VirGL OpenGL passthrough (Linux guests only).
        if isWinAArch64 {
            if machine.enableVirtioGPU {
                // Post-install: virtio-gpu-pci with WDDM 2D acceleration.
                // Requires viogpudo driver installed in the guest.
                args += ["-display", "cocoa", "-device", "virtio-gpu-pci"]
            } else {
                // Install / safe mode: ramfb maps directly to the UEFI framebuffer.
                args += ["-display", "cocoa", "-device", "ramfb"]
            }
        } else if machine.enableVirGL {
            args += ["-display", "cocoa,gl=on"]
            args += isAArch64
                ? ["-device", "virtio-gpu-gl-pci"]
                : ["-device", "virtio-vga-gl"]
        } else {
            args += ["-display", "cocoa"]
            args += isAArch64
                ? ["-device", "virtio-gpu-pci"]
                : ["-device", "virtio-vga"]
        }

        // ── TPM 2.0 emulation (swtpm) ─────────────────────────────────────────────
        // swtpm must be running as a daemon before QEMU starts (handled in
        // startQEMUMachine via startSwtpmIfNeeded). QEMU connects over the
        // UNIX socket at tpm.sock inside the bundle.
        // Device: tpm-tis-device for AArch64 (MMIO TIS), tpm-tis for x86 (ISA TIS).
        if machine.enableTPM {
            let tpmSock = tpmSocketPath(for: machine)
            args += [
                "-chardev", "socket,id=chrtpm,path=\(tpmSock)",
                "-tpmdev",  "emulator,id=tpm0,chardev=chrtpm",
                "-device",  isAArch64 ? "tpm-tis-device,tpmdev=tpm0" : "tpm-tis,tpmdev=tpm0",
            ]
        }

        // ── Extra USB pass-through devices ────────────────────────────────────────
        let discoveredIDs = Set(usbDevices.map(\.id))
        for uid in machine.selectedUSBDeviceIDs where discoveredIDs.contains(uid) {
            args += ["-device", uid]
        }

        return args
    }

    func commandPreview(for draft: CoreVisorDraft) -> String {
        switch draft.backend {
        case .appleVirtualization:
            guard draft.guest == .linux else {
                return "Apple Virtualization supports Linux guests only in this build."
            }
            return "Apple Virtualization: Linux runtime configured with kernel+ramdisk boot or EFI+ISO boot."
        case .qemu:
            guard let path = qemuBinaryPath else { return "QEMU binary not found. Install qemu first." }
            let machine = draftToPreviewMachine(draft)
            return shellJoin([path] + qemuArguments(for: machine))
        }
    }

    // MARK: - Backend support check

    func isBackendSupported(_ backend: VMBackend, for guest: VMGuestType) -> Bool {
        switch (backend, guest) {
        case (.appleVirtualization, .linux): return hasVirtualizationAccess
        case (.appleVirtualization, _):      return false
        case (.qemu, _):                     return qemuBinaryPath != nil
        }
    }

    // MARK: - Private internals

    private func waitForMachineToStop(machineID: UUID, timeoutSeconds: TimeInterval) async {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if !isMachineRuntimeActive(machineID: machineID) { return }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
    }

    private func isMachineRuntimeActive(machineID: UUID) -> Bool {
        let state    = machineStates[machineID] ?? .stopped
        let hasQEMU  = qemuProcesses[machineID] != nil
#if canImport(Virtualization)
        let hasApple = appleSessions[machineID] != nil
#else
        let hasApple = false
#endif
        return !((state == .stopped || state == .error) && !hasQEMU && !hasApple)
    }

    private func draftToPreviewMachine(_ draft: CoreVisorDraft) -> CoreVisorMachine {
        let bundleURL = machinesDirectoryURL().appendingPathComponent("preview.corevm", isDirectory: true)
        let ext = draft.backend == .qemu ? "qcow2" : "img"
        return CoreVisorMachine(
            id: UUID(), name: draft.name, guest: draft.guest, backend: draft.backend,
            cpuCores: draft.cpuCores, memoryGB: draft.memoryGB, diskGB: draft.diskGB,
            enableVirGL: draft.enableVirGL, enableSound: draft.enableSound,
            useVirtioStorage: draft.useVirtioStorage,
            enableTPM: draft.enableTPM, enableVirtioGPU: draft.enableVirtioGPU,
            isoPath: draft.isoPath, virtioDriversISOPath: draft.virtioDriversISOPath,
            kernelPath: draft.kernelPath, ramdiskPath: draft.ramdiskPath,
            kernelCommandLine: draft.kernelCommandLine,
            selectedUSBDeviceIDs: Array(draft.selectedUSBDeviceIDs).sorted(),
            bundlePath: bundleURL.path,
            diskPath: bundleURL.appendingPathComponent("disk.\(ext)").path,
            createdAt: Date()
        )
    }

    private func createMachineInternal(from draft: CoreVisorDraft) async throws -> CoreVisorMachine {
        let safeName  = sanitizeName(draft.name)
        let bundleURL = uniqueBundleURL(for: safeName)
        do {
            try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)

            let ext     = draft.backend == .qemu ? "qcow2" : "img"
            let diskURL = bundleURL.appendingPathComponent("disk.\(ext)")

            if draft.backend == .qemu {
                try await createQEMUDisk(at: diskURL, sizeGB: draft.diskGB)
            } else {
                try createRawDisk(at: diskURL, sizeGB: draft.diskGB)
            }

            let machine = CoreVisorMachine(
                id: UUID(), name: draft.name, guest: draft.guest, backend: draft.backend,
                cpuCores: draft.cpuCores, memoryGB: draft.memoryGB, diskGB: draft.diskGB,
                enableVirGL: draft.enableVirGL, enableSound: draft.enableSound,
                useVirtioStorage: draft.useVirtioStorage,
                enableTPM: draft.enableTPM, enableVirtioGPU: draft.enableVirtioGPU,
                isoPath: draft.isoPath, virtioDriversISOPath: draft.virtioDriversISOPath,
                kernelPath: draft.kernelPath, ramdiskPath: draft.ramdiskPath,
                kernelCommandLine: draft.kernelCommandLine,
                selectedUSBDeviceIDs: Array(draft.selectedUSBDeviceIDs).sorted(),
                bundlePath: bundleURL.path, diskPath: diskURL.path, createdAt: Date()
            )
            try persistMachineConfiguration(machine)
            try ensureMachineRuntimeArtifacts(machine)
            return machine
        } catch {
            try? FileManager.default.removeItem(at: bundleURL)
            throw error
        }
    }

    private func importUTMBundleInternal(_ bundleURL: URL) async throws -> CoreVisorMachine {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: bundleURL.path, isDirectory: &isDir), isDir.boolValue else {
            throw coreVisorError(10, "UTM bundle not found.")
        }
        guard bundleURL.pathExtension.lowercased() == "utm" else {
            throw coreVisorError(11, "Selected item is not a .utm bundle.")
        }

        let sourceDisk = try findUTMDiskImage(in: bundleURL)
        let displayName = bundleURL.deletingPathExtension().lastPathComponent
        let safeName    = sanitizeName(displayName)
        let targetBundle = uniqueBundleURL(for: safeName)
        let targetDisk   = targetBundle.appendingPathComponent("disk.qcow2")

        do {
            try FileManager.default.createDirectory(at: targetBundle, withIntermediateDirectories: true)

            if sourceDisk.pathExtension.lowercased() == "qcow2" {
                try FileManager.default.copyItem(at: sourceDisk, to: targetDisk)
            } else {
                guard let qemuSys = qemuBinaryPath ?? findQEMUBinary(),
                      let qemuImg = findQEMUImgBinary(qemuSystemPath: qemuSys) else {
                    throw coreVisorError(12, "qemu-img is required to import this image format.")
                }
                let result = await runProcess(executable: qemuImg,
                                              arguments: ["convert", "-O", "qcow2",
                                                          sourceDisk.path, targetDisk.path],
                                              timeoutSeconds: 900)
                if result.exitCode != 0 { throw coreVisorError(13, "qemu-img convert failed: \(result.output)") }
            }

            let attrs   = try FileManager.default.attributesOfItem(atPath: targetDisk.path)
            let bytes   = (attrs[.size] as? NSNumber)?.int64Value ?? 0
            let diskGB  = max(4, Int(ceil(Double(bytes) / 1_073_741_824)))

            let machine = CoreVisorMachine(
                id: UUID(), name: displayName, guest: inferredGuestType(from: displayName),
                backend: .qemu, cpuCores: 4, memoryGB: 8, diskGB: diskGB,
                enableVirGL: false, enableSound: true,
                useVirtioStorage: false,
                enableTPM: false, enableVirtioGPU: false,
                isoPath: "", virtioDriversISOPath: "", kernelPath: "", ramdiskPath: "", kernelCommandLine: "",
                selectedUSBDeviceIDs: [],
                bundlePath: targetBundle.path, diskPath: targetDisk.path, createdAt: Date()
            )
            try persistMachineConfiguration(machine)
            return machine
        } catch {
            try? FileManager.default.removeItem(at: targetBundle)
            throw error
        }
    }

    private func findUTMDiskImage(in bundleURL: URL) throws -> URL {
        let allowed: Set<String> = ["qcow2", "img", "raw", "vmdk", "vdi", "vhd", "vhdx"]
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(at: bundleURL, includingPropertiesForKeys: Array(keys)) else {
            throw coreVisorError(14, "Unable to inspect UTM bundle.")
        }
        var bestURL: URL?; var bestSize = -1
        for case let fileURL as URL in enumerator {
            guard allowed.contains(fileURL.pathExtension.lowercased()) else { continue }
            let vals = try? fileURL.resourceValues(forKeys: keys)
            guard vals?.isRegularFile == true else { continue }
            let sz = vals?.fileSize ?? 0
            if sz > bestSize { bestURL = fileURL; bestSize = sz }
        }
        guard let bestURL else { throw coreVisorError(15, "No supported disk image found in .utm bundle.") }
        return bestURL
    }

    private func inferredGuestType(from name: String) -> VMGuestType {
        let l = name.lowercased()
        if l.contains("windows") || l.contains("win") { return .windows }
        if l.contains("netbsd") { return .netBSD }
        if l.contains("unix")   { return .unix   }
        return .linux
    }

    private func installVirGLBundleInternal(from directoryURL: URL) throws -> String {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDir), isDir.boolValue else {
            throw coreVisorError(20, "Selected VirGL bundle path is not a directory.")
        }
        guard let sourceBinary = findVirGLBinary(in: directoryURL) else {
            throw coreVisorError(21, "Could not find qemu-virgl inside selected folder.")
        }

        let sourceDir = sourceBinary.deletingLastPathComponent()
        let virglDir  = findVirGLRendererDirectory(near: directoryURL, qemuDirectory: sourceDir)
        let managed   = managedEmbeddedQEMUDirectoryURL()

        do {
            if FileManager.default.fileExists(atPath: managed.path) { try FileManager.default.removeItem(at: managed) }
            try FileManager.default.createDirectory(at: managed.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: managed, withIntermediateDirectories: true)
            try copyDirectoryContents(from: sourceDir, to: managed)
            if let vd = virglDir {
                let target = managed.appendingPathComponent("virglrenderer", isDirectory: true)
                try? FileManager.default.removeItem(at: target)
                try FileManager.default.copyItem(at: vd, to: target)
            }
            guard let installed = findVirGLBinary(in: managed) else {
                throw coreVisorError(22, "Installed VirGL bundle is missing qemu-virgl.")
            }
            try FileManager.default.setAttributes([.posixPermissions: NSNumber(value: Int16(0o755))],
                                                  ofItemAtPath: installed.path)
            return installed.path
        } catch {
            throw coreVisorError(23, "VirGL install failed: \(error.localizedDescription)")
        }
    }

    private func copyDirectoryContents(from src: URL, to dst: URL) throws {
        for child in try FileManager.default.contentsOfDirectory(at: src, includingPropertiesForKeys: nil) {
            try FileManager.default.copyItem(at: child, to: dst.appendingPathComponent(child.lastPathComponent))
        }
    }

    private func findVirGLRendererDirectory(near selected: URL, qemuDirectory: URL) -> URL? {
        let candidates = [
            selected.appendingPathComponent("virglrenderer"),
            selected.deletingLastPathComponent().appendingPathComponent("virglrenderer"),
            qemuDirectory.appendingPathComponent("virglrenderer"),
            qemuDirectory.deletingLastPathComponent().appendingPathComponent("virglrenderer"),
        ]
        return candidates.first(where: { var d: ObjCBool = false; return FileManager.default.fileExists(atPath: $0.path, isDirectory: &d) && d.boolValue })
    }

    private func findVirGLBinary(in dir: URL) -> URL? {
        let direct = dir.appendingPathComponent("qemu-virgl")
        if isExecutableFile(direct.path) { return direct }
        let nested = dir.appendingPathComponent("qemu-virgl/qemu-virgl")
        if isExecutableFile(nested.path)  { return nested }
        guard let enumerator = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: [.isRegularFileKey]) else { return nil }
        for case let url as URL in enumerator {
            if url.lastPathComponent == "qemu-virgl" && isExecutableFile(url.path) { return url }
        }
        return nil
    }

    // MARK: - QEMU launch

    private func startQEMUMachine(_ machine: CoreVisorMachine) async {
        let machineID = machine.id
        guard let qemuBinaryPath else {
            machineStates[machineID] = .error
            lastError = "QEMU binary not found."
            appendLog("QEMU binary not found.\n", for: machineID)
            return
        }
        if !machine.isoPath.isEmpty && !FileManager.default.fileExists(atPath: machine.isoPath) {
            machineStates[machineID] = .error
            lastError = "Installer ISO missing for \(machine.name)."
            appendLog("Installer ISO not found at \(machine.isoPath)\n", for: machineID)
            return
        }
        if !machine.virtioDriversISOPath.isEmpty && !FileManager.default.fileExists(atPath: machine.virtioDriversISOPath) {
            machineStates[machineID] = .error
            lastError = "VirtIO drivers ISO missing for \(machine.name)."
            appendLog("VirtIO drivers ISO not found at \(machine.virtioDriversISOPath)\n", for: machineID)
            return
        }

        let launchMachine = machine
        if machine.guest == .windows {
            resetUEFIVarsForDoItForMeIfNeeded(machine: launchMachine)
        }

        let launchArgs = qemuArguments(for: launchMachine)
        let process    = Process()
        process.executableURL    = URL(fileURLWithPath: qemuBinaryPath)
        process.arguments        = launchArgs
        process.currentDirectoryURL = URL(fileURLWithPath: machine.bundlePath, isDirectory: true)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError  = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { self?.enqueueLogChunk(text, for: machineID) }
        }

        process.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                self?.qemuProcesses[machineID] = nil
                pipe.fileHandleForReading.readabilityHandler = nil
                self?.pendingLogFlushWorkItems[machineID]?.cancel()
                self?.pendingLogFlushWorkItems[machineID] = nil
                self?.flushPendingLog(for: machineID)

                // Tear down swtpm daemon when the VM exits
                self?.swtpmProcesses[machineID]?.terminate()
                self?.swtpmProcesses[machineID] = nil

                let wasUser = self?.userInitiatedStops.remove(machineID) != nil

                if wasUser {
                    self?.machineStates[machineID] = .stopped
                    self?.appendLog("\nVM stopped by user.\n", for: machineID)
                } else if proc.terminationReason == .exit && proc.terminationStatus == 0 {
                    self?.machineStates[machineID] = .stopped
                    self?.appendLog("\nVM exited cleanly.\n", for: machineID)
                } else {
                    self?.machineStates[machineID] = .error
                    if proc.terminationReason == .uncaughtSignal && proc.terminationStatus == 9 {
                        self?.lastError = "QEMU was killed by SIGKILL — macOS likely blocked the binary. Try setting a custom Homebrew QEMU path."
                        self?.appendLog("\nQEMU received SIGKILL (9). Set a custom Homebrew QEMU path in CoreVisor settings.\n", for: machineID)
                    } else {
                        self?.lastError = "QEMU stopped unexpectedly with status \(proc.terminationStatus)."
                    }
                    self?.appendLog("\nVM stopped unexpectedly (status \(proc.terminationStatus)).\n", for: machineID)
                }
            }
        }

        // ── Start swtpm daemon before QEMU if TPM is enabled ─────────────────────
        if machine.enableTPM {
            if let seed = TPMKeychainStore.load(for: machineID) {
                do {
                    let swtpmProc = try SwtpmController.startDaemon(bundlePath: machine.bundlePath, machineID: machineID, seed: seed)
                    swtpmProcesses[machineID] = swtpmProc
                    appendLog("swtpm daemon started (pid \(swtpmProc.processIdentifier)).\n", for: machineID)
                } catch {
                    appendLog("⚠︎ swtpm failed to start — TPM unavailable: \(error.localizedDescription)\n", for: machineID)
                }
            } else {
                appendLog("⚠︎ No TPM seed in Keychain for this VM. Re-run Do It For Me or disable TPM.\n", for: machineID)
            }
        }

        do {
            try process.run()
            qemuProcesses[machineID] = process
            machineStates[machineID] = .running
            appendLog("Launch command: \(shellJoin([qemuBinaryPath] + launchArgs))\n", for: machineID)
            appendLog("QEMU process started.\n", for: machineID)
        } catch {
            machineStates[machineID] = .error
            lastError = "Failed to launch QEMU: \(error.localizedDescription)"
            appendLog("Failed to launch QEMU: \(error.localizedDescription)\n", for: machineID)
        }
    }

    // MARK: - Apple Virtualization

#if canImport(Virtualization)
    private func startAppleVirtualizationMachine(_ machine: CoreVisorMachine) async {
        guard #available(macOS 13.0, *) else {
            machineStates[machine.id] = .error
            appendLog("Apple Virtualization requires macOS 13 or newer.\n", for: machine.id)
            lastError = "Apple Virtualization requires macOS 13 or newer."
            return
        }

        guard machine.guest == .linux else {
            machineStates[machine.id] = .error
            appendLog("Apple Virtualization supports Linux guests only.\n", for: machine.id)
            lastError = "Apple Virtualization supports Linux guests only."
            return
        }
        if machine.kernelPath.isEmpty && machine.isoPath.isEmpty {
            machineStates[machine.id] = .error
            appendLog("Apple Virtualization requires kernel path or installer ISO.\n", for: machine.id)
            lastError = "Apple Virtualization boot requires kernel or ISO."
            return
        }
        guard hasVirtualizationAccess else {
            machineStates[machine.id] = .error
            appendLog("Apple Virtualization unavailable: missing virtualization entitlement.\n", for: machine.id)
            lastError = "Apple Virtualization requires `com.apple.security.virtualization` entitlement."
            return
        }

        do {
            let config = try createAppleVMConfiguration(for: machine)
            let vm     = VZVirtualMachine(configuration: config)

            let session = AppleVMSession(virtualMachine: vm) { [weak self] error in
                guard let self else { return }
                let wasUser = self.userInitiatedStops.remove(machine.id) != nil
                if wasUser {
                    self.machineStates[machine.id] = .stopped
                    self.appendLog("Guest stopped by user.\n", for: machine.id)
                } else if let error {
                    self.machineStates[machine.id] = .error
                    self.appendLog("Stopped with error: \(error.localizedDescription)\n", for: machine.id)
                } else {
                    self.machineStates[machine.id] = .stopped
                    self.appendLog("Guest stopped.\n", for: machine.id)
                }
                self.appleDisplayWindows[machine.id]?.close()
                self.appleDisplayWindows[machine.id] = nil
                if let obs = self.appleWindowCloseObservers[machine.id] {
                    NotificationCenter.default.removeObserver(obs)
                    self.appleWindowCloseObservers[machine.id] = nil
                }
                self.appleSessions[machine.id] = nil
            }

            vm.delegate = session
            appleSessions[machine.id] = session
            presentAppleVMWindow(for: machine, virtualMachine: vm)

            try await vm.start()
            machineStates[machine.id] = .running
            appendLog("Apple Virtualization VM started.\n", for: machine.id)
        } catch {
            appleDisplayWindows[machine.id]?.close()
            appleDisplayWindows[machine.id] = nil
            if let obs = appleWindowCloseObservers[machine.id] {
                NotificationCenter.default.removeObserver(obs)
                appleWindowCloseObservers[machine.id] = nil
            }
            appleSessions[machine.id] = nil
            userInitiatedStops.remove(machine.id)
            machineStates[machine.id] = .error
            lastError = "Apple Virtualization start failed: \(error.localizedDescription)"
            appendLog("Start failed: \(error.localizedDescription)\n", for: machine.id)
        }
    }

    @available(macOS 13.0, *)
    private func createAppleVMConfiguration(for machine: CoreVisorMachine) throws -> VZVirtualMachineConfiguration {
        let config = VZVirtualMachineConfiguration()
        config.cpuCount  = max(1, machine.cpuCores)
        config.memorySize = UInt64(max(2, machine.memoryGB)) * 1_073_741_824

        let platform = VZGenericPlatformConfiguration()
        platform.machineIdentifier = try loadOrCreateGenericMachineIdentifier(for: machine)
        config.platform = platform

        if !machine.kernelPath.isEmpty {
            let boot = VZLinuxBootLoader(kernelURL: URL(fileURLWithPath: machine.kernelPath))
            if !machine.ramdiskPath.isEmpty { boot.initialRamdiskURL = URL(fileURLWithPath: machine.ramdiskPath) }
            boot.commandLine = machine.kernelCommandLine
            config.bootLoader = boot
        } else {
            let boot = VZEFIBootLoader()
            boot.variableStore = try loadOrCreateEFIVariableStore(for: machine)
            config.bootLoader = boot
        }

        let net = VZVirtioNetworkDeviceConfiguration()
        net.attachment = VZNATNetworkDeviceAttachment()
        config.networkDevices = [net]
        config.entropyDevices = [VZVirtioEntropyDeviceConfiguration()]
        config.memoryBalloonDevices = [VZVirtioTraditionalMemoryBalloonDeviceConfiguration()]

        let diskAttach = try VZDiskImageStorageDeviceAttachment(url: URL(fileURLWithPath: machine.diskPath), readOnly: false)
        var storage: [VZStorageDeviceConfiguration] = [VZVirtioBlockDeviceConfiguration(attachment: diskAttach)]

        if !machine.isoPath.isEmpty, FileManager.default.fileExists(atPath: machine.isoPath) {
            let iso = try VZDiskImageStorageDeviceAttachment(url: URL(fileURLWithPath: machine.isoPath), readOnly: true)
            storage.append(VZVirtioBlockDeviceConfiguration(attachment: iso))
        }
        config.storageDevices = storage

        let gfx = VZVirtioGraphicsDeviceConfiguration()
        gfx.scanouts = [VZVirtioGraphicsScanoutConfiguration(widthInPixels: 1280, heightInPixels: 800)]
        config.graphicsDevices = [gfx]
        config.keyboards = [VZUSBKeyboardConfiguration()]
        config.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]

        try config.validate()
        return config
    }

    @available(macOS 13.0, *)
    private func loadOrCreateEFIVariableStore(for machine: CoreVisorMachine) throws -> VZEFIVariableStore {
        let url = URL(fileURLWithPath: machine.bundlePath).appendingPathComponent(efiVariableStoreFileName)
        if FileManager.default.fileExists(atPath: url.path) { return VZEFIVariableStore(url: url) }
        return try VZEFIVariableStore(creatingVariableStoreAt: url)
    }

    @available(macOS 13.0, *)
    private func loadOrCreateGenericMachineIdentifier(for machine: CoreVisorMachine) throws -> VZGenericMachineIdentifier {
        let url = URL(fileURLWithPath: machine.bundlePath).appendingPathComponent(genericMachineIdentifierFileName)
        if FileManager.default.fileExists(atPath: url.path),
           let data = try? Data(contentsOf: url),
           let id   = VZGenericMachineIdentifier(dataRepresentation: data) { return id }
        let id = VZGenericMachineIdentifier()
        try id.dataRepresentation.write(to: url, options: [.atomic])
        return id
    }

    private func stopAppleSession(_ session: AppleVMSession, machineID: UUID) async {
        do {
            if session.virtualMachine.canRequestStop {
                try session.virtualMachine.requestStop()
            } else if session.virtualMachine.canStop {
                try await session.virtualMachine.stop()
            }
        } catch {
            machineStates[machineID] = .error
            appendLog("Stop failed: \(error.localizedDescription)\n", for: machineID)
        }
    }

#if canImport(AppKit)
    private func presentAppleVMWindow(for machine: CoreVisorMachine, virtualMachine: VZVirtualMachine) {
        let vmView = VZVirtualMachineView(frame: NSRect(x: 0, y: 0, width: 1280, height: 800))
        vmView.virtualMachine = virtualMachine
        vmView.capturesSystemKeys = true
        if #available(macOS 14.0, *) { vmView.automaticallyReconfiguresDisplay = true }

        let vc = NSViewController()
        vc.view = vmView

        let window = NSWindow(
            contentRect: NSRect(x: 140, y: 120, width: 1280, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = "\(machine.name) — CoreVisor"
        window.contentViewController = vc
        window.minSize = NSSize(width: 900, height: 560)

        let controller = NSWindowController(window: window)
        appleDisplayWindows[machine.id] = controller
        appleWindowCloseObservers[machine.id] = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.machineStates[machine.id] == .running || self.machineStates[machine.id] == .starting {
                    self.stopMachine(machine)
                }
            }
        }
        controller.showWindow(nil)
    }
#endif
#else
    private func startAppleVirtualizationMachine(_ machine: CoreVisorMachine) async {
        machineStates[machine.id] = .error
        appendLog("Virtualization framework unavailable on this build.\n", for: machine.id)
    }
#endif

    // MARK: - Disk creation

    private func createQEMUDisk(at diskURL: URL, sizeGB: Int) async throws {
        guard let qemuSys = qemuBinaryPath else {
            throw coreVisorError(1, "QEMU binary missing.")
        }
        guard let qemuImg = findQEMUImgBinary(qemuSystemPath: qemuSys) else {
            throw coreVisorError(2, "qemu-img not found.")
        }
        let result = await runProcess(executable: qemuImg,
                                      arguments: ["create", "-f", "qcow2", diskURL.path, "\(max(4, sizeGB))G"])
        if result.exitCode != 0 { throw coreVisorError(3, "qemu-img failed: \(result.output)") }
    }

    private func createRawDisk(at diskURL: URL, sizeGB: Int) throws {
        let bytes = UInt64(max(4, sizeGB)) * 1_073_741_824
        guard FileManager.default.createFile(atPath: diskURL.path, contents: nil) else {
            throw coreVisorError(4, "Failed to create raw disk file.")
        }
        let handle = try FileHandle(forWritingTo: diskURL)
        try handle.truncate(atOffset: bytes)
        try handle.close()
    }

    // MARK: - Runtime artifact helpers

    private func prepareRuntimeArtifacts(for machine: CoreVisorMachine) throws {
        if machine.backend == .appleVirtualization { try ensureMachineRuntimeArtifacts(machine); return }
        let configURL = URL(fileURLWithPath: machine.bundlePath).appendingPathComponent(machineConfigFileName)
        if !FileManager.default.fileExists(atPath: configURL.path) { try persistMachineConfiguration(machine) }
    }

    private func ensureMachineRuntimeArtifacts(_ machine: CoreVisorMachine) throws {
        let bundleURL = URL(fileURLWithPath: machine.bundlePath)
        if !FileManager.default.fileExists(atPath: bundleURL.path) {
            try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        }
        try persistMachineConfiguration(machine)
        guard machine.backend == .appleVirtualization else { return }
#if canImport(Virtualization)
        if #available(macOS 13.0, *) {
            _ = try loadOrCreateGenericMachineIdentifier(for: machine)
            _ = try loadOrCreateEFIVariableStore(for: machine)
        }
#endif
    }

    private func persistMachineConfiguration(_ machine: CoreVisorMachine) throws {
        let url  = URL(fileURLWithPath: machine.bundlePath).appendingPathComponent(machineConfigFileName)
        let data = try JSONEncoder().encode(machine)
        try data.write(to: url, options: [.atomic])
    }

    // MARK: - Logging

    private func appendLog(_ text: String, for machineID: UUID) {
        guard !text.isEmpty else { return }
        let ts = Self.logTimestampFormatter.string(from: Date())
        var existing = machineLogs[machineID] ?? ""
        let prefix = "[\(ts)] "
        var prefixed = prefix + text.replacingOccurrences(of: "\n", with: "\n" + prefix)
        if prefixed.hasSuffix(prefix) {
            prefixed.removeLast(prefix.count)
        }
        existing.append(prefixed)
        if existing.count > runtimeLogLimit { existing = String(existing.suffix(runtimeLogLimit)) }
        machineLogs[machineID] = existing
    }

    private func enqueueLogChunk(_ text: String, for machineID: UUID) {
        guard !text.isEmpty else { return }
        pendingLogBuffers[machineID, default: ""].append(text)
        guard pendingLogFlushWorkItems[machineID] == nil else { return }

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingLogFlushWorkItems[machineID] = nil
            self.flushPendingLog(for: machineID)
        }
        pendingLogFlushWorkItems[machineID] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + runtimeLogFlushInterval, execute: work)
    }

    private func flushPendingLog(for machineID: UUID) {
        guard let pending = pendingLogBuffers.removeValue(forKey: machineID), !pending.isEmpty else { return }
        appendLog(pending, for: machineID)
    }

    private func shellJoin(_ args: [String]) -> String { args.map(shellQuote).joined(separator: " ") }
    private func shellQuote(_ v: String)       -> String { "'" + v.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    private func qemuUnattendImageFormat(at path: String) -> String {
        // hdiutil-created images may be either UDIF-backed (.dmg container) or raw.
        // QEMU must be told the correct format or launch fails immediately.
        guard let handle = FileHandle(forReadingAtPath: path) else { return "raw" }
        defer { try? handle.close() }
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber)?.uint64Value ?? 0
        guard fileSize >= 512 else { return "raw" }
        do {
            try handle.seek(toOffset: fileSize - 512)
            let trailer = handle.readData(ofLength: 4)
            if trailer == Data("koly".utf8) {
                return "dmg"
            }
        } catch {
            return "raw"
        }
        return "raw"
    }

    private static let logTimestampFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f
    }()

    // MARK: - Persistence

    private func loadMachines() {
        machineStates = [:]; machineLogs = [:]
        for url in [libraryIndexURL(), legacyLibraryIndexURL()] {
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            if let data = try? Data(contentsOf: url),
               let lib  = try? JSONDecoder().decode(CoreVisorLibrary.self, from: data) {
                machines = lib.machines.sorted { $0.createdAt > $1.createdAt }
                for m in machines { machineStates[m.id] = .stopped }
                if !machines.isEmpty { lastError = nil }
                return
            }
        }
        machines = []
    }

    private func saveMachines() {
        do {
            try FileManager.default.createDirectory(at: libraryRootURL(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(CoreVisorLibrary(machines: machines))
            try data.write(to: libraryIndexURL(), options: [.atomic])
        } catch {
            lastError = "Failed to save VM library: \(error.localizedDescription)"
        }
    }

    func libraryRootURL() -> URL {
        let id = Bundle.main.bundleIdentifier ?? "Core-Monitor"
        return (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser)
            .appendingPathComponent(id)
            .appendingPathComponent("CoreVisor")
    }

    private func machinesDirectoryURL() -> URL {
        let url = libraryRootURL().appendingPathComponent("VMs")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func libraryIndexURL()       -> URL { libraryRootURL().appendingPathComponent("library.json") }
    private func legacyLibraryRootURL()  -> URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("CoreVisor") }
    private func legacyLibraryIndexURL() -> URL { legacyLibraryRootURL().appendingPathComponent("library.json") }

    // MARK: - QEMU binary resolution

    private func findQEMUBinary() -> String? {
        let custom = customQEMUBinaryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty {
            if custom.hasPrefix("/"), isUsableQEMUBinary(custom) { return custom }
            if let r = resolveExecutable(named: custom), isUsableQEMUBinary(r) { return r }
            return nil
        }
        if let sys = findSystemQEMUBinary() { return sys }
        if let bundled = findBundledQEMUBinary(), isUsableQEMUBinary(bundled) { return bundled }
        return nil
    }

    private func bootstrapVirGLRuntimeOnStartup() {
        if let managed = installManagedVirGLIfNeeded() {
            if customQEMUBinaryPath != managed { setCustomQEMUBinaryPath(managed) }
            return
        }
        if let bundled = findBundledVirGLBinaryPath(), isExecutableFile(bundled) {
            if customQEMUBinaryPath != bundled { setCustomQEMUBinaryPath(bundled) }
        }
    }

    private func installManagedVirGLIfNeeded() -> String? {
        guard let bundled = bundledEmbeddedQEMUDirectoryURL() else { return nil }
        let managed       = managedEmbeddedQEMUDirectoryURL()
        let managedVirgl  = managed.appendingPathComponent("qemu-virgl")
        do {
            if !FileManager.default.fileExists(atPath: managed.path) {
                try FileManager.default.createDirectory(at: managed.deletingLastPathComponent(), withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: bundled, to: managed)
            } else if !FileManager.default.fileExists(atPath: managedVirgl.path) {
                try? FileManager.default.removeItem(at: managed)
                try FileManager.default.copyItem(at: bundled, to: managed)
            }
            if FileManager.default.fileExists(atPath: managedVirgl.path) {
                try FileManager.default.setAttributes([.posixPermissions: NSNumber(value: Int16(0o755))], ofItemAtPath: managedVirgl.path)
                return managedVirgl.path
            }
        } catch { lastError = "VirGL bootstrap failed: \(error.localizedDescription)" }
        return nil
    }

    private func bundledEmbeddedQEMUDirectoryURL() -> URL? {
        guard let res = Bundle.main.resourceURL else { return nil }
        let url = res.appendingPathComponent("EmbeddedQEMU")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func managedEmbeddedQEMUDirectoryURL() -> URL {
        libraryRootURL().appendingPathComponent(managedEmbeddedQEMUFolderName)
    }

    private func findBundledVirGLBinaryPath() -> String? {
        guard let res = Bundle.main.resourceURL?.path else { return nil }
        let path = (res as NSString).appendingPathComponent("EmbeddedQEMU/qemu-virgl")
        return isExecutableFile(path) ? path : nil
    }

    private func findSystemQEMUBinary() -> String? {
        let candidates = ["qemu-system-aarch64", "qemu-system-x86_64", "qemu-system-arm"]
        let discovered = candidates.compactMap { resolveExecutable(named: $0) }
        let unique     = Array(Set(discovered)).sorted { qemuPriority($0) < qemuPriority($1) }
        return unique.first(where: { isUsableQEMUBinary($0) })
    }

    private func findQEMUImgBinary(qemuSystemPath: String) -> String? {
        if let b = findBundledQEMUImgBinary() { return b }
        let sib = URL(fileURLWithPath: qemuSystemPath).deletingLastPathComponent().appendingPathComponent("qemu-img").path
        if isExecutableFile(sib) { return sib }
        return resolveExecutable(named: "qemu-img")
    }

    private func findBundledQEMUBinary() -> String? {
        guard let res = Bundle.main.resourceURL?.path else { return nil }
        return [
            (res as NSString).appendingPathComponent("EmbeddedQEMU/qemu-system-aarch64"),
            (res as NSString).appendingPathComponent("EmbeddedQEMU/qemu-system-x86_64"),
            (res as NSString).appendingPathComponent("EmbeddedQEMU/qemu-virgl"),
        ].first(where: { isExecutableFile($0) })
    }

    private func findBundledQEMUImgBinary() -> String? {
        guard let res = Bundle.main.resourceURL?.path else { return nil }
        return [
            (res as NSString).appendingPathComponent("EmbeddedQEMU/qemu-img"),
            (res as NSString).appendingPathComponent("EmbeddedQEMU/bin/qemu-img"),
        ].first(where: { isExecutableFile($0) })
    }

    private func resolveExecutable(named name: String) -> String? {
        for dir in executableSearchPaths() {
            let path = (dir as NSString).appendingPathComponent(name)
            if isExecutableFile(path) { return path }
        }
        return nil
    }

    private func executableSearchPaths() -> [String] {
        let envPaths = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(String.init)
        let home     = FileManager.default.homeDirectoryForCurrentUser.path
        let defaults = ["\(home)/bin", "\(home)/.local/bin", "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
        var ordered: [String] = []
        for p in envPaths + defaults where !p.isEmpty && !ordered.contains(p) { ordered.append(p) }
        return ordered
    }

    private func isExecutableFile(_ path: String) -> Bool { FileManager.default.isExecutableFile(atPath: path) }
    private func isUsableQEMUBinary(_ path: String) -> Bool {
        guard isExecutableFile(path) else { return false }
        let name = URL(fileURLWithPath: path).lastPathComponent.lowercased()
        return name.hasPrefix("qemu-system-") || name == "qemu-virgl"
    }

    private func qemuPriority(_ path: String) -> Int {
        let name = URL(fileURLWithPath: path).lastPathComponent.lowercased()
        if name == "qemu-virgl"         { return 0 }
        if name.contains("aarch64")     { return 1 }
        if name.contains("x86_64")      { return 2 }
        if name.hasPrefix("qemu-system-") { return 3 }
        return 4
    }

    // MARK: - UEFI firmware helpers

    private func findAArch64UEFIFirmware() -> String? {
        var candidates: [String] = []
        if let q = qemuBinaryPath {
            let bin   = URL(fileURLWithPath: q).deletingLastPathComponent().path
            let share = URL(fileURLWithPath: bin).deletingLastPathComponent().appendingPathComponent("share/qemu").path
            candidates += [
                (bin   as NSString).appendingPathComponent("edk2-aarch64-code.fd"),
                (bin   as NSString).appendingPathComponent("edk2-arm-code.fd"),
                (share as NSString).appendingPathComponent("edk2-aarch64-code.fd"),
                (share as NSString).appendingPathComponent("edk2-arm-code.fd"),
            ]
        }
        if let res = Bundle.main.resourceURL?.path {
            candidates += [
                (res as NSString).appendingPathComponent("EmbeddedQEMU/edk2-aarch64-code.fd"),
                (res as NSString).appendingPathComponent("EmbeddedQEMU/edk2-arm-code.fd"),
            ]
        }
        candidates += [
            "/opt/homebrew/share/qemu/edk2-aarch64-code.fd",
            "/usr/local/share/qemu/edk2-aarch64-code.fd",
        ]
        return candidates.first(where: { FileManager.default.isReadableFile(atPath: $0) })
    }

    private func findAArch64UEFIVarsTemplate() -> String? {
        var candidates: [String] = []
        if let q = qemuBinaryPath {
            let bin   = URL(fileURLWithPath: q).deletingLastPathComponent().path
            let share = URL(fileURLWithPath: bin).deletingLastPathComponent().appendingPathComponent("share/qemu").path
            candidates += [
                (bin   as NSString).appendingPathComponent("edk2-aarch64-vars.fd"),
                (bin   as NSString).appendingPathComponent("edk2-arm-vars.fd"),
                (share as NSString).appendingPathComponent("edk2-aarch64-vars.fd"),
                (share as NSString).appendingPathComponent("edk2-arm-vars.fd"),
            ]
        }
        if let res = Bundle.main.resourceURL?.path {
            candidates += [
                (res as NSString).appendingPathComponent("EmbeddedQEMU/edk2-aarch64-vars.fd"),
                (res as NSString).appendingPathComponent("EmbeddedQEMU/edk2-arm-vars.fd"),
            ]
        }
        candidates += [
            "/opt/homebrew/share/qemu/edk2-aarch64-vars.fd",
            "/usr/local/share/qemu/edk2-aarch64-vars.fd",
        ]
        return candidates.first(where: { FileManager.default.isReadableFile(atPath: $0) })
    }

    private func ensureAArch64UEFIVars(for machine: CoreVisorMachine) -> String? {
        let varsURL = URL(fileURLWithPath: machine.bundlePath).appendingPathComponent("efi-vars.fd")
        if FileManager.default.isReadableFile(atPath: varsURL.path) { return varsURL.path }
        guard let template = findAArch64UEFIVarsTemplate() else { return nil }
        do {
            try? FileManager.default.createDirectory(at: varsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.copyItem(atPath: template, toPath: varsURL.path)
            return varsURL.path
        } catch {
            appendLog("Failed to prepare EFI vars store: \(error.localizedDescription)\n", for: machine.id)
            return nil
        }
    }

    private func resetUEFIVarsForDoItForMeIfNeeded(machine: CoreVisorMachine) {
        let fm = FileManager.default
        let supportISO = URL(fileURLWithPath: machine.bundlePath).appendingPathComponent("setup-support.iso").path
        guard fm.fileExists(atPath: supportISO), !machine.isoPath.isEmpty else { return }
        guard let template = findAArch64UEFIVarsTemplate() else { return }

        let varsURL = URL(fileURLWithPath: machine.bundlePath).appendingPathComponent("efi-vars.fd")
        do {
            if fm.fileExists(atPath: varsURL.path) { try fm.removeItem(at: varsURL) }
            try fm.copyItem(atPath: template, toPath: varsURL.path)
            appendLog("Reset EFI vars for installer boot.\n", for: machine.id)
        } catch {
            appendLog("Failed to reset EFI vars: \(error.localizedDescription)\n", for: machine.id)
        }
    }

    // MARK: - Entitlement checks

    func refreshEntitlementStatus() {
        isAppSandboxed           = readBooleanEntitlement(key: "com.apple.security.app-sandbox")
        hasVirtualizationEntitlement = readBooleanEntitlement(key: "com.apple.security.virtualization")
    }

    private var hasVirtualizationAccess: Bool { !isAppSandboxed || hasVirtualizationEntitlement }

    private func readBooleanEntitlement(key: String) -> Bool {
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        return (SecTaskCopyValueForEntitlement(task, key as CFString, nil) as? Bool) == true
    }

    // MARK: - QEMU capability probing

    private func qemuHasOpenGLDisplaySupport(qemuBinaryPath: String) async -> Bool {
        let result = await runProcess(executable: qemuBinaryPath, arguments: ["-display", "help"])
        return result.exitCode == 0 && result.output.lowercased().contains("cocoa,gl=on")
    }

    private func loadQEMUUSBDevices(qemuBinaryPath: String) async -> [QEMUUSBDevice] {
        let result = await runProcess(executable: qemuBinaryPath, arguments: ["-device", "help"])
        guard result.exitCode == 0, !result.output.isEmpty else { return [] }

        var devices: [QEMUUSBDevice] = []
        var seen: Set<String> = []

        for line in result.output.split(separator: "\n").map(String.init) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("name ") else { continue }
            let parts   = trimmed.components(separatedBy: ",")
            guard let namePart = parts.first else { continue }
            let rawName = namePart
                .replacingOccurrences(of: "name ", with: "")
                .replacingOccurrences(of: "\"", with: "")
                .trimmingCharacters(in: .whitespaces)
            guard rawName.lowercased().contains("usb"), !seen.contains(rawName) else { continue }
            let detail = parts.dropFirst().joined(separator: ",").trimmingCharacters(in: .whitespaces)
            devices.append(QEMUUSBDevice(id: rawName, name: rawName, detail: detail))
            seen.insert(rawName)
        }
        return devices.sorted { $0.name < $1.name }
    }

    // MARK: - Process runner

    private func runProcess(executable: String, arguments: [String], timeoutSeconds: TimeInterval = 8.0) async -> (output: String, exitCode: Int32) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments     = arguments
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError  = pipe
                do { try process.run() } catch {
                    continuation.resume(returning: ("", -1)); return
                }
                let deadline = Date().addingTimeInterval(timeoutSeconds)
                while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
                if process.isRunning {
                    process.terminate()
                    Thread.sleep(forTimeInterval: 0.1)
                    if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                    let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    continuation.resume(returning: ("\(out)\n[CoreVisor] Process timed out.", -2))
                    return
                }
                let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                continuation.resume(returning: (out, process.terminationStatus))
            }
        }
    }


    // MARK: - Name utilities

    private func sanitizeName(_ text: String) -> String {
        let trimmed  = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "corevisor-vm" : trimmed
        let allowed  = String(fallback.lowercased().map { ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") ? $0 : Character("-") })
        let norm     = allowed
            .replacingOccurrences(of: "--+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        return norm.isEmpty ? "corevisor-vm" : norm
    }

    private func normalizedDraft(_ draft: CoreVisorDraft) -> CoreVisorDraft {
        var d = draft
        d.name = d.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if d.name.isEmpty { d.name = "New VM" }
        d.cpuCores             = min(max(d.cpuCores, 1), 64)
        d.memoryGB             = min(max(d.memoryGB, 1), 256)
        d.diskGB               = min(max(d.diskGB, 4), 2048)
        d.isoPath              = d.isoPath.trimmingCharacters(in: .whitespacesAndNewlines)
        d.virtioDriversISOPath = d.virtioDriversISOPath.trimmingCharacters(in: .whitespacesAndNewlines)
        d.kernelPath           = d.kernelPath.trimmingCharacters(in: .whitespacesAndNewlines)
        d.ramdiskPath          = d.ramdiskPath.trimmingCharacters(in: .whitespacesAndNewlines)
        d.kernelCommandLine    = d.kernelCommandLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if d.kernelCommandLine.isEmpty { d.kernelCommandLine = "console=hvc0" }
        if d.guest == .windows { d.backend = .qemu }
        d.selectedUSBDeviceIDs = Set(d.selectedUSBDeviceIDs)
        return d
    }

    private func makeDuplicateName(from base: String) -> String {
        let prefix = base.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "VM" : base.trimmingCharacters(in: .whitespacesAndNewlines)
        let existing = Set(machines.map { $0.name.lowercased() })
        var suffix = 2; var candidate = "\(prefix) Copy"
        while existing.contains(candidate.lowercased()) { candidate = "\(prefix) Copy \(suffix)"; suffix += 1 }
        return candidate
    }

    private func uniqueBundleURL(for safeName: String) -> URL {
        let root = machinesDirectoryURL()
        var candidate = root.appendingPathComponent("\(safeName).corevm")
        var suffix = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = root.appendingPathComponent("\(safeName)-\(suffix).corevm"); suffix += 1
        }
        return candidate
    }

    nonisolated private func coreVisorError(_ code: Int, _ message: String) -> NSError {
        NSError(domain: "CoreVisor", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

// MARK: - Apple VM session delegate

#if canImport(Virtualization)
private final class AppleVMSession: NSObject, VZVirtualMachineDelegate {
    let virtualMachine: VZVirtualMachine
    private let onStop: (Error?) -> Void

    init(virtualMachine: VZVirtualMachine, onStop: @escaping (Error?) -> Void) {
        self.virtualMachine = virtualMachine
        self.onStop         = onStop
    }

    func guestDidStop(_ virtualMachine: VZVirtualMachine)                           { onStop(nil)   }
    func virtualMachine(_ vm: VZVirtualMachine, didStopWithError error: Error)      { onStop(error) }
}
#endif
