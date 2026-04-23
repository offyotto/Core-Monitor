# File: docs/SECURITY_COMPETITIVE_AUDIT_2026-04-15.md

## Current Role

- Area: Website and documentation.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`docs/SECURITY_COMPETITIVE_AUDIT_2026-04-15.md`](../../../docs/SECURITY_COMPETITIVE_AUDIT_2026-04-15.md) |
| Wiki area | Website and documentation |
| Exists in current checkout | True |
| Size | 7433 bytes |
| Binary | False |
| Line count | 153 |
| Extension | `.md` |

## Imports

None detected.

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| None detected |  |  |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `5dc29ed` | 2026-04-16 | Add privacy controls and refine Core Monitor presentation |
| `c54c313` | 2026-04-16 | Harden helper client authorization and XPC validation |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
# Core-Monitor Security And Competitive Audit

Date: 2026-04-15

## Executive summary

Core-Monitor already has the right strategic shape for a serious Apple Silicon utility:

- local-first monitoring
- open-source transparency
- optional privileged fan control instead of requiring elevated access for everything
- no built-in telemetry, updater framework, or account surface in the core app path

The biggest gap was not missing charts or marketing polish. It was trust hardening around the privileged helper and around user-defined command execution. Those are now the main areas improved in this pass.

## Highest-priority security findings

### 1. Privileged helper accepted XPC clients too broadly

Before this pass, the helper accepted every incoming `NSXPCConnection` and trusted validation done by the app process. That meant the root helper boundary was weaker than it should be, because authorization should be enforced by the privileged service itself.

What changed:

- the helper now derives the allowed client requirement from `SMAuthorizedClients`
- each incoming XPC client is validated against that code-signing requirement
- on macOS 13+, the connection also enforces the same requirement directly through `NSXPCConnection.setCodeSigningRequirement(_:)`
- unauthorized clients are rejected before exported methods are exposed

Why this matters:

- this closes the most important privilege-boundary gap in the repository
- it gives Core-Monitor a stronger fan-control trust story than free tools that leave helper authorization loose or legacy-only

### 2. XPC method inputs were not revalidated inside the helper

Before this pass, `fanID`, `rpm`, and `read` key validation existed on the CLI path and in the app, but not in the XPC entrypoints. That created a trust inversion: privileged behavior depended on lower-privilege callers being honest.

What changed:

- `setFanManual` now validates `fanID` and `rpm` inside the helper
```
