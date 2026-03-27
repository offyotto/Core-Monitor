import Foundation
import Combine
import Security
import ServiceManagement
import AppKit
import Darwin

@MainActor
final class SMCHelperManager: ObservableObject {
    static let shared = SMCHelperManager()

    @Published private(set) var isInstalled: Bool = false
    @Published var statusMessage: String?

    private init() {
        refreshStatus()
    }

    private let helperLabel = "ventaphobia.smc-helper"

    private var helperCandidates: [String] {
        var candidates = [
            "/Library/PrivilegedHelperTools/\(helperLabel)",
            "/usr/local/bin/smc-helper",
            "/opt/homebrew/bin/smc-helper"
        ]
#if DEBUG
        let derivedProductsHelper = URL(fileURLWithPath: Bundle.main.bundlePath)
            .deletingLastPathComponent()
            .appendingPathComponent("smc-helper")
            .path
        let workspaceBuildHelper = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Core-Monitor/Products/smc-helper")
            .path
        candidates.append(contentsOf: [derivedProductsHelper, workspaceBuildHelper])
#endif
        return candidates
    }

    func refreshStatus() {
        isInstalled = helperCandidates.contains { FileManager.default.fileExists(atPath: $0) }
        if isInstalled, statusMessage == "smc-helper not found" {
            statusMessage = nil
        }
    }

    func installViaSMJobBless() {
        guard hasBlessMetadataConfigured() else {
            statusMessage = "SMJobBless config missing: add SMPrivilegedExecutables for \(helperLabel) in app Info.plist."
            refreshStatus()
            return
        }

        if #available(macOS 13.0, *) {
            let plistName = "\(helperLabel).plist"
            do {
                try SMAppService.daemon(plistName: plistName).register()
                statusMessage = "Helper registration requested. Check Login Items approval if prompted."
            } catch {
                statusMessage = "SMAppService registration failed: \(error.localizedDescription)"
            }
            refreshStatus()
            return
        }

        installLegacyViaSMJobBless()
    }

    @available(macOS, introduced: 10.6)
    private func installLegacyViaSMJobBless() {
        var authRef: AuthorizationRef?
        let authFlags: AuthorizationFlags = [.interactionAllowed, .extendRights, .preAuthorize]
        let authStatus = AuthorizationCreate(nil, nil, authFlags, &authRef)

        guard authStatus == errAuthorizationSuccess, let authRef else {
            statusMessage = "Authorization failed (\(authStatus))."
            refreshStatus()
            return
        }

        defer { AuthorizationFree(authRef, []) }

        var cfError: Unmanaged<CFError>?
#if swift(>=5.9)
        // Legacy helper install path for older systems.
#endif
        let blessOK = callSMJobBless(authRef: authRef, cfError: &cfError)

        if blessOK {
            statusMessage = "Privileged helper installed."
        } else {
            let message = (cfError?.takeRetainedValue() as Error?)?.localizedDescription ?? "Unknown SMJobBless error"
            statusMessage = "SMJobBless failed: \(message). Verify SMPrivilegedExecutables/SMAuthorizedClients config and signing."
        }

        refreshStatus()
    }

    private typealias SMJobBlessFunction = @convention(c) (
        CFString,
        CFString,
        AuthorizationRef,
        UnsafeMutablePointer<Unmanaged<CFError>?>?
    ) -> Bool

    private func callSMJobBless(
        authRef: AuthorizationRef,
        cfError: inout Unmanaged<CFError>?
    ) -> Bool {
        guard
            let handle = dlopen(
                "/System/Library/Frameworks/ServiceManagement.framework/ServiceManagement",
                RTLD_NOW
            ),
            let symbol = dlsym(handle, "SMJobBless")
        else {
            statusMessage = "ServiceManagement SMJobBless symbol unavailable."
            return false
        }
        defer { dlclose(handle) }

        let function = unsafeBitCast(symbol, to: SMJobBlessFunction.self)
        return function(kSMDomainSystemLaunchd, helperLabel as CFString, authRef, &cfError)
    }

    private func hasBlessMetadataConfigured() -> Bool {
        guard let privileged = Bundle.main.infoDictionary?["SMPrivilegedExecutables"] as? [String: String] else {
            return false
        }
        return privileged[helperLabel] != nil
    }

    func execute(arguments: [String], allowPrivilegePrompt: Bool = true) -> Bool {
        refreshStatus()
        guard let helperPath = helperCandidates.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            statusMessage = "smc-helper not found"
            return false
        }

        let direct = Process()
        direct.executableURL = URL(fileURLWithPath: helperPath)
        direct.arguments = arguments

        do {
            try direct.run()
            direct.waitUntilExit()
            if direct.terminationStatus == 0 {
                statusMessage = nil
                return true
            }
        } catch {
            // Continue to elevated attempts.
        }

        let sudo = Process()
        sudo.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        sudo.arguments = ["-n", helperPath] + arguments

        do {
            try sudo.run()
            sudo.waitUntilExit()
            if sudo.terminationStatus == 0 {
                statusMessage = nil
                return true
            }
        } catch {
            // Continue.
        }

        guard allowPrivilegePrompt else {
            statusMessage = "Helper failed without privilege prompt"
            return false
        }

        if runWithAdminPrompt(helperPath: helperPath, arguments: arguments) {
            statusMessage = nil
            return true
        }

        statusMessage = "Helper command failed. Install/approve the privileged helper first."
        return false
    }

    private func runWithAdminPrompt(helperPath: String, arguments: [String]) -> Bool {
        let command = ([helperPath] + arguments)
            .map { shellQuote($0) }
            .joined(separator: " ")

        let escapedCommand = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let scriptSource = "do shell script \"\(escapedCommand)\" with administrator privileges"

        var scriptError: NSDictionary?
        guard let appleScript = NSAppleScript(source: scriptSource) else {
            return false
        }
        _ = appleScript.executeAndReturnError(&scriptError)
        return scriptError == nil
    }

    private func shellQuote(_ string: String) -> String {
        "'" + string.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}


