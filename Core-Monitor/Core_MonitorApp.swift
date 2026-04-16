import AppKit
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

        Self.logger.debug("Showing dashboard window frame=\(String(describing: NSStringFromRect(window.frame)), privacy: .public)")
        showWindow(nil)
        promoteVisibility(of: window)
        Self.logger.notice("Dashboard show request completed visible=\(window.isVisible, privacy: .public) key=\(window.isKeyWindow, privacy: .public) main=\(window.isMainWindow, privacy: .public)")
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
    private static let openDashboardRequestNotification = Notification.Name("CoreMonitorOpenDashboardRequest")
    private static let automaticTerminationReason = "Core Monitor keeps menu bar monitoring active."
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "CoreTools.Core-Monitor", category: "Startup")

    private lazy var coordinator = AppCoordinator()
    private lazy var startupManager = StartupManager()

    private var menuBarController: MenuBarController?
    private var dashboardController: DashboardWindowController?
    private var hasPresentedInitialDashboard = false
    private var pendingInitialDashboardAttempts: [DispatchWorkItem] = []
    private var quitShortcutMonitor: Any?
    private var distributedDashboardRequestObserver: NSObjectProtocol?
    private let isRunningUnderXCTest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    private var shouldAutoOpenInitialDashboard = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        ProcessInfo.processInfo.disableAutomaticTermination(Self.automaticTerminationReason)
        guard handOffToRunningInstanceIfNeeded() == false else { return }
        CoreMonitorDefaultsMaintenance.purgeDeprecatedState()
        shouldAutoOpenInitialDashboard = WelcomeGuideProgress.shouldAutoOpenDashboardOnLaunch()
        Self.logger.notice("Launch finished shouldAutoOpenInitialDashboard=\(self.shouldAutoOpenInitialDashboard, privacy: .public)")
        installApplicationMenuIfNeeded()
        installQuitShortcutMonitorIfNeeded()
        installDistributedDashboardRequestObserverIfNeeded()
        if shouldAutoOpenInitialDashboard {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
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
        if let distributedDashboardRequestObserver {
            DistributedNotificationCenter.default().removeObserver(distributedDashboardRequestObserver)
            self.distributedDashboardRequestObserver = nil
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
        Self.logger.notice("Open dashboard requested activationPolicy=\(String(describing: NSApp.activationPolicy()), privacy: .public)")
        setDashboardActivationPolicy()
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

    private func installDistributedDashboardRequestObserverIfNeeded() {
        guard distributedDashboardRequestObserver == nil,
              let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return
        }

        distributedDashboardRequestObserver = DistributedNotificationCenter.default().addObserver(
            forName: Self.openDashboardRequestNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let requestedBundleIdentifier = notification.userInfo?["bundleIdentifier"] as? String
            guard requestedBundleIdentifier == nil || requestedBundleIdentifier == bundleIdentifier else {
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
        Self.logger.debug("Created dashboard window controller")
        return controller
    }

    private func presentInitialDashboardIfNeeded() {
        guard hasPresentedInitialDashboard == false else { return }
        guard shouldAutoOpenInitialDashboard else {
            Self.logger.debug("Skipping initial dashboard presentation")
            return
        }

        hasPresentedInitialDashboard = true
        openDashboard()
        scheduleInitialDashboardAttempts(after: [0.35, 1.0, 2.0])
    }

    private func handOffToRunningInstanceIfNeeded() -> Bool {
        guard isRunningUnderXCTest == false else { return false }
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

        DistributedNotificationCenter.default().postNotificationName(
            Self.openDashboardRequestNotification,
            object: nil,
            userInfo: ["bundleIdentifier": bundleIdentifier],
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
        guard shouldAutoOpenInitialDashboard else {
            cancelInitialDashboardAttempts()
            return
        }

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

    private func restoreAccessoryActivationPolicyIfNeeded() {
        guard dashboardController?.isDashboardVisible != true else { return }
        if NSApp.activationPolicy() != .accessory {
            NSApp.setActivationPolicy(.accessory)
            Self.logger.debug("Restored activation policy to accessory")
        }
    }
}
