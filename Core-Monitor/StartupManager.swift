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
            case .requiresApproval:
                isEnabled = false
                errorMessage = "Startup requires approval in System Settings > Login Items."
            default:
                isEnabled = false
            }
        } else {
            isEnabled = false
            errorMessage = "Startup at login requires macOS 13 or newer."
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
            errorMessage = error.localizedDescription
        }

        refreshState()
    }
}
