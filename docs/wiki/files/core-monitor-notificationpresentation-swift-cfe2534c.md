# File: Core-Monitor/NotificationPresentation.swift

## Current Role

- Area: Core app.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/NotificationPresentation.swift`](../../../Core-Monitor/NotificationPresentation.swift) |
| Wiki area | Core app |
| Exists in current checkout | True |
| Size | 2728 bytes |
| Binary | False |
| Line count | 68 |
| Extension | `.swift` |

## Imports

`Foundation`, `UserNotifications`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| struct | `NotificationStripPresentation` | 3 |
| struct | `Action` | 5 |
| enum | `Style` | 6 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `49e36e2` | 2026-04-17 | Fix notification presentation actor isolation for 14.0.4 |
| `734d179` | 2026-04-17 | Remove remaining alerts strings |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
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
```
