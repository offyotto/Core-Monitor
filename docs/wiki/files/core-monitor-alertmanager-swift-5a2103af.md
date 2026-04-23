# File: Core-Monitor/AlertManager.swift

## Current Role

- Area: Legacy alert system.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/AlertManager.swift`](../../../Core-Monitor/AlertManager.swift) |
| Wiki area | Legacy alert system |
| Exists in current checkout | True |
| Size | 15942 bytes |
| Binary | False |
| Line count | 433 |
| Extension | `.swift` |

## Imports

`Combine`, `Foundation`, `UserNotifications`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `AlertManager` | 4 |
| func | `config` | 79 |
| func | `setRuleEnabled` | 85 |
| func | `setWarningThreshold` | 91 |
| func | `setCriticalThreshold` | 97 |
| func | `setCooldownMinutes` | 103 |
| func | `setRuleDesktopNotificationsEnabled` | 109 |
| func | `applyPreset` | 115 |
| func | `setNotificationPolicy` | 123 |
| func | `setDesktopNotificationsEnabled` | 129 |
| func | `muteNotifications` | 135 |
| func | `clearNotificationMute` | 142 |
| func | `setProcessInsightsEnabled` | 148 |
| func | `clearHistory` | 153 |
| func | `snooze` | 159 |
| func | `dismissUntilRecovery` | 166 |
| func | `requestNotificationAuthorization` | 173 |
| func | `evaluateAlerts` | 182 |
| func | `observeInputs` | 235 |
| func | `shouldDeliverDesktopNotification` | 282 |
| func | `deliverDesktopNotification` | 298 |
| func | `refreshNotificationSettings` | 322 |
| func | `updateConfig` | 330 |
| func | `updateRuntime` | 339 |
| func | `persistStore` | 347 |
| extension | `AlertManager` | 423 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `5dc29ed` | 2026-04-16 | Add privacy controls and refine Core Monitor presentation |
| `3c34251` | 2026-04-16 | Refine helper reachability across alerts and menu bar |
| `1ff7bdb` | 2026-04-16 | Refine helper health states and service alerts |
| `7185d36` | 2026-04-15 | Improve fan control and alert surfaces |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import Combine
import Foundation
import UserNotifications

@MainActor
final class AlertManager: NSObject, ObservableObject {
    @Published private(set) var activeAlerts: [AlertActiveState] = []
    @Published private(set) var history: [AlertEvent] = []
    @Published private(set) var availabilityReasons: [AlertRuleKind: String] = [:]
    @Published private(set) var selectedPreset: AlertPreset
    @Published private(set) var notificationPolicy: AlertNotificationPolicy
    @Published private(set) var desktopNotificationsEnabled: Bool
    @Published private(set) var notificationsMutedUntil: Date?
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var lastNotificationError: String?
    @Published private(set) var processInsightsEnabled: Bool

    private let storageKey = "coremonitor.alertStore.v1"
    private let userDefaults: UserDefaults
    private let notificationCenter: UNUserNotificationCenter
    private let systemMonitor: SystemMonitor
    private let fanController: FanController
    private let helperManager: SMCHelperManager
    private let privacySettings: PrivacySettings

    private var store: AlertStore
    private var cancellables = Set<AnyCancellable>()

    init(
        systemMonitor: SystemMonitor,
        fanController: FanController,
        helperManager: SMCHelperManager? = nil,
        privacySettings: PrivacySettings? = nil,
        userDefaults: UserDefaults = .standard,
        notificationCenter: UNUserNotificationCenter = .current()
    ) {
        let resolvedPrivacySettings = privacySettings ?? .shared
        self.systemMonitor = systemMonitor
        self.fanController = fanController
        self.helperManager = helperManager ?? .shared
```
