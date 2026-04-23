# File: Core-MonitorTests/CustomFanPresetTests.swift

## Current Role

- Area: Tests.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-MonitorTests/CustomFanPresetTests.swift`](../../../Core-MonitorTests/CustomFanPresetTests.swift) |
| Wiki area | Tests |
| Exists in current checkout | True |
| Size | 21649 bytes |
| Binary | False |
| Line count | 555 |
| Extension | `.swift` |

## Imports

`CoreGraphics`, `XCTest`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `CustomFanPresetTests` | 3 |
| func | `testDefaultFanModeIsSystemAutomatic` | 7 |
| func | `testCurvePointDecodesLegacyJSONWithoutIdentifier` | 10 |
| func | `testValidationRejectsDescendingTemperatures` | 31 |
| func | `testInterpolationReturnsExpectedMidpoint` | 54 |
| func | `testFanCurveChartGeometryRoundTripsPointCoordinates` | 74 |
| func | `testFanCurveChartGeometryClampsDraggedPointBetweenNeighbors` | 85 |
| func | `testFanCurveChartGeometrySelectsNearestHandleInsteadOfDefaultingToLastPoint` | 111 |
| func | `testTouchBarCommandRunnerRejectsControlCharacters` | 128 |
| func | `testTouchBarCommandRunnerUsesIsolatedShellConfiguration` | 133 |
| func | `testMonitoringTrendSeriesTrimsSamplesOutsideRetentionWindow` | 145 |
| func | `testMonitoringTrendSeriesSummaryUsesSelectedRangeWindow` | 157 |
| func | `testManagedFanModesExposeQuitRestoreGuidance` | 184 |
| func | `testQuickModesHideLegacySilentAlias` | 190 |
| func | `testSystemAutomaticHandoffOnlyRunsAfterManagedWrite` | 195 |
| func | `testSilentCanonicalizesToSystemAutomatic` | 201 |
| func | `testSilentAliasMatchesSystemAutomaticPresentation` | 206 |
| func | `testSystemOwnedModesAreMarkedAsSystemControlled` | 214 |
| func | `testFanModeGuidanceDifferentiatesMonitoringHandoffAndManagedModes` | 221 |
| func | `testAppleSiliconCaveatOnlyAppearsForManagedModes` | 230 |
| func | `testMonitoringSnapshotHealthReportsWaitingBeforeFirstSample` | 237 |
| func | `testMonitoringSnapshotHealthDistinguishesLiveDelayedAndStaleSamples` | 249 |
| func | `testMonitoringSnapshotHealthFormatsCompactDurations` | 269 |
| func | `testMenuBarStatusSummaryMakesHelperOptionalInSystemOwnedModes` | 276 |
| func | `testMenuBarStatusSummaryKeepsManagedModesExplicitAboutHelperProblems` | 301 |
| func | `testMenuBarStatusSummaryReflectsFanOwnershipInModePill` | 319 |
| class | `MenuBarSettingsTests` | 333 |
| func | `testFreshSettingsDefaultToBalancedPreset` | 336 |
| func | `testRestoreDefaultsReturnsToBalancedPreset` | 347 |
| func | `testInaccessibleConfigurationRestoresBalancedPreset` | 362 |
| func | `testFullPresetEnablesNetworkItem` | 375 |
| func | `makeDefaults` | 384 |
| class | `TopProcessSamplerTests` | 395 |
| func | `testSamplerDoesNotRestartWhenSameIntervalIsAlreadyActive` | 398 |
| func | `testSamplerRestartsWhenStoppedOrIntervalChanges` | 407 |
| class | `KernelPanicGameTests` | 425 |
| func | `testKernelPanicBossCatalogMatchesRequiredOrderAndDialogue` | 428 |
| func | `testKernelPanicCampaignCanReachVictoryInBossOrder` | 444 |
| func | `testKernelPanicCapsShotsAndUsesFacingInsteadOfAutoAim` | 457 |
| func | `testKernelPanicPhaseThreeFakeoutTriggersBeforeStuxnet` | 478 |
| func | `testKernelPanicSkipPhaseAdvancesCampaignAndCanReachVictory` | 497 |
| func | `testKernelPanicMusicCueTracksPhaseEscalation` | 526 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `aca5d59` | 2026-04-19 | Add Kernel Panic release payload |
| `210356e` | 2026-04-19 | Add Kernel Panic release payload |
| `675fabf` | 2026-04-17 | Ship 14.0.5 helper recovery release |
| `7c1b882` | 2026-04-17 | Keep Touch Bar HUD always on |
| `cea99a5` | 2026-04-16 | Finish silent mode cleanup |
| `ebf3e12` | 2026-04-16 | Retire redundant silent fan mode |
| `58feb7a` | 2026-04-16 | Add network menu bar item and popover |
| `b8fd8a6` | 2026-04-16 | Clarify silent mode helper handoff semantics |
| `4709cd6` | 2026-04-16 | Add live fan RPM to the balanced menu bar |
| `77dcc07` | 2026-04-16 | Make silent fan mode truly system-owned |
| `a116902` | 2026-04-16 | Refine menu bar helper status context |
| `a2e946d` | 2026-04-16 | Avoid redundant top process sampling restarts |
| `4334e21` | 2026-04-16 | Refine menu bar default density and preset guidance |
| `9d84730` | 2026-04-16 | Tighten actor isolation in test suites |
| `3dbf6ac` | 2026-04-16 | Default fan control to system mode |
| `728674a` | 2026-04-16 | Surface live monitoring freshness across the UI |
| `3bc6fbd` | 2026-04-16 | Restore system auto on quit and clarify fan mode behavior |
| `c39e966` | 2026-04-16 | Add recent thermal trend history to dashboard |
| `5691635` | 2026-04-16 | Improve custom fan curve editing |
| `7185d36` | 2026-04-15 | Improve fan control and alert surfaces |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import XCTest
import CoreGraphics
@testable import Core_Monitor

@MainActor
final class CustomFanPresetTests: XCTestCase {
    func testDefaultFanModeIsSystemAutomatic() {
        XCTAssertEqual(FanController.defaultMode, .automatic)
    }

    func testCurvePointDecodesLegacyJSONWithoutIdentifier() throws {
        let data = Data(
            """
            {
              "name": "Legacy",
              "version": 1,
              "sensor": "cpu",
              "points": [
                { "temperatureC": 40, "speedPercent": 25 },
                { "temperatureC": 80, "speedPercent": 100 }
              ]
            }
            """.utf8
        )

        let preset = try JSONDecoder().decode(CustomFanPreset.self, from: data)

        XCTAssertEqual(preset.points.count, 2)
        XCTAssertNotEqual(preset.points[0].id, preset.points[1].id)
    }

    func testValidationRejectsDescendingTemperatures() {
        let preset = CustomFanPreset(
            name: "Broken",
            version: 1,
            sensor: .cpu,
            updateIntervalSeconds: 2,
            smoothingStepRPM: 75,
            minimumRPM: 1400,
            maximumRPM: 6200,
```
