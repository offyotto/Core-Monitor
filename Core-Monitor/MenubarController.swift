import AppKit
import Combine
import SwiftUI

// MARK: - MenuBarItemKind
enum MenuBarItemKind: CaseIterable {
    case cpu, memory, disk, temperature

    var systemImageName: String {
        switch self {
        case .cpu:
            return "cpu"
        case .memory:
            return "memorychip"
        case .disk:
            return "internaldrive"
        case .temperature:
            return "thermometer.medium"
        }
    }

    var title: String {
        switch self {
        case .cpu:
            return "CPU"
        case .memory:
            return "Memory"
        case .disk:
            return "Disk"
        case .temperature:
            return "Temperature"
        }
    }

    var defaultsKey: String {
        switch self {
        case .cpu:         return "menubar.cpu.enabled"
        case .memory:      return "menubar.memory.enabled"
        case .disk:        return "menubar.disk.enabled"
        case .temperature: return "menubar.temperature.enabled"
        }
    }
}

// MARK: - MenuBarController  (public facade — same init signature as before)
final class MenuBarController: NSObject {
    private var itemControllers: [SingleMenuBarItemController] = []
    private var updateObserver: Any?
    private var settingsObserver: Any?
    private var alertCancellable: AnyCancellable?

    init(
        systemMonitor:            SystemMonitor,
        fanController:            FanController,
        alertManager:             AlertManager,
        openDashboardAction:      @escaping () -> Void,
        restoreAppTouchBarAction: @escaping () -> Void,
        revertTouchBarAction:     @escaping () -> Void
    ) {
        super.init()

        for kind in MenuBarItemKind.allCases {
            let ctrl = SingleMenuBarItemController(
                kind:                     kind,
                systemMonitor:            systemMonitor,
                fanController:            fanController,
                alertManager:             alertManager,
                openDashboardAction:      openDashboardAction,
                restoreAppTouchBarAction: restoreAppTouchBarAction,
                revertTouchBarAction:     revertTouchBarAction
            )
            itemControllers.append(ctrl)
        }

        updateObserver = NotificationCenter.default.addObserver(
            forName: .systemMonitorDidUpdate,
            object:  systemMonitor,
            queue:   .main
        ) { [weak self] _ in
            self?.itemControllers.forEach { $0.refresh() }
        }

        settingsObserver = NotificationCenter.default.addObserver(
            forName: .menuBarSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.itemControllers.forEach { $0.refresh() }
        }

        alertCancellable = alertManager.$activeAlerts
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.itemControllers.forEach { $0.refresh() }
            }
    }

    deinit {
        if let obs = updateObserver {
            NotificationCenter.default.removeObserver(obs)
        }
        if let obs = settingsObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }
}

// MARK: - SingleMenuBarItemController
final class SingleMenuBarItemController: NSObject, NSPopoverDelegate {
    private enum StatusTone: Equatable {
        case normal
        case warning
        case critical
        case secondary

        var color: NSColor {
            switch self {
            case .normal:
                return .labelColor
            case .warning:
                return .systemOrange
            case .critical:
                return .systemRed
            case .secondary:
                return .secondaryLabelColor
            }
        }
    }

    private struct StatusButtonState: Equatable {
        let isVisible: Bool
        let labelText: String
        let tone: StatusTone
        let hasCriticalAlert: Bool
    }

    private static let labelFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
    private static let alertFont = NSFont.systemFont(ofSize: 10, weight: .bold)

    let kind: MenuBarItemKind
    private var statusItem: NSStatusItem!
    private var popover: NSPopover?

    private let systemMonitor:            SystemMonitor
    private let fanController:            FanController
    private let alertManager:             AlertManager
    private let openDashboardAction:      () -> Void
    private let restoreAppTouchBarAction: () -> Void
    private let revertTouchBarAction:     () -> Void

    // Keep the hosting controller alive
    private var hostingController: NSHostingController<AnyView>?
    private var cachedIconAttachment: NSAttributedString?
    private var lastStatusState: StatusButtonState?

    init(
        kind:                     MenuBarItemKind,
        systemMonitor:            SystemMonitor,
        fanController:            FanController,
        alertManager:             AlertManager,
        openDashboardAction:      @escaping () -> Void,
        restoreAppTouchBarAction: @escaping () -> Void,
        revertTouchBarAction:     @escaping () -> Void
    ) {
        self.kind                     = kind
        self.systemMonitor            = systemMonitor
        self.fanController            = fanController
        self.alertManager             = alertManager
        self.openDashboardAction      = openDashboardAction
        self.restoreAppTouchBarAction = restoreAppTouchBarAction
        self.revertTouchBarAction     = revertTouchBarAction
        super.init()
        setupStatusItem()
        refresh()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .noImage
        cachedIconAttachment = makeStatusBarIconAttachment()
    }

    func refresh() {
        updateStatusButton()
    }

    func updateStatusButton() {
        let state = statusButtonState()
        if statusItem.isVisible != state.isVisible {
            statusItem.isVisible = state.isVisible
        }
        guard state.isVisible, let button = statusItem.button else {
            lastStatusState = state
            return
        }
        guard lastStatusState != state else { return }

        let full = NSMutableAttributedString()

        if let iconAttachment = cachedIconAttachment {
            full.append(iconAttachment)
            full.append(NSAttributedString(string: " "))
        }

        full.append(NSAttributedString(
            string: state.labelText,
            attributes: [
                .foregroundColor: state.tone.color,
                .font: Self.labelFont
            ]
        ))

        if state.hasCriticalAlert {
            full.append(NSAttributedString(string: " "))
            full.append(NSAttributedString(
                string: "●",
                attributes: [
                    .foregroundColor: NSColor.systemRed,
                    .font: Self.alertFont
                ]
            ))
        }

        button.attributedTitle = full
        lastStatusState = state
    }

    // MARK: - Label content per kind

    private func statusButtonState() -> StatusButtonState {
        let isVisible = MenuBarSettings.shared.isEnabled(kind)
        let label = statusLabel()
        return StatusButtonState(
            isVisible: isVisible,
            labelText: label.text,
            tone: label.tone,
            hasCriticalAlert: alertManager.hasCriticalAlert
        )
    }

    private func statusLabel() -> (text: String, tone: StatusTone) {
        switch kind {

        case .cpu:
            let pct = Int(systemMonitor.cpuUsagePercent.rounded())
            let tone: StatusTone = pct > 80 ? .critical : pct > 50 ? .warning : .normal
            return ("CPU \(pct)%", tone)

        case .memory:
            let pct = Int(systemMonitor.memoryUsagePercent.rounded())
            let tone: StatusTone = pct > 85 ? .critical : pct > 70 ? .warning : .normal
            return ("MEM \(pct)%", tone)

        case .disk:
            let pct = Int(systemMonitor.diskStats.usagePercent.rounded())
            let tone: StatusTone = pct > 90 ? .critical : pct > 75 ? .warning : .normal
            return ("SSD \(pct)%", tone)

        case .temperature:
            if let t = systemMonitor.cpuTemperature {
                let ti = Int(t.rounded())
                let tone: StatusTone = t > 90 ? .critical : t > 70 ? .warning : .normal
                return ("\(ti)°", tone)
            }
            return ("—°", .secondary)
        }
    }

    private func statusBarIcon() -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
            .applying(.init(scale: .small))

        return NSImage(systemSymbolName: kind.systemImageName, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
    }

    private func makeStatusBarIconAttachment() -> NSAttributedString? {
        guard let icon = statusBarIcon() else { return nil }

        let targetHeight: CGFloat = 11
        let sourceSize = icon.size
        let aspectRatio = sourceSize.height > 0 ? (sourceSize.width / sourceSize.height) : 1
        let targetWidth = max(9, min(16, targetHeight * aspectRatio))

        let attachment = NSTextAttachment()
        attachment.image = icon
        attachment.bounds = CGRect(x: 0, y: -1, width: targetWidth, height: targetHeight)
        return NSAttributedString(attachment: attachment)
    }

    // MARK: - Popover setup

    private func setupPopover() {
        let rootView = makePopoverView()
        let hc = NSHostingController(rootView: rootView)
        hc.view.translatesAutoresizingMaskIntoConstraints = true
        hc.view.wantsLayer = true
        hc.view.layer?.backgroundColor = NSColor.clear.cgColor
        self.hostingController = hc

        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 500)
        popover?.behavior = .transient
        popover?.animates = true
        popover?.contentViewController = hc
        popover?.delegate = self
        popover?.appearance = nil
    }

    private func makePopoverView() -> AnyView {
        switch kind {
        case .cpu:
            return AnyView(
                CPUMenuPopoverView(systemMonitor: systemMonitor, alertManager: alertManager, openDashboardAction: { [weak self] in
                    self?.popover?.performClose(nil); self?.openDashboardAction()
                })
            )
        case .memory:
            return AnyView(
                MemoryMenuPopoverView(systemMonitor: systemMonitor, alertManager: alertManager, openDashboardAction: { [weak self] in
                    self?.popover?.performClose(nil); self?.openDashboardAction()
                })
            )
        case .disk:
            return AnyView(
                DiskMenuPopoverView(systemMonitor: systemMonitor, alertManager: alertManager, openDashboardAction: { [weak self] in
                    self?.popover?.performClose(nil); self?.openDashboardAction()
                })
            )
        case .temperature:
            return AnyView(
                TemperatureMenuPopoverView(systemMonitor: systemMonitor, fanController: fanController, alertManager: alertManager, openDashboardAction: { [weak self] in
                    self?.popover?.performClose(nil); self?.openDashboardAction()
                })
            )
        }
    }

    private func ensurePopover() {
        guard popover == nil else { return }
        setupPopover()
    }

    // MARK: - Toggle

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover?.isShown == true {
            popover?.performClose(sender)
            return
        }
        guard let button = statusItem.button else { return }
        ensurePopover()
        hostingController?.view.layoutSubtreeIfNeeded()
        let fit    = hostingController?.view.fittingSize ?? NSSize(width: 320, height: 500)
        let maxH   = max(300, min(640, (button.window?.screen?.visibleFrame.height ?? 900) - 100))
        let height = min(max(fit.height, 300), maxH)
        popover?.contentSize = NSSize(width: 320, height: height)
        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover?.contentViewController?.view.window?.makeKey()
    }

    // MARK: - NSPopoverDelegate

    func popoverWillShow(_ notification: Notification) {
        systemMonitor.setInteractiveMonitoringEnabled(true, reason: "menubar.\(kind.title)")
        statusItem.button?.isHighlighted = true
        DispatchQueue.main.async { [weak self] in
            guard let win = self?.popover?.contentViewController?.view.window else { return }
            win.isOpaque = false
            win.backgroundColor = .clear
            win.hasShadow = true
            win.contentView?.wantsLayer = true
            win.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }

    func popoverDidClose(_ notification: Notification) {
        systemMonitor.setInteractiveMonitoringEnabled(false, reason: "menubar.\(kind.title)")
        statusItem.button?.isHighlighted = false
        popover?.contentViewController = nil
        popover?.delegate = nil
        hostingController = nil
        popover = nil
    }
}
