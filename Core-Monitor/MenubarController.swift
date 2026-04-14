import AppKit
import SwiftUI

// MARK: - MenuBarItemKind
enum MenuBarItemKind: CaseIterable {
    case cpu, memory, disk, temperature

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

    init(
        systemMonitor:            SystemMonitor,
        fanController:            FanController,
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
                openDashboardAction:      openDashboardAction,
                restoreAppTouchBarAction: restoreAppTouchBarAction,
                revertTouchBarAction:     revertTouchBarAction
            )
            itemControllers.append(ctrl)
        }

        updateObserver = NotificationCenter.default.addObserver(
            forName: .systemMonitorDidUpdate,
            object:  nil,
            queue:   .main
        ) { [weak self] _ in
            self?.itemControllers.forEach { $0.refresh() }
        }
    }

    deinit {
        if let obs = updateObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }
}

// MARK: - SingleMenuBarItemController
final class SingleMenuBarItemController: NSObject, NSPopoverDelegate {

    let kind: MenuBarItemKind
    private var statusItem: NSStatusItem!
    private var popover:    NSPopover!

    private let systemMonitor:            SystemMonitor
    private let fanController:            FanController
    private let openDashboardAction:      () -> Void
    private let restoreAppTouchBarAction: () -> Void
    private let revertTouchBarAction:     () -> Void

    // Keep the hosting controller alive
    private var hostingController: NSHostingController<AnyView>?

    init(
        kind:                     MenuBarItemKind,
        systemMonitor:            SystemMonitor,
        fanController:            FanController,
        openDashboardAction:      @escaping () -> Void,
        restoreAppTouchBarAction: @escaping () -> Void,
        revertTouchBarAction:     @escaping () -> Void
    ) {
        self.kind                     = kind
        self.systemMonitor            = systemMonitor
        self.fanController            = fanController
        self.openDashboardAction      = openDashboardAction
        self.restoreAppTouchBarAction = restoreAppTouchBarAction
        self.revertTouchBarAction     = revertTouchBarAction
        super.init()
        setupStatusItem()
        setupPopover()
        refresh()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    func refresh() {
        updateStatusButton()
    }

    func updateStatusButton() {
        guard let button = statusItem.button else { return }

        let (labelText, labelColor) = statusLabel()

        let full = NSMutableAttributedString()

        if let iconAttachment = statusBarIconAttachment() {
            full.append(iconAttachment)
            full.append(NSAttributedString(string: " "))
        }

        full.append(NSAttributedString(
            string: labelText,
            attributes: [
                .foregroundColor: labelColor,
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
            ]
        ))

        button.attributedTitle = full
        button.imagePosition   = .noImage
    }

    // MARK: - Label content per kind

    private func statusLabel() -> (String, NSColor) {
        switch kind {

        case .cpu:
            let pct = Int(systemMonitor.cpuUsagePercent.rounded())
            let color: NSColor = pct > 80 ? .systemRed : pct > 50 ? .systemOrange : .labelColor
            return ("CPU \(pct)%", color)

        case .memory:
            let pct = Int(systemMonitor.memoryUsagePercent.rounded())
            let color: NSColor = pct > 85 ? .systemRed : pct > 70 ? .systemOrange : .labelColor
            return ("MEM \(pct)%", color)

        case .disk:
            let pct = Int(systemMonitor.diskStats.usagePercent.rounded())
            let color: NSColor = pct > 90 ? .systemRed : pct > 75 ? .systemOrange : .labelColor
            return ("SSD \(pct)%", color)

        case .temperature:
            if let t = systemMonitor.cpuTemperature {
                let ti = Int(t.rounded())
                let color: NSColor = t > 90 ? .systemRed : t > 70 ? .systemOrange : .labelColor
                return ("\(ti)°", color)
            }
            return ("—°", .secondaryLabelColor)
        }
    }

    private func statusBarIcon() -> NSImage? {
        let name: String
        switch kind {
        case .cpu:         name = "cpu"
        case .memory:      name = "memorychip"
        case .disk:        name = "internaldrive"
        case .temperature: name = "thermometer.medium"
        }

        let configuration = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
            .applying(.init(scale: .small))

        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
    }

    private func statusBarIconAttachment() -> NSAttributedString? {
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
        popover.contentSize       = NSSize(width: 320, height: 500)
        popover.behavior          = .transient
        popover.animates          = true
        popover.contentViewController = hc
        popover.delegate          = self
        popover.appearance        = nil
    }

    private func makePopoverView() -> AnyView {
        switch kind {
        case .cpu:
            return AnyView(
                CPUMenuPopoverView(systemMonitor: systemMonitor, openDashboardAction: { [weak self] in
                    self?.popover.performClose(nil); self?.openDashboardAction()
                })
            )
        case .memory:
            return AnyView(
                MemoryMenuPopoverView(systemMonitor: systemMonitor, openDashboardAction: { [weak self] in
                    self?.popover.performClose(nil); self?.openDashboardAction()
                })
            )
        case .disk:
            return AnyView(
                DiskMenuPopoverView(systemMonitor: systemMonitor, openDashboardAction: { [weak self] in
                    self?.popover.performClose(nil); self?.openDashboardAction()
                })
            )
        case .temperature:
            return AnyView(
                TemperatureMenuPopoverView(systemMonitor: systemMonitor, fanController: fanController, openDashboardAction: { [weak self] in
                    self?.popover.performClose(nil); self?.openDashboardAction()
                })
            )
        }
    }

    // MARK: - Toggle

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        guard let button = statusItem.button else { return }
        hostingController?.view.layoutSubtreeIfNeeded()
        let fit    = hostingController?.view.fittingSize ?? NSSize(width: 320, height: 500)
        let maxH   = max(300, min(640, (button.window?.screen?.visibleFrame.height ?? 900) - 100))
        let height = min(max(fit.height, 300), maxH)
        popover.contentSize = NSSize(width: 320, height: height)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    // MARK: - NSPopoverDelegate

    func popoverWillShow(_ notification: Notification) {
        statusItem.button?.isHighlighted = true
        DispatchQueue.main.async { [weak self] in
            guard let win = self?.popover.contentViewController?.view.window else { return }
            win.isOpaque = false
            win.backgroundColor = .clear
            win.hasShadow = true
            win.contentView?.wantsLayer = true
            win.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }

    func popoverDidClose(_ notification: Notification) {
        statusItem.button?.isHighlighted = false
    }
}

