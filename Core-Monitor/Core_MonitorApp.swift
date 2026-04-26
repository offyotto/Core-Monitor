import AppKit
import Carbon
import OSLog
import SwiftUI

struct CoreMonitorRunningInstance: Equatable {
    let processIdentifier: pid_t
    let launchDate: Date?
    let isFinishedLaunching: Bool
    let isTerminated: Bool
}

enum CoreMonitorSingleInstancePolicy {
    static func handoffTarget(
        from runningInstances: [CoreMonitorRunningInstance],
        currentPID: pid_t
    ) -> CoreMonitorRunningInstance? {
        runningInstances
            .filter { instance in
                instance.processIdentifier != currentPID &&
                instance.isFinishedLaunching &&
                instance.isTerminated == false
            }
            .sorted { lhs, rhs in
                let lhsLaunchDate = lhs.launchDate ?? .distantPast
                let rhsLaunchDate = rhs.launchDate ?? .distantPast
                if lhsLaunchDate != rhsLaunchDate {
                    return lhsLaunchDate < rhsLaunchDate
                }
                return lhs.processIdentifier < rhs.processIdentifier
            }
            .first
    }
}

struct CoreMonitorDashboardHandoffRequest: Equatable {
    private static let bundleIdentifierKey = "bundleIdentifier"
    private static let targetProcessIdentifierKey = "targetProcessIdentifier"

    let bundleIdentifier: String
    let targetProcessIdentifier: pid_t

    var userInfo: [AnyHashable: Any] {
        [
            Self.bundleIdentifierKey: bundleIdentifier,
            Self.targetProcessIdentifierKey: NSNumber(value: targetProcessIdentifier)
        ]
    }

    static func accepts(
        userInfo: [AnyHashable: Any]?,
        expectedBundleIdentifier: String,
        currentProcessIdentifier: pid_t
    ) -> Bool {
        guard let requestedBundleIdentifier = userInfo?[bundleIdentifierKey] as? String,
              requestedBundleIdentifier == expectedBundleIdentifier,
              let requestedPID = userInfo?[targetProcessIdentifierKey] as? NSNumber else {
            return false
        }

        return requestedPID.int32Value == currentProcessIdentifier
    }
}

struct CoreMonitorLaunchEnvironment {
    static func shouldHandleDuplicateLaunch(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        environment["XCTestConfigurationFilePath"] == nil
    }
}

private func debugLaunch(_ message: String) {
    guard ProcessInfo.processInfo.environment["CORE_MONITOR_DEBUG_LAUNCH"] == "1" else { return }
    fputs("[CoreMonitorLaunch] \(message)\n", stderr)
}

@available(macOS 13.0, *)
@MainActor
private final class DashboardWindowController: NSWindowController, NSWindowDelegate {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "CoreTools.Core-Monitor", category: "Startup")
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

        let rootView = DashboardRootView(
            systemMonitor: coordinator.systemMonitor,
            fanController: coordinator.fanController,
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

        Self.logger.debug("Showing dashboard window frame=\(String(describing: NSStringFromRect(window.frame)), privacy: .public)")
        showWindow(nil)
        promoteVisibility(of: window)
        Self.logger.notice("Dashboard show request completed visible=\(window.isVisible, privacy: .public) key=\(window.isKeyWindow, privacy: .public) main=\(window.isMainWindow, privacy: .public)")
        debugLaunch("showDashboard end visible=\(window.isVisible) frame=\(NSStringFromRect(window.frame))")
    }

    func windowWillClose(_ notification: Notification) {
        Self.logger.notice("Dashboard window will close")
        onClose()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        Self.logger.debug("Dashboard window became key")
    }

    func windowDidBecomeMain(_ notification: Notification) {
        Self.logger.debug("Dashboard window became main")
    }

    private func configure(_ window: NSWindow) {
        window.identifier = NSUserInterfaceItemIdentifier("CoreMonitorMainWindow")
        window.title = "Core Monitor"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.isMovableByWindowBackground = false
        window.isOpaque = true
        window.backgroundColor = .windowBackgroundColor
        window.hasShadow = true
        window.collectionBehavior = [.managed, .fullScreenPrimary]
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.minSize = DashboardWindowLayout.minimumContentSize
        window.titlebarSeparatorStyle = .automatic
        window.toolbarStyle = .automatic

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
    private static let openDashboardRequestNotification = Notification.Name("CoreMonitorOpenDashboardRequest")
    private static let automaticTerminationReason = "Core Monitor keeps menu bar monitoring active."
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "CoreTools.Core-Monitor", category: "Startup")

    private lazy var coordinator = AppCoordinator()
    private lazy var startupManager = StartupManager()
    private var launchPresentation: CoreMonitorLaunchPresentation = .menuBarOnly

    private var menuBarController: MenuBarController?
    private var dashboardController: DashboardWindowController?
    private var hasPresentedInitialDashboard = false
    private var pendingInitialDashboardAttempts: [DispatchWorkItem] = []
    private var quitShortcutMonitor: Any?
    private var touchBarShortcutMonitor: Any?
    private var distributedDashboardRequestObserver: NSObjectProtocol?
    private var dashboardShortcutObserver: NSObjectProtocol?
    private let shouldBootstrapInteractiveApp = AppRuntimeContext.shouldBootstrapInteractiveApp()

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard shouldBootstrapInteractiveApp else {
            debugLaunch("didFinishLaunching skipping interactive bootstrap for unit-test host")
            return
        }

        NSWindow.allowsAutomaticWindowTabbing = false
        ProcessInfo.processInfo.disableAutomaticTermination(Self.automaticTerminationReason)
        guard handOffToRunningInstanceIfNeeded() == false else { return }
        CoreMonitorDefaultsMaintenance.purgeDeprecatedState()
        launchPresentation = WelcomeGuideProgress.launchPresentation()
        debugLaunch("bundleIdentifier=\(Bundle.main.bundleIdentifier ?? "nil")")
        debugLaunch("launchPresentation=\(launchPresentation) activationPolicy=\(NSApp.activationPolicy().rawValue)")
        installApplicationMenuIfNeeded()
        installQuitShortcutMonitorIfNeeded()
        installTouchBarShortcutMonitorIfNeeded()
        installDistributedDashboardRequestObserverIfNeeded()
        installDashboardShortcutObserverIfNeeded()
        _ = DashboardShortcutManager.shared
        applyInitialActivationPolicy()
        let shouldAutoOpenDashboard = launchPresentation.shouldAutoOpenDashboard
        Self.logger.notice("Launch finished autoOpenDashboard=\(shouldAutoOpenDashboard, privacy: .public)")
        Self.logger.debug("Activation policy after launch=\(String(describing: NSApp.activationPolicy()), privacy: .public)")
        installMenuBarIfNeeded()
        presentInitialDashboardIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        Self.logger.notice("Application will terminate")
        ProcessInfo.processInfo.enableAutomaticTermination(Self.automaticTerminationReason)
        if let quitShortcutMonitor {
            NSEvent.removeMonitor(quitShortcutMonitor)
            self.quitShortcutMonitor = nil
        }
        if let touchBarShortcutMonitor {
            NSEvent.removeMonitor(touchBarShortcutMonitor)
            self.touchBarShortcutMonitor = nil
        }
        if let distributedDashboardRequestObserver {
            DistributedNotificationCenter.default().removeObserver(distributedDashboardRequestObserver)
            self.distributedDashboardRequestObserver = nil
        }
        if let dashboardShortcutObserver {
            NotificationCenter.default.removeObserver(dashboardShortcutObserver)
            self.dashboardShortcutObserver = nil
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
        Self.logger.notice("Handling reopen without visible windows")
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
        Self.logger.notice("Open dashboard requested activationPolicy=\(String(describing: NSApp.activationPolicy()), privacy: .public)")
        setDashboardActivationPolicy()
        debugLaunch("openDashboard activationPolicy=\(NSApp.activationPolicy().rawValue)")
        let controller = dashboardControllerIfNeeded()
        controller.showDashboard()
        if controller.isDashboardVisible {
            Self.logger.notice("Dashboard became visible")
            cancelInitialDashboardAttempts()
        } else {
            Self.logger.error("Dashboard show request finished without a visible window")
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
        let appName = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String ?? "Core Monitor"
        let mainMenu = NSApp.mainMenu ?? NSMenu()
        let appMenuItem = mainMenu.items.first ?? {
            let item = NSMenuItem()
            mainMenu.insertItem(item, at: 0)
            return item
        }()

        appMenuItem.title = appName
        let appMenu = NSMenu(title: appName)
        let openDashboardItem = NSMenuItem(
            title: "Open Dashboard",
            action: #selector(openDashboardFromMenu(_:)),
            keyEquivalent: DashboardShortcutConfiguration.keyEquivalent
        )
        openDashboardItem.keyEquivalentModifierMask = DashboardShortcutConfiguration.modifierFlags
        openDashboardItem.target = self
        appMenu.addItem(openDashboardItem)

        let openHelpItem = NSMenuItem(
            title: "Open Help",
            action: #selector(openHelpFromMenu(_:)),
            keyEquivalent: ""
        )
        openHelpItem.target = self
        appMenu.addItem(openHelpItem)

        let quitMenuItem = NSMenuItem(
            title: "Quit \(appName)",
            action: #selector(quitApplication(_:)),
            keyEquivalent: "q"
        )
        quitMenuItem.keyEquivalentModifierMask = [.command]
        quitMenuItem.target = self
        appMenu.addItem(quitMenuItem)

        appMenuItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
    }

    private func installDistributedDashboardRequestObserverIfNeeded() {
        guard distributedDashboardRequestObserver == nil,
              let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return
        }

        distributedDashboardRequestObserver = DistributedNotificationCenter.default().addObserver(
            forName: Self.openDashboardRequestNotification,
            object: bundleIdentifier,
            queue: .main
        ) { [weak self] notification in
            guard CoreMonitorDashboardHandoffRequest.accepts(
                userInfo: notification.userInfo,
                expectedBundleIdentifier: bundleIdentifier,
                currentProcessIdentifier: ProcessInfo.processInfo.processIdentifier
            ) else {
                return
            }
            Task { @MainActor [weak self] in
                self?.openDashboard()
            }
        }
    }

    private func installQuitShortcutMonitorIfNeeded() {
        guard quitShortcutMonitor == nil else { return }

        quitShortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard self?.isQuitShortcut(event) == true else { return event }
            NSApp.terminate(nil)
            return nil
        }
    }

    private func installTouchBarShortcutMonitorIfNeeded() {
        guard touchBarShortcutMonitor == nil else { return }

        touchBarShortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard self?.isSystemTouchBarShortcut(event) == true else { return event }
            self?.coordinator.revertToSystemTouchBar()
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

    private func isSystemTouchBarShortcut(_ event: NSEvent) -> Bool {
        let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return modifierFlags == [.command, .shift] && event.keyCode == UInt16(kVK_ANSI_6)
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
        Self.logger.debug("Created dashboard window controller")
        return controller
    }

    private func presentInitialDashboardIfNeeded() {
        guard hasPresentedInitialDashboard == false else { return }
        guard launchPresentation.shouldAutoOpenDashboard else {
            Self.logger.debug("Skipping initial dashboard presentation")
            return
        }

        hasPresentedInitialDashboard = true
        debugLaunch("schedule initial dashboard attempts")
        scheduleInitialDashboardAttempts(after: [0, 0.35, 1.0, 2.0])
    }

    private func handOffToRunningInstanceIfNeeded() -> Bool {
        guard CoreMonitorLaunchEnvironment.shouldHandleDuplicateLaunch() else { return false }
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return false }

        let currentPID = ProcessInfo.processInfo.processIdentifier
        let runningApplications = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        let runningInstances = runningApplications.map {
            CoreMonitorRunningInstance(
                processIdentifier: $0.processIdentifier,
                launchDate: $0.launchDate,
                isFinishedLaunching: $0.isFinishedLaunching,
                isTerminated: $0.isTerminated
            )
        }

        guard let target = CoreMonitorSingleInstancePolicy.handoffTarget(
            from: runningInstances,
            currentPID: currentPID
        ), let targetApplication = runningApplications.first(where: { $0.processIdentifier == target.processIdentifier }) else {
            return false
        }

        let request = CoreMonitorDashboardHandoffRequest(
            bundleIdentifier: bundleIdentifier,
            targetProcessIdentifier: target.processIdentifier
        )

        DistributedNotificationCenter.default().postNotificationName(
            Self.openDashboardRequestNotification,
            object: bundleIdentifier,
            userInfo: request.userInfo,
            deliverImmediately: true
        )
        _ = targetApplication.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        NSApp.setActivationPolicy(.accessory)
        DispatchQueue.main.async {
            NSApp.terminate(nil)
        }
        return true
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

        Self.logger.debug("Retrying initial dashboard presentation")
        openDashboard()
    }

    private func cancelInitialDashboardAttempts() {
        pendingInitialDashboardAttempts.forEach { $0.cancel() }
        pendingInitialDashboardAttempts.removeAll()
    }

    private func setDashboardActivationPolicy() {
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
            Self.logger.debug("Promoted activation policy to regular")
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
            Self.logger.debug("Restored activation policy to accessory")
        }
    }
}
