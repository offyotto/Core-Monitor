import SwiftUI

@main
struct Core_MonitorApp: App {
    @StateObject private var coordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView(
                systemMonitor: coordinator.systemMonitor,
                fanController: coordinator.fanController
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
