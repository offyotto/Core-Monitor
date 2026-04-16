import AppKit
import SwiftUI

private func debugLaunch(_ message: String) {
    guard ProcessInfo.processInfo.environment["CORE_MONITOR_DEBUG_LAUNCH"] == "1" else { return }
    fputs("[CoreMonitorLaunch] \(message)\n", stderr)
}

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
        debugLaunch("showDashboard begin visible=\(window.isVisible) frame=\(NSStringFromRect(window.frame))")

        configure(window)
        coordinator.attachTouchBar(to: window)
        if hasPositionedWindow == false || DashboardWindowLayout.shouldResetFrame(windowFrame: window.frame, visibleFrame: window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame) {
            window.setContentSize(DashboardWindowLayout.targetContentSize(for: window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame))
            window.center()
        }
        hasPositionedWindow = true

        showWindow(nil)
        promoteVisibility(of: window)
        debugLaunch("showDashboard end visible=\(window.isVisible) frame=\(NSStringFromRect(window.frame))")
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
    private var launchPresentation: CoreMonitorLaunchPresentation = .menuBarOnly

    private var menuBarController: MenuBarController?
    private var dashboardController: DashboardWindowController?
    private var hasPresentedInitialDashboard = false
    private var pendingInitialDashboardAttempts: [DispatchWorkItem] = []
    private var quitShortcutMonitor: Any?
    private let shouldBootstrapInteractiveApp = AppRuntimeContext.shouldBootstrapInteractiveApp()

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard shouldBootstrapInteractiveApp else {
            debugLaunch("didFinishLaunching skipping interactive bootstrap for unit-test host")
            return
        }

        NSWindow.allowsAutomaticWindowTabbing = false
        launchPresentation = WelcomeGuideProgress.launchPresentation()
        applyInitialActivationPolicy()
        debugLaunch("didFinishLaunching launchPresentation=\(launchPresentation) activationPolicy=\(NSApp.activationPolicy().rawValue)")
        installApplicationMenuIfNeeded()
        installQuitShortcutMonitorIfNeeded()
        CoreMonitorDefaultsMaintenance.purgeDeprecatedState()
        installMenuBarIfNeeded()
        presentInitialDashboardIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let quitShortcutMonitor {
            NSEvent.removeMonitor(quitShortcutMonitor)
            self.quitShortcutMonitor = nil
        }

        guard shouldBootstrapInteractiveApp else { return }

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
    private func openDashboardFromMenu(_ sender: Any?) {
        openDashboard()
    }

    @objc
    private func openHelpFromMenu(_ sender: Any?) {
        DashboardNavigationRouter.shared.open(.help)
        openDashboard()
    }

    @objc
    private func reopenWelcomeGuideFromMenu(_ sender: Any?) {
        UserDefaults.standard.set(false, forKey: WelcomeGuideProgress.hasSeenDefaultsKey)
        openDashboard()
    }

    @objc
    private func quitApplication(_ sender: Any?) {
        NSApp.terminate(sender)
    }

    func openDashboard() {
        guard shouldBootstrapInteractiveApp else { return }
        setDashboardActivationPolicy()
        debugLaunch("openDashboard activationPolicy=\(NSApp.activationPolicy().rawValue)")
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
        guard NSApp.mainMenu == nil else { return }

        let appName = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String ?? "Core Monitor"
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        appMenuItem.title = appName

        let appMenu = NSMenu(title: appName)
        let openDashboardItem = NSMenuItem(
            title: "Open Dashboard",
            action: #selector(openDashboardFromMenu(_:)),
            keyEquivalent: "o"
        )
        openDashboardItem.keyEquivalentModifierMask = [.command]
        openDashboardItem.target = self
        appMenu.addItem(openDashboardItem)

        let openHelpItem = NSMenuItem(
            title: "Open Help",
            action: #selector(openHelpFromMenu(_:)),
            keyEquivalent: ""
        )
        openHelpItem.target = self
        appMenu.addItem(openHelpItem)

        let reopenWelcomeGuideItem = NSMenuItem(
            title: "Show Welcome Guide",
            action: #selector(reopenWelcomeGuideFromMenu(_:)),
            keyEquivalent: ""
        )
        reopenWelcomeGuideItem.target = self
        appMenu.addItem(reopenWelcomeGuideItem)

        appMenu.addItem(.separator())

        let quitMenuItem = NSMenuItem(
            title: "Quit \(appName)",
            action: #selector(quitApplication(_:)),
            keyEquivalent: "q"
        )
        quitMenuItem.keyEquivalentModifierMask = [.command]
        quitMenuItem.target = self
        appMenu.addItem(quitMenuItem)

        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
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

    private func isQuitShortcut(_ event: NSEvent) -> Bool {
        let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return modifierFlags == [.command] && event.charactersIgnoringModifiers?.lowercased() == "q"
    }

    private func dashboardControllerIfNeeded() -> DashboardWindowController {
        if let dashboardController {
            debugLaunch("dashboardController reuse visible=\(dashboardController.isDashboardVisible)")
            return dashboardController
        }

        let controller = DashboardWindowController(
            coordinator: coordinator,
            startupManager: startupManager
        ) { [weak self] in
            self?.dashboardController = nil
            self?.restoreAccessoryActivationPolicyIfNeeded()
        }
        debugLaunch("dashboardController created")
        dashboardController = controller
        return controller
    }

    private func presentInitialDashboardIfNeeded() {
        guard hasPresentedInitialDashboard == false else { return }
        guard launchPresentation.shouldAutoOpenDashboard else { return }

        hasPresentedInitialDashboard = true
        debugLaunch("schedule initial dashboard attempts")
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
        guard launchPresentation.shouldAutoOpenDashboard else {
            cancelInitialDashboardAttempts()
            return
        }
        debugLaunch("attemptInitialDashboardPresentation visible=\(dashboardController?.isDashboardVisible == true)")

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

    private func applyInitialActivationPolicy() {
        switch launchPresentation {
        case .dashboard:
            NSApp.setActivationPolicy(.regular)
        case .menuBarOnly:
            NSApp.setActivationPolicy(.accessory)
        }
    }

    private func restoreAccessoryActivationPolicyIfNeeded() {
        guard dashboardController?.isDashboardVisible != true else { return }
        if NSApp.activationPolicy() != .accessory {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
