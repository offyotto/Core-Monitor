import Foundation
import AppKit

@MainActor
final class CompanionLaunchpadManager {
    static let shared = CompanionLaunchpadManager()

    private init() {}

    private let companionName = "Core-Monitor Launchpad.app"

    func ensureInstalled(forceRefresh: Bool = false) {
        guard let sourceBundleURL = Bundle.main.bundleURL.standardizedFileURL as URL? else { return }

        let destinations = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]

        for root in destinations {
            let destination = root.appendingPathComponent(companionName)
            if FileManager.default.fileExists(atPath: destination.path) {
                guard forceRefresh else { return }
                try? FileManager.default.removeItem(at: destination)
            }

            do {
                try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: sourceBundleURL, to: destination)
                return
            } catch {
                continue
            }
        }
    }

    func launchCompanion() {
        ensureInstalled(forceRefresh: true)

        if let appURL = installedCompanionURL() {
            launchWithOpenNewInstance(appURL: appURL)
            return
        }

        launchWithOpenNewInstance(appURL: Bundle.main.bundleURL)
    }

    private func installedCompanionURL() -> URL? {
        let candidates = [
            URL(fileURLWithPath: "/Applications", isDirectory: true).appendingPathComponent(companionName),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true).appendingPathComponent(companionName)
        ]
        return candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) })
    }

    private func launchWithOpenNewInstance(appURL: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", appURL.path, "--args", "--launchpad-mode"]
        try? process.run()
    }
}
