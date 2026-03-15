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
    case linux = "Linux"
    case windows = "Windows"
    case macOS = "macOS"
    case netBSD = "NetBSD"
    case unix = "UNIX"

    var id: String { rawValue }
}

enum VMBackend: String, CaseIterable, Identifiable, Codable {
    case appleVirtualization = "Apple Virtualization"
    case qemu = "QEMU"

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
    var name: String = "New VM"
    var guest: VMGuestType = .linux
    var backend: VMBackend = .qemu
    var cpuCores: Int = 4
    var memoryGB: Int = 8
    var diskGB: Int = 64
    var enableVirGL: Bool = false
    var enableSound: Bool = true
    var selectedUSBDeviceIDs: Set<String> = []
    var isoPath: String = ""
    var kernelPath: String = ""
    var ramdiskPath: String = ""
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
    let isoPath: String
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

    let templates: [CoreVisorTemplate] = [
        CoreVisorTemplate(guest: .linux, name: "Linux Desktop", cpuCores: 4, memoryGB: 8, diskGB: 64),
        CoreVisorTemplate(guest: .windows, name: "Windows XP", cpuCores: 1, memoryGB: 2, diskGB: 32),
        CoreVisorTemplate(guest: .windows, name: "Windows 7", cpuCores: 2, memoryGB: 4, diskGB: 64),
        CoreVisorTemplate(guest: .windows, name: "Windows 8.1", cpuCores: 2, memoryGB: 4, diskGB: 64),
        CoreVisorTemplate(guest: .windows, name: "Windows 10", cpuCores: 4, memoryGB: 8, diskGB: 96),
        CoreVisorTemplate(guest: .windows, name: "Windows 11", cpuCores: 6, memoryGB: 12, diskGB: 128),
        CoreVisorTemplate(guest: .netBSD, name: "NetBSD", cpuCores: 2, memoryGB: 4, diskGB: 32),
        CoreVisorTemplate(guest: .unix, name: "UNIX", cpuCores: 2, memoryGB: 4, diskGB: 32)
    ]

    private var qemuProcesses: [UUID: Process] = [:]
    private var userInitiatedStops: Set<UUID> = []
#if canImport(Virtualization)
    private var appleSessions: [UUID: AppleVMSession] = [:]
    private var appleDisplayWindows: [UUID: NSWindowController] = [:]
    private var appleWindowCloseObservers: [UUID: NSObjectProtocol] = [:]
#endif

    private let customQEMUBinaryPathKey = "corevisor.customQEMUBinaryPath"
    private let runtimeStopTimeoutSeconds: TimeInterval = 12.0
    private let runtimeLogLimit = 120_000
    private let managedEmbeddedQEMUFolderName = "EmbeddedQEMU"
    private let machineConfigFileName = "machine.json"
    private let genericMachineIdentifierFileName = "machine-identifier.bin"
    private let efiVariableStoreFileName = "efi-variable-store"

    init() {
        customQEMUBinaryPath = UserDefaults.standard.string(forKey: customQEMUBinaryPathKey) ?? ""
        loadMachines()
        refreshEntitlementStatus()
        Task {
            bootstrapVirGLRuntimeOnStartup()
            await refreshRuntimeData()
        }
    }

    func setCustomQEMUBinaryPath(_ path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if customQEMUBinaryPath == trimmed {
            return
        }
        customQEMUBinaryPath = trimmed

        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: customQEMUBinaryPathKey)
        } else {
            UserDefaults.standard.set(trimmed, forKey: customQEMUBinaryPathKey)
        }
    }

    func clearCustomQEMUBinaryPath() {
        setCustomQEMUBinaryPath("")
    }

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

wmic logicaldisk get name,volumename
dism /Get-WimInfo /WimFile:D:\\sources\\install.wim
dism /Apply-Image /ImageFile:D:\\sources\\install.wim /Index:6 /ApplyDir:W:\\
bcdboot W:\\Windows /s S: /f UEFI
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
        if parsedUSB.isEmpty {
            // Non-fatal; some QEMU builds expose no USB devices in help output.
            if lastError == nil {
                lastError = "No QEMU USB devices reported by qemu -device help."
            }
        } else {
            lastError = nil
        }
    }

    func applyTemplate(_ template: CoreVisorTemplate, to draft: inout CoreVisorDraft) {
        draft.name = template.name
        draft.guest = template.guest
        draft.cpuCores = template.cpuCores
        draft.memoryGB = template.memoryGB
        draft.diskGB = template.diskGB
        if template.guest == .macOS {
            draft.backend = .appleVirtualization
            draft.enableVirGL = false
        } else if !isBackendSupported(draft.backend, for: template.guest) {
            draft.backend = qemuBinaryPath != nil ? .qemu : .appleVirtualization
        }
    }

    func draft(from machine: CoreVisorMachine) -> CoreVisorDraft {
        CoreVisorDraft(
            name: machine.name,
            guest: machine.guest,
            backend: machine.backend,
            cpuCores: machine.cpuCores,
            memoryGB: machine.memoryGB,
            diskGB: machine.diskGB,
            enableVirGL: machine.enableVirGL,
            enableSound: machine.enableSound,
            selectedUSBDeviceIDs: Set(machine.selectedUSBDeviceIDs),
            isoPath: machine.isoPath,
            kernelPath: machine.kernelPath,
            ramdiskPath: machine.ramdiskPath,
            kernelCommandLine: machine.kernelCommandLine
        )
    }

    func duplicateMachine(_ machine: CoreVisorMachine) async {
        var duplicateDraft = draft(from: machine)
        duplicateDraft.name = makeDuplicateName(from: machine.name)
        duplicateDraft.isoPath = ""
        duplicateDraft.kernelPath = ""
        duplicateDraft.ramdiskPath = ""
        await createMachine(from: duplicateDraft)
    }

    func openMachineBundle(_ machine: CoreVisorMachine) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: machine.bundlePath)
    }

    func startAllMachines() async {
        for machine in machines where runtimeState(for: machine) == .stopped || runtimeState(for: machine) == .error {
            await startMachine(machine)
        }
    }

    func stopAllMachines() {
        for machine in machines where runtimeState(for: machine) == .running || runtimeState(for: machine) == .starting {
            stopMachine(machine)
        }
    }

    func createMachine(from draft: CoreVisorDraft) async {
        let draft = normalizedDraft(draft)
        do {
            let machine = try await createMachineInternal(from: draft)
            machines.append(machine)
            machineStates[machine.id] = .stopped
            machineLogs[machine.id] = "Created VM bundle at \(machine.bundlePath)\n"
            saveMachines()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func updateMachine(_ machine: CoreVisorMachine, from draft: CoreVisorDraft) async {
        let draft = normalizedDraft(draft)
        guard let index = machines.firstIndex(where: { $0.id == machine.id }) else {
            lastError = "Could not update \(machine.name): VM was not found."
            return
        }

        let state = machineStates[machine.id] ?? .stopped
        if state == .running || state == .starting || state == .stopping || isMachineRuntimeActive(machineID: machine.id) {
            lastError = "Stop \(machine.name) before editing its configuration."
            appendLog("Update aborted: VM is currently active.\n", for: machine.id)
            return
        }

        if !isBackendSupported(draft.backend, for: draft.guest) {
            lastError = "Selected backend is not supported for this guest."
            return
        }

        let updatedMachine = CoreVisorMachine(
            id: machine.id,
            name: draft.name,
            guest: draft.guest,
            backend: draft.backend,
            cpuCores: draft.cpuCores,
            memoryGB: draft.memoryGB,
            diskGB: machine.diskGB,
            enableVirGL: draft.enableVirGL,
            enableSound: draft.enableSound,
            isoPath: draft.isoPath,
            kernelPath: draft.kernelPath,
            ramdiskPath: draft.ramdiskPath,
            kernelCommandLine: draft.kernelCommandLine,
            selectedUSBDeviceIDs: Array(draft.selectedUSBDeviceIDs).sorted(),
            bundlePath: machine.bundlePath,
            diskPath: machine.diskPath,
            createdAt: machine.createdAt
        )

        do {
            try persistMachineConfiguration(updatedMachine)
            try ensureMachineRuntimeArtifacts(updatedMachine)

            machines[index] = updatedMachine
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
            machineLogs[machine.id] = "Imported from \(bundleURL.path)\n"
            saveMachines()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func installVirGLBundle(from directoryURL: URL) async {
        isScanning = true
        defer { isScanning = false }

        do {
            let installedBinaryPath = try installVirGLBundleInternal(from: directoryURL)
            setCustomQEMUBinaryPath(installedBinaryPath)
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
            appendLog("Delete aborted: VM is still active.\n", for: machine.id)
            return
        }

        do {
            if FileManager.default.fileExists(atPath: machine.bundlePath) {
                try FileManager.default.removeItem(atPath: machine.bundlePath)
            }
        } catch {
            lastError = "Failed to delete \(machine.name): \(error.localizedDescription)"
            appendLog("Delete failed: \(error.localizedDescription)\n", for: machine.id)
            return
        }

        machines.removeAll { $0.id == machine.id }
        machineStates[machine.id] = nil
        machineLogs[machine.id] = nil
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
        if machine.guest == .windows && machine.backend != .qemu {
            machineStates[machine.id] = .error
            lastError = "Windows guests must run on QEMU in this build."
            appendLog("Blocked launch: Windows guests are QEMU-only.\n", for: machine.id)
            return
        }
        guard FileManager.default.fileExists(atPath: machine.bundlePath) else {
            machineStates[machine.id] = .error
            appendLog("VM bundle not found at \(machine.bundlePath)\n", for: machine.id)
            lastError = "VM bundle missing for \(machine.name)."
            return
        }
        guard FileManager.default.fileExists(atPath: machine.diskPath) else {
            machineStates[machine.id] = .error
            appendLog("VM disk not found at \(machine.diskPath)\n", for: machine.id)
            lastError = "VM disk missing for \(machine.name)."
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

        switch machine.backend {
        case .qemu:
            await startQEMUMachine(machine)
        case .appleVirtualization:
            await startAppleVirtualizationMachine(machine)
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

        if let process = qemuProcesses[machine.id] {
            process.terminate()
            return
        }

#if canImport(Virtualization)
        if let session = appleSessions[machine.id] {
            Task {
                await stopAppleSession(session, machineID: machine.id)
            }
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

    func clearRuntimeLog(for machine: CoreVisorMachine) {
        machineLogs[machine.id] = ""
    }

    func clearAllRuntimeLogs() {
        for machine in machines {
            machineLogs[machine.id] = ""
        }
    }

    var hasAnyRunningMachine: Bool {
        machineStates.values.contains { $0 == .running || $0 == .starting || $0 == .stopping }
    }

    var requiresVirtualizationEntitlement: Bool {
        isAppSandboxed && !hasVirtualizationEntitlement
    }

    private func waitForMachineToStop(machineID: UUID, timeoutSeconds: TimeInterval) async {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if !isMachineRuntimeActive(machineID: machineID) {
                return
            }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
    }

    private func isMachineRuntimeActive(machineID: UUID) -> Bool {
        let state = machineStates[machineID] ?? .stopped
        let hasQEMU = qemuProcesses[machineID] != nil
#if canImport(Virtualization)
        let hasApple = appleSessions[machineID] != nil
#else
        let hasApple = false
#endif
        return !((state == .stopped || state == .error) && !hasQEMU && !hasApple)
    }

    func isBackendSupported(_ backend: VMBackend, for guest: VMGuestType) -> Bool {
        switch (backend, guest) {
        case (.appleVirtualization, .linux):
            return hasVirtualizationAccess
        case (.appleVirtualization, _):
            return false
        case (.qemu, _):
            return qemuBinaryPath != nil
        }
    }

    func commandPreview(for draft: CoreVisorDraft) -> String {
        switch draft.backend {
        case .appleVirtualization:
            guard draft.guest == .linux else {
                return "Apple Virtualization currently supports Linux guests only in this build."
            }
            return "Apple Virtualization: Linux runtime configured with kernel+ramdisk boot or EFI+ISO boot."
        case .qemu:
            guard let qemuBinaryPath else {
                return "QEMU binary not found. Install qemu first."
            }
            let machine = draftToPreviewMachine(draft)
            return shellJoin([qemuBinaryPath] + qemuArguments(for: machine))
        }
    }

    private func draftToPreviewMachine(_ draft: CoreVisorDraft) -> CoreVisorMachine {
        let bundleURL = machinesDirectoryURL().appendingPathComponent("preview.corevm", isDirectory: true)
        let diskExtension = draft.backend == .qemu ? "qcow2" : "img"
        let diskURL = bundleURL.appendingPathComponent("disk.\(diskExtension)")

        return CoreVisorMachine(
            id: UUID(),
            name: draft.name,
            guest: draft.guest,
            backend: draft.backend,
            cpuCores: draft.cpuCores,
            memoryGB: draft.memoryGB,
            diskGB: draft.diskGB,
            enableVirGL: draft.enableVirGL,
            enableSound: draft.enableSound,
            isoPath: draft.isoPath,
            kernelPath: draft.kernelPath,
            ramdiskPath: draft.ramdiskPath,
            kernelCommandLine: draft.kernelCommandLine,
            selectedUSBDeviceIDs: Array(draft.selectedUSBDeviceIDs).sorted(),
            bundlePath: bundleURL.path,
            diskPath: diskURL.path,
            createdAt: Date()
        )
    }

    private func createMachineInternal(from draft: CoreVisorDraft) async throws -> CoreVisorMachine {
        let safeName = sanitizeName(draft.name)
        let bundleURL = uniqueBundleURL(for: safeName)

        do {
            try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)

            let diskExtension = draft.backend == .qemu ? "qcow2" : "img"
            let diskURL = bundleURL.appendingPathComponent("disk.\(diskExtension)")

            if draft.backend == .qemu {
                try await createQEMUDisk(at: diskURL, sizeGB: draft.diskGB)
            } else {
                try createRawDisk(at: diskURL, sizeGB: draft.diskGB)
            }

            let machine = CoreVisorMachine(
                id: UUID(),
                name: draft.name,
                guest: draft.guest,
                backend: draft.backend,
                cpuCores: draft.cpuCores,
                memoryGB: draft.memoryGB,
                diskGB: draft.diskGB,
                enableVirGL: draft.enableVirGL,
                enableSound: draft.enableSound,
                isoPath: draft.isoPath,
                kernelPath: draft.kernelPath,
                ramdiskPath: draft.ramdiskPath,
                kernelCommandLine: draft.kernelCommandLine,
                selectedUSBDeviceIDs: Array(draft.selectedUSBDeviceIDs).sorted(),
                bundlePath: bundleURL.path,
                diskPath: diskURL.path,
                createdAt: Date()
            )

            try persistMachineConfiguration(machine)
            try ensureMachineRuntimeArtifacts(machine)

            return machine
        } catch {
            if FileManager.default.fileExists(atPath: bundleURL.path) {
                try? FileManager.default.removeItem(at: bundleURL)
            }
            throw error
        }
    }

    private func importUTMBundleInternal(_ bundleURL: URL) async throws -> CoreVisorMachine {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: bundleURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw NSError(domain: "CoreVisor", code: 10, userInfo: [NSLocalizedDescriptionKey: "UTM bundle not found."])
        }
        guard bundleURL.pathExtension.lowercased() == "utm" else {
            throw NSError(domain: "CoreVisor", code: 11, userInfo: [NSLocalizedDescriptionKey: "Selected item is not a .utm bundle."])
        }

        let sourceDiskURL = try findUTMDiskImage(in: bundleURL)
        let sourceDiskExtension = sourceDiskURL.pathExtension.lowercased()

        let displayName = bundleURL.deletingPathExtension().lastPathComponent
        let safeName = sanitizeName(displayName)
        let targetBundleURL = uniqueBundleURL(for: safeName)
        let targetDiskURL = targetBundleURL.appendingPathComponent("disk.qcow2")

        do {
            try FileManager.default.createDirectory(at: targetBundleURL, withIntermediateDirectories: true)

            if sourceDiskExtension == "qcow2" {
                try FileManager.default.copyItem(at: sourceDiskURL, to: targetDiskURL)
            } else {
                guard let qemuSystemPath = qemuBinaryPath ?? findQEMUBinary(),
                      let qemuImgPath = findQEMUImgBinary(qemuSystemPath: qemuSystemPath) else {
                    throw NSError(
                        domain: "CoreVisor",
                        code: 12,
                        userInfo: [NSLocalizedDescriptionKey: "qemu-img is required to import \(sourceDiskExtension) images."]
                    )
                }

                let convertResult = await runProcess(
                    executable: qemuImgPath,
                    arguments: ["convert", "-O", "qcow2", sourceDiskURL.path, targetDiskURL.path],
                    timeoutSeconds: 900
                )
                if convertResult.exitCode != 0 {
                    throw NSError(
                        domain: "CoreVisor",
                        code: 13,
                        userInfo: [NSLocalizedDescriptionKey: "qemu-img convert failed: \(convertResult.output)"]
                    )
                }
            }

            let diskAttributes = try FileManager.default.attributesOfItem(atPath: targetDiskURL.path)
            let diskBytes = (diskAttributes[.size] as? NSNumber)?.int64Value ?? 0
            let diskGB = max(4, Int(ceil(Double(diskBytes) / 1_073_741_824.0)))

            let machine = CoreVisorMachine(
                id: UUID(),
                name: displayName,
                guest: inferredGuestType(from: displayName),
                backend: .qemu,
                cpuCores: 4,
                memoryGB: 8,
                diskGB: diskGB,
                enableVirGL: false,
                enableSound: true,
                isoPath: "",
                kernelPath: "",
                ramdiskPath: "",
                kernelCommandLine: "",
                selectedUSBDeviceIDs: [],
                bundlePath: targetBundleURL.path,
                diskPath: targetDiskURL.path,
                createdAt: Date()
            )

            try persistMachineConfiguration(machine)
            return machine
        } catch {
            if FileManager.default.fileExists(atPath: targetBundleURL.path) {
                try? FileManager.default.removeItem(at: targetBundleURL)
            }
            throw error
        }
    }

    private func findUTMDiskImage(in bundleURL: URL) throws -> URL {
        let allowedExtensions: Set<String> = ["qcow2", "img", "raw", "vmdk", "vdi", "vhd", "vhdx"]
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(at: bundleURL, includingPropertiesForKeys: Array(resourceKeys)) else {
            throw NSError(domain: "CoreVisor", code: 14, userInfo: [NSLocalizedDescriptionKey: "Unable to inspect UTM bundle."])
        }

        var bestURL: URL?
        var bestSize: Int = -1

        for case let fileURL as URL in enumerator {
            guard allowedExtensions.contains(fileURL.pathExtension.lowercased()) else { continue }
            let values = try? fileURL.resourceValues(forKeys: resourceKeys)
            guard values?.isRegularFile == true else { continue }
            let size = values?.fileSize ?? 0
            if size > bestSize {
                bestURL = fileURL
                bestSize = size
            }
        }

        guard let bestURL else {
            throw NSError(domain: "CoreVisor", code: 15, userInfo: [NSLocalizedDescriptionKey: "No supported disk image found in .utm bundle."])
        }
        return bestURL
    }

    private func inferredGuestType(from name: String) -> VMGuestType {
        let lowered = name.lowercased()
        if lowered.contains("windows") || lowered.contains("win") { return .windows }
        if lowered.contains("netbsd") { return .netBSD }
        if lowered.contains("unix") { return .unix }
        return .linux
    }

    private func installVirGLBundleInternal(from directoryURL: URL) throws -> String {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw NSError(domain: "CoreVisor", code: 20, userInfo: [NSLocalizedDescriptionKey: "Selected VirGL bundle path is not a directory."])
        }

        guard let sourceQemuBinary = findVirGLBinary(in: directoryURL) else {
            throw NSError(domain: "CoreVisor", code: 21, userInfo: [NSLocalizedDescriptionKey: "Could not find qemu-virgl inside selected folder."])
        }

        let sourceQemuDirectory = sourceQemuBinary.deletingLastPathComponent()
        let virglRendererDirectory = findVirGLRendererDirectory(near: directoryURL, qemuDirectory: sourceQemuDirectory)

        let managedDirectory = managedEmbeddedQEMUDirectoryURL()
        let parentDirectory = managedDirectory.deletingLastPathComponent()

        do {
            if FileManager.default.fileExists(atPath: managedDirectory.path) {
                try FileManager.default.removeItem(at: managedDirectory)
            }

            try FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: managedDirectory, withIntermediateDirectories: true)

            try copyDirectoryContents(from: sourceQemuDirectory, to: managedDirectory)

            if let virglRendererDirectory {
                let targetVirglRenderer = managedDirectory.appendingPathComponent("virglrenderer", isDirectory: true)
                if FileManager.default.fileExists(atPath: targetVirglRenderer.path) {
                    try? FileManager.default.removeItem(at: targetVirglRenderer)
                }
                try FileManager.default.copyItem(at: virglRendererDirectory, to: targetVirglRenderer)
            }

            guard let installedBinary = findVirGLBinary(in: managedDirectory) else {
                throw NSError(domain: "CoreVisor", code: 22, userInfo: [NSLocalizedDescriptionKey: "Installed VirGL bundle is missing qemu-virgl."])
            }

            try FileManager.default.setAttributes(
                [.posixPermissions: NSNumber(value: Int16(0o755))],
                ofItemAtPath: installedBinary.path
            )

            return installedBinary.path
        } catch {
            throw NSError(domain: "CoreVisor", code: 23, userInfo: [NSLocalizedDescriptionKey: "VirGL install failed: \(error.localizedDescription)"])
        }
    }

    private func copyDirectoryContents(from sourceDirectory: URL, to destinationDirectory: URL) throws {
        let children = try FileManager.default.contentsOfDirectory(at: sourceDirectory, includingPropertiesForKeys: nil)
        for child in children {
            let target = destinationDirectory.appendingPathComponent(child.lastPathComponent, isDirectory: false)
            try FileManager.default.copyItem(at: child, to: target)
        }
    }

    private func findVirGLRendererDirectory(near selectedDirectory: URL, qemuDirectory: URL) -> URL? {
        let candidates = [
            selectedDirectory.appendingPathComponent("virglrenderer", isDirectory: true),
            selectedDirectory.deletingLastPathComponent().appendingPathComponent("virglrenderer", isDirectory: true),
            qemuDirectory.appendingPathComponent("virglrenderer", isDirectory: true),
            qemuDirectory.deletingLastPathComponent().appendingPathComponent("virglrenderer", isDirectory: true)
        ]

        for candidate in candidates {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return candidate
            }
        }
        return nil
    }

    private func findVirGLBinary(in directoryURL: URL) -> URL? {
        let directCandidate = directoryURL.appendingPathComponent("qemu-virgl", isDirectory: false)
        if isExecutableFile(directCandidate.path) {
            return directCandidate
        }

        let nestedCandidate = directoryURL.appendingPathComponent("qemu-virgl/qemu-virgl", isDirectory: false)
        if isExecutableFile(nestedCandidate.path) {
            return nestedCandidate
        }

        let searchKeys: [URLResourceKey] = [.isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(at: directoryURL, includingPropertiesForKeys: searchKeys) else {
            return nil
        }

        for case let url as URL in enumerator {
            if url.lastPathComponent != "qemu-virgl" {
                continue
            }
            if isExecutableFile(url.path) {
                return url
            }
        }
        return nil
    }

    private func sanitizeName(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "corevisor-vm" : trimmed
        let allowed = fallback.lowercased().map { char -> Character in
            if char.isLetter || char.isNumber || char == "-" || char == "_" {
                return char
            }
            return "-"
        }
        let normalized = String(allowed)
            .replacingOccurrences(of: "--+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        return normalized.isEmpty ? "corevisor-vm" : normalized
    }

    private func normalizedDraft(_ draft: CoreVisorDraft) -> CoreVisorDraft {
        var normalized = draft
        normalized.name = normalized.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.name.isEmpty {
            normalized.name = "New VM"
        }
        normalized.cpuCores = min(max(normalized.cpuCores, 1), 64)
        normalized.memoryGB = min(max(normalized.memoryGB, 1), 256)
        normalized.diskGB = min(max(normalized.diskGB, 4), 2048)
        normalized.isoPath = normalized.isoPath.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.kernelPath = normalized.kernelPath.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.ramdiskPath = normalized.ramdiskPath.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.kernelCommandLine = normalized.kernelCommandLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.kernelCommandLine.isEmpty {
            normalized.kernelCommandLine = "console=hvc0"
        }
        if normalized.guest == .windows {
            // Windows guests are routed to QEMU for compatibility on Apple Silicon.
            normalized.backend = .qemu
        }
        normalized.selectedUSBDeviceIDs = Set(normalized.selectedUSBDeviceIDs)
        return normalized
    }

    private func makeDuplicateName(from baseName: String) -> String {
        let trimmed = baseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidatePrefix = trimmed.isEmpty ? "VM" : trimmed
        let existingNames = Set(machines.map { $0.name.lowercased() })

        var suffix = 2
        var candidate = "\(candidatePrefix) Copy"
        while existingNames.contains(candidate.lowercased()) {
            candidate = "\(candidatePrefix) Copy \(suffix)"
            suffix += 1
        }
        return candidate
    }

    private func uniqueBundleURL(for safeName: String) -> URL {
        let root = machinesDirectoryURL()
        var candidate = root.appendingPathComponent("\(safeName).corevm", isDirectory: true)
        var suffix = 2

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = root.appendingPathComponent("\(safeName)-\(suffix).corevm", isDirectory: true)
            suffix += 1
        }
        return candidate
    }

    private func createQEMUDisk(at diskURL: URL, sizeGB: Int) async throws {
        guard let qemuSystem = qemuBinaryPath else {
            throw NSError(domain: "CoreVisor", code: 1, userInfo: [NSLocalizedDescriptionKey: "QEMU binary missing."])
        }

        guard let qemuImgPath = findQEMUImgBinary(qemuSystemPath: qemuSystem) else {
            throw NSError(domain: "CoreVisor", code: 2, userInfo: [NSLocalizedDescriptionKey: "qemu-img not found. Install qemu-img or place it beside \(qemuSystem)."])
        }

        let args = ["create", "-f", "qcow2", diskURL.path, "\(max(4, sizeGB))G"]
        let result = await runProcess(executable: qemuImgPath, arguments: args)
        if result.exitCode != 0 {
            throw NSError(domain: "CoreVisor", code: 3, userInfo: [NSLocalizedDescriptionKey: "qemu-img failed: \(result.output)"])
        }
    }

    private func createRawDisk(at diskURL: URL, sizeGB: Int) throws {
        let bytes = UInt64(max(4, sizeGB)) * 1_073_741_824
        guard FileManager.default.createFile(atPath: diskURL.path, contents: nil) else {
            throw NSError(domain: "CoreVisor", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to create raw disk file."])
        }
        let handle = try FileHandle(forWritingTo: diskURL)
        try handle.truncate(atOffset: bytes)
        try handle.close()
    }

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

        let launchArguments = qemuArguments(for: machine)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: qemuBinaryPath)
        process.arguments = launchArguments
        process.currentDirectoryURL = URL(fileURLWithPath: machine.bundlePath, isDirectory: true)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                self?.appendLog(text, for: machineID)
            }
        }

        process.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                self?.qemuProcesses[machineID] = nil
                pipe.fileHandleForReading.readabilityHandler = nil
                let wasUserInitiatedStop = self?.userInitiatedStops.remove(machineID) != nil

                if wasUserInitiatedStop {
                    self?.machineStates[machineID] = .stopped
                    self?.appendLog("\nVM stopped by user.\n", for: machineID)
                } else if process.terminationReason == .exit && process.terminationStatus == 0 {
                    self?.machineStates[machineID] = .stopped
                    self?.appendLog("\nVM exited cleanly.\n", for: machineID)
                } else {
                    self?.machineStates[machineID] = .error
                    if process.terminationReason == .uncaughtSignal && process.terminationStatus == 9 {
                        self?.lastError = "QEMU was killed by SIGKILL (9). This usually means macOS blocked the binary (signature/quarantine) or the system force-killed it."
                        self?.appendLog("\nQEMU received SIGKILL (9). Try setting a custom Homebrew QEMU path in CoreVisor Backend settings.\n", for: machineID)
                    } else {
                        self?.lastError = "QEMU stopped unexpectedly with status \(process.terminationStatus)."
                    }
                    self?.appendLog("\nVM stopped unexpectedly with status \(process.terminationStatus).\n", for: machineID)
                }
            }
        }

        do {
            try process.run()
            qemuProcesses[machineID] = process
            machineStates[machineID] = .running
            if launchArguments.contains("-m"),
               let memoryIndex = launchArguments.firstIndex(of: "-m"),
               launchArguments.indices.contains(memoryIndex + 1) {
                let selectedMemory = launchArguments[memoryIndex + 1]
                if selectedMemory != "\(max(1, machine.memoryGB))G" {
                    appendLog("Adjusted guest memory from \(max(1, machine.memoryGB))G to \(selectedMemory) for compatibility.\n", for: machineID)
                }
            }
            appendLog("Launch command: \(shellJoin([qemuBinaryPath] + launchArguments))\n", for: machineID)
            appendLog("QEMU process started.\n", for: machineID)
        } catch {
            machineStates[machineID] = .error
            lastError = "Failed to launch QEMU: \(error.localizedDescription)"
            appendLog("Failed to launch QEMU: \(error.localizedDescription)\n", for: machineID)
        }
    }

#if canImport(Virtualization)
    private func startAppleVirtualizationMachine(_ machine: CoreVisorMachine) async {
        guard machine.guest == .linux else {
            machineStates[machine.id] = .error
            appendLog("Apple Virtualization currently supports Linux guests only in this build.\n", for: machine.id)
            lastError = "Apple Virtualization currently supports Linux guests only."
            return
        }
        if machine.kernelPath.isEmpty && machine.isoPath.isEmpty {
            machineStates[machine.id] = .error
            appendLog("Apple Virtualization boot requires either a Linux kernel path or an installer ISO path.\n", for: machine.id)
            lastError = "Apple Virtualization boot requires kernel or ISO."
            return
        }
        guard hasVirtualizationAccess else {
            machineStates[machine.id] = .error
            appendLog("Apple Virtualization is unavailable: sandboxed build is missing `com.apple.security.virtualization` entitlement.\n", for: machine.id)
            lastError = "Apple Virtualization requires `com.apple.security.virtualization` in sandboxed builds."
            return
        }

        do {
            let config = try createAppleVMConfiguration(for: machine)
            let vm = VZVirtualMachine(configuration: config)

            let session = AppleVMSession(virtualMachine: vm) { [weak self] error in
                guard let self else { return }
                let wasUserInitiatedStop = self.userInitiatedStops.remove(machine.id) != nil
                if wasUserInitiatedStop {
                    self.machineStates[machine.id] = .stopped
                    self.appendLog("Apple Virtualization guest stopped by user.\n", for: machine.id)
                } else if let error {
                    self.machineStates[machine.id] = .error
                    self.appendLog("Apple Virtualization stopped with error: \(error.localizedDescription)\n", for: machine.id)
                } else {
                    self.machineStates[machine.id] = .stopped
                    self.appendLog("Apple Virtualization guest stopped.\n", for: machine.id)
                }
                self.appleDisplayWindows[machine.id]?.close()
                self.appleDisplayWindows[machine.id] = nil
                if let observer = self.appleWindowCloseObservers[machine.id] {
                    NotificationCenter.default.removeObserver(observer)
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
            if let observer = appleWindowCloseObservers[machine.id] {
                NotificationCenter.default.removeObserver(observer)
                appleWindowCloseObservers[machine.id] = nil
            }
            appleSessions[machine.id] = nil
            userInitiatedStops.remove(machine.id)
            machineStates[machine.id] = .error
            lastError = "Apple Virtualization start failed: \(error.localizedDescription)"
            appendLog("Apple Virtualization start failed: \(error.localizedDescription)\n", for: machine.id)
        }
    }

    private func createAppleVMConfiguration(for machine: CoreVisorMachine) throws -> VZVirtualMachineConfiguration {
        let configuration = VZVirtualMachineConfiguration()
        configuration.cpuCount = max(1, machine.cpuCores)
        configuration.memorySize = UInt64(max(2, machine.memoryGB)) * 1_073_741_824

        let platform = VZGenericPlatformConfiguration()
        platform.machineIdentifier = try loadOrCreateGenericMachineIdentifier(for: machine)
        configuration.platform = platform

        if !machine.kernelPath.isEmpty {
            let kernelURL = URL(fileURLWithPath: machine.kernelPath)
            let boot = VZLinuxBootLoader(kernelURL: kernelURL)
            if !machine.ramdiskPath.isEmpty {
                boot.initialRamdiskURL = URL(fileURLWithPath: machine.ramdiskPath)
            }
            boot.commandLine = machine.kernelCommandLine
            configuration.bootLoader = boot
        } else {
            let bootLoader = VZEFIBootLoader()
            bootLoader.variableStore = try loadOrCreateEFIVariableStore(for: machine)
            configuration.bootLoader = bootLoader
        }

        let networkDevice = VZVirtioNetworkDeviceConfiguration()
        networkDevice.attachment = VZNATNetworkDeviceAttachment()
        configuration.networkDevices = [networkDevice]
        configuration.entropyDevices = [VZVirtioEntropyDeviceConfiguration()]
        configuration.memoryBalloonDevices = [VZVirtioTraditionalMemoryBalloonDeviceConfiguration()]

        let diskAttachment = try VZDiskImageStorageDeviceAttachment(url: URL(fileURLWithPath: machine.diskPath), readOnly: false)
        var storage: [VZStorageDeviceConfiguration] = [VZVirtioBlockDeviceConfiguration(attachment: diskAttachment)]

        if !machine.isoPath.isEmpty {
            let isoURL = URL(fileURLWithPath: machine.isoPath)
            if FileManager.default.fileExists(atPath: isoURL.path) {
                let isoAttachment = try VZDiskImageStorageDeviceAttachment(url: isoURL, readOnly: true)
                storage.append(VZVirtioBlockDeviceConfiguration(attachment: isoAttachment))
            }
        }
        configuration.storageDevices = storage

        let graphics = VZVirtioGraphicsDeviceConfiguration()
        graphics.scanouts = [VZVirtioGraphicsScanoutConfiguration(widthInPixels: 1280, heightInPixels: 800)]
        configuration.graphicsDevices = [graphics]
        configuration.keyboards = [VZUSBKeyboardConfiguration()]
        configuration.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]

        try configuration.validate()
        return configuration
    }

    private func loadOrCreateEFIVariableStore(for machine: CoreVisorMachine) throws -> VZEFIVariableStore {
        let storeURL = URL(fileURLWithPath: machine.bundlePath)
            .appendingPathComponent(efiVariableStoreFileName, isDirectory: false)
        if FileManager.default.fileExists(atPath: storeURL.path) {
            appendLog("Using EFI variable store: \(storeURL.path)\n", for: machine.id)
            return VZEFIVariableStore(url: storeURL)
        }
        appendLog("Creating EFI variable store: \(storeURL.path)\n", for: machine.id)
        return try VZEFIVariableStore(creatingVariableStoreAt: storeURL)
    }

    private func loadOrCreateGenericMachineIdentifier(for machine: CoreVisorMachine) throws -> VZGenericMachineIdentifier {
        let identifierURL = URL(fileURLWithPath: machine.bundlePath)
            .appendingPathComponent(genericMachineIdentifierFileName, isDirectory: false)
        if FileManager.default.fileExists(atPath: identifierURL.path) {
            let data = try Data(contentsOf: identifierURL)
            if let restored = VZGenericMachineIdentifier(dataRepresentation: data) {
                appendLog("Using machine identifier: \(identifierURL.path)\n", for: machine.id)
                return restored
            }
        }

        let identifier = VZGenericMachineIdentifier()
        try identifier.dataRepresentation.write(to: identifierURL, options: [.atomic])
        appendLog("Created machine identifier: \(identifierURL.path)\n", for: machine.id)
        return identifier
    }

    private func stopAppleSession(_ session: AppleVMSession, machineID: UUID) async {
        do {
            if session.virtualMachine.canRequestStop {
                try session.virtualMachine.requestStop()
                appendLog("Stop requested.\n", for: machineID)
            } else if session.virtualMachine.canStop {
                try await session.virtualMachine.stop()
                appendLog("Force stop requested.\n", for: machineID)
            } else {
                appendLog("VM is not in a stoppable state right now.\n", for: machineID)
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
        if #available(macOS 14.0, *) {
            vmView.automaticallyReconfiguresDisplay = true
        }

        let contentController = NSViewController()
        contentController.view = vmView

        let window = NSWindow(
            contentRect: NSRect(x: 140, y: 120, width: 1280, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "\(machine.name) — CoreVisor"
        window.contentViewController = contentController
        window.minSize = NSSize(width: 900, height: 560)

        let controller = NSWindowController(window: window)
        appleDisplayWindows[machine.id] = controller
        appleWindowCloseObservers[machine.id] = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
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

    func qemuArguments(for machine: CoreVisorMachine) -> [String] {
        let qemuName = URL(fileURLWithPath: qemuBinaryPath ?? "").lastPathComponent.lowercased()
#if arch(arm64)
        let hostPrefersAArch64 = true
#else
        let hostPrefersAArch64 = false
#endif
        let isAArch64 = qemuName.contains("aarch64") || qemuName.contains("arm") || (qemuName.isEmpty && hostPrefersAArch64)
        let isWindowsAArch64 = isAArch64 && machine.guest == .windows
        let hasISO = !machine.isoPath.isEmpty
        let effectiveMemoryGB = max(1, machine.memoryGB)

        var args: [String] = [
            "-smp", "\(max(1, machine.cpuCores))",
            "-m", "\(effectiveMemoryGB)G"
        ]

        args += ["-accel", "hvf", "-accel", "tcg"]

        if isAArch64 {
            let machineValue: String
            if isWindowsAArch64 {
                // Prefer lower-memory-map compatibility for Windows ARM installers.
                machineValue = "virt,highmem=off"
            } else {
                machineValue = "virt,highmem=on"
            }
            args += [
                "-machine", machineValue,
                "-cpu", "host"
            ]

            if let efi = findAArch64UEFIFirmware() {
                if let vars = ensureAArch64UEFIVars(for: machine) {
                    args += [
                        "-drive", "if=pflash,format=raw,readonly=on,file=\(efi)",
                        "-drive", "if=pflash,format=raw,file=\(vars)"
                    ]
                } else {
                    args += ["-bios", efi]
                }
            }
        } else {
            args += [
                "-machine", "q35",
                "-cpu", "host"
            ]
        }

        args += [
            "-device", "virtio-net-pci",
            "-device", "qemu-xhci",
            "-device", "usb-kbd",
            "-device", "usb-mouse",
            "-device", "usb-tablet"
        ]

        if isAArch64 {
            let diskBootIndex = hasISO ? 2 : 1
            if isWindowsAArch64 {
                args += [
                    "-drive", "if=none,id=system,file=\(machine.diskPath),format=qcow2",
                    "-device", "nvme,drive=system,serial=coremon0,bootindex=\(diskBootIndex)"
                ]
            } else {
                args += [
                    "-drive", "if=none,id=system,file=\(machine.diskPath),format=qcow2",
                    "-device", "virtio-blk-pci,drive=system,bootindex=\(diskBootIndex)"
                ]
            }
        } else {
            args += ["-drive", "if=virtio,file=\(machine.diskPath),format=qcow2"]
        }

        if hasISO {
            if isAArch64 {
                if isWindowsAArch64 {
                    args += [
                        "-device", "virtio-scsi-pci,id=scsi0",
                        // Expose ISO on both SCSI CD and USB mass storage to improve installer compatibility.
                        "-drive", "if=none,id=cdrom,file=\(machine.isoPath),media=cdrom,readonly=on",
                        "-device", "scsi-cd,bus=scsi0.0,drive=cdrom,bootindex=1",
                        "-drive", "if=none,id=cdromusb,file=\(machine.isoPath),format=raw,readonly=on",
                        "-device", "usb-storage,drive=cdromusb",
                        "-boot", "order=d"
                    ]
                } else {
                    args += [
                        "-device", "virtio-scsi-pci,id=scsi0",
                        "-drive", "if=none,id=cdrom,file=\(machine.isoPath),media=cdrom,readonly=on",
                        "-device", "scsi-cd,bus=scsi0.0,drive=cdrom,bootindex=1",
                        "-boot", "menu=on"
                    ]
                }
            } else {
                args += ["-cdrom", machine.isoPath, "-boot", "order=d"]
            }
        } else {
            args += ["-boot", "order=c"]
        }

        if machine.enableSound && !isWindowsAArch64 {
            args += [
                "-audiodev", "coreaudio,id=ca",
                "-device", "ich9-intel-hda",
                "-device", "hda-output,audiodev=ca"
            ]
        }

        if isWindowsAArch64 {
            args += ["-display", "cocoa", "-device", "ramfb"]
        } else if machine.enableVirGL {
            args += ["-display", "cocoa,gl=on"]

            if isAArch64 {
                args += ["-device", "virtio-gpu-gl-pci"]
            } else {
                args += ["-device", "virtio-vga-gl"]
            }
        } else {
            if isAArch64 {
                args += ["-display", "cocoa", "-device", "virtio-gpu-pci"]
            } else {
                args += ["-display", "cocoa", "-device", "virtio-vga"]
            }
        }

        let discoveredUSBIDs = Set(usbDevices.map(\.id))
        for usbID in machine.selectedUSBDeviceIDs where discoveredUSBIDs.contains(usbID) {
            args += ["-device", usbID]
        }

        return args
    }

    private func prepareRuntimeArtifacts(for machine: CoreVisorMachine) throws {
        if machine.backend == .appleVirtualization {
            try ensureMachineRuntimeArtifacts(machine)
            return
        }

        let configURL = URL(fileURLWithPath: machine.bundlePath, isDirectory: true)
            .appendingPathComponent(machineConfigFileName)
        if !FileManager.default.fileExists(atPath: configURL.path) {
            try persistMachineConfiguration(machine)
        }
    }

    private func ensureMachineRuntimeArtifacts(_ machine: CoreVisorMachine) throws {
        let bundleURL = URL(fileURLWithPath: machine.bundlePath, isDirectory: true)
        if !FileManager.default.fileExists(atPath: bundleURL.path) {
            try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        }

        try persistMachineConfiguration(machine)

        guard machine.backend == .appleVirtualization else { return }
        _ = try loadOrCreateGenericMachineIdentifier(for: machine)
        _ = try loadOrCreateEFIVariableStore(for: machine)
    }

    private func persistMachineConfiguration(_ machine: CoreVisorMachine) throws {
        let configURL = URL(fileURLWithPath: machine.bundlePath, isDirectory: true)
            .appendingPathComponent(machineConfigFileName)
        let data = try JSONEncoder().encode(machine)
        try data.write(to: configURL, options: [.atomic])
    }

    private func appendLog(_ text: String, for machineID: UUID) {
        let timestamp = Self.logTimestampFormatter.string(from: Date())
        var existing = machineLogs[machineID] ?? ""
        let prefixed = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                line.isEmpty ? "" : "[\(timestamp)] \(line)"
            }
            .joined(separator: "\n")
        existing.append(prefixed)
        if existing.count > runtimeLogLimit {
            existing = String(existing.suffix(runtimeLogLimit))
        }
        machineLogs[machineID] = existing
    }

    private func shellJoin(_ arguments: [String]) -> String {
        arguments.map(shellQuote).joined(separator: " ")
    }

    private func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static let logTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private func loadMachines() {
        machineStates = [:]
        machineLogs = [:]

        let urlsToTry = [libraryIndexURL(), legacyLibraryIndexURL()]
        var loadedLibrary: CoreVisorLibrary?

        for url in urlsToTry {
            guard FileManager.default.fileExists(atPath: url.path) else {
                continue
            }

            do {
                let data = try Data(contentsOf: url)
                let library = try JSONDecoder().decode(CoreVisorLibrary.self, from: data)
                loadedLibrary = library
                break
            } catch {
                lastError = "Failed to read VM library at \(url.lastPathComponent): \(error.localizedDescription)"
                continue
            }
        }

        guard let library = loadedLibrary else {
            machines = []
            machineStates = [:]
            machineLogs = [:]
            return
        }
        machines = library.machines.sorted { $0.createdAt > $1.createdAt }
        for machine in machines {
            machineStates[machine.id] = .stopped
        }
        if !machines.isEmpty {
            lastError = nil
        }
    }

    private func saveMachines() {
        let directory = libraryRootURL()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let library = CoreVisorLibrary(machines: machines)
            let data = try JSONEncoder().encode(library)
            try data.write(to: libraryIndexURL(), options: [.atomic])
        } catch {
            lastError = "Failed to save VM library: \(error.localizedDescription)"
        }
    }

    private func libraryRootURL() -> URL {
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let appIdentifier = Bundle.main.bundleIdentifier ?? "Core-Monitor"
            return appSupport
                .appendingPathComponent(appIdentifier, isDirectory: true)
                .appendingPathComponent("CoreVisor", isDirectory: true)
        }
        return legacyLibraryRootURL()
    }

    private func machinesDirectoryURL() -> URL {
        let url = libraryRootURL().appendingPathComponent("VMs", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            lastError = "Failed to create VM directory: \(error.localizedDescription)"
        }
        return url
    }

    private func libraryIndexURL() -> URL {
        libraryRootURL().appendingPathComponent("library.json")
    }

    private func legacyLibraryRootURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("CoreVisor", isDirectory: true)
    }

    private func legacyLibraryIndexURL() -> URL {
        legacyLibraryRootURL().appendingPathComponent("library.json")
    }

    private func findQEMUBinary() -> String? {
        // Optional explicit override for development/testing.
        let custom = customQEMUBinaryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty {
            if custom.hasPrefix("/") && isUsableQEMUBinary(custom) {
                return custom
            }

            if let resolved = resolveExecutable(named: custom) {
                if isUsableQEMUBinary(resolved) {
                    return resolved
                }
            }
            return nil
        }

        // Prefer installed system QEMU when available.
        if let systemQEMU = findSystemQEMUBinary() {
            return systemQEMU
        }

        // Shipping mode: use bundled QEMU by default when no override is set.
        if let bundled = findBundledQEMUBinary(), isUsableQEMUBinary(bundled) {
            return bundled
        }

        return nil
    }

    private func bootstrapVirGLRuntimeOnStartup() {
        if let managedVirGLPath = installManagedVirGLIfNeeded() {
            if customQEMUBinaryPath != managedVirGLPath {
                setCustomQEMUBinaryPath(managedVirGLPath)
            }
            return
        }

        if let bundledVirGLPath = findBundledVirGLBinaryPath(), isExecutableFile(bundledVirGLPath) {
            if customQEMUBinaryPath != bundledVirGLPath {
                setCustomQEMUBinaryPath(bundledVirGLPath)
            }
        }
    }

    private func installManagedVirGLIfNeeded() -> String? {
        guard let bundledDirectory = bundledEmbeddedQEMUDirectoryURL() else { return nil }

        let managedDirectory = managedEmbeddedQEMUDirectoryURL()
        let managedVirGLBinary = managedDirectory.appendingPathComponent("qemu-virgl")

        do {
            if !FileManager.default.fileExists(atPath: managedDirectory.path) {
                try FileManager.default.createDirectory(
                    at: managedDirectory.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try FileManager.default.copyItem(at: bundledDirectory, to: managedDirectory)
            } else if !FileManager.default.fileExists(atPath: managedVirGLBinary.path) {
                try? FileManager.default.removeItem(at: managedDirectory)
                try FileManager.default.copyItem(at: bundledDirectory, to: managedDirectory)
            }

            if FileManager.default.fileExists(atPath: managedVirGLBinary.path) {
                try FileManager.default.setAttributes(
                    [.posixPermissions: NSNumber(value: Int16(0o755))],
                    ofItemAtPath: managedVirGLBinary.path
                )
                return managedVirGLBinary.path
            }
        } catch {
            lastError = "VirGL bootstrap failed: \(error.localizedDescription)"
        }
        return nil
    }

    private func bundledEmbeddedQEMUDirectoryURL() -> URL? {
        guard let resourceRoot = Bundle.main.resourceURL else { return nil }
        let embedded = resourceRoot.appendingPathComponent("EmbeddedQEMU", isDirectory: true)
        return FileManager.default.fileExists(atPath: embedded.path) ? embedded : nil
    }

    private func managedEmbeddedQEMUDirectoryURL() -> URL {
        libraryRootURL().appendingPathComponent(managedEmbeddedQEMUFolderName, isDirectory: true)
    }

    private func findBundledVirGLBinaryPath() -> String? {
        guard let resourceRoot = Bundle.main.resourceURL?.path else { return nil }
        let virgl = (resourceRoot as NSString).appendingPathComponent("EmbeddedQEMU/qemu-virgl")
        return isExecutableFile(virgl) ? virgl : nil
    }

    private func findSystemQEMUBinary() -> String? {
        let candidates = [
            "qemu-system-aarch64",
            "qemu-system-x86_64",
            "qemu-system-arm"
        ]

        var discovered: [String] = []
        for name in candidates {
            if let resolved = resolveExecutable(named: name) {
                discovered.append(resolved)
            }
        }

        let uniqueSorted = Array(Set(discovered)).sorted { qemuPriority($0) < qemuPriority($1) }
        return uniqueSorted.first(where: { isUsableQEMUBinary($0) })
    }

    private func findQEMUImgBinary(qemuSystemPath: String) -> String? {
        if let bundledImg = findBundledQEMUImgBinary() {
            return bundledImg
        }

        let sibling = URL(fileURLWithPath: qemuSystemPath)
            .deletingLastPathComponent()
            .appendingPathComponent("qemu-img")
            .path

        if isExecutableFile(sibling) {
            return sibling
        }

        if let fromPath = resolveExecutable(named: "qemu-img") {
            return fromPath
        }
        return nil
    }

    private func findBundledQEMUBinary() -> String? {
        guard let resourceRoot = Bundle.main.resourceURL?.path else { return nil }

        let candidates = [
            (resourceRoot as NSString).appendingPathComponent("EmbeddedQEMU/qemu-system-aarch64"),
            (resourceRoot as NSString).appendingPathComponent("EmbeddedQEMU/qemu-system-x86_64"),
            (resourceRoot as NSString).appendingPathComponent("EmbeddedQEMU/qemu-virgl")
        ]

        return candidates.first(where: { isExecutableFile($0) })
    }

    private func findBundledQEMUImgBinary() -> String? {
        guard let resourceRoot = Bundle.main.resourceURL?.path else { return nil }

        let candidates = [
            (resourceRoot as NSString).appendingPathComponent("EmbeddedQEMU/qemu-img"),
            (resourceRoot as NSString).appendingPathComponent("EmbeddedQEMU/bin/qemu-img")
        ]

        return candidates.first(where: { isExecutableFile($0) })
    }

    private func resolveExecutable(named name: String) -> String? {
        for directory in executableSearchPaths() {
            let fullPath = (directory as NSString).appendingPathComponent(name)
            if isExecutableFile(fullPath) {
                return fullPath
            }
        }
        return nil
    }

    private func executableSearchPaths() -> [String] {
        let envPaths = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let defaults = [
            "\(home)/bin",
            "\(home)/.local/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin"
        ]
        var ordered: [String] = []

        for path in envPaths + defaults where !path.isEmpty {
            if !ordered.contains(path) {
                ordered.append(path)
            }
        }

        return ordered
    }

    private func isExecutableFile(_ path: String) -> Bool {
        FileManager.default.isExecutableFile(atPath: path)
    }

    private func isUsableQEMUBinary(_ path: String) -> Bool {
        guard isExecutableFile(path) else { return false }
        let name = URL(fileURLWithPath: path).lastPathComponent.lowercased()
        return name.hasPrefix("qemu-system-") || name == "qemu-virgl"
    }

    private func qemuPriority(_ path: String) -> Int {
        let name = URL(fileURLWithPath: path).lastPathComponent.lowercased()

        if name == "qemu-virgl" { return 0 }
        if name.contains("aarch64") { return 1 }
        if name.contains("x86_64") { return 2 }
        if name.hasPrefix("qemu-system-") { return 3 }
        return 4
    }

    private func findAArch64UEFIFirmware() -> String? {
        var candidates: [String] = []
        if let qemuPath = qemuBinaryPath {
            let binDir = URL(fileURLWithPath: qemuPath).deletingLastPathComponent().path
            candidates.append((binDir as NSString).appendingPathComponent("edk2-aarch64-code.fd"))
            candidates.append((binDir as NSString).appendingPathComponent("edk2-arm-code.fd"))
            let shareDir = URL(fileURLWithPath: binDir).deletingLastPathComponent().appendingPathComponent("share/qemu").path
            candidates.append((shareDir as NSString).appendingPathComponent("edk2-aarch64-code.fd"))
            candidates.append((shareDir as NSString).appendingPathComponent("edk2-arm-code.fd"))
        }
        if let resourceRoot = Bundle.main.resourceURL?.path {
            candidates.append((resourceRoot as NSString).appendingPathComponent("EmbeddedQEMU/edk2-aarch64-code.fd"))
            candidates.append((resourceRoot as NSString).appendingPathComponent("EmbeddedQEMU/edk2-arm-code.fd"))
            candidates.append((resourceRoot as NSString).appendingPathComponent("EmbeddedQEMU/share/qemu/edk2-aarch64-code.fd"))
            candidates.append((resourceRoot as NSString).appendingPathComponent("EmbeddedQEMU/share/qemu/edk2-arm-code.fd"))
        }
        candidates += [
            "/opt/homebrew/share/qemu/edk2-aarch64-code.fd",
            "/usr/local/share/qemu/edk2-aarch64-code.fd",
            "/opt/homebrew/share/qemu/edk2-arm-code.fd",
            "/usr/local/share/qemu/edk2-arm-code.fd"
        ]

        return candidates.first(where: { FileManager.default.isReadableFile(atPath: $0) })
    }

    private func findAArch64UEFIVarsTemplate() -> String? {
        var candidates: [String] = []
        if let qemuPath = qemuBinaryPath {
            let binDir = URL(fileURLWithPath: qemuPath).deletingLastPathComponent().path
            candidates.append((binDir as NSString).appendingPathComponent("edk2-aarch64-vars.fd"))
            candidates.append((binDir as NSString).appendingPathComponent("edk2-arm-vars.fd"))
            let shareDir = URL(fileURLWithPath: binDir).deletingLastPathComponent().appendingPathComponent("share/qemu").path
            candidates.append((shareDir as NSString).appendingPathComponent("edk2-aarch64-vars.fd"))
            candidates.append((shareDir as NSString).appendingPathComponent("edk2-arm-vars.fd"))
        }
        if let resourceRoot = Bundle.main.resourceURL?.path {
            candidates.append((resourceRoot as NSString).appendingPathComponent("EmbeddedQEMU/edk2-aarch64-vars.fd"))
            candidates.append((resourceRoot as NSString).appendingPathComponent("EmbeddedQEMU/edk2-arm-vars.fd"))
            candidates.append((resourceRoot as NSString).appendingPathComponent("EmbeddedQEMU/share/qemu/edk2-aarch64-vars.fd"))
            candidates.append((resourceRoot as NSString).appendingPathComponent("EmbeddedQEMU/share/qemu/edk2-arm-vars.fd"))
        }
        candidates += [
            "/opt/homebrew/share/qemu/edk2-aarch64-vars.fd",
            "/usr/local/share/qemu/edk2-aarch64-vars.fd",
            "/opt/homebrew/share/qemu/edk2-arm-vars.fd",
            "/usr/local/share/qemu/edk2-arm-vars.fd"
        ]

        return candidates.first(where: { FileManager.default.isReadableFile(atPath: $0) })
    }

    private func ensureAArch64UEFIVars(for machine: CoreVisorMachine) -> String? {
        let varsURL = URL(fileURLWithPath: machine.bundlePath, isDirectory: true).appendingPathComponent("efi-vars.fd")

        if FileManager.default.isReadableFile(atPath: varsURL.path) {
            return varsURL.path
        }

        guard let templatePath = findAArch64UEFIVarsTemplate() else {
            return nil
        }

        do {
            let parentDirectory = varsURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: parentDirectory.path) {
                try FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true)
            }
            try FileManager.default.copyItem(atPath: templatePath, toPath: varsURL.path)
            return varsURL.path
        } catch {
            appendLog("Failed to prepare EFI vars store: \(error.localizedDescription)\n", for: machine.id)
            return nil
        }
    }

    func refreshEntitlementStatus() {
        isAppSandboxed = readBooleanEntitlement(key: "com.apple.security.app-sandbox")
        hasVirtualizationEntitlement = readBooleanEntitlement(key: "com.apple.security.virtualization")
    }

    private var hasVirtualizationAccess: Bool {
        !isAppSandboxed || hasVirtualizationEntitlement
    }

    private func readBooleanEntitlement(key: String) -> Bool {
        guard let task = SecTaskCreateFromSelf(nil) else {
            return false
        }

        let value = SecTaskCopyValueForEntitlement(task, key as CFString, nil)
        return (value as? Bool) == true
    }

    private func qemuHasOpenGLDisplaySupport(qemuBinaryPath: String) async -> Bool {
        let output = await runProcess(executable: qemuBinaryPath, arguments: ["-display", "help"])
        guard output.exitCode == 0, !output.output.isEmpty else { return false }

        let text = output.output.lowercased()
        return text.contains("cocoa,gl=on")
    }

    private func loadQEMUUSBDevices(qemuBinaryPath: String) async -> [QEMUUSBDevice] {
        let output = await runProcess(executable: qemuBinaryPath, arguments: ["-device", "help"])
        guard output.exitCode == 0, !output.output.isEmpty else { return [] }

        var devices: [QEMUUSBDevice] = []
        var seenIDs: Set<String> = []
        let lines = output.output.split(separator: "\n").map(String.init)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("name ") else { continue }

            let parts = trimmed.components(separatedBy: ",")
            guard let namePart = parts.first else { continue }
            let rawName = namePart
                .replacingOccurrences(of: "name ", with: "")
                .replacingOccurrences(of: "\"", with: "")
                .trimmingCharacters(in: .whitespaces)

            guard rawName.lowercased().contains("usb"), !seenIDs.contains(rawName) else { continue }

            let detail = parts.dropFirst().joined(separator: ",").trimmingCharacters(in: .whitespaces)
            devices.append(QEMUUSBDevice(id: rawName, name: rawName, detail: detail))
            seenIDs.insert(rawName)
        }

        return devices.sorted { $0.name < $1.name }
    }

    private func runProcess(
        executable: String,
        arguments: [String],
        timeoutSeconds: TimeInterval = 8.0
    ) async -> (output: String, exitCode: Int32) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments

                let outputPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = outputPipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: ("", -1))
                    return
                }

                let deadline = Date().addingTimeInterval(timeoutSeconds)
                while process.isRunning && Date() < deadline {
                    Thread.sleep(forTimeInterval: 0.05)
                }

                if process.isRunning {
                    process.terminate()
                    Thread.sleep(forTimeInterval: 0.1)
                    if process.isRunning {
                        process.interrupt()
                    }
                    Thread.sleep(forTimeInterval: 0.1)
                    if process.isRunning {
                        kill(process.processIdentifier, SIGKILL)
                    }

                    let timedOutData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let timedOutOutput = String(data: timedOutData, encoding: .utf8) ?? ""
                    continuation.resume(
                        returning: ("\(timedOutOutput)\n[CoreVisor] Process timed out after \(Int(timeoutSeconds))s.", -2)
                    )
                    return
                }

                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: (output, process.terminationStatus))
            }
        }
    }
}

#if canImport(Virtualization)
private final class AppleVMSession: NSObject, VZVirtualMachineDelegate {
    let virtualMachine: VZVirtualMachine
    private let onStop: (Error?) -> Void

    init(virtualMachine: VZVirtualMachine, onStop: @escaping (Error?) -> Void) {
        self.virtualMachine = virtualMachine
        self.onStop = onStop
    }

    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        onStop(nil)
    }

    func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
        onStop(error)
    }
}
#endif
