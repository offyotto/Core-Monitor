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

@available(macOS 13.0, *)
@main
struct Core_MonitorApp: App {
    @StateObject private var coordinator    = AppCoordinator()
    @StateObject private var startupManager = StartupManager()

    @State private var menuBarController: MenuBarController?
    @State private var mainWindow: NSWindow?
    @State private var hasShownFirstLaunchDashboard = UserDefaults.standard.bool(forKey: Self.firstLaunchDashboardKey)

    private static let firstLaunchDashboardKey = "coremonitor.didShowFirstLaunchDashboard"

    init() {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    var body: some Scene {
        WindowGroup {
            mainContent
                .onAppear {
                    if menuBarController == nil {
                        menuBarController = MenuBarController(
                            systemMonitor:    coordinator.systemMonitor,
                            fanController:    coordinator.fanController,
                            openDashboardAction: openDashboard,
                            restoreAppTouchBarAction: coordinator.revertToAppTouchBar,
                            revertTouchBarAction: coordinator.revertToSystemTouchBar
                        )
                    }
                    DispatchQueue.main.async {
                        if hasShownFirstLaunchDashboard == false {
                            hasShownFirstLaunchDashboard = true
                            UserDefaults.standard.set(true, forKey: Self.firstLaunchDashboardKey)
                            openDashboard()
                        } else {
                            NSApp.setActivationPolicy(.accessory)
                            hideMainWindow()
                        }
                    }
                }
        }
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
    }

    private var mainContent: some View {
        ContentView(
            systemMonitor:    coordinator.systemMonitor,
            fanController:    coordinator.fanController,
            startupManager:   startupManager
        )
        .frame(minWidth: 820, minHeight: 560)
        .background(
            WindowAccessor { window in
                guard let window else { return }
                mainWindow = window
                window.minSize = NSSize(width: 820, height: 560)
                if window.frame.size == .zero || window.frame.size.width < 820 || window.frame.size.height < 560 {
                    window.setContentSize(NSSize(width: 980, height: 640))
                }
                if window.identifier == nil {
                    window.identifier = NSUserInterfaceItemIdentifier("CoreMonitorMainWindow")
                }
                window.isMovableByWindowBackground = true
                window.isOpaque = false
                window.backgroundColor = .clear
                window.hasShadow = true
                window.collectionBehavior = [.managed, .fullScreenPrimary]
                coordinator.attachTouchBar(to: window)
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
}
