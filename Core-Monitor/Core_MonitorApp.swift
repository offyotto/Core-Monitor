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
        currentPID: pid_t,
        ownerPID: pid_t?
    ) -> CoreMonitorRunningInstance? {
        guard let ownerPID, ownerPID != currentPID else { return nil }
        // The kernel lock elects the owner. A launching owner is valid; the
        // sender retries until its dashboard observer can acknowledge delivery.
        return runningInstances.first { $0.processIdentifier == ownerPID && !$0.isTerminated }
    }
}

struct CoreMonitorDashboardHandoffRequest: Equatable {
    private static let bundleIdentifierKey = "bundleIdentifier"
    private static let targetProcessIdentifierKey = "targetProcessIdentifier"

    let bundleIdentifier: String
    let targetProcessIdentifier: pid_t
    let requestIdentifier: UUID
    let requesterProcessIdentifier: pid_t

    init(bundleIdentifier: String, targetProcessIdentifier: pid_t,
         requestIdentifier: UUID = UUID(), requesterProcessIdentifier: pid_t = ProcessInfo.processInfo.processIdentifier) {
        self.bundleIdentifier = bundleIdentifier
        self.targetProcessIdentifier = targetProcessIdentifier
        self.requestIdentifier = requestIdentifier
        self.requesterProcessIdentifier = requesterProcessIdentifier
    }

    var userInfo: [AnyHashable: Any] {
        [
            Self.bundleIdentifierKey: bundleIdentifier,
            Self.targetProcessIdentifierKey: NSNumber(value: targetProcessIdentifier),
            "requestIdentifier": requestIdentifier.uuidString,
            "requesterProcessIdentifier": NSNumber(value: requesterProcessIdentifier)
        ]
    }

    var notificationObject: String? { Self.notificationObject(for: userInfo) }

    static func notificationObject(for info: [AnyHashable: Any]?) -> String? {
        guard let info, let data = try? JSONSerialization.data(withJSONObject: info) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func notificationInfo(object: Any?, legacyUserInfo: [AnyHashable: Any]?) -> [AnyHashable: Any]? {
        if let object = object as? String, object.utf8.count <= 4_096,
           let data = object.data(using: .utf8),
           let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return info
        }
        return legacyUserInfo
    }

    static func acceptsAcknowledgement(
        userInfo: [AnyHashable: Any]?, bundleIdentifier: String,
        requestIdentifier: UUID, requesterPID: pid_t, ownerPID: pid_t
    ) -> Bool {
        userInfo?[bundleIdentifierKey] as? String == bundleIdentifier &&
        userInfo?["requestIdentifier"] as? String == requestIdentifier.uuidString &&
        (userInfo?["requesterProcessIdentifier"] as? NSNumber)?.int32Value == requesterPID &&
        (userInfo?[targetProcessIdentifierKey] as? NSNumber)?.int32Value == ownerPID
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
    private static let dashboardAcknowledgementNotification = Notification.Name("CoreMonitorDashboardAcknowledgement")
    private static let automaticTerminationReason = "Core Monitor keeps menu bar monitoring active."
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "CoreTools.Core-Monitor", category: "Startup")

    private lazy var coordinator = AppCoordinator()
    private lazy var startupManager = StartupManager()
    private var launchPresentation: CoreMonitorLaunchPresentation = .menuBarOnly

    private var menuBarController: MenuBarController?
    private var dashboardController: DashboardWindowController?
    private var hasPresentedInitialDashboard = false
    private var didBootstrapPrimaryInstance = false
    private var instanceLock: SingleInstanceLock?
    private var handoffTask: Task<Void, Never>?
    private var acknowledgedHandoff: UUID?
    private var handoffTargetPID: pid_t?
    private var lastDashboardRequestIdentifier: String?
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
        bootstrapPrimaryInstance()
    }

    private func bootstrapPrimaryInstance() {
        guard !didBootstrapPrimaryInstance else { return }
        didBootstrapPrimaryInstance = true
        CoreMonitorDefaultsMaintenance.purgeDeprecatedState()
        SettingsWindowManager.shared.configure(
            systemMonitor: coordinator.systemMonitor,
            fanController: coordinator.fanController,
            startupManager: startupManager
        )
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
        handoffTask?.cancel()
        cancelInitialDashboardAttempts()
        if didBootstrapPrimaryInstance { coordinator.stop() }
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
    private func openSettingsFromMenu(_ sender: Any?) {
        SettingsWindowManager.shared.show()
    }

    @objc
    private func openHelpFromMenu(_ sender: Any?) {
        NSWorkspace.shared.open(CoreMonitorShareKit.websiteURL)
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
        guard didBootstrapPrimaryInstance else { return }
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

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettingsFromMenu(_:)),
            keyEquivalent: ","
        )
        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.target = self
        appMenu.addItem(settingsItem)

        appMenu.addItem(.separator())

        let welcomeItem = NSMenuItem(
            title: "Welcome to Core Monitor…",
            action: #selector(reopenWelcomeGuideFromMenu(_:)),
            keyEquivalent: ""
        )
        welcomeItem.target = self
        appMenu.addItem(welcomeItem)

        let openHelpItem = NSMenuItem(
            title: "Core Monitor Help",
            action: #selector(openHelpFromMenu(_:)),
            keyEquivalent: ""
        )
        openHelpItem.target = self
        appMenu.addItem(openHelpItem)

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
            let info = CoreMonitorDashboardHandoffRequest.notificationInfo(
                object: notification.object, legacyUserInfo: notification.userInfo
            )
            guard CoreMonitorDashboardHandoffRequest.accepts(
                userInfo: info,
                expectedBundleIdentifier: bundleIdentifier,
                currentProcessIdentifier: ProcessInfo.processInfo.processIdentifier
            ) else {
                return
            }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let requestID = info?["requestIdentifier"] as? String
                if requestID == nil || requestID != lastDashboardRequestIdentifier {
                    openDashboard()
                    lastDashboardRequestIdentifier = requestID
                }
                if requestID != nil, dashboardController?.isDashboardVisible == true,
                   let object = CoreMonitorDashboardHandoffRequest.notificationObject(for: info) {
                    DistributedNotificationCenter.default().postNotificationName(
                        Self.dashboardAcknowledgementNotification, object: object,
                        userInfo: nil, deliverImmediately: true
                    )
                }
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
            // windowWillClose arrives before AppKit finishes hiding the window.
            DispatchQueue.main.async { [weak self] in
                self?.restoreAccessoryActivationPolicyIfNeeded()
            }
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
        guard CoreMonitorLaunchEnvironment.shouldHandleDuplicateLaunch(),
              let bundleIdentifier = Bundle.main.bundleIdentifier else { return false }
        let lock: SingleInstanceLock
        do {
            lock = SingleInstanceLock(fileURL: try SingleInstanceLock.fileURL(bundleIdentifier: bundleIdentifier))
            instanceLock = lock
            if try lock.acquire() { return false }
        } catch {
            NSApp.presentError(error)
            DispatchQueue.main.async { NSApp.terminate(nil) }
            return true
        }

        NSApp.setActivationPolicy(.accessory)
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let requestID = UUID()
        handoffTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let observer = DistributedNotificationCenter.default().addObserver(
                forName: Self.dashboardAcknowledgementNotification, object: nil, queue: .main
            ) { [weak self] notification in
                let info = CoreMonitorDashboardHandoffRequest.notificationInfo(
                    object: notification.object, legacyUserInfo: notification.userInfo
                )
                Task { @MainActor [weak self] in
                    guard let self, let ownerPID = handoffTargetPID,
                          CoreMonitorDashboardHandoffRequest.acceptsAcknowledgement(
                            userInfo: info, bundleIdentifier: bundleIdentifier,
                            requestIdentifier: requestID, requesterPID: currentPID, ownerPID: ownerPID
                          ) else { return }
                    acknowledgedHandoff = requestID
                }
            }
            defer { DistributedNotificationCenter.default().removeObserver(observer) }

            for _ in 0..<50 {
                guard !Task.isCancelled else { return }
                do {
                    // If the owner exits before acknowledging, take over its
                    // released kernel lock instead of leaving no running app.
                    if try lock.acquire() {
                        bootstrapPrimaryInstance()
                        return
                    }
                } catch {
                    NSApp.presentError(error)
                    NSApp.terminate(nil)
                    return
                }
                let applications = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
                let instances = applications.map {
                    CoreMonitorRunningInstance(processIdentifier: $0.processIdentifier, launchDate: $0.launchDate,
                                               isFinishedLaunching: $0.isFinishedLaunching, isTerminated: $0.isTerminated)
                }
                if let target = CoreMonitorSingleInstancePolicy.handoffTarget(
                    from: instances, currentPID: currentPID, ownerPID: lock.ownerPID
                ), let application = applications.first(where: { $0.processIdentifier == target.processIdentifier }) {
                    if handoffTargetPID != target.processIdentifier {
                        handoffTargetPID = target.processIdentifier
                        acknowledgedHandoff = nil
                    }
                    if acknowledgedHandoff == requestID {
                        NSApp.terminate(nil)
                        return
                    }
                    let request = CoreMonitorDashboardHandoffRequest(bundleIdentifier: bundleIdentifier,
                        targetProcessIdentifier: target.processIdentifier, requestIdentifier: requestID,
                        requesterProcessIdentifier: currentPID)
                    // App Sandbox requires a nil userInfo dictionary. The
                    // object is a bounded JSON string with the same routing IDs.
                    if let object = request.notificationObject {
                        DistributedNotificationCenter.default().postNotificationName(
                            Self.openDashboardRequestNotification, object: object,
                            userInfo: nil, deliverImmediately: true
                        )
                    }
                    if target.isFinishedLaunching {
                        _ = application.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                    }
                }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            let alert = NSAlert()
            alert.messageText = "Core Monitor is already running"
            alert.informativeText = "The running app has not responded. Switch to it, or quit it before opening Core Monitor again."
            alert.runModal()
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
