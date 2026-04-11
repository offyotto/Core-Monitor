import Foundation
import Combine
import Security
import ServiceManagement

// MARK: - SMC Helper Manager
//
// Manages execution of the privileged smc-helper binary that writes fan
// target speeds to the Apple System Management Controller (SMC).
//
// Preferred execution path:
//   1. Connect to a privileged Mach service installed via SMJobBless.

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

    private var installedHelperPath: String {
        "/Library/PrivilegedHelperTools/\(helperLabel)"
    }

    // MARK: - Status

    func refreshStatus() {
        isInstalled = fileManager.fileExists(atPath: installedHelperPath)
        if isInstalled,
           statusMessage == "Fan write access unavailable: no installed helper found." {
            statusMessage = nil
        }
    }

    // MARK: - Execute

    func ensureInstalledIfNeeded() -> Bool {
        refreshStatus()
        guard !fileManager.fileExists(atPath: installedHelperPath) else { return true }
        guard !hasAttemptedBlessInstall else { return false }

        hasAttemptedBlessInstall = true
        let didInstall = attemptPrivilegedInstall()
        refreshStatus()
        if didInstall && fileManager.fileExists(atPath: installedHelperPath) {
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

        if !fileManager.fileExists(atPath: installedHelperPath) {
            statusMessage = "Fan write access unavailable: privileged helper not installed."
        } else {
            statusMessage = "Fan write access unavailable: could not connect to privileged helper."
        }
        return false
    }

    func readValue(key: String) -> Double? {
        refreshStatus()

        if !fileManager.fileExists(atPath: installedHelperPath), !ensureInstalledIfNeeded() {
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

    // MARK: - Helper Installation

    func installBundledHelper(completion: @escaping (Bool, String?) -> Void) {
        let flags: AuthorizationFlags = [.interactionAllowed, .extendRights, .preAuthorize]

        var authRef: AuthorizationRef?
        let authStatus: OSStatus = kSMRightBlessPrivilegedHelper.withCString { rightName in
            var authItem = AuthorizationItem(name: rightName, valueLength: 0, value: nil, flags: 0)
            return withUnsafeMutablePointer(to: &authItem) { itemPointer in
                var authRights = AuthorizationRights(count: 1, items: itemPointer)
                return AuthorizationCreate(&authRights, nil, flags, &authRef)
            }
        }

        guard authStatus == errAuthorizationSuccess, let authRef else {
            completion(false, "Failed to create authorization reference.")
            return
        }
        defer { AuthorizationFree(authRef, []) }

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
}
