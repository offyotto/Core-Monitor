import Foundation
import Combine

@MainActor
final class SMCHelperManager: ObservableObject {
    static let shared = SMCHelperManager()

    @Published private(set) var isInstalled: Bool = false
    @Published var statusMessage: String?

    private let helperLabel = "ventaphobia.smc-helper"

    private init() {
        refreshStatus()
    }

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
        if isInstalled, statusMessage == "Fan write access unavailable: no installed helper found." {
            statusMessage = nil
        }
    }

    func execute(arguments: [String]) -> Bool {
        refreshStatus()

        guard let helperPath = helperCandidates.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            statusMessage = "Fan write access unavailable: no installed helper found."
            return false
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: helperPath)
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
}
