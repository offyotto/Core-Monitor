import SwiftUI
import AppKit

private struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            onResolve(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            onResolve(nsView.window)
        }
    }
}

@main
struct Core_MonitorApp: App {
    @StateObject private var coordinator    = AppCoordinator()
    @StateObject private var startupManager = StartupManager()

    // Holds the NSStatusItem + NSPopover for the menu bar panel
    @State private var menuBarController: MenuBarController?
    @State private var mainWindow: NSWindow?

    init() {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    var body: some Scene {
        WindowGroup {
            mainContent
                .onAppear {
                    // Spin up the menu bar controller once the coordinator is ready.
                    // Guard against double-init on hot reloads.
                    if menuBarController == nil {
                        menuBarController = MenuBarController(
                            systemMonitor:    coordinator.systemMonitor,
                            fanController:    coordinator.fanController,
                            updater:          AppUpdater.shared,
                            coreVisorManager: coordinator.coreVisorManager,
                            openDashboardAction: openDashboard,
                            openCoreVisorAction: openCoreVisor,
                            restoreAppTouchBarAction: coordinator.revertToAppTouchBar,
                            revertTouchBarAction: coordinator.revertToSystemTouchBar
                        )
                    }
                }
        }
    }

    private var mainContent: some View {
        ContentView(
            systemMonitor:    coordinator.systemMonitor,
            fanController:    coordinator.fanController,
            startupManager:   startupManager,
            coreVisorManager: coordinator.coreVisorManager,
            touchBarWidgetSettings: coordinator.touchBarWidgetSettings
        )
        .background(
            WindowAccessor { window in
                guard let window else { return }
                mainWindow = window
            }
        )
    }

    private func openDashboard() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.unhide(nil)

        if let mainWindow {
            mainWindow.makeKeyAndOrderFront(nil)
            mainWindow.orderFrontRegardless()
        } else if let fallbackWindow = NSApp.windows.first(where: { $0.styleMask.contains(.titled) }) {
            fallbackWindow.makeKeyAndOrderFront(nil)
            fallbackWindow.orderFrontRegardless()
        }
    }

    private func openCoreVisor() {
        openDashboard()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .openCoreVisorSheet, object: nil)
        }
    }
}
