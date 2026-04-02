import Foundation
import Combine
import Security
import AppKit
import ServiceManagement

// MARK: - SMC Helper Manager
//
// Manages execution of the privileged smc-helper binary that writes fan
// target speeds to the Apple System Management Controller (SMC).
//
// Preferred execution path:
//   1. Connect to a privileged Mach service installed via SMJobBless.
// Debug fallback:
//   2. Run a locally-built helper binary directly for Xcode development.

@MainActor
final class SMCHelperManager: ObservableObject {

    static let shared = SMCHelperManager()

    @Published private(set) var isInstalled: Bool = false
    @Published var statusMessage: String?

    // Bundle identifier of the helper used for the privileged-helper path
    private let helperLabel = "ventaphobia.smc-helper"
    private var hasAttemptedBlessInstall = false

    private let fileManager = FileManager.default

    private init() {
        refreshStatus()
    }

    // MARK: - Candidate Paths

    /// All candidate paths in priority order.
    private var helperCandidates: [String] {
        var candidates: [String] = []

        // 1. Production privileged-helper location (SMCHelperManager primary)
        candidates.append("/Library/PrivilegedHelperTools/\(helperLabel)")

#if DEBUG
        // 2. Derived-data build directory (Xcode debug builds)
        let derivedHelper = URL(fileURLWithPath: Bundle.main.bundlePath)
            .deletingLastPathComponent()
            .appendingPathComponent("smc-helper")
            .path
        candidates.append(derivedHelper)

        // 3. Workspace-relative build product
        let workspaceHelper = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Core-Monitor/Products/smc-helper")
            .path
        candidates.append(workspaceHelper)
#endif
        return candidates
    }

    // MARK: - Status

    func refreshStatus() {
        isInstalled = helperCandidates.contains { path in
            fileManager.fileExists(atPath: path)
        }
        if isInstalled,
           statusMessage == "Fan write access unavailable: no installed helper found." {
            statusMessage = nil
        }
    }

    // MARK: - Execute

    func ensureInstalledIfNeeded() -> Bool {
        refreshStatus()
        let installedPath = "/Library/PrivilegedHelperTools/\(helperLabel)"
        guard !fileManager.fileExists(atPath: installedPath) else { return true }
        guard !hasAttemptedBlessInstall else { return false }

        hasAttemptedBlessInstall = true
        let didInstall = attemptPrivilegedInstall()
        refreshStatus()
        if didInstall && fileManager.fileExists(atPath: installedPath) {
            hasAttemptedBlessInstall = false
            return true
        }
        return false
    }

    /// Executes the helper with the given arguments.
    /// Returns true on success.
    func execute(arguments: [String]) -> Bool {
        refreshStatus()

        if executeViaBlessedXPC(arguments: arguments) {
            return true
        }

#if DEBUG
        if !fileManager.fileExists(atPath: "/Library/PrivilegedHelperTools/\(helperLabel)"),
           let helperURL = helperCandidates.dropFirst().compactMap({ validatedHelperURL(atPath: $0) }).first,
           runDirect(helperURL: helperURL, arguments: arguments) {
            return true
        }
#endif

        if !fileManager.fileExists(atPath: "/Library/PrivilegedHelperTools/\(helperLabel)") {
            statusMessage = "Fan write access unavailable: privileged helper not installed."
        } else {
            statusMessage = "Fan write access unavailable: could not connect to privileged helper."
        }
        return false
    }

    func readValue(key: String) -> Double? {
        refreshStatus()

        let installedPath = "/Library/PrivilegedHelperTools/\(helperLabel)"
        if !fileManager.fileExists(atPath: installedPath), !ensureInstalledIfNeeded() {
            return nil
        }

        let connection = NSXPCConnection(machServiceName: helperLabel, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: SMCHelperXPCProtocol.self)

        var remoteValue: Double?
        var remoteError: String?
        let semaphore = DispatchSemaphore(value: 0)

        connection.invalidationHandler = {
            semaphore.signal()
        }
        connection.interruptionHandler = {
            semaphore.signal()
        }
        connection.resume()

        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
            remoteError = error.localizedDescription
            semaphore.signal()
        }) as? SMCHelperXPCProtocol else {
            connection.invalidate()
            statusMessage = "Failed to create helper connection."
            return nil
        }

        proxy.readValue(key) { value, errorMessage in
            remoteValue = value?.doubleValue
            remoteError = errorMessage as String?
            semaphore.signal()
        }

        let waitResult = semaphore.wait(timeout: .now() + 5)
        connection.invalidate()

        if waitResult == .timedOut {
            statusMessage = "Timed out while waiting for privileged helper."
            return nil
        }

        if let remoteError {
            statusMessage = remoteError
            return nil
        }

        statusMessage = nil
        return remoteValue
    }

    // MARK: - Execution Strategies

    private func attemptPrivilegedInstall() -> Bool {
        var didInstall = false
        var installMessage: String?
        installBundledHelper { success, message in
            didInstall = success
            installMessage = message
        }
        if !didInstall, let installMessage {
            statusMessage = installMessage
        }
        return didInstall
    }

    private func executeViaBlessedXPC(arguments: [String]) -> Bool {
        guard !arguments.isEmpty else {
            statusMessage = "Helper command missing."
            return false
        }

        let connection = NSXPCConnection(machServiceName: helperLabel, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: SMCHelperXPCProtocol.self)

        var remoteError: String?
        let semaphore = DispatchSemaphore(value: 0)

        connection.invalidationHandler = {
            semaphore.signal()
        }
        connection.interruptionHandler = {
            semaphore.signal()
        }
        connection.resume()

        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
            remoteError = error.localizedDescription
            semaphore.signal()
        }) as? SMCHelperXPCProtocol else {
            connection.invalidate()
            statusMessage = "Failed to create helper connection."
            return false
        }

        switch arguments[0] {
        case "set":
            guard arguments.count == 3,
                  let fanID = Int(arguments[1]),
                  let rpm = Int(arguments[2]) else {
                connection.invalidate()
                statusMessage = "Invalid helper arguments."
                return false
            }
            proxy.setFanManual(fanID, rpm: rpm) { errorMessage in
                remoteError = errorMessage as String?
                semaphore.signal()
            }

        case "auto":
            guard arguments.count == 2,
                  let fanID = Int(arguments[1]) else {
                connection.invalidate()
                statusMessage = "Invalid helper arguments."
                return false
            }
            proxy.setFanAuto(fanID) { errorMessage in
                remoteError = errorMessage as String?
                semaphore.signal()
            }

        case "read":
            guard arguments.count == 2 else {
                connection.invalidate()
                statusMessage = "Invalid helper arguments."
                return false
            }
            proxy.readValue(arguments[1]) { _, errorMessage in
                remoteError = errorMessage as String?
                semaphore.signal()
            }

        default:
            connection.invalidate()
            statusMessage = "Unknown helper command."
            return false
        }

        let waitResult = semaphore.wait(timeout: .now() + 5)
        connection.invalidate()

        if waitResult == .timedOut {
            statusMessage = "Timed out while waiting for privileged helper."
            return false
        }

        if let remoteError {
            statusMessage = remoteError
            return false
        }

        statusMessage = nil
        return true
    }

    private func runDirect(helperURL: URL, arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = helperURL
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError  = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                statusMessage = nil
                return true
            }
        } catch {
            // binary may need root; fall through to sudo strategies
        }
        return false
    }

    // MARK: - Helper Installation

    func installBundledHelper(completion: @escaping (Bool, String?) -> Void) {
        var authRef: AuthorizationRef?
        let authStatus = AuthorizationCreate(nil, nil, [], &authRef)
        guard authStatus == errAuthorizationSuccess, let authRef else {
            completion(false, "Failed to create authorization reference.")
            return
        }

        let flags: AuthorizationFlags = [.interactionAllowed, .extendRights, .preAuthorize]
        let copyStatus: OSStatus = kSMRightBlessPrivilegedHelper.withCString { rightName in
            var items = [AuthorizationItem(name: rightName, valueLength: 0, value: nil, flags: 0)]
            return items.withUnsafeMutableBufferPointer { buffer in
                var rights = AuthorizationRights(count: 1, items: buffer.baseAddress)
                return AuthorizationCopyRights(authRef, &rights, nil, flags, nil)
            }
        }
        guard copyStatus == errAuthorizationSuccess else {
            completion(false, "Authorization was denied.")
            return
        }

        var blessError: Unmanaged<CFError>?
        let blessed = SMJobBless(kSMDomainSystemLaunchd, helperLabel as CFString, authRef, &blessError)
        if blessed {
            refreshStatus()
            completion(true, nil)
        } else {
            let message = (blessError?.takeRetainedValue().localizedDescription) ?? "SMJobBless failed."
            completion(false, message)
        }
    }

    // MARK: - Path Validation

    private func validatedHelperURL(atPath path: String) -> URL? {
        let url = URL(fileURLWithPath: path).standardizedFileURL

        guard isPathAllowed(url) else { return nil }

        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
              values.isRegularFile == true,
              values.isSymbolicLink != true else { return nil }

        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path) else {
            return nil
        }

        guard isOwnershipValid(for: url, attributes: attributes),
              isPermissionsValid(attributes: attributes),
              isCodeSignatureValid(for: url) else { return nil }

        return url
    }

    private func isPathAllowed(_ url: URL) -> Bool {
        let privilegedHelper = "/Library/PrivilegedHelperTools/\(helperLabel)"
        if url.path == privilegedHelper { return true }

#if DEBUG
        let derivedHelper = URL(fileURLWithPath: Bundle.main.bundlePath)
            .deletingLastPathComponent()
            .appendingPathComponent("smc-helper")
            .standardizedFileURL
        let workspaceHelper = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Core-Monitor/Products/smc-helper")
            .standardizedFileURL
        if url == derivedHelper || url == workspaceHelper { return true }
#endif
        return false
    }

    private func isOwnershipValid(for url: URL, attributes: [FileAttributeKey: Any]) -> Bool {
        guard let owner = attributes[.ownerAccountID] as? NSNumber else { return false }

#if DEBUG
        // In debug, allow binaries owned by the current user (built locally)
        if url.path != "/Library/PrivilegedHelperTools/\(helperLabel)" {
            return owner.uint32Value == getuid() || owner.uint32Value == 0
        }
#endif
        // Production: must be root-owned
        return owner.uint32Value == 0
    }

    private func isPermissionsValid(attributes: [FileAttributeKey: Any]) -> Bool {
        guard let permissions = attributes[.posixPermissions] as? NSNumber else { return false }
        let mode = permissions.uint16Value
        // Reject world-writable or group-writable bits
        return (mode & 0o022) == 0
    }

    private func isCodeSignatureValid(for url: URL) -> Bool {
#if DEBUG
        // Skip signature check for locally-built debug helpers
        if url.path != "/Library/PrivilegedHelperTools/\(helperLabel)" {
            return true
        }
#endif
        var staticCode: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode)
        guard createStatus == errSecSuccess, let code = staticCode else { return false }
        return SecStaticCodeCheckValidity(code, [], nil) == errSecSuccess
    }
}
