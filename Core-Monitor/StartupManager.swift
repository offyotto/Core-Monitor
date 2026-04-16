import Foundation
import Combine
import ServiceManagement

@MainActor
final class StartupManager: ObservableObject {
    @Published var isEnabled: Bool = false
    @Published var errorMessage: String?

    init() {
        refreshState()
    }

    func refreshState() {
        if #available(macOS 13.0, *) {
            let status = SMAppService.mainApp.status
            switch status {
            case .enabled:
                isEnabled = true
                errorMessage = nil
            case .requiresApproval:
                isEnabled = false
                errorMessage = "Launch at Login needs approval in System Settings > General > Login Items."
            case .notFound:
                isEnabled = false
                errorMessage = "The Core-Monitor login item was not found. Turn Launch at Login off, then on again."
            case .notRegistered:
                isEnabled = false
                errorMessage = nil   // not registered yet — no error, just off
            @unknown default:
                isEnabled = false
                errorMessage = nil
            }
        } else {
            isEnabled = false
            errorMessage = "Launch at login requires macOS 13 or newer."
        }
    }

    func setEnabled(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else { return }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = startupErrorMessage(for: error)
        }

        refreshState()
    }

    private func startupErrorMessage(for error: Error) -> String {
        let nsError = error as NSError
        let description = nsError.localizedDescription.lowercased()
        if description.contains("authorization") || description.contains("permission") {
            return "Permission denied. Open System Settings > General > Login Items to allow Core-Monitor."
        }
        if description.contains("already") {
            return "Login item is already registered."
        }
        return nsError.localizedDescription
    }
}

@MainActor
struct DashboardNavigationRoute: Equatable {
    let id: UUID
    let selection: SidebarItem
}

@MainActor
final class DashboardNavigationRouter: ObservableObject {
    static let shared = DashboardNavigationRouter()

    @Published private(set) var route: DashboardNavigationRoute?

    func open(_ selection: SidebarItem) {
        route = DashboardNavigationRoute(id: UUID(), selection: selection)
    }

    func consume(_ route: DashboardNavigationRoute) -> SidebarItem? {
        guard self.route?.id == route.id else { return nil }
        self.route = nil
        return route.selection
    }
}
