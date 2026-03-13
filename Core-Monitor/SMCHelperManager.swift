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
        let derivedProductsHelper = URL(fileURLWithPath: Bundle.main.bundlePath)
            .deletingLastPathComponent()
            .appendingPathComponent("smc-helper")
            .path
        return [
            "/Library/PrivilegedHelperTools/\(helperLabel)",
            derivedProductsHelper,
            "/Users/bookme/Desktop/Core-Monitor/Products/smc-helper",
            "/usr/local/bin/smc-helper",
            "/opt/homebrew/bin/smc-helper",
            "/Users/bookme/Downloads/solofan-1.3.0/tools/smc-helper/smc-helper"
        ]
    }

    func refreshStatus() {
        isInstalled = helperCandidates.contains { FileManager.default.fileExists(atPath: $0) }
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

        if #unavailable(macOS 13.0) {
            installLegacyViaSMJobBless()
            return
        }

        statusMessage = "Helper registration is only available on macOS 13+ (SMAppService) or older systems with SMJobBless."
        refreshStatus()
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
                return true
            }
        } catch {
            // Continue.
        }

        guard allowPrivilegePrompt else {
            statusMessage = "Helper failed without privilege prompt"
            return false
        }

        let command = "'\(helperPath)' \(arguments.joined(separator: " "))"
        let script = "do shell script \"\(command)\" with administrator privileges"

        var scriptError: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            statusMessage = "Failed to prepare privilege prompt"
            return false
        }

        _ = appleScript.executeAndReturnError(&scriptError)
        let ok = scriptError == nil
        statusMessage = ok ? "Helper command succeeded" : "Helper command failed"
        return ok
    }
}
