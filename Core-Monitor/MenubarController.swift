import AppKit
import Combine
import SwiftUI

// MARK: - MenuBarItemKind
enum MenuBarItemKind: CaseIterable {
    case cpu, fan, memory, network, disk, temperature

    // Same glyph per metric as the dashboard sidebar, so the menu bar and the
    // main window speak one visual language.
    var systemImageName: String {
        switch self {
        case .cpu:
            return "cpu"
        case .fan:
            return "fan"
        case .memory:
            return "memorychip"
        case .network:
            return "network"
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
        case .fan:
            return "Fan"
        case .memory:
            return "Memory"
        case .network:
            return "Network"
        case .disk:
            return "Disk"
        case .temperature:
            return "Temperature"
        }
    }

    var defaultsKey: String {
        switch self {
        case .cpu:         return "menubar.cpu.enabled"
        case .fan:         return "menubar.fan.enabled"
        case .memory:      return "menubar.memory.enabled"
        case .network:     return "menubar.network.enabled"
        case .disk:        return "menubar.disk.enabled"
        case .temperature: return "menubar.temperature.enabled"
        }
    }
}

// MARK: - MenuBarController  (public facade — same init signature as before)
@MainActor
final class MenuBarController: NSObject {
    private var itemControllers: [SingleMenuBarItemController] = []
    private var snapshotCancellable: AnyCancellable?
    private var settingsObserver: Any?

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

        snapshotCancellable = systemMonitor.$snapshot
            .map(\.sampledAt)
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.scheduleRefreshAllItems()
            }

        settingsObserver = NotificationCenter.default.addObserver(
            forName: .menuBarSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleRefreshAllItems()
        }
    }

    deinit {
        if let obs = settingsObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    private nonisolated func scheduleRefreshAllItems() {
        Task { @MainActor [weak self] in
            self?.refreshAllItems()
        }
    }

    private func refreshAllItems() {
        itemControllers.forEach { $0.refresh() }
    }
}

// MARK: - SingleMenuBarItemController
@MainActor
final class SingleMenuBarItemController: NSObject, NSPopoverDelegate {
    private enum StatusTone: Equatable {
        case normal
        case warning
        case critical
        case secondary

        // Menu bar extras stay monochrome like the system's own items; severity
        // color lives in the popovers and the dashboard, not up here.
        var color: NSColor {
            switch self {
            case .normal, .warning, .critical:
                return .labelColor
            case .secondary:
                return .secondaryLabelColor
            }
        }
    }

    private struct StatusButtonState: Equatable {
        let isVisible: Bool
        let labelText: String
        let tone: StatusTone
    }

    private static let labelFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
    let kind: MenuBarItemKind
    private var statusItem: NSStatusItem!
    private var popover: NSPopover?

    private let systemMonitor:            SystemMonitor
    private let fanController:            FanController
    private let openDashboardAction:      () -> Void
    private let restoreAppTouchBarAction: () -> Void
    private let revertTouchBarAction:     () -> Void

    // Keep the hosting controller alive
    private var hostingController: NSHostingController<AnyView>?
    private var lastStatusState: StatusButtonState?

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
        refresh()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        // A template image next to a plain value label renders like a native
        // status item: the system handles tinting, spacing, and appearance.
        button.image = statusBarIcon()
        button.imagePosition = .imageLeading
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

        // The icon stays a system-tinted template image; only the value text
        // carries a tone color, and only when something needs attention.
        button.attributedTitle = NSAttributedString(
            string: " " + state.labelText,
            attributes: [
                .foregroundColor: state.tone.color,
                .font: Self.labelFont
            ]
        )
        lastStatusState = state
    }

    // MARK: - Label content per kind

    private func statusButtonState() -> StatusButtonState {
        let isVisible = MenuBarSettings.shared.isEnabled(kind)
        let label = statusLabel()
        return StatusButtonState(
            isVisible: isVisible,
            labelText: label.text,
            tone: label.tone
        )
    }

    // The template icon already names the metric, so the label is just the
    // value — icon + number, like the system battery and Wi-Fi items.
    private func statusLabel() -> (text: String, tone: StatusTone) {
        switch kind {

        case .cpu:
            let pct = Int(systemMonitor.cpuUsagePercent.rounded())
            let tone: StatusTone = pct > 80 ? .critical : pct > 50 ? .warning : .normal
            return ("\(pct)%", tone)

        case .fan:
            let speeds = systemMonitor.fanSpeeds.filter { $0 > 0 }
            guard let highestRPM = speeds.max() else {
                return ("—", .secondary)
            }

            let utilization = Double(highestRPM) / Double(max(fanController.maxSpeed, 1))
            let tone: StatusTone = utilization > 0.85 ? .critical : utilization > 0.6 ? .warning : .normal
            return (ReadingFormat.rpmShort(highestRPM), tone)

        case .memory:
            let pct = Int(systemMonitor.memoryUsagePercent.rounded())
            let tone: StatusTone = pct > 85 ? .critical : pct > 70 ? .warning : .normal
            return ("\(pct)%", tone)

        case .network:
            let download = systemMonitor.networkStats.downloadBytesPerSec
            let upload = systemMonitor.networkStats.uploadBytesPerSec
            let dominant = max(download, upload)
            let arrow = download >= upload ? "↓" : "↑"
            let label = NetworkThroughputFormatter
                .abbreviatedRate(bytesPerSecond: dominant)
                .replacingOccurrences(of: " ", with: "")
            let tone: StatusTone = dominant < 1_000 ? .secondary : .normal
            return ("\(arrow)\(label)", tone)

        case .disk:
            let pct = Int(systemMonitor.diskStats.usagePercent.rounded())
            let tone: StatusTone = pct > 90 ? .critical : pct > 75 ? .warning : .normal
            return ("\(pct)%", tone)

        case .temperature:
            if let t = systemMonitor.cpuTemperature {
                let ti = Int(t.rounded())
                let safetyTemperature = systemMonitor.cpuSafetyTemperature ?? t
                let tone: StatusTone = safetyTemperature > 90 ? .critical : safetyTemperature > 70 ? .warning : .normal
                return ("\(ti)°", tone)
            }
            return ("—°", .secondary)
        }
    }

    private func statusBarIcon() -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        let image = NSImage(systemSymbolName: kind.systemImageName, accessibilityDescription: kind.title)?
            .withSymbolConfiguration(configuration)
        // Template rendering lets the menu bar tint the glyph for light/dark
        // appearance and reduced-transparency wallpapers.
        image?.isTemplate = true
        return image
    }

    // MARK: - Popover setup

    private func setupPopover() {
        let rootView = MetricPopoverView(
            kind: kind,
            systemMonitor: systemMonitor,
            fanController: fanController,
            openSection: { [weak self] section in
                self?.popover?.performClose(nil)
                self?.openSelectionFromPopover(section)
            }
        )
        let hc = NSHostingController(rootView: AnyView(rootView))
        hc.view.translatesAutoresizingMaskIntoConstraints = true
        self.hostingController = hc

        popover = NSPopover()
        popover?.contentSize = NSSize(width: 300, height: 400)
        popover?.behavior = .transient
        popover?.animates = true
        popover?.contentViewController = hc
        popover?.delegate = self
        popover?.appearance = nil
    }

    private func openSelectionFromPopover(_ selection: MonitorSection) {
        DashboardNavigationRouter.shared.open(selection)
        openDashboardAction()
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
        let fit    = hostingController?.view.fittingSize ?? NSSize(width: 300, height: 400)
        let maxH   = max(240, min(640, (button.window?.screen?.visibleFrame.height ?? 900) - 100))
        let height = min(max(fit.height, 240), maxH)
        popover?.contentSize = NSSize(width: 300, height: height)
        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover?.contentViewController?.view.window?.makeKey()
    }

    // MARK: - NSPopoverDelegate

    func popoverWillShow(_ notification: Notification) {
        systemMonitor.setInteractiveMonitoringEnabled(true, reason: "menubar.\(kind.title)")
        statusItem.button?.isHighlighted = true
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
