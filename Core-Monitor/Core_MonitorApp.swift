import SwiftUI
import AppKit

private struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow?) -> Void
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { onResolve(view.window) }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { onResolve(nsView.window) }
    }
}

@main
struct Core_MonitorApp: App {
    @StateObject private var coordinator    = AppCoordinator()
    @StateObject private var startupManager = StartupManager()

    @State private var menuBarController: MenuBarController?
    @State private var mainWindow: NSWindow?

    init() {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    var body: some Scene {
        WindowGroup {
            mainContent
                .onAppear {
                    // Run as accessory so no Dock icon shows on launch
                    NSApp.setActivationPolicy(.accessory)

                    if menuBarController == nil {
                        menuBarController = MenuBarController(
                            systemMonitor:    coordinator.systemMonitor,
                            fanController:    coordinator.fanController,
                            updater:          AppUpdater.shared,
                            openDashboardAction: openDashboard,
                            restoreAppTouchBarAction: coordinator.revertToAppTouchBar,
                            revertTouchBarAction: coordinator.revertToSystemTouchBar
                        )
                    }
                    // Hide window on first launch — app lives in menu bar
                    DispatchQueue.main.async { hideMainWindow() }
                }
        }
        .windowStyle(.hiddenTitleBar)
    }

    private var mainContent: some View {
        ContentView(
            systemMonitor:    coordinator.systemMonitor,
            fanController:    coordinator.fanController,
            startupManager:   startupManager,
            touchBarWidgetSettings: coordinator.touchBarWidgetSettings
        )
        .frame(minWidth: 740, minHeight: 520)
        .background(
            WindowAccessor { window in
                guard let window else { return }
                mainWindow = window
                window.minSize = NSSize(width: 740, height: 520)
                if window.identifier == nil {
                    window.identifier = NSUserInterfaceItemIdentifier("CoreMonitorMainWindow")
                }
                // Frameless look – no native titlebar chrome
                window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.titlebarSeparatorStyle = .none
                window.isMovableByWindowBackground = true
                window.isOpaque = false
                window.backgroundColor = .clear
                window.hasShadow = true
                // Position traffic lights so they sit at the right spot over our custom header
                positionTrafficLights(in: window)
            }
        )
    }

    // MARK: Window management

    private func hideMainWindow() {
        if let w = mainWindow {
            w.orderOut(nil)
        } else if let w = NSApp.windows.first(where: { $0.styleMask.contains(.titled) }) {
            w.orderOut(nil)
        }
    }

    func openDashboard() {
        // Switch back to regular policy so the window can become key
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if let w = mainWindow {
            w.makeKeyAndOrderFront(nil)
            w.orderFrontRegardless()
        } else if let w = NSApp.windows.first(where: { $0.styleMask.contains(.titled) }) {
            w.makeKeyAndOrderFront(nil)
            w.orderFrontRegardless()
        }
    }

    // MARK: Traffic lights

    private func positionTrafficLights(in window: NSWindow) {
        guard
            let close = window.standardWindowButton(.closeButton),
            let mini  = window.standardWindowButton(.miniaturizeButton),
            let zoom  = window.standardWindowButton(.zoomButton),
            let container = close.superview
        else { return }

        let top: CGFloat    = 21
        let left: CGFloat   = 20
        let spacing: CGFloat = 12
        let size = close.frame.size
        let y    = container.bounds.height - size.height - top

        for (i, btn) in [close, mini, zoom].enumerated() {
            btn.setFrameOrigin(NSPoint(x: left + CGFloat(i) * (size.width + spacing), y: y))
        }
    }
}
