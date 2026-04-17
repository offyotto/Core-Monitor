import AppKit
import Combine
import Foundation

@available(macOS 13.0, *)
@MainActor
final class AppCoordinator: ObservableObject {
    let systemMonitor: SystemMonitor
    let fanController: FanController

    private let touchBarPresenter = TouchBarPrivatePresenter()
    private let customizationSettings = TouchBarCustomizationSettings.shared
    private let touchBarMonitoringReason = "touchbar"

    private lazy var coreMonTouchBarController = CoreMonTouchBarController(
        weatherProvider: nil,
        monitor: systemMonitor
    )

    private var launchObserver: NSObjectProtocol?
    private var activationObserver: NSObjectProtocol?
    private var resignObserver: NSObjectProtocol?
    private var workspaceActivationObserver: NSObjectProtocol?
    private var terminateObserver: NSObjectProtocol?
    private var customizationObserver: NSObjectProtocol?
    private var bootstrapWorkItem: DispatchWorkItem?
    private var touchBarReassertWorkItem: DispatchWorkItem?
    private weak var attachedWindow: NSWindow?

    init() {
        let monitor = SystemMonitor()
        let fanController = FanController(systemMonitor: monitor)
        self.systemMonitor = monitor
        self.fanController = fanController

        start()
    }

    func start() {
        systemMonitor.startMonitoring()
        if customizationSettings.presentationMode != .app {
            customizationSettings.presentationMode = .app
        }
        installTouchBarBootstrapObservers()
        applySavedTouchBarMode()
    }

    func stop() {
        bootstrapWorkItem?.cancel()
        bootstrapWorkItem = nil
        touchBarReassertWorkItem?.cancel()
        touchBarReassertWorkItem = nil
        fanController.restoreSystemAutomaticOnTermination()
        if let launchObserver {
            NotificationCenter.default.removeObserver(launchObserver)
            self.launchObserver = nil
        }
        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
            self.activationObserver = nil
        }
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
            self.resignObserver = nil
        }
        if let workspaceActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceActivationObserver)
            self.workspaceActivationObserver = nil
        }
        if let terminateObserver {
            NotificationCenter.default.removeObserver(terminateObserver)
            self.terminateObserver = nil
        }
        if let customizationObserver {
            NotificationCenter.default.removeObserver(customizationObserver)
            self.customizationObserver = nil
        }
        stopAppTouchBar()
        systemMonitor.stopMonitoring()
    }

    func revertToSystemTouchBar() {
        cancelTouchBarScheduling()
        customizationSettings.presentationMode = .system
        stopAppTouchBar()
    }

    func revertToAppTouchBar() {
        customizationSettings.presentationMode = .app
        startAppTouchBar()
    }

    func attachTouchBar(to window: NSWindow) {
        attachedWindow = window
        touchBarPresenter.attach(to: window)
        coreMonTouchBarController.install(in: window)

        if presentationMode == .app {
            startAppTouchBar()
        } else {
            stopAppTouchBar()
        }
    }

    private func applySavedTouchBarMode() {
        switch presentationMode {
        case .app:
            scheduleTouchBarBootstrap()
        case .system:
            stopAppTouchBar()
        }
    }

    private func cancelTouchBarScheduling() {
        bootstrapWorkItem?.cancel()
        bootstrapWorkItem = nil
        touchBarReassertWorkItem?.cancel()
        touchBarReassertWorkItem = nil
    }

    private func installTouchBarBootstrapObservers() {
        guard launchObserver == nil,
              activationObserver == nil,
              resignObserver == nil,
              workspaceActivationObserver == nil,
              terminateObserver == nil,
              customizationObserver == nil else {
            return
        }

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
                guard self?.presentationMode == .app else { return }
                self?.startAppTouchBar()
            }
        }

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleTouchBarReassertion()
            }
        }

        workspaceActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let activatedApplication = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let shouldReassert = activatedApplication != nil && activatedApplication != NSRunningApplication.current
            Task { @MainActor [weak self] in
                guard let self, shouldReassert else { return }
                self.scheduleTouchBarReassertion()
            }
        }

        terminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.stopAppTouchBar()
            }
        }

        customizationObserver = NotificationCenter.default.addObserver(
            forName: .touchBarCustomizationDidChange,
            object: TouchBarCustomizationSettings.shared,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.coreMonTouchBarController.reloadCustomization()
                switch self.presentationMode {
                case .app:
                    self.startAppTouchBar()
                case .system:
                    self.stopAppTouchBar()
                }
            }
        }
    }

    private func scheduleTouchBarReassertion() {
        guard presentationMode == .app else { return }
        touchBarReassertWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.presentationMode == .app else { return }
                self.startAppTouchBar()
            }
        }
        touchBarReassertWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem)
    }

    private func scheduleTouchBarBootstrap() {
        bootstrapWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.presentationMode == .app else { return }
                self.startAppTouchBar()
            }
        }
        bootstrapWorkItem = workItem
        DispatchQueue.main.async(execute: workItem)
    }

    private func startAppTouchBar() {
        let controller = coreMonTouchBarController
        if let attachedWindow {
            controller.install(in: attachedWindow)
        }
        systemMonitor.setMonitoringIntervalOverride(TB.refreshInterval, reason: touchBarMonitoringReason)
        controller.start()
        touchBarPresenter.present(touchBar: controller.touchBar)
    }

    private func stopAppTouchBar() {
        touchBarPresenter.dismissToSystemTouchBar()
        systemMonitor.setMonitoringIntervalOverride(nil, reason: touchBarMonitoringReason)
        coreMonTouchBarController.stop()
    }

    private var presentationMode: TouchBarPresentationMode {
        customizationSettings.presentationMode
    }
}
