import AppKit
import SwiftUI

@available(macOS 13.0, *)
@MainActor
private final class DashboardWindowController: NSWindowController, NSWindowDelegate {
    private let coordinator: AppCoordinator
    private let startupManager: StartupManager
    private let onClose: () -> Void
    private var hasPositionedWindow = false

    init(
        coordinator: AppCoordinator,
        startupManager: StartupManager,
        onClose: @escaping () -> Void
    ) {
        self.coordinator = coordinator
        self.startupManager = startupManager
        self.onClose = onClose

        let rootView = ContentView(
            systemMonitor: coordinator.systemMonitor,
            fanController: coordinator.fanController,
            alertManager: coordinator.alertManager,
            startupManager: startupManager
        )
        let hostingController = NSHostingController(rootView: rootView)
        hostingController.sizingOptions = []
        let window = NSWindow(contentViewController: hostingController)

        super.init(window: window)
        configure(window)
        coordinator.attachTouchBar(to: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showDashboard() {
        guard let window else { return }

        configure(window)
        coordinator.attachTouchBar(to: window)
        NSApp.activate(ignoringOtherApps: true)

        showWindow(nil)
        if hasPositionedWindow == false || DashboardWindowLayout.shouldResetFrame(windowFrame: window.frame, visibleFrame: window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame) {
            window.setContentSize(DashboardWindowLayout.targetContentSize(for: window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame))
            window.center()
        }
        hasPositionedWindow = true
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }

    func windowDidBecomeKey(_ notification: Notification) {
    }

    func windowDidBecomeMain(_ notification: Notification) {
    }

    private func configure(_ window: NSWindow) {
        window.identifier = NSUserInterfaceItemIdentifier("CoreMonitorMainWindow")
        window.title = "Core Monitor"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.collectionBehavior = [.managed, .fullScreenPrimary]
        window.styleMask.insert(.fullSizeContentView)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.minSize = DashboardWindowLayout.minimumContentSize
        window.titlebarSeparatorStyle = .none

        if DashboardWindowLayout.shouldResetFrame(windowFrame: window.frame, visibleFrame: window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame) {
            window.setContentSize(DashboardWindowLayout.targetContentSize(for: window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame))
        }
    }
}

@available(macOS 13.0, *)
@MainActor
final class CoreMonitorApplicationDelegate: NSObject, NSApplicationDelegate {
    private let legacyWindowStateResetKey = "coremonitor.didResetLegacySwiftUIWindowFrames.v1"
    private lazy var coordinator = AppCoordinator()
    private lazy var startupManager = StartupManager()

    private var menuBarController: MenuBarController?
    private var dashboardController: DashboardWindowController?
    private var hasPresentedInitialDashboard = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        NSApp.setActivationPolicy(.accessory)
        purgeLegacyWindowStateIfNeeded()
        installMenuBarIfNeeded()
        presentInitialDashboardIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator.stop()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        false
    }

    func applicationShouldRestoreApplicationState(_ app: NSApplication) -> Bool {
        false
    }

    func applicationShouldSaveApplicationState(_ app: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard flag == false else { return false }
        openDashboard()
        return true
    }

    func openDashboard() {
        dashboardControllerIfNeeded().showDashboard()
    }

    private func installMenuBarIfNeeded() {
        guard menuBarController == nil else { return }

        let coordinator = coordinator
        menuBarController = MenuBarController(
            systemMonitor: coordinator.systemMonitor,
            fanController: coordinator.fanController,
            alertManager: coordinator.alertManager,
            openDashboardAction: { [weak self] in
                self?.openDashboard()
            },
            restoreAppTouchBarAction: { [weak self] in
                self?.coordinator.revertToAppTouchBar()
            },
            revertTouchBarAction: { [weak self] in
                self?.coordinator.revertToSystemTouchBar()
            }
        )
    }

    private func dashboardControllerIfNeeded() -> DashboardWindowController {
        if let dashboardController {
            return dashboardController
        }

        let controller = DashboardWindowController(
            coordinator: coordinator,
            startupManager: startupManager
        ) { [weak self] in
            self?.dashboardController = nil
        }
        dashboardController = controller
        return controller
    }

    private func presentInitialDashboardIfNeeded() {
        guard hasPresentedInitialDashboard == false else { return }
        guard WelcomeGuideProgress.shouldAutoOpenDashboardOnLaunch() else { return }

        hasPresentedInitialDashboard = true
        DispatchQueue.main.async { [weak self] in
            self?.openDashboard()
        }
    }

    private func purgeLegacyWindowStateIfNeeded() {
        let defaults = UserDefaults.standard
        let domainName = Bundle.main.bundleIdentifier ?? "CoreTools.Core-Monitor"
        var domain = defaults.persistentDomain(forName: domainName) ?? defaults.dictionaryRepresentation()

        guard (domain[legacyWindowStateResetKey] as? Bool) != true else { return }

        for key in domain.keys {
            if key.hasPrefix("NSWindow Frame SwiftUI.") || key == "NSWindow Frame CoreMonitorMainWindow" {
                domain.removeValue(forKey: key)
            }
        }

        domain[legacyWindowStateResetKey] = true
        defaults.setPersistentDomain(domain, forName: domainName)
        defaults.synchronize()
    }
}
