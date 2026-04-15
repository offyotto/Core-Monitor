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

    enum ConnectionState: Equatable {
        case missing
        case unknown
        case checking
        case reachable
        case unreachable
    }

    static let shared = SMCHelperManager()

    @Published private(set) var isInstalled: Bool = false
    @Published private(set) var connectionState: ConnectionState = .missing
    @Published var statusMessage: String?

    // Bundle identifier of the helper used for the privileged-helper path
    private let helperLabel = HelperConfiguration.label
    private var hasAttemptedBlessInstall = false

    private let fileManager = FileManager.default
    private var diagnosticsTask: Task<Void, Never>?

    private init() {
        refreshStatus()
    }

    private var installedHelperPath: String {
        "/Library/PrivilegedHelperTools/\(helperLabel)"
    }

    // MARK: - Status

    func refreshStatus() {
        isInstalled = fileManager.fileExists(atPath: installedHelperPath)
        if isInstalled == false {
            diagnosticsTask?.cancel()
            diagnosticsTask = nil
            connectionState = .missing
            if statusMessage == "Fan write access unavailable: privileged helper not installed." {
                statusMessage = nil
            }
            return
        }

        if connectionState == .missing {
            connectionState = .unknown
        }

        if statusMessage == "Fan write access unavailable: privileged helper not installed." {
            statusMessage = nil
        }
    }

    func refreshDiagnostics() {
        refreshStatus()
        guard isInstalled else { return }

        diagnosticsTask?.cancel()
        connectionState = .checking

        let helperLabel = helperLabel
        diagnosticsTask = Task.detached(priority: .utility) {
            let outcome = Self.probeConnection(label: helperLabel)
            guard Task.isCancelled == false else { return }

            await MainActor.run {
                SMCHelperManager.shared.applyProbeOutcome(outcome)
            }
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
            refreshDiagnostics()
            return true
        }
        return false
    }

    /// Executes the helper with the given arguments.
    /// Returns true on success.
    func execute(arguments: [String]) -> Bool {
        execute(arguments: arguments, allowInstall: true, timeout: 5)
    }

    func executeIfInstalled(arguments: [String], timeout: TimeInterval = 5) -> Bool {
        execute(arguments: arguments, allowInstall: false, timeout: timeout)
    }

    private func execute(arguments: [String], allowInstall: Bool, timeout: TimeInterval) -> Bool {
        refreshStatus()

        if allowInstall {
            guard fileManager.fileExists(atPath: installedHelperPath) || ensureInstalledIfNeeded() else {
                connectionState = .missing
                statusMessage = "Fan write access unavailable: privileged helper not installed."
                return false
            }
        } else {
            guard fileManager.fileExists(atPath: installedHelperPath) else {
                connectionState = .missing
                return false
            }
        }

        return executeViaBlessedXPC(arguments: arguments, timeout: timeout)
    }

    func readValue(key: String) -> Double? {
        refreshStatus()

        if !fileManager.fileExists(atPath: installedHelperPath), !ensureInstalledIfNeeded() {
            connectionState = .missing
            return nil
        }

        switch withHelperConnection(timeout: 5, perform: { proxy, finish in
            proxy.readValue(key) { value, errorMessage in
                finish(value?.doubleValue, errorMessage as String?)
            }
        }) {
        case .success(let value):
            statusMessage = nil
            connectionState = .reachable
            return value
        case .failure(let message):
            statusMessage = message
            connectionState = .unreachable
            return nil
        }
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

    private func executeViaBlessedXPC(arguments: [String], timeout: TimeInterval) -> Bool {
        guard !arguments.isEmpty else {
            statusMessage = "Helper command missing."
            return false
        }

        let result: ConnectionResult<Bool>

        switch arguments[0] {
        case "set":
            guard arguments.count == 3,
                  let fanID = Int(arguments[1]),
                  let rpm = Int(arguments[2]) else {
                statusMessage = "Invalid helper arguments."
                return false
            }
            result = withHelperConnection(timeout: timeout) { proxy, finish in
                proxy.setFanManual(fanID, rpm: rpm) { errorMessage in
                    finish(true, errorMessage as String?)
                }
            }

        case "auto":
            guard arguments.count == 2,
                  let fanID = Int(arguments[1]) else {
                statusMessage = "Invalid helper arguments."
                return false
            }
            result = withHelperConnection(timeout: timeout) { proxy, finish in
                proxy.setFanAuto(fanID) { errorMessage in
                    finish(true, errorMessage as String?)
                }
            }

        case "read":
            guard arguments.count == 2 else {
                statusMessage = "Invalid helper arguments."
                return false
            }
            result = withHelperConnection(timeout: timeout) { proxy, finish in
                proxy.readValue(arguments[1]) { _, errorMessage in
                    finish(true, errorMessage as String?)
                }
            }

        default:
            statusMessage = "Unknown helper command."
            return false
        }

        switch result {
        case .success:
            statusMessage = nil
            connectionState = .reachable
            return true
        case .failure(let message):
            statusMessage = message
            connectionState = .unreachable
            return false
        }
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
            refreshDiagnostics()
            completion(true, nil)
        } else {
            let message = (blessError?.takeRetainedValue().localizedDescription) ?? "SMJobBless failed."
            completion(false, message)
        }
    }

    func installFromApp() {
        installBundledHelper { [weak self] success, message in
            guard let self else { return }
            if success {
                hasAttemptedBlessInstall = false
                refreshStatus()
                statusMessage = "Privileged helper installed. Fan control is ready."
                refreshDiagnostics()
            } else {
                refreshStatus()
                statusMessage = message ?? "Failed to install privileged helper."
            }
        }
    }

    // MARK: - Diagnostics

    private enum ProbeOutcome {
        case reachable
        case failure(String)
    }

    private enum ConnectionResult<Value> {
        case success(Value)
        case failure(String)
    }

    private func applyProbeOutcome(_ outcome: ProbeOutcome) {
        switch outcome {
        case .reachable:
            connectionState = .reachable
            if statusMessage == "Privileged helper installed. Fan control is ready."
                || statusMessage?.localizedCaseInsensitiveContains("privileged helper") == true {
                statusMessage = nil
            }

        case .failure(let message):
            connectionState = .unreachable
            if statusMessage == nil || statusMessage?.localizedCaseInsensitiveContains("helper") == true {
                statusMessage = message
            }
        }
    }

    private func withHelperConnection<Value>(
        timeout: TimeInterval,
        perform: (SMCHelperXPCProtocol, @escaping (Value?, String?) -> Void) -> Void
    ) -> ConnectionResult<Value> {
        let connection = NSXPCConnection(machServiceName: helperLabel, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: SMCHelperXPCProtocol.self)

        var remoteValue: Value?
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
            return .failure("Failed to create helper connection.")
        }

        perform(proxy) { value, errorMessage in
            remoteValue = value
            remoteError = errorMessage
            semaphore.signal()
        }

        let waitResult = semaphore.wait(timeout: .now() + timeout)
        connection.invalidate()

        if waitResult == .timedOut {
            return .failure("Timed out while waiting for privileged helper.")
        }

        if let remoteError {
            return .failure(Self.decorateConnectionFailure(remoteError))
        }

        guard let remoteValue else {
            return .failure(Self.decorateConnectionFailure(nil))
        }

        return .success(remoteValue)
    }

    private nonisolated static func probeConnection(label: String) -> ProbeOutcome {
        let connection = NSXPCConnection(machServiceName: label, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: SMCHelperXPCProtocol.self)

        var remoteError: String?
        var didReceiveReply = false
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
            return .failure("Failed to create helper connection.")
        }

        proxy.readValue("FNum") { _, errorMessage in
            didReceiveReply = true
            remoteError = errorMessage as String?
            semaphore.signal()
        }

        let waitResult = semaphore.wait(timeout: .now() + 1.5)
        connection.invalidate()

        if waitResult == .timedOut {
            return .failure("Timed out while waiting for privileged helper.")
        }

        if didReceiveReply {
            return .reachable
        }

        if let remoteError {
            return .failure(Self.decorateConnectionFailure(remoteError))
        }

        return .failure(Self.decorateConnectionFailure(nil))
    }

    private nonisolated static func decorateConnectionFailure(_ rawMessage: String?) -> String {
        if let signingIssue = currentAppSigningIssue() {
            return signingIssue
        }

        let trimmed = rawMessage?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard trimmed.isEmpty == false else {
            return "Fan write access unavailable: could not connect to privileged helper."
        }

        return trimmed
    }

    private nonisolated static func currentAppSigningIssue() -> String? {
        var staticCode: SecStaticCode?
        let status = SecStaticCodeCreateWithPath(Bundle.main.bundleURL as CFURL, SecCSFlags(), &staticCode)
        guard status == errSecSuccess, let staticCode else {
            return nil
        }

        var signingInfoRef: CFDictionary?
        let infoStatus = SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &signingInfoRef
        )
        guard infoStatus == errSecSuccess,
              let signingInfo = signingInfoRef as? [String: Any] else {
            return nil
        }

        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "unknown"
        let signedIdentifier = signingInfo[kSecCodeInfoIdentifier as String] as? String
        let teamIdentifier = signingInfo[kSecCodeInfoTeamIdentifier as String] as? String

        if teamIdentifier?.isEmpty != false {
            return "Fan write access unavailable: this Core Monitor build is ad-hoc signed, so the installed privileged helper will reject it. Run the signed app bundle or reinstall the helper from a matching signed build."
        }

        if let signedIdentifier, signedIdentifier != bundleIdentifier {
            return "Fan write access unavailable: app signature identifier \(signedIdentifier) does not match bundle identifier \(bundleIdentifier). Rebuild and reinstall the helper from the same signed app."
        }

        return nil
    }
}
