# Security Policy

## Reporting a Vulnerability

Please do not open a public GitHub issue for security vulnerabilities.

If you find a vulnerability in Core-Monitor, report it privately by contacting the maintainer through the GitHub repository owner profile or by opening a private security advisory if available.

Include:

- A clear description of the issue
- Steps to reproduce it
- The affected version or commit
- Any relevant logs, crash reports, or proof of concept details
- Whether the issue involves the privileged helper, XPC communication, fan control, permissions, or local data exposure

## Scope

Security-sensitive areas include:

- Privileged helper behavior
- XPC communication between the app and helper
- Fan control and SMC access
- Permission handling
- Local data exposure
- Code signing, packaging, and update flow

General crashes, UI bugs, feature requests, and unsupported hardware behavior should be reported as normal GitHub issues instead.

## Supported Versions

Only the latest public release and the current `main` branch are actively considered for security fixes.

## Privacy

Core-Monitor is open source and is designed to run locally without telemetry, analytics, ad tech, or account tracking.
