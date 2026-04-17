import Foundation
import UserNotifications

struct NotificationStripPresentation: Equatable {
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

    @MainActor
    init(notificationManager: AlertManager) {
        self.init(
            activeAlertCount: notificationManager.activeAlerts.count,
            authorizationStatus: notificationManager.authorizationStatus,
            desktopNotificationsEnabled: notificationManager.desktopNotificationsEnabled,
            notificationsMutedUntil: notificationManager.notificationsMutedUntil
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
            detail = "\(activeAlertCount) active notification\(activeAlertCount == 1 ? "" : "s")"
            action = Action(title: "Open Notifications", icon: "bell.badge", style: .prominent)
            return
        }

        let notificationsMuted = notificationsMutedUntil.map { $0 > now } ?? false

        switch authorizationStatus {
        case .notDetermined:
            detail = "Desktop notifications are not set up yet. In-app history already records every event."
            action = Action(title: "Set Up Notifications", icon: "bell.badge", style: .standard)
        case .denied:
            detail = "Desktop notifications are off in System Settings. In-app history still records every event."
            action = Action(title: "Notification Settings", icon: "bell.slash", style: .standard)
        case .authorized, .provisional:
            if notificationsMuted {
                detail = "Desktop notifications are muted for now. In-app history still records every event."
                action = Action(title: "Notification Settings", icon: "bell.slash", style: .standard)
            } else if desktopNotificationsEnabled == false {
                detail = "Desktop banners are off. In-app history still records every event."
                action = Action(title: "Notification Settings", icon: "bell.slash", style: .standard)
            } else {
                detail = "Notification thresholds and recent history stay available from the notification screen."
                action = nil
            }
        @unknown default:
            detail = "Notification thresholds and recent history stay available from the notification screen."
            action = nil
        }
    }
}
