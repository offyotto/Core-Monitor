import Foundation
import UserNotifications

struct AlertsDashboardStripPresentation: Equatable {
    struct Action: Equatable {
        enum Style: Equatable {
            case prominent
            case standard
        }

        let title: String
        let icon: String
        let style: Style
    }

    let detail: String
    let action: Action?

    init(alertManager: AlertManager) {
        self.init(
            activeAlertCount: alertManager.activeAlerts.count,
            authorizationStatus: alertManager.authorizationStatus,
            desktopNotificationsEnabled: alertManager.desktopNotificationsEnabled,
            notificationsMutedUntil: alertManager.notificationsMutedUntil
        )
    }

    init(
        activeAlertCount: Int,
        authorizationStatus: UNAuthorizationStatus,
        desktopNotificationsEnabled: Bool,
        notificationsMutedUntil: Date?,
        now: Date = Date()
    ) {
        if activeAlertCount > 0 {
            detail = "\(activeAlertCount) active alert\(activeAlertCount == 1 ? "" : "s")"
            action = Action(title: "Open Alerts", icon: "bell.badge", style: .prominent)
            return
        }

        let notificationsMuted = notificationsMutedUntil.map { $0 > now } ?? false

        switch authorizationStatus {
        case .notDetermined:
            detail = "Desktop notifications are not set up yet. In-app history already records every alert."
            action = Action(title: "Set Up Alerts", icon: "bell.badge", style: .standard)
        case .denied:
            detail = "Desktop notifications are off in System Settings. In-app history still records every alert."
            action = Action(title: "Alert Settings", icon: "bell.slash", style: .standard)
        case .authorized, .provisional:
            if notificationsMuted {
                detail = "Desktop notifications are muted for now. In-app history still records every alert."
                action = Action(title: "Alert Settings", icon: "bell.slash", style: .standard)
            } else if desktopNotificationsEnabled == false {
                detail = "Desktop banners are off. In-app history still records every alert."
                action = Action(title: "Alert Settings", icon: "bell.slash", style: .standard)
            } else {
                detail = "Alert thresholds and recent history stay available from the Alerts screen."
                action = nil
            }
        @unknown default:
            detail = "Alert thresholds and recent history stay available from the Alerts screen."
            action = nil
        }
    }
}
