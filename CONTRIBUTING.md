# Contributing to Core Monitor

Core Monitor is a macOS utility with privileged-helper fan control, real-time monitoring, menu bar surfaces, alerts, onboarding, and optional Touch Bar support.

That mix makes small regressions easy to ship unless contributors stay disciplined about scope and verification.

## Start here

Before editing code, read:

1. [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
2. [`docs/HELPER_DIAGNOSTICS.md`](docs/HELPER_DIAGNOSTICS.md) if your change touches helper install, signing, or fan control
3. the closest existing tests for the feature you are about to change

## Local prerequisites

- Xcode with the macOS SDK used by the project
- a macOS machine for app builds and runtime verification
- a signed build only if you need to validate the full privileged-helper trust path end to end

You can build and test most of the app without installing the helper.

## Core build and test commands

Build:

```bash
xcodebuild -project Core-Monitor.xcodeproj -scheme Core-Monitor -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

Test:

```bash
xcodebuild -project Core-Monitor.xcodeproj -scheme Core-Monitor -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
```

When a feature has focused regression tests, run those too:

```bash
xcodebuild -project Core-Monitor.xcodeproj -scheme Core-Monitor -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test -only-testing:Core-MonitorTests/HelperDiagnosticsReportTests
```

## Change strategy

Prefer the smallest owner of the behavior:

- monitoring regressions: `SystemMonitor.swift`
- helper or fan-write trust issues: `SMCHelperManager.swift`, `SMCHelperXPC.swift`, or `smc-helper/`
- alert threshold/evaluation issues: `AlertEngine.swift`
- menu bar visibility or density: `MenuBarSettings.swift`, `MenubarController.swift`, `MenuBarExtraView.swift`
- onboarding or helper explanation problems: `WelcomeGuide.swift`

If a change crosses multiple layers, document why in the commit message and worklog.

## Helper and fan-control safety rules

- Do not weaken validation inside the privileged helper.
- Do not assume the app process is a sufficient trust boundary for privileged behavior.
- Keep “monitoring works without the helper” true.
- Keep “System Auto returns control to macOS” language accurate anywhere fan modes are described.
- If you change helper trust or installation behavior, update both user-facing copy and support intake docs.

## UI and product verification

For user-visible changes:

1. Build the app
2. Launch it
3. Inspect the affected surface directly
4. Capture screenshots when the change affects onboarding, menu bar behavior, alerts, or dashboard layout

Do not claim a UI improvement without looking at the actual runtime result.

## Tests and regression coverage

- Add focused tests when changing:
  - helper diagnostics or helper trust behavior
  - fan curve validation or interpolation
  - alert evaluation logic
  - permission-gating behavior such as weather/location startup handling
- Keep tests close to the feature boundary instead of relying only on full-suite coverage.

## Issues and bug reports

If a bug touches fan control, helper install, helper reachability, or signing mismatch:

- ask for the exported helper diagnostics report
- use the GitHub bug form in `.github/ISSUE_TEMPLATE/bug_report.yml`
- avoid debugging those reports from screenshots alone

## Pull request expectations

- Keep commits atomic and specific
- include verification notes
- call out any runtime limitation you could not validate
- avoid unrelated refactors in high-risk files such as `ContentView.swift` and `SystemMonitor.swift`

Core Monitor benefits more from a steady stream of verified improvements than from large speculative rewrites.
