// DoItForMeManager.swift
// CoreVisor — fully automated Windows 11 ARM installer pipeline
//
// Pipeline:
//   1. Download Windows 11 ARM ISO (Microsoft static CDN)
//   2. Download VirtIO drivers ISO
//   3. Build setup-support ISO (separate removable media)
//      • Keeps Microsoft ISO untouched/bootable
//      • Carries autounattend.xml + $WinpeDriver$ drivers
//      • LabConfig registry keys bypass TPM/SecureBoot/RAM/CPU/Storage checks
//      • Local account, no Microsoft account, no password
//      • FirstLogonCommands install NetKVM + viogpudo silently
//   4. Create VM + virtual disk
//   5. Initialize TPM (swtpm)
//   6. Boot — fully unattended install (~15-20 min)

import Foundation
import Security
import Combine

// MARK: - Phase model

enum DoItForMePhase: Equatable {
    case idle
    case downloadingISO(progress: Double, detail: String)
    case downloadingVirtIO(progress: Double, detail: String)
    case injectingISO(detail: String)
    case creatingDisk
    case initializingTPM
    case preparingLaunch
    case done(machine: CoreVisorMachine)
    case failed(String)

    var isActive: Bool {
        switch self { case .idle, .done, .failed: return false; default: return true }
    }

    var progressFraction: Double {
        switch self {
        case .downloadingISO(let p, _):    return 0.02 + p * 0.55
        case .downloadingVirtIO(let p, _): return 0.58 + p * 0.18
        case .injectingISO:                return 0.78
        case .creatingDisk:                return 0.84
        case .initializingTPM:             return 0.91
        case .preparingLaunch:             return 0.97
        case .done:                        return 1.0
        default:                           return 0.0
        }
    }

    var label: String {
        switch self {
        case .idle:                        return "Ready"
        case .downloadingISO(_, let d):    return d
        case .downloadingVirtIO(_, let d): return d
        case .injectingISO(let d):         return d
        case .creatingDisk:                return "Creating virtual disk…"
        case .initializingTPM:             return "Initializing TPM…"
        case .preparingLaunch:             return "Launching…"
        case .done(let m):                 return "\(m.name) is ready"
        case .failed(let e):               return "Error: \(e)"
        }
    }

    var icon: String {
        switch self {
        case .downloadingISO:    return "arrow.down.circle"
        case .downloadingVirtIO: return "cpu"
        case .injectingISO:      return "doc.badge.gearshape"
        case .creatingDisk:      return "externaldrive.badge.plus"
        case .initializingTPM:   return "lock.shield"
        case .preparingLaunch:   return "play.circle"
        case .done:              return "checkmark.circle.fill"
        default:                 return "gearshape"
        }
    }
}

// MARK: - Keychain TPM seed store

enum TPMKeychainStore {
    private static let service = "com.coremonitor.tpm"

    static func save(seed: Data, for machineID: UUID) -> Bool {
        delete(for: machineID)
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service as CFString,
            kSecAttrAccount: machineID.uuidString as CFString,
            kSecValueData:   seed as CFData,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func load(for machineID: UUID) -> Data? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service as CFString,
            kSecAttrAccount: machineID.uuidString as CFString,
            kSecReturnData:  true as CFBoolean,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    @discardableResult
    static func delete(for machineID: UUID) -> Bool {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service as CFString,
            kSecAttrAccount: machineID.uuidString as CFString,
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}

// MARK: - swtpm lifecycle

final class SwtpmController {
    nonisolated static func stateDir(in bundlePath: String) -> String {
        (bundlePath as NSString).appendingPathComponent("tpm")
    }
    /// Socket lives in /tmp/corevm-{uuid8}/ to stay under the 104-byte UNIX limit.
    /// The tpm state dir stays inside the bundle (persistent across reboots).
    nonisolated static func socketPath(machineID: UUID) -> String {
        "/tmp/corevm-\(machineID.uuidString.prefix(8).lowercased())/tpm.sock"
    }
    /// Legacy overload — derives UUID-based path from the socket being in /tmp
    nonisolated static func socketPath(in bundlePath: String) -> String {
        // Fallback only: callers that have the machineID should use socketPath(machineID:)
        (bundlePath as NSString).appendingPathComponent("tpm.sock")
    }
    nonisolated static func binaryPath() -> String? {
        ["/opt/homebrew/bin/swtpm", "/usr/local/bin/swtpm"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    nonisolated static func initStateDirectory(bundlePath: String, seed: Data) throws {
        guard let binary = binaryPath() else {
            throw NSError(domain: "swtpm", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "swtpm not found. Install with: brew install swtpm"])
        }
        let dir = stateDir(in: bundlePath)
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let keyHex = seed.map { String(format: "%02x", $0) }.joined()
        let p = Process()
        p.executableURL = URL(fileURLWithPath: binary)
        p.arguments = ["create", "--tpm2", "--tpmstate", "dir=\(dir)",
                       "--key", "pwdfile=/dev/stdin,mode=aes-256-cbc"]
        let inPipe = Pipe()
        p.standardInput  = inPipe; p.standardOutput = Pipe(); p.standardError = Pipe()
        try p.run()
        inPipe.fileHandleForWriting.write(keyHex.data(using: .utf8)!)
        inPipe.fileHandleForWriting.closeFile()
        p.waitUntilExit()
    }

    nonisolated static func startDaemon(bundlePath: String, machineID: UUID, seed: Data) throws -> Process {
        guard let binary = binaryPath() else {
            throw NSError(domain: "swtpm", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "swtpm not found. Install with: brew install swtpm"])
        }
        let dir  = stateDir(in: bundlePath)
        let sock = socketPath(machineID: machineID)
        // Ensure /tmp/corevm-{uuid8}/ exists
        let sockDir = (sock as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: sockDir, withIntermediateDirectories: true)
        let keyHex = seed.map { String(format: "%02x", $0) }.joined()
        try? FileManager.default.removeItem(atPath: sock)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: binary)
        p.arguments = ["socket", "--tpm2", "--tpmstate", "dir=\(dir)",
                       "--ctrl", "type=unixio,path=\(sock)",
                       "--log", "level=0",
                       "--key", "pwdfile=/dev/stdin,mode=aes-256-cbc"]
        let inPipe = Pipe()
        p.standardInput  = inPipe; p.standardOutput = Pipe(); p.standardError = Pipe()
        try p.run()
        inPipe.fileHandleForWriting.write(keyHex.data(using: .utf8)!)
        inPipe.fileHandleForWriting.closeFile()
        for _ in 0..<20 {
            if FileManager.default.fileExists(atPath: sock) { break }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return p
    }
}

// MARK: - Windows 11 ARM64 ISO catalog

enum Win11ISOCatalog {
    struct Entry { let url: URL; let name: String; let bytes: Int; let sha256: String? }
    private static let consumerURL = "https://software-static.download.prss.microsoft.com/dbazure/888969d5-f34g-4e03-ac9d-1f9786c66749/26200.6584.250915-1905.25h2_ge_release_svc_refresh_CLIENT_CONSUMER_A64FRE_en-us.iso"
    static func resolve() -> Entry {
        Entry(url: URL(string: consumerURL)!, name: "Win11_25H2_ARM64_en-us.iso", bytes: 5_000_000_000, sha256: nil)
    }
}

// MARK: - autounattend.xml generator
//
// Generates a fully unattended Windows 11 answer file.
// windowsPE pass: locale, disk partition, LabConfig bypass keys
// specialize pass: computer name, timezone
// oobeSystem pass: skip all screens, local account, auto-login, driver install
//
// NOTE: VirtIO ISO is on usb-storage (not SCSI), so Windows assigns it a drive
// letter independently of the install ISO. The FirstLogonCommands script scans
// all drive letters A-Z to find the VirtIO ISO by its volume label ("virtio-win")
// rather than assuming a fixed letter, making it immune to drive enumeration order.

enum AutounattendGenerator {

    static func xml(
        computerName: String = "COREVISOR-WIN",
        username: String = "User"
    ) -> String {
        return [xmlHeader(),
                windowsPEPass(),
                specializePass(computerName: computerName),
                oobePass(username: username)]
            .joined(separator: "\n")
    }

    private static func xmlHeader() -> String {
        """
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
"""
    }

    private static func windowsPEPass() -> String {
        """
  <settings pass="windowsPE">
    <component name="Microsoft-Windows-International-Core-WinPE"
               processorArchitecture="arm64" publicKeyToken="31bf3856ad364e35"
               language="neutral" versionScope="nonSxS"
               xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
      <SetupUILanguage>
        <UILanguage>en-US</UILanguage>
      </SetupUILanguage>
      <InputLocale>en-US</InputLocale>
      <SystemLocale>en-US</SystemLocale>
      <UILanguage>en-US</UILanguage>
      <UserLocale>en-US</UserLocale>
    </component>
    <component name="Microsoft-Windows-Setup"
               processorArchitecture="arm64" publicKeyToken="31bf3856ad364e35"
               language="neutral" versionScope="nonSxS"
               xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
      <RunSynchronous>
        <RunSynchronousCommand wcm:action="add">
          <Order>1</Order>
          <Path>reg add HKLM\\SYSTEM\\Setup\\LabConfig /v BypassTPMCheck /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>2</Order>
          <Path>reg add HKLM\\SYSTEM\\Setup\\LabConfig /v BypassSecureBootCheck /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>3</Order>
          <Path>reg add HKLM\\SYSTEM\\Setup\\LabConfig /v BypassRAMCheck /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>4</Order>
          <Path>reg add HKLM\\SYSTEM\\Setup\\LabConfig /v BypassCPUCheck /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>5</Order>
          <Path>reg add HKLM\\SYSTEM\\Setup\\LabConfig /v BypassStorageCheck /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>6</Order>
          <Path>reg add HKLM\\SYSTEM\\Setup\\MoSetup /v AllowUpgradesWithUnsupportedTPMOrCPU /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
      </RunSynchronous>
      <DiskConfiguration>
        <Disk wcm:action="add">
          <DiskID>0</DiskID>
          <WillWipeDisk>true</WillWipeDisk>
          <CreatePartitions>
            <CreatePartition wcm:action="add">
              <Order>1</Order>
              <Type>EFI</Type>
              <Size>260</Size>
            </CreatePartition>
            <CreatePartition wcm:action="add">
              <Order>2</Order>
              <Type>MSR</Type>
              <Size>16</Size>
            </CreatePartition>
            <CreatePartition wcm:action="add">
              <Order>3</Order>
              <Type>Primary</Type>
              <Extend>true</Extend>
            </CreatePartition>
          </CreatePartitions>
          <ModifyPartitions>
            <ModifyPartition wcm:action="add">
              <Order>1</Order>
              <PartitionID>1</PartitionID>
              <Label>System</Label>
              <Format>FAT32</Format>
            </ModifyPartition>
            <ModifyPartition wcm:action="add">
              <Order>2</Order>
              <PartitionID>3</PartitionID>
              <Label>Windows</Label>
              <Letter>C</Letter>
              <Format>NTFS</Format>
            </ModifyPartition>
          </ModifyPartitions>
        </Disk>
      </DiskConfiguration>
      <ImageInstall>
        <OSImage>
          <InstallTo>
            <DiskID>0</DiskID>
            <PartitionID>3</PartitionID>
          </InstallTo>
          <InstallToAvailablePartition>false</InstallToAvailablePartition>
        </OSImage>
      </ImageInstall>
      <UserData>
        <AcceptEula>true</AcceptEula>
        <FullName>User</FullName>
        <Organization>CoreVisor</Organization>
      </UserData>
    </component>
  </settings>
"""
    }

    private static func specializePass(computerName: String) -> String {
        """
  <settings pass="specialize">
    <component name="Microsoft-Windows-Shell-Setup"
               processorArchitecture="arm64" publicKeyToken="31bf3856ad364e35"
               language="neutral" versionScope="nonSxS"
               xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
      <ComputerName>\(computerName)</ComputerName>
      <TimeZone>Pacific Standard Time</TimeZone>
    </component>
  </settings>
"""
    }

    private static func oobePass(username: String) -> String {
        return """
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-Shell-Setup"
               processorArchitecture="arm64" publicKeyToken="31bf3856ad364e35"
               language="neutral" versionScope="nonSxS"
               xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
      <OOBE>
        <HideEULAPage>true</HideEULAPage>
        <HideLocalAccountScreen>false</HideLocalAccountScreen>
        <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
        <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
        <NetworkLocation>Work</NetworkLocation>
        <ProtectYourPC>3</ProtectYourPC>
        <SkipMachineOOBE>true</SkipMachineOOBE>
        <SkipUserOOBE>true</SkipUserOOBE>
      </OOBE>

      <UserAccounts>
        <LocalAccounts>
          <LocalAccount wcm:action="add">
            <Password><Value></Value><PlainText>true</PlainText></Password>
            <Description>CoreVisor User</Description>
            <DisplayName>\(username)</DisplayName>
            <Group>Administrators</Group>
            <Name>\(username)</Name>
          </LocalAccount>
        </LocalAccounts>
      </UserAccounts>

      <AutoLogon>
        <Password><Value></Value><PlainText>true</PlainText></Password>
        <Enabled>true</Enabled>
        <LogonCount>2</LogonCount>
        <Username>\(username)</Username>
      </AutoLogon>
    </component>
  </settings>

</unattend>
"""
    }
}

// MARK: - ISO patcher
//
// Injects autounattend.xml and VirtIO drivers into the Windows ISO using
// only macOS built-in tools (hdiutil + ditto) — no extra brew dependencies.
//
// ┌─ WHY NOT makehybrid? ──────────────────────────────────────────────────────┐
// │ hdiutil makehybrid rebuilds the ISO from a directory tree. It cannot       │
// │ reproduce the original ISO's EFI System Partition (the raw FAT image that  │
// │ EDK2 boots from). The result drops straight to EFI shell because EDK2      │
// │ finds no valid BOOTAA64.EFI entry. -eltorito-boot only handles legacy BIOS  │
// │ El Torito; AArch64 EDK2 ignores it entirely.                               │
// └────────────────────────────────────────────────────────────────────────────┘
//
// ┌─ SHADOW-PATCH METHOD ──────────────────────────────────────────────────────┐
// │ 1. hdiutil convert sourceISO → UDRW (writable raw image, same disk layout) │
// │ 2. hdiutil attach UDRW read/write → mount the live filesystem              │
// │ 3. Write autounattend.xml and $WinpeDriver$ directly into the mounted fs   │
// │ 4. hdiutil detach                                                           │
// │ 5. hdiutil convert UDRW → UDTO (.iso CDR format, read-only)                │
// │                                                                             │
// │ The output ISO has identical boot sectors, EFI partition, and El Torito    │
// │ catalog to the original — EDK2 boots it identically.                       │
// └────────────────────────────────────────────────────────────────────────────┘

// Legacy helper retained for reference; current pipeline does not mutate the
// Microsoft installer ISO anymore.
// MARK: - Unattend image builder
//
// Creates a tiny FAT32 disk image containing autounattend.xml and NetKVM
// WinPE drivers. Attached to QEMU as a second usb-storage device.
//
// Why FAT32 instead of patching the Windows ISO:
//   macOS will never mount an ISO9660 or UDF volume read-write — the kernel
//   filesystem drivers for both are read-only by design. No hdiutil flag
//   (including -readwrite or -imagekey diskimage-class=CRawDiskImage) changes
//   this because the restriction is in the FS driver, not the image driver.
//
//   FAT32 images created with hdiutil mount read-write perfectly on macOS.
//   Windows Setup scans ALL attached drives for autounattend.xml at startup —
//   not just the boot drive. This is how Parallels/VMware Fusion do it.
//   Microsoft documents this for WDS/MDT: any removable/USB drive at root works.
//   $WinpeDriver$ at the root of any attached drive is also scanned by WinPE.

enum UnattendImageBuilder {

    static func build(
        destImage: String,
        unattendXML: String,
        virtioISO: String,
        onProgress: @escaping (String) -> Void
    ) async throws {
        let fm = FileManager.default

        // Build the FAT32 image from a staging directory using
        // `hdiutil create -srcfolder`. This avoids mounting anything —
        // the app never writes to /Volumes/*, which is outside the sandbox.
        // hdiutil assembles the FAT32 image internally from the directory tree.

        let tmp = fm.temporaryDirectory
            .appendingPathComponent("corevisor-unattend-\(UUID().uuidString.prefix(8))")
        let staging = tmp.appendingPathComponent("staging")
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmp) }

        // ── Step 1: write autounattend.xml into staging ───────────────────────────
        onProgress("Writing autounattend.xml…")
        for name in ["autounattend.xml", "Autounattend.xml"] {
            try unattendXML.write(
                to: staging.appendingPathComponent(name),
                atomically: true, encoding: .utf8
            )
        }

        // ── Step 2: copy NetKVM from VirtIO ISO into staging/$WinpeDriver$ ────────
        // Mount VirtIO ISO read-only (reading /Volumes is allowed in sandbox).
        // Only NetKVM — NVMe is natively visible to WinPE ARM64.
        // vioscsi/viostor alongside NVMe → 0x80070103 storage stack conflict.
        if fm.fileExists(atPath: virtioISO) {
            onProgress("Extracting NetKVM WinPE driver…")
            if let vioMount = try await attachParsePlist(image: virtioISO, readOnly: true) {
                defer { quiet("/usr/bin/hdiutil", ["detach", vioMount, "-force"]) }
                let winpeDrv = staging.appendingPathComponent("$WinpeDriver$")
                try? fm.createDirectory(at: winpeDrv, withIntermediateDirectories: true)
                let src = URL(fileURLWithPath: vioMount)
                    .appendingPathComponent("NetKVM/w11/ARM64")
                if fm.fileExists(atPath: src.path) {
                    try? fm.copyItem(at: src, to: winpeDrv.appendingPathComponent("NetKVM"))
                }
            }
        }

        // ── Step 3: build FAT32 image from staging dir (no mount needed) ─────────
        // hdiutil create -srcfolder builds the image internally without ever
        // mounting to /Volumes — safe inside the app sandbox.
        onProgress("Building unattend disk image…")
        if fm.fileExists(atPath: destImage) { try fm.removeItem(atPath: destImage) }

        // hdiutil appends .dmg — give it the base path and rename after
        let imageBase = (destImage as NSString).deletingPathExtension
        let imageDmg  = imageBase + ".dmg"
        if fm.fileExists(atPath: imageDmg) { try? fm.removeItem(atPath: imageDmg) }

        try await run("/usr/bin/hdiutil", [
            "create",
            "-srcfolder", staging.path,
            "-fs",        "MS-DOS",
            "-volname",   "UNATTEND",
            "-format",    "UDIF",
            "-o",         imageBase
        ])

        // Rename .dmg → .img so QEMU recognises it as a raw-ish image
        let actualDmg: String = {
            if fm.fileExists(atPath: imageDmg) { return imageDmg }
            if fm.fileExists(atPath: destImage) { return destImage }
            return imageDmg
        }()
        if actualDmg != destImage {
            if fm.fileExists(atPath: destImage) { try? fm.removeItem(atPath: destImage) }
            try fm.moveItem(atPath: actualDmg, toPath: destImage)
        }

        guard fm.fileExists(atPath: destImage) else {
            throw unattendError(2, "hdiutil create did not produce unattend image at \(destImage)")
        }
        onProgress("Unattend image ready.")
    }

    // MARK: - hdiutil attach via plist (read-only mounts only — for VirtIO ISO)

    private static func attachParsePlist(image: String, readOnly: Bool) async throws -> String? {
        var args = ["attach", image, "-nobrowse", "-noverify", "-plist"]
        if readOnly { args.append("-readonly") }
        let output = try await runCapturing("/usr/bin/hdiutil", args)
        guard let data = output.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict     = plist as? [String: Any],
              let entities = dict["system-entities"] as? [[String: Any]]
        else { return nil }
        var result: String? = nil
        for entity in entities {
            if let mp = entity["mount-point"] as? String, !mp.isEmpty { result = mp }
        }
        return result
    }

    // MARK: - Process helpers

    private static func run(_ binary: String, _ args: [String]) async throws {
        _ = try await runCapturing(binary, args, throwOnFailure: true)
    }

    private static func runCapturing(
        _ binary: String, _ args: [String], throwOnFailure: Bool = false
    ) async throws -> String {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: binary)
            p.arguments = args
            let outPipe = Pipe(), errPipe = Pipe()
            p.standardOutput = outPipe; p.standardError = errPipe
            p.terminationHandler = { proc in
                let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                if throwOnFailure && proc.terminationStatus != 0 {
                    let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    cont.resume(throwing: NSError(
                        domain: "UnattendBuilder", code: Int(proc.terminationStatus),
                        userInfo: [NSLocalizedDescriptionKey:
                            "\((binary as NSString).lastPathComponent) failed (\(proc.terminationStatus)): \(err.prefix(600))"]
                    )); return
                }
                cont.resume(returning: out)
            }
            do { try p.run() } catch { cont.resume(throwing: error) }
        }
    }

    @discardableResult
    private static func quiet(_ bin: String, _ args: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: bin); p.arguments = args
        p.standardOutput = Pipe(); p.standardError = Pipe()
        try? p.run(); p.waitUntilExit(); return p.terminationStatus
    }

    private static func unattendError(_ code: Int, _ msg: String) -> NSError {
        NSError(domain: "UnattendBuilder", code: code, userInfo: [NSLocalizedDescriptionKey: msg])
    }
}


// MARK: - DoItForMeManager

@MainActor
final class DoItForMeManager: ObservableObject {

    @Published private(set) var phase: DoItForMePhase = .idle
    @Published private(set) var swtpmAvailable: Bool  = false

    var manualISOPath:   String = ""
    var windowsUsername: String = "User"
    var computerName:    String = "COREVISOR-WIN"

    private weak var coreVisorManager: CoreVisorManager?
    private var downloadTask: Task<Void, Never>?

    init(coreVisorManager: CoreVisorManager) {
        self.coreVisorManager = coreVisorManager
        self.swtpmAvailable   = SwtpmController.binaryPath() != nil
    }

    func run(vmName: String = "Windows 11 ARM",
             cpuCores: Int = 6, memoryGB: Int = 8, diskGB: Int = 80) {
        guard !phase.isActive else { return }
        downloadTask = Task { [weak self] in
            await self?.pipeline(vmName: vmName, cpuCores: cpuCores,
                                 memoryGB: memoryGB, diskGB: diskGB)
        }
    }

    func cancel() {
        downloadTask?.cancel(); downloadTask = nil; phase = .idle
    }

    // MARK: - Pipeline

    private func pipeline(vmName: String, cpuCores: Int, memoryGB: Int, diskGB: Int) async {
        guard let mgr = coreVisorManager else {
            phase = .failed("CoreVisorManager not available"); return
        }
        do {
            let isoDir    = mgr.libraryRootURL().appendingPathComponent("CoreVisor/ISO")
            let virtioDir = mgr.libraryRootURL().appendingPathComponent("CoreVisor")
            try FileManager.default.createDirectory(at: isoDir, withIntermediateDirectories: true)

            // ── 1: Windows ISO ────────────────────────────────────────────────────
            let baseISOPath: String
            if !manualISOPath.isEmpty && FileManager.default.fileExists(atPath: manualISOPath) {
                baseISOPath = manualISOPath
            } else {
                let iso  = Win11ISOCatalog.resolve()
                let dest = isoDir.appendingPathComponent(iso.name)
                let existingSize = (try? FileManager.default
                    .attributesOfItem(atPath: dest.path)[.size] as? Int64) ?? 0
                if existingSize >= 4_000_000_000 {
                    phase = .downloadingISO(progress: 1.0, detail: "Using cached Windows ISO")
                } else {
                    try? FileManager.default.removeItem(at: dest)
                    try await downloadWithProgress(
                        from: iso.url, to: dest,
                        totalBytes: iso.bytes, sourceLabel: "Microsoft CDN"
                    ) { [weak self] f, d in
                        self?.phase = .downloadingISO(progress: f, detail: d)
                    }
                }
                baseISOPath = dest.path
            }

            // ── 2: VirtIO drivers ─────────────────────────────────────────────────
            let virtioDest = virtioDir.appendingPathComponent("virtio-win.iso")
            phase = .downloadingVirtIO(progress: 0, detail: "Downloading VirtIO drivers...")
            let virtioURL = try await mgr.downloadVirtioISOToURLWithProgress(virtioDest) { [weak self] p in
                self?.phase = .downloadingVirtIO(
                    progress: p,
                    detail: "Downloading VirtIO drivers... \(Int(p * 100))%"
                )
            }

            // ── 3: Build FAT32 unattend image (autounattend.xml + NetKVM) ───────────
            // macOS cannot mount ISO9660/UDF read-write — the kernel FS drivers are
            // read-only by design, regardless of image format or hdiutil flags.
            // FAT32 images mount read-write natively. Windows Setup scans ALL attached
            // drives for autounattend.xml at startup, not just the boot drive.
            // This is how Parallels and VMware Fusion handle unattended installs.
            phase = .injectingISO(detail: "Generating autounattend.xml...")
            let xml = AutounattendGenerator.xml(
                computerName: computerName,
                username:     windowsUsername
            )
            let unattendImagePath = isoDir.appendingPathComponent("corevisor-unattend.img").path
            try await UnattendImageBuilder.build(
                destImage:   unattendImagePath,
                unattendXML: xml,
                virtioISO:   virtioURL.path
            ) { [weak self] detail in
                self?.phase = .injectingISO(detail: detail)
            }

            // ── 4: Create VM ──────────────────────────────────────────────────────
            phase = .creatingDisk
            var draft = CoreVisorDraft()
            draft.name                 = vmName
            draft.guest                = .windows
            draft.backend              = .qemu
            draft.cpuCores             = cpuCores
            draft.memoryGB             = memoryGB
            draft.diskGB               = diskGB
            draft.enableSound          = false
            draft.isoPath              = baseISOPath       // original untouched Windows ISO
            draft.virtioDriversISOPath = virtioURL.path
            draft.useVirtioStorage     = false
            draft.enableTPM            = swtpmAvailable
            draft.enableVirtioGPU      = false
            let machine = try await mgr.createMachinePublic(from: draft)

            // Store the unattend image in the VM bundle so CoreVisorManager
            // auto-attaches it on first boot as a usb-storage device.
            let bundleUnattend = URL(fileURLWithPath: machine.bundlePath)
                .appendingPathComponent("unattend.img")
            if FileManager.default.fileExists(atPath: bundleUnattend.path) {
                try? FileManager.default.removeItem(at: bundleUnattend)
            }
            try FileManager.default.copyItem(
                at:  URL(fileURLWithPath: unattendImagePath),
                to:  bundleUnattend
            )
            // ── 5: TPM ────────────────────────────────────────────────────────────
            if machine.enableTPM {
                phase = .initializingTPM
                try await initTPM(for: machine)
            }

            // ── 6: Launch ─────────────────────────────────────────────────────────
            phase = .preparingLaunch
            try? await Task.sleep(nanoseconds: 400_000_000)
            phase = .done(machine: machine)

        } catch is CancellationError {
            phase = .idle
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    // MARK: - TPM

    func initTPM(for machine: CoreVisorMachine) async throws {
        let seed: Data
        if let existing = TPMKeychainStore.load(for: machine.id) {
            seed = existing
        } else {
            var raw = [UInt8](repeating: 0, count: 32)
            guard SecRandomCopyBytes(kSecRandomDefault, raw.count, &raw) == errSecSuccess else {
                throw NSError(domain: "TPM", code: 4,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to generate random TPM seed"])
            }
            seed = Data(raw)
            _ = TPMKeychainStore.save(seed: seed, for: machine.id)
        }
        try await Task.detached(priority: .userInitiated) {
            try SwtpmController.initStateDirectory(bundlePath: machine.bundlePath, seed: seed)
        }.value
    }

    // MARK: - Download helper

    private func downloadWithProgress(
        from url: URL, to dest: URL,
        totalBytes: Int, sourceLabel: String,
        onProgress: @escaping (Double, String) -> Void
    ) async throws {
        let tmpDest   = dest.deletingLastPathComponent()
            .appendingPathComponent(dest.lastPathComponent + ".download")
        let urlString = url.absoluteString

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        p.arguments = [
            "-L", "-C", "-",
            "--retry", "5", "--retry-delay", "3", "--retry-all-errors",
            "-o", tmpDest.path,
            "--no-progress-meter",
            "-w", "%{http_code}\n%{size_download}\n",
            "-k",
            "-A", "Windows-Update-Agent/10.0.10011.16384 Client-Protocol/2.31",
            urlString
        ]

        let outPipe = Pipe(); let errPipe = Pipe()
        p.standardOutput = outPipe; p.standardError = errPipe

        let progressTask = Task.detached(priority: .utility) {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                let recv = (try? FileManager.default
                    .attributesOfItem(atPath: tmpDest.path)[.size] as? Int64) ?? 0
                let frac  = totalBytes > 0 ? min(Double(recv) / Double(totalBytes), 0.99) : 0
                let label = "Downloading from \(sourceLabel)... \(Self.fmtBytes(recv))"
                          + (totalBytes > 0 ? " / \(Self.fmtBytes(Int64(totalBytes)))" : "")
                await MainActor.run { onProgress(frac, label) }
            }
        }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            p.terminationHandler = { proc in
                progressTask.cancel()
                let exitCode  = proc.terminationStatus
                let stdout    = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(),
                                      encoding: .utf8) ?? ""
                let lines     = stdout.components(separatedBy: "\n").filter { !$0.isEmpty }
                let httpCode  = Int(lines.dropLast().last ?? "") ?? 0
                let recvBytes = Int64(lines.last ?? "") ?? 0

                if exitCode != 0 {
                    let msg = (String(data: errPipe.fileHandleForReading.readDataToEndOfFile(),
                                     encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    cont.resume(throwing: NSError(domain: "download", code: Int(exitCode), userInfo: [
                        NSLocalizedDescriptionKey: "curl failed (exit \(exitCode)): \(msg.prefix(300))"
                    ])); return
                }
                if httpCode != 0 && httpCode != 200 {
                    try? FileManager.default.removeItem(at: tmpDest)
                    cont.resume(throwing: NSError(domain: "download", code: httpCode, userInfo: [
                        NSLocalizedDescriptionKey: "CDN returned HTTP \(httpCode)"
                    ])); return
                }
                if totalBytes > 100_000_000 {
                    let actual = recvBytes > 0 ? recvBytes
                        : ((try? FileManager.default.attributesOfItem(
                              atPath: tmpDest.path)[.size] as? Int64) ?? 0)
                    if actual < Int64(Double(totalBytes) * 0.95) {
                        cont.resume(throwing: NSError(domain: "download", code: 2, userInfo: [
                            NSLocalizedDescriptionKey:
                                "Download incomplete: received \(actual / 1_048_576) MB, " +
                                "expected ~\(totalBytes / 1_048_576) MB. Press Retry to resume."
                        ])); return
                    }
                }
                do {
                    if FileManager.default.fileExists(atPath: dest.path) {
                        try FileManager.default.removeItem(at: dest)
                    }
                    try FileManager.default.moveItem(at: tmpDest, to: dest)
                    cont.resume()
                } catch { cont.resume(throwing: error) }
            }
            do { try p.run() } catch { progressTask.cancel(); cont.resume(throwing: error) }
        }
    }

    nonisolated private static func fmtBytes(_ b: Int64) -> String {
        if b >= 1_073_741_824 { return String(format: "%.1f GB", Double(b) / 1_073_741_824) }
        if b >= 1_048_576     { return String(format: "%.0f MB", Double(b) / 1_048_576) }
        return "\(b) B"
    }

    @discardableResult
    nonisolated private static func runQuiet(_ binary: String, _ args: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: binary)
        p.arguments = args
        p.standardOutput = Pipe()
        p.standardError = Pipe()
        do {
            try p.run()
        } catch {
            return -1
        }
        p.waitUntilExit()
        return p.terminationStatus
    }

}

