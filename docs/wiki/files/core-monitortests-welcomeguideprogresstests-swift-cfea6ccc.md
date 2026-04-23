# File: Core-MonitorTests/WelcomeGuideProgressTests.swift

## Current Role

- Area: Tests.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-MonitorTests/WelcomeGuideProgressTests.swift`](../../../Core-MonitorTests/WelcomeGuideProgressTests.swift) |
| Wiki area | Tests |
| Exists in current checkout | True |
| Size | 7734 bytes |
| Binary | False |
| Line count | 179 |
| Extension | `.swift` |

## Imports

`XCTest`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `WelcomeGuideProgressTests` | 2 |
| func | `testShouldAutoOpenDashboardOnLaunchWhenGuideHasNotBeenSeen` | 5 |
| func | `testShouldNotAutoOpenDashboardAfterGuideHasBeenSeen` | 12 |
| func | `testDefaultsMaintenanceRemovesDeprecatedLaunchDiagnosticsResidue` | 21 |
| func | `testDefaultsMaintenanceRechecksDeprecatedLaunchDiagnosticsWhenResetMarkerAlreadyExists` | 42 |
| func | `testDefaultsMaintenanceRemovesLegacyWindowFrameKeysWithoutTouchingOtherState` | 64 |
| func | `testWelcomeGuidePresentationKeepsGuidePendingAfterUnexpectedDismissal` | 83 |
| func | `testWelcomeGuidePresentationPersistsCompletionAfterGuideFinishes` | 93 |
| func | `makeDefaults` | 104 |
| func | `defaultsSuiteName` | 115 |
| class | `DashboardNavigationRouterTests` | 120 |
| func | `testConsumeReturnsRequestedSelectionAndClearsRoute` | 123 |
| func | `testConsumeRejectsStaleRouteAfterNewRequest` | 132 |
| class | `TouchBarCustomizationSettingsTests` | 147 |
| func | `testFreshSettingsDefaultToSystemPresentationMode` | 150 |
| func | `testLegacyPresentationModeStillMigratesForwardWhenStored` | 159 |
| func | `makeDefaults` | 168 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `e24d811` | 2026-04-16 | :)) |
| `133d9ad` | 2026-04-16 | Replace alert surfaces with monitoring status |
| `616b507` | 2026-04-16 | Fix first-launch welcome guide persistence |
| `c408c06` | 2026-04-16 | Default fresh installs to system Touch Bar |
| `7dd298c` | 2026-04-16 | Make launch diagnostics cleanup idempotent |
| `001a339` | 2026-04-16 | Purge deprecated launch diagnostics defaults |
| `b27fd63` | 2026-04-16 | Deep-link menu bar alerts into the dashboard |
| `844ce69` | 2026-04-16 | Fix first-launch dashboard discoverability |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import XCTest
@testable import Core_Monitor

final class WelcomeGuideProgressTests: XCTestCase {
    func testShouldAutoOpenDashboardOnLaunchWhenGuideHasNotBeenSeen() {
        let defaults = makeDefaults()

        XCTAssertEqual(WelcomeGuideProgress.launchPresentation(defaults: defaults), .dashboard)
        XCTAssertTrue(WelcomeGuideProgress.shouldAutoOpenDashboardOnLaunch(defaults: defaults))
        XCTAssertFalse(WelcomeGuideProgress.hasSeen(in: defaults))
    }

    func testShouldNotAutoOpenDashboardAfterGuideHasBeenSeen() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: WelcomeGuideProgress.hasSeenDefaultsKey)

        XCTAssertEqual(WelcomeGuideProgress.launchPresentation(defaults: defaults), .menuBarOnly)
        XCTAssertFalse(WelcomeGuideProgress.shouldAutoOpenDashboardOnLaunch(defaults: defaults))
        XCTAssertTrue(WelcomeGuideProgress.hasSeen(in: defaults))
    }

    func testDefaultsMaintenanceRemovesDeprecatedLaunchDiagnosticsResidue() {
        let defaults = makeDefaults()
        let bundleIdentifier = defaultsSuiteName(for: defaults)

        defaults.set("launch", forKey: "coremonitor.launchDiagnostics.lastOpenRequestSource")
        defaults.set("2026-04-16T00:00:00Z", forKey: "coremonitor.launchDiagnostics.lastVisibleAt")
        defaults.set(true, forKey: "coremonitor.didShowFirstLaunchDashboard")
        defaults.set("keep", forKey: "coremonitor.unrelated")

        CoreMonitorDefaultsMaintenance.purgeDeprecatedState(
            defaults: defaults,
            bundleIdentifier: bundleIdentifier
        )

        XCTAssertNil(defaults.object(forKey: "coremonitor.launchDiagnostics.lastOpenRequestSource"))
        XCTAssertNil(defaults.object(forKey: "coremonitor.launchDiagnostics.lastVisibleAt"))
        XCTAssertNil(defaults.object(forKey: "coremonitor.didShowFirstLaunchDashboard"))
        XCTAssertEqual(defaults.string(forKey: "coremonitor.unrelated"), "keep")
        XCTAssertTrue(defaults.bool(forKey: CoreMonitorDefaultsMaintenance.deprecatedLaunchStateResetKey))
```
