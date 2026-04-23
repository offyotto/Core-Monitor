# File: Core-Monitor/WelcomeGuideProgress.swift

## Current Role

- Area: Startup and onboarding.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/WelcomeGuideProgress.swift`](../../../Core-Monitor/WelcomeGuideProgress.swift) |
| Wiki area | Startup and onboarding |
| Exists in current checkout | True |
| Size | 4739 bytes |
| Binary | False |
| Line count | 133 |
| Extension | `.swift` |

## Imports

`Foundation`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| enum | `CoreMonitorLaunchPresentation` | 2 |
| enum | `WelcomeGuideProgress` | 11 |
| enum | `CoreMonitorDefaultsMaintenance` | 27 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `7c1b882` | 2026-04-17 | Keep Touch Bar HUD always on |
| `133d9ad` | 2026-04-16 | Replace alert surfaces with monitoring status |
| `5fe6a4c` | 2026-04-16 | Harden first-launch startup and onboarding state |
| `7dd298c` | 2026-04-16 | Make launch diagnostics cleanup idempotent |
| `001a339` | 2026-04-16 | Purge deprecated launch diagnostics defaults |
| `78d0fd2` | 2026-04-16 | Stabilize onboarding launch and menu bar defaults |
| `844ce69` | 2026-04-16 | Fix first-launch dashboard discoverability |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import Foundation

enum CoreMonitorLaunchPresentation: Equatable {
    case dashboard
    case menuBarOnly

    var shouldAutoOpenDashboard: Bool {
        self == .dashboard
    }
}

enum WelcomeGuideProgress {
    static let hasSeenDefaultsKey = "com.coremonitor.hasSeenWelcomeGuide.v1"

    static func hasSeen(in defaults: UserDefaults = .standard) -> Bool {
        return (defaults.object(forKey: hasSeenDefaultsKey) as? Bool) ?? false
    }

    static func launchPresentation(defaults: UserDefaults = .standard) -> CoreMonitorLaunchPresentation {
        hasSeen(in: defaults) ? .menuBarOnly : .dashboard
    }

    static func shouldAutoOpenDashboardOnLaunch(defaults: UserDefaults = .standard) -> Bool {
        launchPresentation(defaults: defaults).shouldAutoOpenDashboard
    }
}

enum CoreMonitorDefaultsMaintenance {
    static let legacyWindowStateResetKey = "coremonitor.didResetLegacySwiftUIWindowFrames.v1"
    static let deprecatedLaunchStateResetKey = "coremonitor.didPurgeDeprecatedLaunchState.v1"

    private static let deprecatedLaunchStatePrefixes = [
        "coremonitor.launchDiagnostics."
    ]

    private static let deprecatedLaunchStateKeys = [
        "coremonitor.didShowFirstLaunchDashboard"
    ]

    static func purgeDeprecatedState(
```
