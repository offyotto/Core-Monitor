import Foundation
import Combine
import ServiceManagement

enum LaunchAtLoginState: Equatable {
    case enabled
    case disabled
    case requiresApproval
    case notFound
    case unsupported
}

enum LaunchAtLoginAction: Equatable {
    case enable
    case openSystemSettings
}

enum LaunchAtLoginStatusTone: Equatable {
    case positive
    case neutral
    case caution
}

struct LaunchAtLoginStatusSummary: Equatable {
    let badge: String
    let detail: String
    let tone: LaunchAtLoginStatusTone
    let action: LaunchAtLoginAction?
    let actionTitle: String?

    static func make(status: LaunchAtLoginState, errorMessage: String?) -> LaunchAtLoginStatusSummary {
        switch status {
        case .enabled:
            if let errorMessage, errorMessage.isEmpty == false {
                return .init(
                    badge: "Enabled",
                    detail: errorMessage,
                    tone: .caution,
                    action: settingsAction(for: errorMessage),
                    actionTitle: settingsActionTitle(for: errorMessage)
                )
            }

            return .init(
                badge: "Enabled",
                detail: "Core Monitor will relaunch after sign-in so menu bar monitoring stays available.",
                tone: .positive,
                action: nil,
                actionTitle: nil
            )

        case .disabled:
            if let errorMessage, errorMessage.isEmpty == false {
                return .init(
                    badge: "Needs Attention",
                    detail: errorMessage,
                    tone: .caution,
                    action: settingsAction(for: errorMessage),
                    actionTitle: settingsActionTitle(for: errorMessage)
                )
            }

            return .init(
                badge: "Optional",
                detail: "Enable this if you rely on Core Monitor staying present in the menu bar after restart.",
                tone: .neutral,
                action: .enable,
                actionTitle: "Enable"
            )

        case .requiresApproval:
            return .init(
                badge: "Approval Needed",
                detail: errorMessage ?? "Launch at Login needs approval in System Settings > General > Login Items.",
                tone: .caution,
                action: .openSystemSettings,
                actionTitle: "Open Login Items"
            )

        case .notFound:
            return .init(
                badge: "Needs Attention",
                detail: errorMessage ?? "The Core-Monitor login item was not found. Turn Launch at Login off, then on again.",
                tone: .caution,
                action: .openSystemSettings,
                actionTitle: "Open Login Items"
            )

        case .unsupported:
            return .init(
                badge: "Unavailable",
                detail: errorMessage ?? "Launch at login requires macOS 13 or newer.",
                tone: .caution,
                action: nil,
                actionTitle: nil
            )
        }
    }

    private static func settingsAction(for errorMessage: String) -> LaunchAtLoginAction? {
        let normalized = errorMessage.lowercased()
        if normalized.contains("system settings")
            || normalized.contains("login items")
            || normalized.contains("permission")
            || normalized.contains("authorization") {
            return .openSystemSettings
        }
        return nil
    }

    private static func settingsActionTitle(for errorMessage: String) -> String? {
        settingsAction(for: errorMessage) == .openSystemSettings ? "Open Login Items" : nil
    }
}

@MainActor
final class StartupManager: ObservableObject {
    @Published var isEnabled: Bool = false
    @Published var errorMessage: String?
    @Published private(set) var state: LaunchAtLoginState = .disabled

    private var lastAttemptErrorMessage: String?

    init() {
        refreshState()
    }

    func refreshState() {
        if #available(macOS 13.0, *) {
            let status = SMAppService.mainApp.status
            switch status {
            case .enabled:
                state = .enabled
                isEnabled = true
                errorMessage = lastAttemptErrorMessage
            case .requiresApproval:
                state = .requiresApproval
                isEnabled = false
                errorMessage = "Launch at Login needs approval in System Settings > General > Login Items."
            case .notFound:
                state = .notFound
                isEnabled = false
                errorMessage = "The Core-Monitor login item was not found. Turn Launch at Login off, then on again."
            case .notRegistered:
                state = .disabled
                isEnabled = false
                errorMessage = lastAttemptErrorMessage
            @unknown default:
                state = .disabled
                isEnabled = false
                errorMessage = lastAttemptErrorMessage
            }
        } else {
            state = .unsupported
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
            lastAttemptErrorMessage = nil
        } catch {
            lastAttemptErrorMessage = startupErrorMessage(for: error)
        }

        refreshState()
    }

    func openLoginItemsSettings() {
        guard #available(macOS 13.0, *) else { return }
        SMAppService.openSystemSettingsLoginItems()
    }

    var statusSummary: LaunchAtLoginStatusSummary {
        LaunchAtLoginStatusSummary.make(status: state, errorMessage: errorMessage)
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
