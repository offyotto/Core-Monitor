import AppKit
import SwiftUI

// MARK: - MenuBarController
// Owns the NSStatusItem and NSPopover. Replaces MenuBarExtra entirely.
final class MenuBarController: NSObject, NSPopoverDelegate {

    private var statusItem: NSStatusItem!
    private var popover:    NSPopover!

    private let systemMonitor:    SystemMonitor
    private let fanController:    FanController
    private let updater:          AppUpdater
    private let coreVisorManager: CoreVisorManager
    private let openDashboardAction: () -> Void
    private let openCoreVisorAction: () -> Void
    private let restoreAppTouchBarAction: () -> Void
    private let revertTouchBarAction: () -> Void

    // Keep the hosting controller alive so @ObservedObject stays connected
    private var hostingController: NSHostingController<MenuBarMenuView>?

    // Monitor label update timer
    private var labelUpdateCancellable: Any?

    init(
        systemMonitor:    SystemMonitor,
        fanController:    FanController,
        updater:          AppUpdater,
        coreVisorManager: CoreVisorManager,
        openDashboardAction: @escaping () -> Void,
        openCoreVisorAction: @escaping () -> Void,
        restoreAppTouchBarAction: @escaping () -> Void,
        revertTouchBarAction: @escaping () -> Void
    ) {
        self.systemMonitor    = systemMonitor
        self.fanController    = fanController
        self.updater          = updater
        self.coreVisorManager = coreVisorManager
        self.openDashboardAction = openDashboardAction
        self.openCoreVisorAction = openCoreVisorAction
        self.restoreAppTouchBarAction = restoreAppTouchBarAction
        self.revertTouchBarAction = revertTouchBarAction
        super.init()
        setupStatusItem()
        setupPopover()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        // Seed the label immediately; it refreshes via the hosting view's own @ObservedObject
        updateStatusButton()

        // Refresh the button label whenever SystemMonitor publishes
        labelUpdateCancellable = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SystemMonitorDidUpdate"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateStatusButton()
        }
    }

    private func updateStatusButton() {
        guard let button = statusItem.button else { return }

        // Build the attributed string to match MenuBarStatusLabel visually
        let label = compactMetric()
        let color  = metricNSColor()

        let fanImage = NSImage(systemSymbolName: "fanblades.fill", accessibilityDescription: nil)
        let imageAttachment = NSTextAttachment()
        imageAttachment.image = fanImage

        let full = NSMutableAttributedString()

        // Use a proper NSImage for the icon on the button itself
        let labelAttr = NSAttributedString(
            string: " \(label)",
            attributes: [
                .foregroundColor: color,
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
            ]
        )
        full.append(labelAttr)

        button.attributedTitle = full

        // Fan icon as the button image (left side)
        if let img = NSImage(systemSymbolName: "fanblades.fill", accessibilityDescription: nil) {
            img.isTemplate = false
            let tinted = img.tinted(with: fanNSColor())
            button.image = tinted
            button.imagePosition = .imageLeft
        }
    }

    private func setupPopover() {
        let contentView = MenuBarMenuView(
            systemMonitor:    systemMonitor,
            fanController:    fanController,
            updater:          updater,
            coreVisorManager: coreVisorManager,
            openDashboardAction: { [weak self] in
                self?.popover.performClose(nil)
                self?.openDashboardAction()
            },
            openCoreVisorAction: { [weak self] in
                self?.popover.performClose(nil)
                self?.openCoreVisorAction()
            },
            restoreAppTouchBarAction: { [weak self] in
                self?.popover.performClose(nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self?.restoreAppTouchBarAction()
                }
            },
            revertTouchBarAction: { [weak self] in
                self?.popover.performClose(nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self?.revertTouchBarAction()
                }
            }
        )

        let hc = NSHostingController(rootView: contentView)
        // Allow the hosting controller to size itself naturally
        hc.view.translatesAutoresizingMaskIntoConstraints = true
        self.hostingController = hc

        popover = NSPopover()
        popover.contentSize       = NSSize(width: 310, height: 500)
        popover.behavior          = .transient   // closes on outside click, no 2s timeout
        popover.animates          = true
        popover.contentViewController = hc
        popover.delegate          = self

        // Use the system HUD appearance so it blends with the dark menu bar panel look
        popover.appearance = NSAppearance(named: .vibrantDark)
    }

    // MARK: - Toggle

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            guard let button = statusItem.button else { return }

            // Recalculate natural content height before showing
            let fittingSize = hostingController?.view.fittingSize ?? NSSize(width: 310, height: 500)
            let height = min(max(fittingSize.height, 200), 700)
            popover.contentSize = NSSize(width: 310, height: height)

            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - NSPopoverDelegate

    func popoverWillShow(_ notification: Notification) {
        statusItem.button?.isHighlighted = true
    }

    func popoverDidClose(_ notification: Notification) {
        statusItem.button?.isHighlighted = false
    }

    // MARK: - Metric helpers (mirrors MenuBarStatusLabel logic)

    private func compactMetric() -> String {
        if let temp  = systemMonitor.cpuTemperature               { return "\(Int(temp.rounded()))°"           }
        if let watts = systemMonitor.totalSystemWatts              { return String(format: "%.0fW", abs(watts)) }
        if let rpm   = systemMonitor.fanSpeeds.first, rpm > 0      { return "\(rpm)"                           }
        return "\(Int(systemMonitor.cpuUsagePercent.rounded()))%"
    }

    private func metricNSColor() -> NSColor {
        if let temp = systemMonitor.cpuTemperature {
            if temp > 90 { return .systemRed    }
            if temp > 70 { return .systemOrange }
        }
        return NSColor(red: 1.0, green: 0.72, blue: 0.18, alpha: 1)
    }

    private func fanNSColor() -> NSColor {
        let load = systemMonitor.cpuUsagePercent
        if load > 80 { return .systemRed    }
        if load > 50 { return .systemOrange }
        return NSColor(red: 1.0, green: 0.72, blue: 0.18, alpha: 1)
    }
}

// MARK: - NSImage tint helper
private extension NSImage {
    func tinted(with color: NSColor) -> NSImage {
        let copy = self.copy() as! NSImage
        copy.lockFocus()
        color.set()
        NSRect(origin: .zero, size: copy.size).fill(using: .sourceAtop)
        copy.unlockFocus()
        copy.isTemplate = false
        return copy
    }
}
