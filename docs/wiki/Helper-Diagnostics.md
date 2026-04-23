# Helper Diagnostics

`HelperDiagnosticsExporter.swift` creates a JSON support report. It captures app version/build, bundle ID, macOS version, Mac model/chip, signing information, bundled and installed helper paths, helper install/connectivity state, fan-control backend metadata, launch-at-login status, menu bar reachability, and recovery recommendations.

The diagnostics report deliberately excludes telemetry, account data, shell history, historical sensor logs, and unrelated file contents. It is point-in-time support context.

Use it when helper install, fan writes, signing mismatch, launch-at-login, or menu bar visibility are involved. It is surfaced in the System tab and the welcome-guide readiness panel.
