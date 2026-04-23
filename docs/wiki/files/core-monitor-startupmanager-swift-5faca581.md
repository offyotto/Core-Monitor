# File: Core-Monitor/StartupManager.swift

## Current Role

- Area: Startup and onboarding.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/StartupManager.swift`](../../../Core-Monitor/StartupManager.swift) |
| Wiki area | Startup and onboarding |
| Exists in current checkout | True |
| Size | 7137 bytes |
| Binary | False |
| Line count | 221 |
| Extension | `.swift` |

## Imports

`Combine`, `Foundation`, `ServiceManagement`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| enum | `LaunchAtLoginState` | 4 |
| enum | `LaunchAtLoginAction` | 12 |
| enum | `LaunchAtLoginStatusTone` | 17 |
| struct | `LaunchAtLoginStatusSummary` | 23 |
| class | `StartupManager` | 115 |
| func | `refreshState` | 127 |
| func | `setEnabled` | 159 |
| func | `openLoginItemsSettings` | 176 |
| func | `startupErrorMessage` | 185 |
| struct | `DashboardNavigationRoute` | 198 |
| class | `DashboardNavigationRouter` | 204 |
| func | `open` | 210 |
| func | `consume` | 214 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `cfea009` | 2026-04-16 | Polish launch-at-login recovery flow |
| `b27fd63` | 2026-04-16 | Deep-link menu bar alerts into the dashboard |
| `b09dbec` | 2026-04-14 | Tighten app copy and weather privacy behavior |
| `3252194` | 2026-03-27 | Clean repo and keep only active Core-Monitor project |
| `61a73aa` | 2026-03-15 | Commit ig |
| `81e0938` | 2026-03-13 | Add auto fan aggressiveness slider and fix QEMU boot/display defaults |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
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
```
