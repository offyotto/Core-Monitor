import AppKit
import Foundation
import Combine
import Security
import ServiceManagement
import Darwin

// MARK: - SMC Helper Manager
//
// Manages execution of the privileged smc-helper binary that writes fan
// target speeds to the Apple System Management Controller (SMC).
//
// Preferred execution path:
//   1. Connect to a privileged Mach service installed via SMJobBless.

@MainActor
final class SMCHelperManager: ObservableObject {
    struct ControlMetadata: Equatable {
        let modeKeyFormat: String
        let forceTestAvailable: Bool
    }

    private static let missingInstallMessage = "Fan write access unavailable: privileged helper not installed."
    private static let incompleteInstallMessage = "Fan write access unavailable: the privileged helper install is incomplete or stale. Repair it from this app build."

    private enum LegacyServiceManagementBridge {
        typealias JobRemoveFunction = @convention(c) (
            CFString,
            CFString,
            AuthorizationRef,
            Bool,
            UnsafeMutablePointer<Unmanaged<CFError>?>?
        ) -> Bool

        typealias JobBlessFunction = @convention(c) (
            CFString,
            CFString,
            AuthorizationRef,
            UnsafeMutablePointer<Unmanaged<CFError>?>?
        ) -> Bool

        static let launchdErrorDomain = "CFErrorDomainLaunchd"

        private static let serviceManagementHandle: UnsafeMutableRawPointer? = {
            dlopen("/System/Library/Frameworks/ServiceManagement.framework/ServiceManagement", RTLD_NOW)
        }()

        private static func resolve<Function>(_ symbolName: String, as type: Function.Type) -> Function? {
            guard let serviceManagementHandle,
                  let symbol = dlsym(serviceManagementHandle, symbolName) else {
                return nil
            }
            return unsafeBitCast(symbol, to: type)
        }

        static func jobRemove(
            domain: CFString,
            jobLabel: CFString,
            auth: AuthorizationRef,
            wait: Bool,
            outError: UnsafeMutablePointer<Unmanaged<CFError>?>?
        ) -> Bool {
            guard let function = resolve("SMJobRemove", as: JobRemoveFunction.self) else {
                outError?.pointee = nil
                return false
            }
            return function(domain, jobLabel, auth, wait, outError)
        }

        static func jobBless(
            domain: CFString,
            executableLabel: CFString,
            auth: AuthorizationRef,
            outError: UnsafeMutablePointer<Unmanaged<CFError>?>?
        ) -> Bool {
            guard let function = resolve("SMJobBless", as: JobBlessFunction.self) else {
                outError?.pointee = nil
                return false
            }
            return function(domain, executableLabel, auth, outError)
        }
    }

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

    private var installedLaunchDaemonPath: String {
        "/Library/LaunchDaemons/\(helperLabel).plist"
    }

    // MARK: - Status

    func refreshStatus() {
        let helperExists = fileManager.fileExists(atPath: installedHelperPath)
        let launchDaemonExists = fileManager.fileExists(atPath: installedLaunchDaemonPath)
        let installNeedsRepair: Bool

        if helperExists || launchDaemonExists {
            installNeedsRepair = helperExists != launchDaemonExists || helperInstallationLooksOrphaned()
        } else {
            installNeedsRepair = false
        }

        isInstalled = helperExists
        if helperExists == false {
            diagnosticsTask?.cancel()
            diagnosticsTask = nil
            connectionState = installNeedsRepair ? .unreachable : .missing
            if installNeedsRepair {
                if statusMessage == nil
                    || statusMessage == Self.missingInstallMessage
                    || statusMessage == Self.incompleteInstallMessage
                {
                    statusMessage = Self.incompleteInstallMessage
                }
            } else if statusMessage == Self.missingInstallMessage || statusMessage == Self.incompleteInstallMessage {
                statusMessage = nil
            }
            return
        }

        if connectionState == .missing {
            connectionState = .unknown
        }

        if statusMessage == Self.missingInstallMessage || statusMessage == Self.incompleteInstallMessage {
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
        let helperExists = fileManager.fileExists(atPath: installedHelperPath)

        if helperExists, connectionState != .unreachable {
            return true
        }

        guard !hasAttemptedBlessInstall else {
            return helperExists && connectionState == .reachable
        }

        hasAttemptedBlessInstall = true
        let didInstall = attemptPrivilegedInstall(forceReinstall: connectionState == .unreachable)
        refreshStatus()
        if didInstall && fileManager.fileExists(atPath: installedHelperPath) {
            hasAttemptedBlessInstall = false
            refreshDiagnostics()
            return true
        }
        return helperExists && connectionState == .reachable
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
                statusMessage = Self.missingInstallMessage
                return false
            }
        } else {
            guard fileManager.fileExists(atPath: installedHelperPath) else {
                connectionState = .missing
                return false
            }
        }

        let didExecute = executeViaBlessedXPC(arguments: arguments, timeout: timeout)
        guard didExecute == false, allowInstall, shouldAttemptHelperRepair(afterFailureMessage: statusMessage) else {
            return didExecute
        }

        guard attemptRepairingStaleHelper() else {
            return false
        }

        return executeViaBlessedXPC(arguments: arguments, timeout: timeout)
    }

    func readValue(key: String) -> Double? {
        refreshStatus()

        guard fileManager.fileExists(atPath: installedHelperPath) else {
            connectionState = .missing
            return nil
        }

        let result = readValueViaHelper(key: key, timeout: 5)
        switch result {
        case .success(let value):
            statusMessage = nil
            connectionState = .reachable
            return value
        case .failure(let message):
            statusMessage = message
            connectionState = .unreachable

            guard shouldAttemptHelperRepair(afterFailureMessage: message), attemptRepairingStaleHelper() else {
                return nil
            }

            switch readValueViaHelper(key: key, timeout: 5) {
            case .success(let value):
                statusMessage = nil
                connectionState = .reachable
                return value
            case .failure(let retryMessage):
                statusMessage = retryMessage
                connectionState = .unreachable
                return nil
            }
        }
    }

    func readControlMetadata(timeout: TimeInterval = 1.0) -> ControlMetadata? {
        refreshStatus()

        guard fileManager.fileExists(atPath: installedHelperPath) else {
            return nil
        }

        let result: ConnectionResult<ControlMetadata> = withHelperConnection(timeout: timeout) { proxy, finish in
            proxy.readControlMetadata { modeKeyFormat, forceTestAvailable, errorMessage in
                guard let modeKeyFormat else {
                    finish(nil, errorMessage as String?)
                    return
                }

                finish(
                    ControlMetadata(
                        modeKeyFormat: modeKeyFormat as String,
                        forceTestAvailable: forceTestAvailable?.boolValue ?? false
                    ),
                    errorMessage as String?
                )
            }
        }

        switch result {
        case .success(let metadata):
            return metadata
        case .failure:
            return nil
        }
    }

    // MARK: - Execution Strategies

    private func attemptPrivilegedInstall(forceReinstall: Bool = false) -> Bool {
        var didInstall = false
        var installMessage: String?
        installBundledHelper(forceReinstall: forceReinstall) { success, message in
            didInstall = success
            installMessage = message
        }
        if !didInstall, let installMessage {
            statusMessage = installMessage
        }
        return didInstall
    }

    private func attemptRepairingStaleHelper() -> Bool {
        refreshStatus()
        guard fileManager.fileExists(atPath: installedHelperPath)
                || fileManager.fileExists(atPath: installedLaunchDaemonPath) else {
            return false
        }

        let didRepair = attemptPrivilegedInstall(forceReinstall: true)
        refreshStatus()
        if didRepair {
            hasAttemptedBlessInstall = false
            refreshDiagnostics()
        }
        return didRepair
    }

    private func shouldAttemptHelperRepair(afterFailureMessage message: String?) -> Bool {
        let normalized = message?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        guard normalized.isEmpty == false else { return false }

        if normalized.contains("ad-hoc signed")
            || normalized.contains("bundle identifier")
            || normalized.contains("does not match")
        {
            return false
        }

        if normalized.contains("launchd error 4")
            || normalized.contains("could not connect to privileged helper")
            || normalized.contains("timed out while waiting for privileged helper")
            || normalized.contains("failed to create helper connection")
            || normalized.contains("rejected this app build")
            || normalized.contains("rejected or could not reach this app build")
            || normalized.contains("could not reach this app build")
        {
            return true
        }

        return false
    }

    private func helperInstallationLooksOrphaned() -> Bool {
        let installedHelperExists = fileManager.fileExists(atPath: installedHelperPath)
        let installedLaunchDaemonExists = fileManager.fileExists(atPath: installedLaunchDaemonPath)

        guard installedHelperExists || installedLaunchDaemonExists else {
            return false
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["print", "system/\(helperLabel)"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return false
        }

        return Self.helperInstallAppearsOrphaned(
            installedHelperExists: installedHelperExists,
            installedLaunchDaemonExists: installedLaunchDaemonExists,
            launchctlExitStatus: process.terminationStatus
        )
    }

    private func removeOrphanedHelperInstallInteractively() -> String? {
        let shellScript = Self.orphanedHelperCleanupShellScript(label: helperLabel)
        let source = "do shell script \(Self.appleScriptStringLiteral(shellScript)) with administrator privileges"

        guard let appleScript = NSAppleScript(source: source) else {
            return "Could not prepare the stale helper cleanup script."
        }

        var errorInfo: NSDictionary?
        _ = appleScript.executeAndReturnError(&errorInfo)

        guard let errorInfo else {
            return nil
        }

        return Self.administratorCleanupFailureMessage(errorInfo: errorInfo)
    }

    static func helperInstallAppearsOrphaned(
        installedHelperExists: Bool,
        installedLaunchDaemonExists: Bool,
        launchctlExitStatus: Int32
    ) -> Bool {
        guard installedHelperExists || installedLaunchDaemonExists else {
            return false
        }

        if installedHelperExists != installedLaunchDaemonExists {
            return true
        }

        return launchctlExitStatus != 0
    }

    static func orphanedHelperCleanupShellScript(label: String) -> String {
        let launchctlTarget = shellEscaped("system/\(label)")
        let helperPath = shellEscaped("/Library/PrivilegedHelperTools/\(label)")
        let launchDaemonPath = shellEscaped("/Library/LaunchDaemons/\(label).plist")
        return "/bin/launchctl bootout \(launchctlTarget) >/dev/null 2>&1 || true; /bin/rm -f \(helperPath) \(launchDaemonPath)"
    }

    nonisolated static func shouldAttemptOrphanedInstallCleanup(afterBlessFailureMessage message: String) -> Bool {
        let normalized = message.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.isEmpty == false else { return false }

        return normalized.contains("cferrordomainlaunchd")
            || normalized.contains("launchd error")
            || normalized.contains("launchd")
    }

    private nonisolated static func administratorCleanupFailureMessage(errorInfo: NSDictionary) -> String {
        let errorNumber = errorInfo[NSAppleScript.errorNumber] as? Int
        let errorMessage = (errorInfo[NSAppleScript.errorMessage] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if errorNumber == -128 {
            return "Administrator approval was canceled while removing the stale privileged helper."
        }

        if let errorMessage, errorMessage.isEmpty == false {
            return "Could not remove the stale privileged helper: \(errorMessage)"
        }

        return "Could not remove the stale privileged helper."
    }

    private nonisolated static func appleScriptStringLiteral(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private nonisolated static func shellEscaped(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "'", with: "'\"'\"'")
        return "'\(escaped)'"
    }

    private func readValueViaHelper(key: String, timeout: TimeInterval) -> ConnectionResult<Double> {
        withHelperConnection(timeout: timeout, perform: { proxy, finish in
            proxy.readValue(key) { value, errorMessage in
                finish(value?.doubleValue, errorMessage as String?)
            }
        })
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

    func installBundledHelper(forceReinstall: Bool = false, completion: @escaping (Bool, String?) -> Void) {
        let flags: AuthorizationFlags = [.interactionAllowed, .extendRights, .preAuthorize]

        var authRef: AuthorizationRef?
        let authStatus: OSStatus = kSMRightBlessPrivilegedHelper.withCString { blessRightName in
            if forceReinstall {
                return kSMRightModifySystemDaemons.withCString { removeRightName in
                    var authItems = [
                        AuthorizationItem(name: blessRightName, valueLength: 0, value: nil, flags: 0),
                        AuthorizationItem(name: removeRightName, valueLength: 0, value: nil, flags: 0)
                    ]
                    return authItems.withUnsafeMutableBufferPointer { buffer in
                        guard let itemPointer = buffer.baseAddress else {
                            return errAuthorizationInternal
                        }
                        var authRights = AuthorizationRights(count: 2, items: itemPointer)
                        return AuthorizationCreate(&authRights, nil, flags, &authRef)
                    }
                }
            } else {
                var authItem = AuthorizationItem(name: blessRightName, valueLength: 0, value: nil, flags: 0)
                return withUnsafeMutablePointer(to: &authItem) { itemPointer in
                    var authRights = AuthorizationRights(count: 1, items: itemPointer)
                    return AuthorizationCreate(&authRights, nil, flags, &authRef)
                }
            }
        }

        guard authStatus == errAuthorizationSuccess, let authRef else {
            completion(false, "Failed to create authorization reference.")
            return
        }
        defer { AuthorizationFree(authRef, []) }

        if forceReinstall {
            // Tear down stale launchd state before bootstrapping the fresh helper.
            var removeError: Unmanaged<CFError>?
            let removed = LegacyServiceManagementBridge.jobRemove(
                domain: kSMDomainSystemLaunchd,
                jobLabel: helperLabel as CFString,
                auth: authRef,
                wait: true,
                outError: &removeError
            )
            if removed == false, let removeError {
                let nsError = removeError.takeRetainedValue() as Error as NSError
                let isMissingJob = nsError.domain == LegacyServiceManagementBridge.launchdErrorDomain
                    && nsError.code == Int(kSMErrorJobNotFound)
                if !isMissingJob {
                    completion(false, nsError.localizedDescription)
                    return
                }
            }
            refreshStatus()
        }

        var blessError: Unmanaged<CFError>?
        let blessed = LegacyServiceManagementBridge.jobBless(
            domain: kSMDomainSystemLaunchd,
            executableLabel: helperLabel as CFString,
            auth: authRef,
            outError: &blessError
        )
        if blessed {
            refreshStatus()
            refreshDiagnostics()
            completion(true, nil)
        } else {
            let message = (blessError?.takeRetainedValue().localizedDescription) ?? "Privileged helper installation failed."

            guard Self.shouldAttemptOrphanedInstallCleanup(afterBlessFailureMessage: message),
                  forceReinstall || helperInstallationLooksOrphaned() || message.localizedCaseInsensitiveContains("launchd") else {
                completion(false, message)
                return
            }

            if let cleanupFailureMessage = removeOrphanedHelperInstallInteractively() {
                completion(false, cleanupFailureMessage)
                return
            }

            refreshStatus()

            var retryError: Unmanaged<CFError>?
            let retriedBless = LegacyServiceManagementBridge.jobBless(
                domain: kSMDomainSystemLaunchd,
                executableLabel: helperLabel as CFString,
                auth: authRef,
                outError: &retryError
            )
            if retriedBless {
                refreshStatus()
                refreshDiagnostics()
                completion(true, nil)
            } else {
                let retryMessage = (retryError?.takeRetainedValue().localizedDescription) ?? "Privileged helper installation failed."
                completion(false, retryMessage)
            }
        }
    }

    func installFromApp(forceReinstall: Bool = false) {
        statusMessage = forceReinstall
            ? "Waiting for administrator approval to repair the privileged helper."
            : "Waiting for administrator approval to install the privileged helper."

        installBundledHelper(forceReinstall: forceReinstall) { [weak self] success, message in
            guard let self else { return }
            if success {
                hasAttemptedBlessInstall = false
                refreshStatus()
                statusMessage = forceReinstall
                    ? "Privileged helper reinstalled from this app build. Fan control is ready."
                    : "Privileged helper installed. Fan control is ready."
                refreshDiagnostics()
            } else {
                refreshStatus()
                statusMessage = message ?? (forceReinstall ? "Failed to reinstall privileged helper." : "Failed to install privileged helper.")
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
