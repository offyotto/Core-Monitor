# File: Core-MonitorTests/HelperDiagnosticsReportTests.swift

## Current Role

- Area: Tests.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-MonitorTests/HelperDiagnosticsReportTests.swift`](../../../Core-MonitorTests/HelperDiagnosticsReportTests.swift) |
| Wiki area | Tests |
| Exists in current checkout | True |
| Size | 12045 bytes |
| Binary | False |
| Line count | 253 |
| Extension | `.swift` |

## Imports

`XCTest`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `HelperDiagnosticsReportTests` | 2 |
| func | `testMakeReportExplainsMonitoringOnlyModeWhenHelperIsMissing` | 5 |
| func | `testMakeReportPrioritizesSigningMismatchRecovery` | 45 |
| func | `testMakeReportCarriesLoginApprovalGuidance` | 84 |
| func | `testHelperInstallAppearsOrphanedWhenFilesExistButLaunchdServiceIsMissing` | 122 |
| func | `testHelperInstallAppearsOrphanedWhenLaunchdPlistExistsWithoutHelperBinary` | 132 |
| func | `testHelperInstallDoesNotAppearOrphanedWhenLaunchdServiceExists` | 142 |
| func | `testOrphanedHelperCleanupScriptTargetsInstalledHelperArtifacts` | 152 |
| func | `testLaunchdBlessFailuresTriggerOrphanedCleanupRetry` | 159 |
| func | `testNonLaunchdBlessFailuresSkipOrphanedCleanupRetry` | 167 |
| func | `testMakeReportCallsOutIncompleteHelperInstall` | 175 |
| func | `testMakeReportCarriesAppleSiliconFanBackendMetadata` | 213 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `675fabf` | 2026-04-17 | Ship 14.0.5 helper recovery release |
| `bd80f00` | 2026-04-17 | Fix fan helper recovery and weather fallback |
| `b544f6f` | 2026-04-17 | Repair orphaned helper reinstall path |
| `5dc29ed` | 2026-04-16 | Add privacy controls and refine Core Monitor presentation |
| `80000af` | 2026-04-16 | Add friendly host model names to diagnostics |
| `9d4d7d1` | 2026-04-16 | Capture dashboard launch state in support diagnostics |
| `3668c50` | 2026-04-16 | Add exportable helper diagnostics reports |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import XCTest
@testable import Core_Monitor

final class HelperDiagnosticsReportTests: XCTestCase {
    func testMakeReportExplainsMonitoringOnlyModeWhenHelperIsMissing() {
        let context = HelperDiagnosticsContext(
            generatedAt: Date(timeIntervalSince1970: 1_000),
            appBundleIdentifier: "CoreTools.Core-Monitor",
            appVersion: "1.4.1",
            appBuild: "1410",
            macOSVersion: "macOS 15.5",
            hostModelIdentifier: "Mac16,7",
            hostModelName: "MacBook Pro (16-inch, 2024, M4 Pro/Max)",
            chipName: "Apple M4 Pro",
            helperLabel: "ventaphobia.smc-helper",
            bundledHelperPath: "/Applications/Core-Monitor.app/Contents/Library/LaunchServices/ventaphobia.smc-helper",
            bundledHelperExists: true,
            installedHelperPath: "/Library/PrivilegedHelperTools/ventaphobia.smc-helper",
            installedHelperExists: false,
            connectionState: .missing,
            helperStatusMessage: nil,
            fanBackendRepository: "agoodkind/macos-smc-fan",
            fanModeKeyFormat: nil,
            fanForceTestAvailable: nil,
            launchAtLoginEnabled: false,
            launchAtLoginError: nil,
            enabledMenuBarItemCount: 1,
            menuBarPresetTitle: "Balanced",
            signingInfo: HelperDiagnosticsSigningInfo(
                signedIdentifier: "CoreTools.Core-Monitor",
                teamIdentifier: "TEAM1234",
                isAdHocOrUnsigned: false,
                issue: nil
            )
        )

        let report = HelperDiagnosticsExporter.makeReport(from: context)

        XCTAssertEqual(report.summary, "Monitoring-only configuration. The privileged helper is not installed.")
        XCTAssertTrue(report.recommendedActions.contains("Monitoring already works without the helper. Install it only if you want manual or profile-based fan control."))
```
