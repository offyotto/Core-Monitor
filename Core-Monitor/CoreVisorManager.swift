import Foundation
import Combine
import Security
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
    var backend: VMBackend = .appleVirtualization
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
    @Published private(set) var usbDevices: [QEMUUSBDevice] = []
    @Published private(set) var isScanning = false
    @Published private(set) var hasVirtualizationEntitlement = false
    @Published private(set) var machines: [CoreVisorMachine] = []
    @Published private(set) var machineStates: [UUID: CoreVisorRuntimeState] = [:]
    @Published private(set) var machineLogs: [UUID: String] = [:]
    @Published var lastError: String?

    let templates: [CoreVisorTemplate] = [
        CoreVisorTemplate(guest: .linux, name: "Linux Desktop", cpuCores: 4, memoryGB: 8, diskGB: 64),
        CoreVisorTemplate(guest: .windows, name: "Windows 11", cpuCores: 6, memoryGB: 12, diskGB: 128),
        CoreVisorTemplate(guest: .macOS, name: "macOS Guest", cpuCores: 4, memoryGB: 8, diskGB: 80),
        CoreVisorTemplate(guest: .netBSD, name: "NetBSD", cpuCores: 2, memoryGB: 4, diskGB: 32),
        CoreVisorTemplate(guest: .unix, name: "UNIX", cpuCores: 2, memoryGB: 4, diskGB: 32)
    ]

    private var qemuProcesses: [UUID: Process] = [:]
#if canImport(Virtualization)
    private var appleSessions: [UUID: AppleVMSession] = [:]
#endif

    init() {
        loadMachines()
        refreshEntitlementStatus()
        Task {
            await refreshRuntimeData()
        }
    }

    func refreshRuntimeData() async {
        isScanning = true
        defer { isScanning = false }
        refreshEntitlementStatus()

        qemuBinaryPath = findQEMUBinary()
        guard let qemuBinaryPath else {
            usbDevices = []
            lastError = "QEMU not found in /opt/homebrew/bin or /usr/local/bin."
            return
        }

        let parsedUSB = await loadQEMUUSBDevices(qemuBinaryPath: qemuBinaryPath)
        usbDevices = parsedUSB
        if parsedUSB.isEmpty {
            lastError = "No QEMU USB devices reported by qemu -device help."
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
        }
    }

    func createMachine(from draft: CoreVisorDraft) async {
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

    func removeMachine(_ machine: CoreVisorMachine) {
        stopMachine(machine)
        try? FileManager.default.removeItem(atPath: machine.bundlePath)
        machines.removeAll { $0.id == machine.id }
        machineStates[machine.id] = nil
        machineLogs[machine.id] = nil
        saveMachines()
    }

    func startMachine(_ machine: CoreVisorMachine) async {
        guard machineStates[machine.id] != .running, machineStates[machine.id] != .starting else { return }

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
    }

    func runtimeState(for machine: CoreVisorMachine) -> CoreVisorRuntimeState {
        machineStates[machine.id] ?? .stopped
    }

    func runtimeLog(for machine: CoreVisorMachine) -> String {
        machineLogs[machine.id] ?? ""
    }

    func isBackendSupported(_ backend: VMBackend, for guest: VMGuestType) -> Bool {
        switch (backend, guest) {
        case (.appleVirtualization, .linux), (.appleVirtualization, .macOS):
            return hasVirtualizationEntitlement
        case (.appleVirtualization, _):
            return false
        case (.qemu, _):
            return qemuBinaryPath != nil
        }
    }

    func commandPreview(for draft: CoreVisorDraft) -> String {
        switch draft.backend {
        case .appleVirtualization:
            if draft.guest == .macOS {
                return "Apple Virtualization (macOS): requires restore image install flow (IPSW) before first boot."
            }
            return "Apple Virtualization: native runtime configured. Linux supports kernel+ramdisk boot or EFI+ISO boot."
        case .qemu:
            guard let qemuBinaryPath else {
                return "QEMU binary not found. Install qemu first."
            }
            let machine = draftToPreviewMachine(draft)
            return ([qemuBinaryPath] + qemuArguments(for: machine)).joined(separator: " ")
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

        let configURL = bundleURL.appendingPathComponent("machine.json")
        let data = try JSONEncoder().encode(machine)
        try data.write(to: configURL)

        return machine
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
        return String(allowed)
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

        let qemuImgURL = URL(fileURLWithPath: qemuSystem)
            .deletingLastPathComponent()
            .appendingPathComponent("qemu-img")

        guard FileManager.default.isReadableFile(atPath: qemuImgURL.path) else {
            throw NSError(domain: "CoreVisor", code: 2, userInfo: [NSLocalizedDescriptionKey: "qemu-img not found next to \(qemuSystem)."])
        }

        let args = ["create", "-f", "qcow2", diskURL.path, "\(max(4, sizeGB))G"]
        let result = await runProcess(executable: qemuImgURL.path, arguments: args)
        if result.exitCode != 0 {
            throw NSError(domain: "CoreVisor", code: 3, userInfo: [NSLocalizedDescriptionKey: "qemu-img failed: \(result.output)"])
        }
    }

    private func createRawDisk(at diskURL: URL, sizeGB: Int) throws {
        let bytes = UInt64(max(4, sizeGB)) * 1_073_741_824
        FileManager.default.createFile(atPath: diskURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: diskURL)
        try handle.truncate(atOffset: bytes)
        try handle.close()
    }

    private func startQEMUMachine(_ machine: CoreVisorMachine) async {
        let machineID = machine.id
        guard let qemuBinaryPath else {
            machineStates[machineID] = .error
            appendLog("QEMU binary not found.\n", for: machineID)
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: qemuBinaryPath)
        process.arguments = qemuArguments(for: machine)

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

                if process.terminationReason == .exit && process.terminationStatus == 0 {
                    self?.machineStates[machineID] = .stopped
                    self?.appendLog("\nVM exited cleanly.\n", for: machineID)
                } else {
                    self?.machineStates[machineID] = .error
                    self?.appendLog("\nVM stopped unexpectedly with status \(process.terminationStatus).\n", for: machineID)
                }
            }
        }

        do {
            try process.run()
            qemuProcesses[machineID] = process
            machineStates[machineID] = .running
            appendLog("QEMU process started.\n", for: machineID)
        } catch {
            machineStates[machineID] = .error
            appendLog("Failed to launch QEMU: \(error.localizedDescription)\n", for: machineID)
        }
    }

#if canImport(Virtualization)
    private func startAppleVirtualizationMachine(_ machine: CoreVisorMachine) async {
        do {
            let config = try createAppleVMConfiguration(for: machine)
            let vm = VZVirtualMachine(configuration: config)

            let session = AppleVMSession(virtualMachine: vm) { [weak self] error in
                guard let self else { return }
                if let error {
                    self.machineStates[machine.id] = .error
                    self.appendLog("Apple Virtualization stopped with error: \(error.localizedDescription)\n", for: machine.id)
                } else {
                    self.machineStates[machine.id] = .stopped
                    self.appendLog("Apple Virtualization guest stopped.\n", for: machine.id)
                }
                self.appleSessions[machine.id] = nil
            }

            vm.delegate = session
            appleSessions[machine.id] = session

            try await vm.start()
            machineStates[machine.id] = .running
            appendLog("Apple Virtualization VM started.\n", for: machine.id)
        } catch {
            machineStates[machine.id] = .error
            appendLog("Apple Virtualization start failed: \(error.localizedDescription)\n", for: machine.id)
        }
    }

    private func createAppleVMConfiguration(for machine: CoreVisorMachine) throws -> VZVirtualMachineConfiguration {
        let configuration = VZVirtualMachineConfiguration()
        configuration.cpuCount = max(1, machine.cpuCores)
        configuration.memorySize = UInt64(max(2, machine.memoryGB)) * 1_073_741_824

        let platform = VZGenericPlatformConfiguration()
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
            configuration.bootLoader = VZEFIBootLoader()
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

    private func stopAppleSession(_ session: AppleVMSession, machineID: UUID) async {
        do {
            if session.virtualMachine.canRequestStop {
                try session.virtualMachine.requestStop()
            } else if session.virtualMachine.canStop {
                try await session.virtualMachine.stop()
            }
            machineStates[machineID] = .stopped
            appendLog("Stop requested.\n", for: machineID)
        } catch {
            machineStates[machineID] = .error
            appendLog("Stop failed: \(error.localizedDescription)\n", for: machineID)
        }
    }
#else
    private func startAppleVirtualizationMachine(_ machine: CoreVisorMachine) async {
        machineStates[machine.id] = .error
        appendLog("Virtualization framework unavailable on this build.\n", for: machine.id)
    }
#endif

    func qemuArguments(for machine: CoreVisorMachine) -> [String] {
        let isAArch64 = (qemuBinaryPath ?? "").contains("aarch64")

        var args: [String] = [
            "-smp", "\(max(1, machine.cpuCores))",
            "-m", "\(max(1, machine.memoryGB))G",
            "-accel", "hvf"
        ]

        if isAArch64 {
            args += [
                "-machine", "virt,highmem=on",
                "-cpu", "host"
            ]

            if let efi = findAArch64UEFIFirmware() {
                args += ["-bios", efi]
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
            "-drive", "if=virtio,file=\(machine.diskPath),format=qcow2"
        ]

        if !machine.isoPath.isEmpty {
            args += ["-cdrom", machine.isoPath, "-boot", "order=d"]
        } else {
            args += ["-boot", "order=c"]
        }

        if machine.enableSound {
            args += [
                "-audiodev", "coreaudio,id=ca",
                "-device", "ich9-intel-hda",
                "-device", "hda-output,audiodev=ca"
            ]
        }

        if machine.enableVirGL {
            args += ["-display", "cocoa,gl=on", "-device", "virtio-gpu-gl-pci"]
        } else {
            args += ["-display", "cocoa", "-device", "virtio-gpu-pci"]
        }

        for usbID in machine.selectedUSBDeviceIDs {
            args += ["-device", usbID]
        }

        return args
    }

    private func appendLog(_ text: String, for machineID: UUID) {
        var existing = machineLogs[machineID] ?? ""
        existing.append(text)
        if existing.count > 60_000 {
            existing = String(existing.suffix(60_000))
        }
        machineLogs[machineID] = existing
    }

    private func loadMachines() {
        let url = libraryIndexURL()
        guard let data = try? Data(contentsOf: url),
              let library = try? JSONDecoder().decode(CoreVisorLibrary.self, from: data) else {
            machines = []
            return
        }
        machines = library.machines.sorted { $0.createdAt > $1.createdAt }
        for machine in machines {
            machineStates[machine.id] = .stopped
        }
    }

    private func saveMachines() {
        let directory = libraryRootURL()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let library = CoreVisorLibrary(machines: machines)
        guard let data = try? JSONEncoder().encode(library) else { return }
        try? data.write(to: libraryIndexURL())
    }

    private func libraryRootURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("CoreVisor", isDirectory: true)
    }

    private func machinesDirectoryURL() -> URL {
        let url = libraryRootURL().appendingPathComponent("VMs", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func libraryIndexURL() -> URL {
        libraryRootURL().appendingPathComponent("library.json")
    }

    private func findQEMUBinary() -> String? {
        let candidates = [
            "/opt/homebrew/bin/qemu-system-aarch64",
            "/usr/local/bin/qemu-system-aarch64",
            "/opt/homebrew/bin/qemu-system-x86_64",
            "/usr/local/bin/qemu-system-x86_64"
        ]

        return candidates.first(where: { FileManager.default.isReadableFile(atPath: $0) })
    }

    private func findAArch64UEFIFirmware() -> String? {
        let candidates = [
            "/opt/homebrew/share/qemu/edk2-aarch64-code.fd",
            "/usr/local/share/qemu/edk2-aarch64-code.fd",
            "/opt/homebrew/share/qemu/edk2-arm-code.fd",
            "/usr/local/share/qemu/edk2-arm-code.fd"
        ]

        return candidates.first(where: { FileManager.default.isReadableFile(atPath: $0) })
    }

    func refreshEntitlementStatus() {
        hasVirtualizationEntitlement = readVirtualizationEntitlement()
    }

    private func readVirtualizationEntitlement() -> Bool {
        guard let task = SecTaskCreateFromSelf(nil) else {
            return false
        }

        let key = "com.apple.security.virtualization" as CFString
        let value = SecTaskCopyValueForEntitlement(task, key, nil)
        return (value as? Bool) == true
    }

    private func loadQEMUUSBDevices(qemuBinaryPath: String) async -> [QEMUUSBDevice] {
        let output = await runProcess(executable: qemuBinaryPath, arguments: ["-device", "help"])
        guard !output.output.isEmpty else { return [] }

        var devices: [QEMUUSBDevice] = []
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

            guard rawName.contains("usb") else { continue }

            let detail = parts.dropFirst().joined(separator: ",").trimmingCharacters(in: .whitespaces)
            devices.append(QEMUUSBDevice(id: rawName, name: rawName, detail: detail))
        }

        return devices.sorted { $0.name < $1.name }
    }

    private func runProcess(executable: String, arguments: [String]) async -> (output: String, exitCode: Int32) {
        await withCheckedContinuation { continuation in
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

            process.terminationHandler = { process in
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
