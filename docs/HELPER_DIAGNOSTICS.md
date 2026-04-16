# Helper Diagnostics

Core Monitor now includes an exportable helper diagnostics report for support and bug triage.

Use it when:

- the app says the privileged helper is unavailable
- fan writes fail or do nothing
- helper installation succeeds but connection checks still fail
- launch-at-login or menu bar reachability might be part of the support issue

## How to export it

1. Open `System`
2. Use the `Helper Diagnostics` card
3. Click `Export Report`
4. Save the JSON file and attach it to your issue or support thread

You can still reach the same export flow from `Help` → `Reopen Welcome Guide` → final readiness step if you want the onboarding checklist at the same time.

The app reveals the saved file in Finder after export.

## What the report includes

- Core Monitor bundle identifier, version, build, and macOS version
- Mac model identifier, friendly name, and chip name
- app signing identity details relevant to helper trust
- bundled helper path and installed helper path
- helper install state and current connectivity state
- current helper status message, if one exists
- launch-at-login state and approval errors
- menu bar preset title and enabled-item count
- recommended recovery actions based on the captured state

## What it does not include

- analytics or network activity
- account information
- historical sensor logs
- shell history
- file contents outside the saved report itself

The report is a point-in-time local snapshot meant to explain helper trust, login-item status, and menu bar reachability, not a continuous diagnostic trace.

If Core Monitor is running but its menu bar items are missing, check `System Settings` → `Menu Bar` before assuming the app failed to launch. Newer macOS releases can hide third-party menu bar apps there even when the process is healthy.

## Reading the summary quickly

- `Monitoring-only configuration` means the helper is not installed. Core Monitor can still monitor sensors, alerts, and menu bar state normally.
- `Helper reachable` means the app should be able to perform privileged fan writes on supported Macs.
- `Helper is installed, but this app could not establish a trusted connection` usually points to signing mismatch, stale helper state, or a reinstall problem.
- `Helper exists, but Core Monitor has not completed a trusted health probe yet` usually means the helper has just been installed or the app still needs a recheck.

## Recommended issue-report workflow

If a problem touches fan control or helper installation:

1. Reproduce the issue
2. Export a fresh helper diagnostics report immediately after reproducing it
3. If the issue is "the app is running but the menu bar icons are gone," first verify `System Settings` → `Menu Bar` still allows Core Monitor to appear there
4. Attach the JSON file to the GitHub issue
5. Include screenshots for any visible UI inconsistency or onboarding confusion
