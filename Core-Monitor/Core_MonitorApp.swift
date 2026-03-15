import SwiftUI
import AppKit

@main
struct Core_MonitorApp: App {
    private enum SceneID {
        static let mainWindow = "main"
    }

    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var startupManager = StartupManager()

    init() {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    var body: some Scene {
        WindowGroup(id: SceneID.mainWindow) {
            ContentView(
                systemMonitor: coordinator.systemMonitor,
                fanController: coordinator.fanController,
                startupManager: startupManager
            )
        }
        .defaultSize(width: 920, height: 620)

        MenuBarExtra {
            MenuBarMenuView(systemMonitor: coordinator.systemMonitor, fanController: coordinator.fanController)
        } label: {
            MenuBarStatusLabel(systemMonitor: coordinator.systemMonitor)
        }
        .menuBarExtraStyle(.menu)
    }
}
