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
- Revalidated the competitor matrix against current public sources instead of leaving the repo on stale competitor assumptions; corrected the Stats release signal and folded TG Pro’s current startup-polish notes back into Core Monitor’s product bar.
- Kept the README rewrite scoped to a sharper thermal-first story, clearer install channels, and a more explicit “monitoring first, helper optional” trust posture so the repo presentation matches the product lane documented in `docs/COMPETITOR_MATRIX_2026.md`.

### Completed batch
- Fixed a real first-launch regression in the accessory-style app: the onboarding/dashboard open decision was being poisoned by defaults-layer state before the welcome-guide preference had actually been persisted.
- Hardened `WelcomeGuideProgress` to read the app’s persisted defaults domain directly, stopped the legacy window-frame cleanup from rewriting unrelated defaults, aligned the Help screen’s welcome-guide fallback with first-run behavior, and kept the app in `.regular` activation while the dashboard window is open so the onboarding surface no longer vanishes a second after launch.
- Finished the in-progress dashboard navigation router by exposing the shared sidebar selection type, which makes the new menu bar `Open Alerts` deep link build and work instead of leaving the branch in a compile-broken state.
- Verified the batch with a full `xcodebuild -project Core-Monitor.xcodeproj -scheme Core-Monitor -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test` pass and repeated clean-launch polling after deleting `com.coremonitor.hasSeenWelcomeGuide.v1`; the dashboard window now stays present through the first 10 seconds of launch instead of disappearing after roughly two.

### Completed batch
- Cleaned up the current compiler warnings in the menu bar refresh path and weather location-access controller instead of leaving actor-isolation and no-op annotation noise in the baseline build.
- Switched menu bar item refresh fan-out onto a main-actor hop helper so Combine and notification callbacks no longer touch actor-isolated state directly.
- Re-verified the app with a fresh macOS build and a serialized `xcodebuild ... test` pass after the initial concurrent-build lock collision.

### Completed batch
- Tightened the test target’s Swift 6 actor-isolation posture by marking the alert and fan-preset suites as main-actor tests instead of leaving warnings around Codable and static access on main-isolated types.
- Re-ran the full macOS test suite for this batch in a clean detached worktree because an unrelated local edit in `Core_MonitorApp.swift` currently breaks the active checkout’s build.

### Completed batch
- Added a lightweight dashboard-navigation router so menu bar alert surfaces can deep-link straight into the `Alerts` tab instead of always dumping users into `Overview`.
- Wired active-alert menu bar popovers to show an `Open Alerts` action only when it is relevant, and added focused routing tests to lock the request/consume behavior down.
- Verified the batch in a clean detached worktree again because the active checkout still contains an unrelated compile-breaking local edit in `Core_MonitorApp.swift`.

### Completed batch
- Shifted fresh menu bar defaults back toward a balanced three-item layout so new installs and reset flows do not start in the noisiest possible configuration.
- Marked the Balanced preset as the recommended daily layout and tightened the restore path so corrupted all-off states recover into a reachable, readable baseline.
- Added menu bar settings coverage for default, reset, and inaccessible-state recovery behavior.

### Completed batch
- Made top-process sampling restarts idempotent so reasserting the same activity-sampling interval no longer tears down the sampler and forces an immediate extra process scan.
- This reduces avoidable process enumeration churn when dashboard and menu bar surfaces add or remove overlapping “detailed sampling” reasons while the effective interval stays the same.
- Added focused scheduling coverage so future refactors keep the sampler’s start/restart policy cheap and predictable.

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

### Completed batch
- Reduced background churn across the Touch Bar and menu bar paths by centralizing refresh timing, caching date formatters, and removing per-widget polling timers that were duplicating the main monitor cadence.
- Added adaptive activity sampling so expensive top-process/detail work only stays hot while detailed UI is actually visible, while the default background state backs off to a much slower cadence.

### Completed batch
- Upgraded the custom fan curve editor from a static preview to a directly draggable chart with constrained point movement, so editing the curve no longer depends on only tiny numeric sliders and JSON.
- Added regression coverage for chart geometry, nearest-handle selection, and point clamping so the interaction stays stable as the editor evolves.

### Completed batch
- Hardened the privileged helper boundary so XPC clients are validated against the helper’s authorized-client requirement and helper entrypoints revalidate fan IDs, RPM values, and SMC keys instead of trusting the caller.
- Added a dedicated security audit note capturing the helper-boundary tightening and the remaining product/security follow-ups.

### Completed batch
- Added a reusable rolling trend-history model with 1-minute, 5-minute, and 15-minute time windows instead of only fixed 60-second sparklines.
- Surfaced a new Overview dashboard trend section for CPU temp, GPU temp, primary fan RPM, and system watts so recent thermal behavior is visible at a glance without jumping to external tools.
- Verified the batch with a fresh macOS build and full `xcodebuild ... test` pass, plus targeted unit coverage for history retention and range summaries.

### Completed batch
- Refreshed the competitor matrix with current-source notes on Stats, iStat Menus 7, TG Pro, Macs Fan Control, plus open-source reference points including Hot, iGlance, and iSMC.
- Tightened the README’s positioning so the repo is explicit about which product lane Core Monitor is choosing instead of implying it will beat every utility on every axis.

### Completed batch
- Collapsed `SystemMonitor` onto its published `snapshot` instead of maintaining a second parallel set of mutable top-level telemetry fields, removing the manual `objectWillChange` broadcast on every sample.
- Switched the dashboard refresh path to observe `systemMonitor.$snapshot` directly so the main SwiftUI surface now follows the same source of truth already used by alerts and history/trend logic.
- Verified the batch with a fresh macOS build and full `xcodebuild ... test` pass.

### Completed batch
- Added a dedicated `Helper Diagnostics` support card to the `System` tab so rechecks and report export no longer depend on reopening the welcome guide.
- Updated in-app help and the helper diagnostics doc so the support flow now points users to `System` first, while keeping the welcome guide path available.
- Verified the batch with a fresh macOS build and full `xcodebuild ... test` pass.

### Completed batch
- Tightened helper-health propagation so alert evaluation now uses explicit helper connection state instead of guessing from status-message text.
- Updated the menu bar status summary to react to live helper reachability and show distinct `Ready`, `Checking`, `Pending`, `Missing`, and attention states instead of a stale install-only badge.
- Added targeted alert-engine regression coverage for missing, checking, and unreachable helper states, then verified the batch with `xcodebuild -project Core-Monitor.xcodeproj -scheme Core-Monitor -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test`.

### Completed batch
- Removed the `alwaysOutOfDate` flag from the privileged-helper embed build phase so Xcode can honor the existing input/output paths instead of rerunning that script on every build and test cycle.
- Verified the improvement with two consecutive macOS builds and a fresh `xcodebuild ... test` pass; the old “Based on dependency analysis” warning is gone from the filtered build output.

### Completed batch
- Upgraded the in-app Help search from title-only matching to a lightweight keyword index so common support queries like helper, location, weather, alerts, and login items now resolve to the right sections.
- Added a clearer search UX with result counts, a one-click clear action, and an empty-state card instead of leaving users with a blank scroll view when no topic matches.
- Added dedicated `HelpViewSearchTests` coverage and re-verified the full macOS suite with `xcodebuild -project Core-Monitor.xcodeproj -scheme Core-Monitor -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test`.

### Completed batch
- Closed a trust-critical fan-control gap by making app shutdown perform a best-effort return-to-system-auto pass instead of leaving managed RPM targets active until macOS eventually overrides them.
- Added an in-app fan-mode guidance card so each mode now explains who owns the fan curve, whether the helper path is required, when Core Monitor restores system auto, and when Apple Silicon may delay visible RPM changes.
- Updated the README and in-app Help to match the real control model, then added regression coverage for the new fan-mode guidance metadata.

### Completed batch
- Expanded the overview trend surface beyond thermals so it now includes time-range memory usage and swap history alongside CPU, GPU, fan, and power trends.
- Renamed the section to `Load & Thermal Trends` so the dashboard wording matches the broader sustained-load story instead of implying it is temperature-only.

### Completed batch
- Added a reusable monitoring-freshness model that classifies snapshots as `Waiting`, `Live`, `Delayed`, or `Stale` from the existing sample timestamp and active cadence.
- Surfaced that status in both the Overview dashboard and menu bar popovers, including last-update copy plus live sensor/process sampling cadence so users can tell when telemetry is lagging instead of trusting stale numbers.
- Added targeted freshness-model tests and re-verified the full macOS suite with `xcodebuild -project Core-Monitor.xcodeproj -scheme Core-Monitor -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test`.

### Completed batch
- Used current public competitor sources to refresh the Stats section with its latest public release signal and to double-check menu bar/distribution support expectations against current macOS guidance.
- Added explicit Help and diagnostics guidance for the modern macOS `System Settings` → `Menu Bar` recovery path when Core Monitor is running but its icons are hidden.
- Added `HelpViewSearchTests` coverage for the new `allow in menu bar` / hidden-icon support language, then re-verified the macOS suite with `xcodebuild -project Core-Monitor.xcodeproj -scheme Core-Monitor -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test`.

### Completed batch
- Added persistent dashboard-launch diagnostics so exported helper/support reports now capture whether onboarding was expected to auto-open the dashboard, which source requested it, the last activation policy seen, and whether a visible dashboard window was ever recorded.
- Updated the `System` support copy and `docs/HELPER_DIAGNOSTICS.md` so startup-visibility issues are explicitly part of the diagnostics workflow instead of being lumped into vague “app didn’t launch” reports.
- Added `HelperDiagnosticsReportTests` coverage for the missing-visible-window case, re-verified the full macOS suite with `xcodebuild -project Core-Monitor.xcodeproj -scheme Core-Monitor -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test`, and runtime-checked that a clean first launch still records `autoOpenEligible=1` plus `launch` as the open source while `System Events` reports zero Core Monitor windows.

### Completed batch
- Fixed the Touch Bar weather widget so it stays inside the real Touch Bar vertical budget instead of asking Auto Layout for a taller three-line stack and logging a runtime height violation.
- Collapsed the expanded weather copy into a single compact summary line, reduced label sizing to match the pill surface, and set the widget’s intrinsic height to `TB.pillH` so pill and strip renderers agree on its footprint.
- Added `WeatherWidgetLayoutTests` coverage for compact and expanded sizing, re-ran the full macOS suite, and confirmed a fresh app launch no longer logs the old `Expected min height ... WeatherWidget` warning.

### Completed batch
- Refreshed `MacModelRegistry` against Apple’s current Mac identification pages so recent MacBook Air, MacBook Pro, Mac mini, iMac, and Mac Studio identifiers resolve to accurate names instead of stale placeholders.
- Fixed multiple Apple Silicon MacBook Pro mappings, switched the Overview subtitle from the raw `hw.model` string to a friendly model name, and limited the delayed fan-response caveat to the portable Apple Silicon Macs where it actually applies.
- Added dedicated registry and fan-guidance tests so future model-table edits catch duplicate identifiers, stale mappings, and caveat regressions before they ship.

### Completed batch
- Extended helper diagnostics exports to carry both the raw host model identifier and the friendly model name derived from the refreshed registry.
- Updated helper diagnostics tests and docs so support threads can immediately tell which Mac was involved without decoding identifiers manually.

### Completed batch
- Removed the dashboard’s extra copy-state layer so `ContentView` now renders directly from `SystemMonitor.snapshot` and the monitor-owned history buffers instead of rebuilding a second shadow model on every sample.
- Expanded the Battery tab with clearer power-state diagnostics: source, time-to-full or time-remaining, temperature, voltage, and current are now surfaced from the existing sampler instead of being hidden behind the raw data model.
- Added `BatteryDetailFormatterTests` coverage and verified the batch with a fresh macOS build, a targeted battery formatter test run, and a full `xcodebuild ... test` pass.

### Completed batch
- Brought the in-app Help copy back in sync with the product by documenting the newer 1-minute, 5-minute, and 15-minute trend windows in the Overview topic instead of leaving the older “point-in-time dashboard” explanation.
- Expanded the Battery help topic and search keywords so users can now find runtime, adapter/source, voltage, current, and amperage guidance from the shipped help instead of guessing from the UI.
- Added `HelpViewSearchTests` coverage for the new battery keywords and re-verified the full macOS suite with `xcodebuild ... test`.

### Completed batch
- Changed fresh installs and any missing persisted preference to start fan control in `System` mode instead of defaulting to helper-backed `Smart`, which removes the bogus “helper failed” startup posture from a monitoring-only first launch.
- Added passive fan-status copy plus alert/test coverage so helper availability stays quiet while macOS owns cooling, and softened the `Fans` helper card when the selected mode does not currently need the helper.
- Updated the README and in-app Help to match the new monitoring-first default, rebuilt the macOS app successfully, and runtime-checked the first-launch dashboard plus post-onboarding Overview/Fans states with fresh screenshots. Full `xcodebuild ... test` runs after the UI-driven inspection hit host-app bootstrap failures without a matching crash report, so this batch is build-verified and runtime-verified but still needs a clean follow-up test pass.

### Completed batch
- Gave the accessory-style dashboard window an explicit `Core Monitor` title instead of leaving the macOS-visible window name as `Untitled`, which improves accessibility, Mission Control/window-menu labeling, and support screenshots.
- Rebuilt the macOS app and verified the title through `System Events`, which now reports the dashboard window name as `Core Monitor`.

### Completed batch
- Reworked the welcome-guide flow so each presentation resets to the first onboarding step instead of reopening on a stale later screen.
- Added a vertical overflow fallback for long onboarding steps and tightened the final “Quick Setup Checklist” layout so the guide degrades to scrolling instead of silently clipping action rows.
- Rebuilt the macOS app repeatedly and verified the welcome-guide flow visually from a clean first launch through the final step with fresh screenshots.

### Completed batch
- Removed the app’s persistent dashboard-launch diagnostics path so Core Monitor no longer records local open/visible window behavior for support exports.
- Tightened the privacy story across the app and repo: the welcome guide, menu bar popover, helper diagnostics docs, and README now make the local-only monitoring model explicit and stop using telemetry-heavy wording for core hardware readings.
- Made quit easier to reach from the menu bar popover with a dedicated red control instead of burying termination as a low-emphasis action row.

### Completed batch
- Added Privacy Controls for alerts and memory views so users can turn off process insights, scrub app names from local alert history, and still keep threshold detection active.
- Stopped background top-process sampling when Privacy Controls are off, deleted the now-unused dashboard diagnostics file, and updated alert-engine coverage for the redacted path.
- Rewrote the README and GitHub Pages presentation into a calmer Apple-inspired product voice with a lighter visual treatment and a stronger privacy-first story.

### Completed batch
- Extracted dashboard window sizing into a dedicated `DashboardWindowLayout` policy so the launch/reset heuristics are testable instead of being trapped inside the app delegate window controller.
- Increased the default dashboard footprint and the minimum reset height after runtime inspection showed the overview opening visibly cramped on a laptop-sized screen.
- Verified the batch with a fresh macOS build, targeted `DashboardWindowLayoutTests`, and repeated runtime screenshots; the dashboard now resets a previously cramped frame from `948×560` to `999×640`.

### Completed batch
- Pulled the process-history privacy controls into a shared `PrivacyControlsSectionContent` so the copy, toggle behavior, and history-clearing affordance no longer drift between different screens.
- Surfaced the same privacy controls directly in the `System` tab instead of leaving them discoverable only from `Alerts`, which makes privacy setup easier during first-run configuration.
- Updated Help search keywords and copy so `privacy`, `process names`, and `alert history` now point users to both the `Alerts` and `System` paths, then re-verified the full macOS test suite with `xcodebuild ... test`.

### Completed batch
- Removed the legacy `systemMonitorDidUpdate` broadcast and moved the menu bar and Touch Bar refresh path onto `SystemMonitor`'s published snapshot cadence instead of duplicating every sample through `NotificationCenter`.
- Dropped the stale `RAMPressureTouchBarWidget` observer because the widget was already refreshed through the centralized Touch Bar state application path, which trims one more redundant monitor listener.
- Rebuilt the macOS app, reran the full `xcodebuild ... test` suite, and runtime-smoke-tested the Debug build by relaunching it and confirming the live menu bar items still update (`CPU`, `MEM`, `SSD`, and temperature).

### Completed batch
- Reverted invalid `nonisolated` annotations from the fan and monitoring value-model layer so the project still compiles on GitHub Actions' Xcode 16.2 runner.
- Kept the truly actor-crossing cases explicit by leaving helper probe methods nonisolated, moving the Touch Bar slider presenter onto the main actor, and making the process sampler itself plain so `SystemMonitor` can construct it synchronously.
- Re-ran `xcodebuild -project Core-Monitor.xcodeproj -scheme Core-Monitor -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test` and confirmed the repo is back to a green local build before pushing the CI repair.

### Completed batch
- Tightened the menu bar popover status model so it now shows the active fan mode alongside helper state instead of surfacing stale recent-alert badges that made a healthy monitoring session look unhealthy.
- Added explicit menu bar summary logic for the important trust distinction between `Helper Optional` in system-owned cooling and real helper problems in managed fan modes, then covered that logic with focused unit tests.
- Added a direct `Open Fans` path from the temperature popover whenever the current fan mode is helper-backed, rebuilt the macOS app, re-ran the full `xcodebuild ... test` suite, and runtime-checked the updated popovers with fresh screenshots.

### Completed batch
- Tightened the weather opt-in path so an authorized weather widget now asks Core Location for a fresh on-device fix before dropping to the Cupertino fallback, which keeps “enabled but still showing Cupertino” from looking broken after access is granted.
- Added focused `WeatherViewModelTests` coverage for live-location refresh, fallback behavior when no fix is available, and automatic refresh when location authorization or the current fix changes while the weather module is running.
- Verified the batch with a fresh macOS build and a full `xcodebuild -project Core-Monitor.xcodeproj -scheme Core-Monitor -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test` pass.

### Completed batch
- Restored standard quit affordances for the accessory-style app by installing a real app menu with `Quit Core Monitor` and handling `⌘Q` locally even when the app is running without a normal Dock presence.
- Added explicit quit controls to both the main sidebar and Basic Mode header so users are not forced to hunt for the menu bar popover just to terminate the app.
- Re-verified the batch against the same clean macOS build and full `xcodebuild ... test` pass used for the weather work, then pushed the weather changes separately to keep the runtime/accessory polish commit atomic.

### Completed batch
- Centralized startup defaults maintenance in a testable helper instead of leaving one-off cleanup logic inside the app delegate, then extended it to purge the now-deprecated `coremonitor.launchDiagnostics.*` and `coremonitor.didShowFirstLaunchDashboard` residue alongside the older legacy window-frame cleanup.
- Added focused `WelcomeGuideProgressTests` coverage so both the launch-state purge and the legacy window-frame purge are locked down against a real suite-backed `UserDefaults` domain rather than only through app-launch side effects.
- Verified the batch with targeted `WelcomeGuideProgressTests`, a full `xcodebuild -project Core-Monitor.xcodeproj -scheme Core-Monitor -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test` pass, and a debug-app launch check against `/Users/bookme/Library/Preferences/CoreTools.Core-Monitor.plist` confirming the deprecated launch-state keys no longer persist on disk.

### Completed batch
- Stopped the dashboard from forcing high-churn process sampling on every sidebar surface, and now only enable the faster top-process cadence where it materially helps: `Alerts` and `Memory` in the full dashboard.
- Added `DashboardProcessSamplingPolicyTests` coverage so Basic Mode and the low-value surfaces stay on the cheaper background cadence instead of drifting back to always-on detailed sampling.
- Re-verified the change with a full `xcodebuild -project Core-Monitor.xcodeproj -scheme Core-Monitor -destination 'platform=macOS' -derivedDataPath .deriveddata CODE_SIGNING_ALLOWED=NO test` pass, plus a debug-app runtime check confirming the monitoring-status copy now reflects the scoped sampling behavior.

### Completed batch
- Hardened startup against duplicate launches by detecting an already-running Core Monitor instance, handing dashboard focus back to that process, and terminating the new copy before it can publish another set of menu bar extras.
- Added `CoreMonitorSingleInstancePolicyTests` coverage for the handoff-target selection rules and exempted the path under XCTest so the host app does not terminate itself during unit-test bootstrapping.
- Re-verified the batch with the same clean full macOS test pass, then forced a second launch from the built executable and confirmed the process count stays at one for the Debug app path instead of stacking a duplicate instance.

### Completed batch
- Throttled expensive disk-capacity refreshes behind a dedicated `DiskStatsRefreshPolicy` instead of recalculating purgeable and important-usage volume state on every 1-second dashboard sample.
- Cached the last disk snapshot inside `SystemMonitor` and added focused `DiskStatsRefreshPolicyTests` coverage so future edits do not quietly reintroduce per-sample disk refresh churn.
- Re-verified the batch with targeted policy tests, a fresh full `xcodebuild -project Core-Monitor.xcodeproj -scheme Core-Monitor -destination 'platform=macOS' -derivedDataPath .deriveddata CODE_SIGNING_ALLOWED=NO test` pass, and a short relaunch log check showing only a single `com.apple.cache_delete` timestamp in the post-launch window instead of a per-second pattern.
