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

    var isDashboardVisible: Bool {
        window?.isVisible == true
    }

    func showDashboard() {
        guard let window else { return }

        configure(window)
        coordinator.attachTouchBar(to: window)
        if hasPositionedWindow == false || DashboardWindowLayout.shouldResetFrame(windowFrame: window.frame, visibleFrame: window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame) {
            window.setContentSize(DashboardWindowLayout.targetContentSize(for: window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame))
            window.center()
        }
        hasPositionedWindow = true

        showWindow(nil)
        promoteVisibility(of: window)
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

    private func promoteVisibility(of window: NSWindow) {
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])

        DispatchQueue.main.async { [weak window] in
            guard let window, window.isVisible == false || NSApp.isActive == false else { return }

            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        }
    }
}

@available(macOS 13.0, *)
@MainActor
final class CoreMonitorApplicationDelegate: NSObject, NSApplicationDelegate {
    private lazy var coordinator = AppCoordinator()
    private lazy var startupManager = StartupManager()

    private var menuBarController: MenuBarController?
    private var dashboardController: DashboardWindowController?
    private var hasPresentedInitialDashboard = false
    private var pendingInitialDashboardAttempts: [DispatchWorkItem] = []
    private var quitShortcutMonitor: Any?
    private var dashboardShortcutObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        installApplicationMenuIfNeeded()
        installQuitShortcutMonitorIfNeeded()
        installDashboardShortcutObserverIfNeeded()
        _ = DashboardShortcutManager.shared
        NSApp.setActivationPolicy(.accessory)
        CoreMonitorDefaultsMaintenance.purgeDeprecatedState()
        installMenuBarIfNeeded()
        presentInitialDashboardIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let quitShortcutMonitor {
            NSEvent.removeMonitor(quitShortcutMonitor)
            self.quitShortcutMonitor = nil
        }
        if let dashboardShortcutObserver {
            NotificationCenter.default.removeObserver(dashboardShortcutObserver)
            self.dashboardShortcutObserver = nil
        }
        cancelInitialDashboardAttempts()
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

    @objc
    private func quitApplication(_ sender: Any?) {
        NSApp.terminate(sender)
    }

    @objc
    private func openDashboardFromMenu(_ sender: Any?) {
        openDashboard()
    }

    func openDashboard() {
        setDashboardActivationPolicy()
        let controller = dashboardControllerIfNeeded()
        controller.showDashboard()
        if controller.isDashboardVisible {
            cancelInitialDashboardAttempts()
        }
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

    private func installApplicationMenuIfNeeded() {
        let appName = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String ?? "Core Monitor"
        let mainMenu = NSApp.mainMenu ?? NSMenu()
        let appMenuItem = mainMenu.items.first ?? {
            let item = NSMenuItem()
            mainMenu.insertItem(item, at: 0)
            return item
        }()

        appMenuItem.title = appName
        let appMenu = appMenuItem.submenu ?? NSMenu(title: appName)
        appMenu.title = appName

        if appMenu.item(withTitle: "Open Dashboard") == nil {
            let openDashboardMenuItem = NSMenuItem(
                title: "Open Dashboard",
                action: #selector(openDashboardFromMenu(_:)),
                keyEquivalent: DashboardShortcutConfiguration.keyEquivalent
            )
            openDashboardMenuItem.keyEquivalentModifierMask = DashboardShortcutConfiguration.modifierFlags
            openDashboardMenuItem.target = self
            appMenu.insertItem(openDashboardMenuItem, at: 0)

            if appMenu.items.indices.contains(1) == false || appMenu.items[1].isSeparatorItem == false {
                appMenu.insertItem(.separator(), at: min(1, appMenu.items.count))
            }
        }

        let quitTitle = "Quit \(appName)"
        if let existingQuitItem = appMenu.item(withTitle: quitTitle) ?? appMenu.items.first(where: { $0.title.hasPrefix("Quit ") }) {
            existingQuitItem.title = quitTitle
            existingQuitItem.action = #selector(quitApplication(_:))
            existingQuitItem.keyEquivalent = "q"
            existingQuitItem.keyEquivalentModifierMask = [.command]
            existingQuitItem.target = self
        } else {
            if appMenu.items.last?.isSeparatorItem == false {
                appMenu.addItem(.separator())
            }

            let quitMenuItem = NSMenuItem(
                title: quitTitle,
                action: #selector(quitApplication(_:)),
                keyEquivalent: "q"
            )
            quitMenuItem.keyEquivalentModifierMask = [.command]
            quitMenuItem.target = self
            appMenu.addItem(quitMenuItem)
        }

        appMenuItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
    }

    private func installQuitShortcutMonitorIfNeeded() {
        guard quitShortcutMonitor == nil else { return }

        quitShortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard self?.isQuitShortcut(event) == true else { return event }
            NSApp.terminate(nil)
            return nil
        }
    }

    private func installDashboardShortcutObserverIfNeeded() {
        guard dashboardShortcutObserver == nil else { return }

        dashboardShortcutObserver = NotificationCenter.default.addObserver(
            forName: .dashboardShortcutDidActivate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.openDashboard()
            }
        }
    }

    private func isQuitShortcut(_ event: NSEvent) -> Bool {
        let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return modifierFlags == [.command] && event.charactersIgnoringModifiers?.lowercased() == "q"
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
            self?.restoreAccessoryActivationPolicyIfNeeded()
        }
        dashboardController = controller
        return controller
    }

    private func presentInitialDashboardIfNeeded() {
        guard hasPresentedInitialDashboard == false else { return }
        guard WelcomeGuideProgress.shouldAutoOpenDashboardOnLaunch() else { return }

        hasPresentedInitialDashboard = true
        scheduleInitialDashboardAttempts(after: [0, 0.35, 1.0, 2.0])
    }

    private func scheduleInitialDashboardAttempts(after delays: [TimeInterval]) {
        cancelInitialDashboardAttempts()

        for delay in delays {
            let workItem = DispatchWorkItem { [weak self] in
                self?.attemptInitialDashboardPresentation()
            }
            pendingInitialDashboardAttempts.append(workItem)

            if delay == 0 {
                DispatchQueue.main.async(execute: workItem)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
            }
        }
    }

    private func attemptInitialDashboardPresentation() {
        guard WelcomeGuideProgress.shouldAutoOpenDashboardOnLaunch() else {
            cancelInitialDashboardAttempts()
            return
        }

        if dashboardController?.isDashboardVisible == true {
            cancelInitialDashboardAttempts()
            return
        }

        openDashboard()
    }

    private func cancelInitialDashboardAttempts() {
        pendingInitialDashboardAttempts.forEach { $0.cancel() }
        pendingInitialDashboardAttempts.removeAll()
    }

    private func setDashboardActivationPolicy() {
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
    }

    private func restoreAccessoryActivationPolicyIfNeeded() {
        guard dashboardController?.isDashboardVisible != true else { return }
        if NSApp.activationPolicy() != .accessory {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
