import Foundation
import Combine
import SwiftUI
import AppKit
#if canImport(Sparkle)
import Sparkle
#endif

struct AppUpdateInfo {
    let displayName: String
}

@MainActor
final class AppUpdater: NSObject, ObservableObject {
    static let shared = AppUpdater()

    @Published private(set) var updateAvailable: AppUpdateInfo?
    @Published private(set) var isChecking = false
    @Published private(set) var lastChecked: Date?
    @Published private(set) var checkError: String?
    @Published private(set) var downloadProgress = 0.0
    @Published private(set) var isDownloading = false
    @Published private(set) var downloadedFileURL: URL?

    #if canImport(Sparkle)
    private lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: self,
        userDriverDelegate: self
    )
    #endif

    override private init() {
        super.init()
    }

    var currentVersion: String {
        AppVersion.current
    }

    func checkForUpdates(silent: Bool = false) async {
        checkError = nil
        lastChecked = Date()
        isChecking = true

        #if canImport(Sparkle)
        if silent {
            updaterController.updater.checkForUpdatesInBackground()
        } else {
            runInteractiveSparkleCheck()
        }
        #else
        isChecking = false
        checkError = "Sparkle is not linked yet. Add the Sparkle Swift Package to enable app updates."
        #endif
    }

    func dismissUpdate() {
        updateAvailable = nil
    }

    func openReleasePage() {
        #if canImport(Sparkle)
        isChecking = true
        checkError = nil
        runInteractiveSparkleCheck()
        #else
        checkError = "Sparkle is not linked yet. Add the Sparkle Swift Package to enable app updates."
        #endif
    }

    func downloadAndInstall() async {
        #if canImport(Sparkle)
        isChecking = true
        checkError = nil
        runInteractiveSparkleCheck()
        #else
        checkError = "Sparkle is not linked yet. Add the Sparkle Swift Package to enable app updates."
        #endif
    }

    #if canImport(Sparkle)
    private func runInteractiveSparkleCheck() {
        prepareForSparkleUI()

        guard updaterController.updater.canCheckForUpdates else {
            isChecking = false
            checkError = "The updater is busy right now. Try again in a moment."
            return
        }

        updaterController.checkForUpdates(nil)
    }

    private func prepareForSparkleUI() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if let mainWindow = NSApp.windows.first(where: { $0.styleMask.contains(.titled) }) {
            mainWindow.makeKeyAndOrderFront(nil)
            mainWindow.orderFrontRegardless()
        }
    }

    private func handleSparkleError(_ error: Error) {
        let nsError = error as NSError
        let noUpdateCode = 1001
        let installationCanceledCode = 4007

        if nsError.domain == SUSparkleErrorDomain, nsError.code == noUpdateCode {
            checkError = nil
        } else if nsError.domain == SUSparkleErrorDomain, nsError.code == installationCanceledCode {
            checkError = nil
        } else {
            checkError = nsError.localizedDescription
        }
    }
    #endif
}

#if canImport(Sparkle)
extension AppUpdater: SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    func standardUserDriverWillShowModalAlert() {
        prepareForSparkleUI()
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        isChecking = false
        checkError = nil
        updateAvailable = AppUpdateInfo(displayName: item.displayVersionString)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        isChecking = false
        checkError = nil
        updateAvailable = nil
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        isChecking = false
        updateAvailable = nil
        handleSparkleError(error)
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        isChecking = false
        handleSparkleError(error)
    }
}
#endif

struct UpdateBannerView: View {
    @ObservedObject var updater: AppUpdater
    var actionTitle: String = "Check With Sparkle"
    var action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.bdAccent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Update Available")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                    Text("Sparkle will guide the download and install.")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Button {
                action()
            } label: {
                Text(actionTitle)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.bdAccent.opacity(0.22))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color(red: 0.10, green: 0.13, blue: 0.18))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.bdAccent.opacity(0.3), lineWidth: 1)
        )
    }
}
