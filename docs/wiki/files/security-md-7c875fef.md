# File: SECURITY.md

## Current Role

- Area: Repository support.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`SECURITY.md`](../../../SECURITY.md) |
| Wiki area | Repository support |
| Exists in current checkout | True |
| Size | 1073 bytes |
| Binary | False |
| Line count | 33 |
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
| `b4891fe` | 2026-04-14 | Refine public product and documentation copy |
| `7398a64` | 2026-04-11 | remove yapalogy from security.md:\ |
| `9de18b6` | 2026-04-07 | Create SECURITY.md |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
# Security Policy

## Reporting a Vulnerability

Please do not open a public GitHub issue for security vulnerabilities.

If you find a vulnerability in Core-Monitor, report it privately through the repository owner profile or by opening a private security advisory if that option is available.

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
- Code signing and release packaging

General crashes, UI bugs, feature requests, and unsupported hardware behavior should be reported as normal GitHub issues instead.

## Supported Versions

Only the latest public release and the current `main` branch are actively considered for security fixes.
```
