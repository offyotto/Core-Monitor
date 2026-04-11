import AppKit
import Combine
import Foundation

@available(macOS 13.0, *)
@MainActor
final class AppCoordinator: ObservableObject {
    private enum TouchBarMode: String {
        case app
        case system
    }

    let systemMonitor: SystemMonitor
    let fanController: FanController

    private let touchBarPresenter = TouchBarPrivatePresenter()

    private let coreMonTouchBarController: CoreMonTouchBarController

    private let touchBarModeKey = "coremonitor.touchBarMode"
    private let touchBarModeMigrationKey = "coremonitor.touchBarMode.blankBarV1"
    private var launchObserver: NSObjectProtocol?
    private var activationObserver: NSObjectProtocol?
    private var terminateObserver: NSObjectProtocol?
    private var customizationObserver: NSObjectProtocol?
    private var bootstrapWorkItem: DispatchWorkItem?

    init() {
        let monitor = SystemMonitor()
        self.systemMonitor = monitor
        self.fanController = FanController(systemMonitor: monitor)

        // Build controller with the live monitor so MEM/CPU/BAT bars are populated
        self.coreMonTouchBarController = CoreMonTouchBarController(
            weatherProvider: nil,   // nil = uses default (mock DEBUG / live RELEASE)
            monitor: monitor
        )

        start()
    }

    func start() {
        systemMonitor.startMonitoring()
        normalizeTouchBarModePreference()
        installTouchBarBootstrapObservers()
        applySavedTouchBarMode()

        coreMonTouchBarController.start()
    }

    func stop() {
        bootstrapWorkItem?.cancel()
        bootstrapWorkItem = nil
        if let launchObserver {
            NotificationCenter.default.removeObserver(launchObserver)
            self.launchObserver = nil
        }
        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
            self.activationObserver = nil
        }
        if let terminateObserver {
            NotificationCenter.default.removeObserver(terminateObserver)
            self.terminateObserver = nil
        }
        if let customizationObserver {
            NotificationCenter.default.removeObserver(customizationObserver)
            self.customizationObserver = nil
        }
        coreMonTouchBarController.stop()
        stopAppTouchBar()
        systemMonitor.stopMonitoring()
    }

    func revertToSystemTouchBar() {
        saveTouchBarMode(.system)
        touchBarPresenter.dismissToSystemTouchBar()
    }

    func revertToAppTouchBar() {
        saveTouchBarMode(.app)
        startAppTouchBar()
    }

    func attachTouchBar(to window: NSWindow) {
        touchBarPresenter.attach(to: window)
        // Also install the standard NSTouchBar on the window as a fallback
        coreMonTouchBarController.install(in: window)

        if savedTouchBarMode == .app {
            startAppTouchBar()
        } else {
            stopAppTouchBar()
        }
    }

    private func normalizeTouchBarModePreference() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: touchBarModeMigrationKey) == false else { return }
        saveTouchBarMode(.app)
        defaults.set(true, forKey: touchBarModeMigrationKey)
    }

    private func applySavedTouchBarMode() {
        switch savedTouchBarMode {
        case .app:
            scheduleTouchBarBootstrap()
        case .system:
            stopAppTouchBar()
        }
    }

    private func installTouchBarBootstrapObservers() {
        guard launchObserver == nil, activationObserver == nil, terminateObserver == nil, customizationObserver == nil else { return }

        launchObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didFinishLaunchingNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleTouchBarBootstrap()
            }
        }

        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard self?.savedTouchBarMode == .app else { return }
                self?.startAppTouchBar()
            }
        }

        terminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.touchBarPresenter.dismissToSystemTouchBar()
            }
        }

        customizationObserver = NotificationCenter.default.addObserver(
            forName: .touchBarCustomizationDidChange,
            object: TouchBarCustomizationSettings.shared,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard self?.savedTouchBarMode == .app else { return }
                self?.startAppTouchBar()
            }
        }
    }

    private func scheduleTouchBarBootstrap() {
        bootstrapWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard self?.savedTouchBarMode == .app else { return }
                self?.startAppTouchBar()
            }
        }
        bootstrapWorkItem = workItem
        DispatchQueue.main.async(execute: workItem)
    }

    private func startAppTouchBar() {
        touchBarPresenter.present(touchBar: coreMonTouchBarController.touchBar)
    }

    private func stopAppTouchBar() {
        touchBarPresenter.dismiss()
    }

    private var savedTouchBarMode: TouchBarMode {
        let raw = UserDefaults.standard.string(forKey: touchBarModeKey) ?? TouchBarMode.app.rawValue
        return TouchBarMode(rawValue: raw) ?? .app
    }

    private func saveTouchBarMode(_ mode: TouchBarMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: touchBarModeKey)
    }
}
