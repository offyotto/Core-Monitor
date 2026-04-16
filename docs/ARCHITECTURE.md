# Core Monitor Architecture

This document is the fast orientation map for contributors working on Core Monitor.

It focuses on the code paths that matter most for product quality, helper trust, and user-facing behavior.

## App shell and entry points

- `Core-Monitor/Core_MonitorApp.swift`
  - App entry point and top-level scene wiring.
  - Owns the shared long-lived objects that feed the dashboard, menu bar, onboarding, and fan control surfaces.
- `Core-Monitor/AppCoordinator.swift`
  - Coordinates launch behavior, dashboard visibility, and menu bar interactions.
  - Good first stop when the app starts in the wrong place or loses discoverability.
- `Core-Monitor/ContentView.swift`
  - Main dashboard surface.
  - Large file with the highest concentration of cross-feature UI, so changes here should stay tightly scoped.

## Monitoring pipeline

- `Core-Monitor/SystemMonitor.swift`
  - Core sampler for CPU, memory, thermal, battery, power, network, and SMC-backed sensor reads.
  - Maintains the live in-memory history buffers used by dashboard and menu bar surfaces.
  - Runs background sampling and publishes the latest `snapshot`.
- `Core-Monitor/MonitoringSnapshot.swift`
  - Shared point-in-time data model for the latest monitoring sample.
  - Keep new monitoring surfaces reading from this model rather than inventing parallel ad hoc state.
- `Core-Monitor/TopProcessSampler.swift`
  - Samples top CPU and memory processes for dashboard context and privacy-sensitive memory views.
  - Important privacy-sensitive path because it captures local process metadata.

## Fan control pipeline

- `Core-Monitor/FanController.swift`
  - Product-facing fan mode logic.
  - Decides when fan writes are needed, validates presets/curves, and falls back when helper or SMC access is unavailable.
- `Core-Monitor/FanCurveEditorView.swift`
  - Dedicated UI for custom curve editing.
  - Geometry and validation changes should normally come with tests.
- `Core-Monitor/SMCHelperManager.swift`
  - App-side bridge for helper installation, helper health probes, and XPC calls.
  - Main source of truth for helper install state, connection reachability, and user-facing helper errors.
- `Core-Monitor/SMCHelperXPC.swift`
  - Shared XPC protocol contract between app and helper.
- `smc-helper/`
  - Privileged helper target.
  - Contains the helper executable entry point and privileged implementation details.
  - Any trust-boundary validation belongs here, not only in the app process.

## Monitoring status and legacy alert code

- `Core-Monitor/AlertsView.swift`
  - Transitional file that now hosts the dashboard/system status panels used by the Overview and System surfaces while still carrying the retired alerts view.
  - Good place to refine monitoring freshness, helper state, SMC status, and privacy messaging without adding new dashboard state owners.
- `Core-Monitor/AlertEngine.swift`
  - Legacy pure evaluation logic for the retired alert system.
  - Do not extend this path unless alerts are being intentionally reintroduced.
- `Core-Monitor/AlertModels.swift`
  - Legacy threshold and persistence-facing alert data model kept for the retired alert subsystem.
- `Core-Monitor/AlertManager.swift`
  - Legacy runtime orchestration layer for the retired alert subsystem.
  - The main app shell no longer wires this into the current dashboard or menu bar product path.

## Menu bar and dashboard surfaces

- `Core-Monitor/MenubarController.swift`
  - Creates and updates menu bar items.
  - Important when menu bar density, refresh behavior, or visibility rules change.
- `Core-Monitor/MenuBarExtraView.swift`
  - Main menu bar popover UI and quick-glance details.
- `Core-Monitor/MenuBarSettings.swift`
  - Persistence and validation for which menu bar items are enabled.
  - Guarantees the app keeps at least one visible item so it stays reachable.
- `Core-Monitor/MenuBarConfigurationSection.swift`
  - Settings UI for visibility presets and live menu bar configuration.

## Onboarding, help, and supportability

- `Core-Monitor/WelcomeGuide.swift`
  - First-run onboarding flow.
  - Best place for trust explainers, startup guidance, and helper-facing setup language.
- `Core-Monitor/HelpView.swift`
  - In-app help and discoverability surface.
  - Should stay aligned with actual behavior, especially around helper requirements and permissions.
- `Core-Monitor/HelperDiagnosticsExporter.swift`
  - Builds the exportable helper diagnostics report used for support and bug intake.

## Touch Bar and optional surfaces

- `Core-Monitor/CoreMonTouchBarController.swift`
  - Main Touch Bar presentation/controller path.
- `Core-Monitor/TouchBarUtilityWidgets.swift`
  - Built-in utility widget implementations and launcher widgets.
- `Core-Monitor/TouchBarCustomizationCompatibility.swift`
  - Persistence and compatibility helpers for Touch Bar layout customization.
- `Core-Monitor/PockWidgetSources/`
  - Widget-specific implementations used by the Touch Bar/presentation system.

## Weather and permissions

- `Core-Monitor/WeatherService.swift`
  - WeatherKit integration and weather view-model state.
  - This path must avoid interrupting launch or onboarding with premature location prompts.
- `Core-Monitor/WeatherLocationAccessSection.swift`
  - UI for explicit location access management.

## Persistence and configuration hotspots

- `MenuBarSettings`
  - Stored in `UserDefaults`.
- `StartupManager`
  - Wraps `SMAppService` for launch-at-login state and approval messaging.
- `AlertManager`
  - Persists the retired alert configuration/history model that is no longer part of the main app shell.
- `FanController`
  - Persists custom presets/curve state and active fan configuration.
- Touch Bar customization
  - Stored through the compatibility/customization helpers under `TouchBarCustomizationCompatibility.swift`.

## Safe change strategy

When changing behavior, prefer this order:

1. Update the smallest owner of the behavior.
2. Add or extend focused tests close to that behavior.
3. Build on macOS.
4. Run the relevant tests.
5. Relaunch and inspect the affected surface if it is user-visible.

Examples:

- helper trust or fan-write bug: start with `SMCHelperManager`, `SMCHelperXPC`, or `smc-helper/`
- monitoring status or helper-health confusion: start with `AlertsView.swift` (legacy filename) and `MenuBarStatusSummary.swift`
- legacy alert behavior being intentionally removed or audited: start with `AlertEngine.swift`
- onboarding confusion: start with `WelcomeGuide.swift`
- menu bar clutter or reachability problems: start with `MenuBarSettings.swift` and `MenubarController.swift`
- sampling or performance regressions: start with `SystemMonitor.swift`

## Current architectural pressure points

- `ContentView.swift` remains oversized and still mixes multiple feature surfaces.
- `MenuBarExtraView.swift` is feature-rich enough that regressions can hide inside layout polish work.
- `SystemMonitor.swift` owns a large amount of sampling responsibility, which makes correctness and performance changes high-impact.
- Helper and fan-control trust depends on keeping the app-side messaging and helper-side enforcement aligned.

## Recommended contributor workflow

- Read this file first.
- Read the relevant feature file and its adjacent tests second.
- Prefer atomic changes that stay inside one feature boundary when possible.
- If a change crosses monitoring, helper, and UI layers, document the reason in the commit message and worklog.
