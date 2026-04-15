# WORKLOG

## 2026-04-15

### Reviewed
- Repository structure, app bootstrap, menu bar controller, dashboard window flow, `SystemMonitor`, fan control, helper/XPC path, and current docs.
- Current build and test health with `xcodebuild` on macOS.
- Runtime behavior far enough to confirm the app launches as menu bar items and relies on menu bar access by default.

### Baseline
- `xcodebuild -project Core-Monitor.xcodeproj -scheme Core-Monitor -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build` succeeded.
- `xcodebuild -project Core-Monitor.xcodeproj -scheme Core-Monitor -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test` succeeded.
- The worktree already contained significant local changes, so all edits in this session are layered on top without reverting in-progress work.

### Prioritized action list
- Improve menu bar configuration UX and reduce menu bar clutter friction with presets and clearer live-item controls.
- Keep chipping away at the oversized SwiftUI surfaces, starting with `ContentView.swift`.
- Continue runtime/menu bar polish, then convert competitor findings into product and documentation improvements.

### In progress
- Extracted the menu bar configuration card into its own SwiftUI file.
- Added menu bar presets and live preview values to make density choices faster and more obvious.

### Completed batch
- Verified the menu bar settings refactor and preset flow with a fresh macOS build and test pass.
- Confirmed the debug app still launches and publishes the expected live menu bar item titles after the change.

### Next batch
- Added a sourced competitor matrix covering Stats, iStat Menus 7, TG Pro, and Macs Fan Control.
- Captured the product and trust implications so roadmap and README changes can point to concrete public evidence instead of vague claims.

### Completed batch
- Refined the first-launch welcome guide into smaller SwiftUI subviews and turned the final step into a live readiness checklist for menu bar reachability, launch-at-login, and helper state.
- Verified the onboarding refactor with a fresh macOS build and test pass.

### Completed batch
- Traced an actual startup UX regression: the default Touch Bar weather path was prompting for location on launch before the dashboard flow was even reachable.
- Changed weather to stay dormant until the user explicitly opts in, added a dedicated location-access control in Touch Bar settings, and updated weather widgets to explain the dormant state instead of showing a vague failure.
- Rebuilt, reran the macOS test suite, and confirmed at runtime that launch now lands in the menu bar popover without the location permission modal hijacking first use.

### Completed batch
- Made the weather location-access path injectable so the startup permission behavior is testable instead of being locked to `CLLocationManager` globals.
- Added targeted `WeatherViewModel` regression coverage for three cases: no launch-time permission prompt, clear optional-location messaging before opt-in, and fallback weather loading when access exists without a current fix.
- Verified the batch with `xcodebuild ... test -only-testing:Core-MonitorTests/WeatherViewModelTests`.

### Completed batch
- Added a structured helper diagnostics exporter that writes a JSON report with app signing details, helper install/connectivity state, launch-at-login state, and menu bar reachability context.
- Surfaced diagnostics export directly in the welcome-guide readiness panel so support and trust workflows are available where users first decide whether they need helper-backed fan control.
- Verified the batch with a fresh macOS build, a full `xcodebuild ... test` pass, and a targeted `-only-testing:Core-MonitorTests/HelperDiagnosticsReportTests` run.

### Completed batch
- Added a GitHub bug-report form that asks for the exported helper diagnostics report when issues involve helper install, signing, or fan control.
- Added `docs/HELPER_DIAGNOSTICS.md` so support guidance and privacy expectations for the JSON report are source-controlled instead of tribal knowledge.

### Completed batch
- Added `docs/ARCHITECTURE.md` to map the app shell, monitoring path, fan-control/helper boundary, alerts stack, onboarding, and Touch Bar code for contributors.
- Documented the highest-risk change areas so future work is less likely to push random edits into oversized files without understanding ownership first.

### Completed batch
- Added `CONTRIBUTING.md` with the core macOS build/test commands, helper-safety rules, UI verification expectations, and support-intake guidance for contributors.
- Tightened contributor onboarding around the project’s highest-risk areas instead of leaving build/test and helper-trust expectations implicit.

## 2026-04-16

### Completed batch
- Fixed the first-launch discoverability gap for the accessory-style app: if the welcome guide has never been seen, Core Monitor now opens the dashboard automatically instead of launching invisibly into the menu bar.
- Centralized the welcome-guide completion flag so launch behavior and onboarding sheet state use the same source of truth.
- Added `WelcomeGuideProgressTests` to lock the launch decision down, rebuilt the macOS app, and confirmed at runtime that a fresh launch now shows the onboarding sheet over a visible dashboard window.

### Completed batch
- Added a helper diagnostics report that captures signing state, helper install/probe status, launch-at-login state, and menu bar reachability so support issues can be exported as structured JSON instead of vague screenshots.
- Turned helper health into a richer local state machine (`missing`, `checking`, `reachable`, `unreachable`) and surfaced that in service alerts instead of pretending helper status is just installed vs missing.
- Removed the old external-fan-control/tamper alert path, simplified recovery notification noise, and verified the whole macOS suite with `xcodebuild -project Core-Monitor.xcodeproj -scheme Core-Monitor -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test`.

### Completed batch
- Checked in the explicit `main.swift` app entry point used by the accessory-style startup flow so the branch no longer depends on an untracked local file to boot the macOS app.
