import Foundation
import Combine
import AppKit

// MARK: - GitHub release model
private struct GitHubRelease: Decodable {
    let tag_name: String
    let name: String?
    let body: String?
    let html_url: String
    let published_at: String
    let prerelease: Bool
    let assets: [GitHubAsset]
}

private struct GitHubAsset: Decodable {
    let name: String
    let browser_download_url: String
    let size: Int
}

// MARK: - Semantic version comparison
private struct SemVer: Comparable {
    let major: Int
    let minor: Int
    let patch: Int

    init?(_ string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = Self.normalizedVersionString(from: trimmed)
        let parts = normalized.split(separator: ".").compactMap { Int($0) }
        guard parts.count >= 1 else { return nil }
        major = parts.count > 0 ? parts[0] : 0
        minor = parts.count > 1 ? parts[1] : 0
        patch = parts.count > 2 ? parts[2] : 0
    }

    private static func normalizedVersionString(from string: String) -> String {
        let strippedPrefix = String(string.drop(while: { !$0.isNumber }))
        let allowed = CharacterSet(charactersIn: "0123456789.")
        let scalars = strippedPrefix.unicodeScalars.prefix { allowed.contains($0) }
        return String(String.UnicodeScalarView(scalars))
    }

    static func < (lhs: SemVer, rhs: SemVer) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }

    var displayString: String { "\(major).\(minor).\(patch)" }
}

// MARK: - Update info
struct AppUpdateInfo {
    let tagName: String
    let displayName: String
    let releaseNotes: String
    let releasePageURL: URL
    let publishedAt: String
    let downloadURL: URL?
    let downloadFileName: String?
    let downloadSizeBytes: Int
}

// MARK: - AppUpdater
@MainActor
final class AppUpdater: ObservableObject {
    static let shared = AppUpdater()

    @Published private(set) var updateAvailable: AppUpdateInfo?
    @Published private(set) var isChecking: Bool = false
    @Published private(set) var lastChecked: Date?
    @Published private(set) var checkError: String?
    @Published private(set) var downloadProgress: Double = 0          // 0–1
    @Published private(set) var isDownloading: Bool = false
    @Published private(set) var downloadedFileURL: URL?

    private let repoOwner = "offyotto-sl3"
    private let repoName  = "Core-Monitor"
    private let checkIntervalSeconds: TimeInterval = 3600              // 1 hour
    private var autoCheckTask: Task<Void, Never>?
    private var downloadTask: URLSessionDataTask?

    private init() {
        schedulePeriodicCheck()
    }

    deinit {
        autoCheckTask?.cancel()
    }

    // MARK: - Public API

    var currentVersion: String {
        AppVersion.current
    }

    func checkForUpdates(silent: Bool = false) async {
        guard !isChecking else { return }
        isChecking = true
        checkError = nil
        updateAvailable = nil

        defer {
            isChecking = false
            lastChecked = Date()
        }

        do {
            let release = try await fetchLatestRelease()
            guard !release.prerelease else { return }

            guard let remote = SemVer(release.tag_name),
                  let local = SemVer(currentVersion) else { return }
            guard remote > local else { return }

            // Find a .zip or .dmg asset
            let dmgAsset  = release.assets.first { $0.name.hasSuffix(".dmg") }
            let zipAsset  = release.assets.first { $0.name.hasSuffix(".zip") }
            let bestAsset = dmgAsset ?? zipAsset

            let publishedFormatted = formatPublishedDate(release.published_at)

            updateAvailable = AppUpdateInfo(
                tagName: release.tag_name,
                displayName: release.name ?? release.tag_name,
                releaseNotes: release.body ?? "No release notes provided.",
                releasePageURL: URL(string: release.html_url)!,
                publishedAt: publishedFormatted,
                downloadURL: bestAsset.flatMap { URL(string: $0.browser_download_url) },
                downloadFileName: bestAsset?.name,
                downloadSizeBytes: bestAsset?.size ?? 0
            )
        } catch {
            if !silent {
                checkError = error.localizedDescription
            }
        }
    }

    func dismissUpdate() {
        updateAvailable = nil
    }

    func openReleasePage() {
        guard let info = updateAvailable else { return }
        NSWorkspace.shared.open(info.releasePageURL)
    }

    func downloadAndInstall() async {
        guard let info = updateAvailable, let url = info.downloadURL else {
            openReleasePage()
            return
        }

        isDownloading  = true
        downloadProgress = 0
        downloadedFileURL = nil

        defer { isDownloading = false }

        do {
            let localURL = try await downloadFile(from: url, fileName: info.downloadFileName ?? "update")
            downloadedFileURL = localURL

            if url.pathExtension.lowercased() == "dmg" {
                NSWorkspace.shared.open(localURL)
            } else if url.pathExtension.lowercased() == "zip" {
                NSWorkspace.shared.selectFile(localURL.path, inFileViewerRootedAtPath: localURL.deletingLastPathComponent().path)
            } else {
                NSWorkspace.shared.open(localURL)
            }
        } catch {
            checkError = "Download failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Private helpers

    private func schedulePeriodicCheck() {
        autoCheckTask = Task { [weak self] in
            // Small initial delay so it doesn't run at cold-start
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            while !Task.isCancelled {
                await self?.checkForUpdates(silent: true)
                try? await Task.sleep(nanoseconds: UInt64(self?.checkIntervalSeconds ?? 3600) * 1_000_000_000)
            }
        }
    }

    private func fetchLatestRelease() async throws -> GitHubRelease {
        let urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Core-Monitor/\(currentVersion) (macOS)", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 12

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            if http.statusCode == 404 {
                throw NSError(domain: "AppUpdater", code: 404,
                              userInfo: [NSLocalizedDescriptionKey: "No releases found on GitHub."])
            }
            throw NSError(domain: "AppUpdater", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "GitHub API returned HTTP \(http.statusCode)."])
        }

        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }

    private func downloadFile(from url: URL, fileName: String) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CoreMonitorUpdate", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let destURL = tempDir.appendingPathComponent(fileName)

        // Remove stale file if present
        try? FileManager.default.removeItem(at: destURL)

        return try await withCheckedThrowingContinuation { continuation in
            let session = URLSession(configuration: .default)
            let task = session.downloadTask(with: url) { [weak self] tmpURL, response, error in
                if let error {
                    Task { @MainActor in continuation.resume(throwing: error) }
                    return
                }
                guard let tmpURL else {
                    Task { @MainActor in
                        continuation.resume(throwing: NSError(
                            domain: "AppUpdater", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Download produced no file."]))
                    }
                    return
                }
                do {
                    try FileManager.default.moveItem(at: tmpURL, to: destURL)
                    Task { @MainActor [weak self] in
                        self?.downloadProgress = 1.0
                        continuation.resume(returning: destURL)
                    }
                } catch {
                    Task { @MainActor in continuation.resume(throwing: error) }
                }
            }

            task.resume()

            // Observe progress
            Task { @MainActor [weak self] in
                while !task.progress.isFinished && !Task.isCancelled {
                    self?.downloadProgress = task.progress.fractionCompleted
                    try? await Task.sleep(nanoseconds: 120_000_000)
                }
            }
        }
    }

    private func formatPublishedDate(_ iso: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: iso) {
            let display = DateFormatter()
            display.dateStyle = .medium
            display.timeStyle = .none
            return display.string(from: date)
        }
        return iso
    }
}

// MARK: - Update banner view (embeds into ContentView)
import SwiftUI

struct UpdateBannerView: View {
    @ObservedObject var updater: AppUpdater
    @State private var expanded = false

    var body: some View {
        if let info = updater.updateAvailable {
            VStack(alignment: .leading, spacing: 0) {
                // Collapsed header strip
                HStack(spacing: 10) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(red: 0.35, green: 0.72, blue: 1.0))

                    VStack(alignment: .leading, spacing: 1) {
                        Text("UPDATE AVAILABLE — \(info.displayName)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(red: 0.35, green: 0.72, blue: 1.0))
                            .cmKerning(0.6)
                        Text("v\(updater.currentVersion) → \(info.tagName)  ·  \(info.publishedAt)")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color(white: 0.45))
                    }

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            expanded.toggle()
                        }
                    } label: {
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color(white: 0.4))
                    }
                    .buttonStyle(.plain)

                    Button {
                        updater.dismissUpdate()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color(white: 0.35))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)

                if expanded {
                    Divider()
                        .overlay(Color(white: 1, opacity: 0.07))

                    VStack(alignment: .leading, spacing: 10) {
                        // Release notes
                        if !info.releaseNotes.isEmpty {
                            ScrollView(.vertical, showsIndicators: false) {
                                Text(info.releaseNotes)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(Color(white: 0.6))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 90)
                        }

                        // Download progress
                        if updater.isDownloading {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("DOWNLOADING")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Color(white: 0.4))
                                        .cmKerning(0.8)
                                    Spacer()
                                    Text("\(Int(updater.downloadProgress * 100))%")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Color(red: 0.35, green: 0.72, blue: 1.0))
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color(white: 0.15))
                                            .frame(height: 3)
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color(red: 0.35, green: 0.72, blue: 1.0))
                                            .frame(width: geo.size.width * updater.downloadProgress, height: 3)
                                            .animation(.easeOut(duration: 0.2), value: updater.downloadProgress)
                                    }
                                }
                                .frame(height: 3)
                            }
                        } else {
                            // Action buttons
                            HStack(spacing: 8) {
                                if info.downloadURL != nil {
                                    Button {
                                        Task { await updater.downloadAndInstall() }
                                    } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: "arrow.down.circle")
                                                .font(.system(size: 10, weight: .bold))
                                            Text("DOWNLOAD & INSTALL")
                                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                                .cmKerning(0.5)
                                        }
                                        .foregroundStyle(Color(red: 0.07, green: 0.07, blue: 0.08))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color(red: 0.35, green: 0.72, blue: 1.0))
                                        .clipShape(RoundedRectangle(cornerRadius: 5))
                                    }
                                    .buttonStyle(.plain)
                                }

                                Button {
                                    updater.openReleasePage()
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "arrow.up.right.square")
                                            .font(.system(size: 10, weight: .bold))
                                        Text("VIEW ON GITHUB")
                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                            .cmKerning(0.5)
                                    }
                                    .foregroundStyle(Color(white: 0.55))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color(white: 0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(Color(white: 1, opacity: 0.1), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
            }
            .background(Color(red: 0.10, green: 0.13, blue: 0.18))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(red: 0.35, green: 0.72, blue: 1.0).opacity(0.3), lineWidth: 1)
            )
            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .move(edge: .bottom).combined(with: .opacity)))
        }
    }
}
