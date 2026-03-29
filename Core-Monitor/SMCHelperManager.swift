import Foundation
import Combine
import Security

@MainActor
final class SMCHelperManager: ObservableObject {
    static let shared = SMCHelperManager()

    @Published private(set) var isInstalled: Bool = false
    @Published var statusMessage: String?

    private let helperLabel = "ventaphobia.smc-helper"
    private let fileManager = FileManager.default

    private init() {
        refreshStatus()
    }

    private var helperCandidates: [String] {
        var candidates = [
            "/Library/PrivilegedHelperTools/\(helperLabel)"
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
        isInstalled = helperCandidates.contains { validatedHelperURL(atPath: $0) != nil }
        if isInstalled, statusMessage == "Fan write access unavailable: no installed helper found." {
            statusMessage = nil
        }
    }

    func execute(arguments: [String]) -> Bool {
        refreshStatus()

        guard let helperURL = helperCandidates.compactMap({ validatedHelperURL(atPath: $0) }).first else {
            statusMessage = "Fan write access unavailable: no installed helper found."
            return false
        }

        let process = Process()
        process.executableURL = helperURL
        process.arguments = arguments

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                statusMessage = nil
                return true
            }
            statusMessage = "Fan write access denied by helper."
        } catch {
            statusMessage = "Fan write access failed: \(error.localizedDescription)"
        }

        return false
    }

    private func validatedHelperURL(atPath path: String) -> URL? {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        guard isPathAllowed(url) else { return nil }
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
              values.isRegularFile == true,
              values.isSymbolicLink != true else {
            return nil
        }
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path) else {
            return nil
        }
        guard isOwnershipValid(for: url, attributes: attributes),
              isPermissionsValid(attributes: attributes),
              isCodeSignatureValid(for: url) else {
            return nil
        }
        return url
    }

    private func isPathAllowed(_ url: URL) -> Bool {
        if url.path == "/Library/PrivilegedHelperTools/\(helperLabel)" {
            return true
        }
#if DEBUG
        let derivedProductsHelper = URL(fileURLWithPath: Bundle.main.bundlePath)
            .deletingLastPathComponent()
            .appendingPathComponent("smc-helper")
            .standardizedFileURL
        let workspaceBuildHelper = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Core-Monitor/Products/smc-helper")
            .standardizedFileURL
        return url == derivedProductsHelper || url == workspaceBuildHelper
#else
        return false
#endif
    }

    private func isOwnershipValid(for url: URL, attributes: [FileAttributeKey: Any]) -> Bool {
#if DEBUG
        if url.path != "/Library/PrivilegedHelperTools/\(helperLabel)" {
            if let owner = attributes[.ownerAccountID] as? NSNumber {
                return owner.uint32Value == getuid()
            }
            return false
        }
#endif
        guard let owner = attributes[.ownerAccountID] as? NSNumber else {
            return false
        }
        return owner.uint32Value == 0
    }

    private func isPermissionsValid(attributes: [FileAttributeKey: Any]) -> Bool {
        guard let permissions = attributes[.posixPermissions] as? NSNumber else {
            return false
        }
        let mode = permissions.uint16Value
        return (mode & 0o022) == 0
    }

    private func isCodeSignatureValid(for url: URL) -> Bool {
#if DEBUG
        if url.path != "/Library/PrivilegedHelperTools/\(helperLabel)" {
            return true
        }
#endif
        var staticCode: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode)
        guard createStatus == errSecSuccess, let staticCode else {
            return false
        }
        let checkStatus = SecStaticCodeCheckValidity(staticCode, [], nil)
        return checkStatus == errSecSuccess
    }
}
