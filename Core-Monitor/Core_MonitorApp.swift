import AppKit
import SwiftUI

@available(macOS 13.0, *)
@MainActor
private final class DashboardWindowController: NSWindowController, NSWindowDelegate {
    private static let defaultContentSize = NSSize(width: 980, height: 640)
    private static let minimumContentSize = NSSize(width: 820, height: 560)

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
        if hasPositionedWindow == false || Self.shouldResetFrame(for: window) {
            window.setContentSize(Self.targetContentSize(for: window.screen))
            window.center()
        }
        hasPositionedWindow = true
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func windowWillClose(_ notification: Notification) {
        DashboardLaunchDiagnostics.recordDashboardClosed()
        onClose()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        DashboardLaunchDiagnostics.recordDashboardDidBecomeVisible()
    }

    func windowDidBecomeMain(_ notification: Notification) {
        DashboardLaunchDiagnostics.recordDashboardDidBecomeVisible()
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
        window.minSize = Self.minimumContentSize
        window.titlebarSeparatorStyle = .none

        if Self.shouldResetFrame(for: window) {
            window.setContentSize(Self.targetContentSize(for: window.screen))
        }
    }

    private static func targetContentSize(for screen: NSScreen?) -> NSSize {
        guard let visibleFrame = (screen ?? NSScreen.main)?.visibleFrame,
              visibleFrame.width > 0,
              visibleFrame.height > 0 else {
            return defaultContentSize
        }

        return NSSize(
            width: min(defaultContentSize.width, max(minimumContentSize.width, visibleFrame.width * 0.74)),
            height: min(defaultContentSize.height, max(minimumContentSize.height, visibleFrame.height * 0.78))
        )
    }

    private static func shouldResetFrame(for window: NSWindow) -> Bool {
        let frame = window.frame
        guard let visibleFrame = (window.screen ?? NSScreen.main)?.visibleFrame,
              visibleFrame.width > 0,
              visibleFrame.height > 0 else {
            return frame.width < minimumContentSize.width || frame.height < minimumContentSize.height
        }

        return frame.width < minimumContentSize.width ||
            frame.height < minimumContentSize.height ||
            frame.width > visibleFrame.width * 0.92 ||
            frame.height > visibleFrame.height * 0.92
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
        DashboardLaunchDiagnostics.recordLaunchState(
            welcomeGuideSeen: WelcomeGuideProgress.hasSeen(),
            autoOpenEligible: WelcomeGuideProgress.shouldAutoOpenDashboardOnLaunch(),
            activationPolicyDescription: activationPolicyDescription(for: NSApp.activationPolicy())
        )
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
        openDashboard(source: .reopen)
        return true
    }

    func openDashboard(source: DashboardOpenSource = .direct) {
        DashboardLaunchDiagnostics.recordDashboardOpenRequested(
            source: source,
            activationPolicyDescription: activationPolicyDescription(for: NSApp.activationPolicy())
        )
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
                self?.openDashboard(source: .menuBar)
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
            self?.openDashboard(source: .launch)
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

    private func activationPolicyDescription(for policy: NSApplication.ActivationPolicy) -> String {
        switch policy {
        case .regular:
            return "regular"
        case .accessory:
            return "accessory"
        case .prohibited:
            return "prohibited"
        @unknown default:
            return "unknown"
        }
    }
}
