# File: XCODE_CLOUD.md

## Current Role

- Area: Repository support.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`XCODE_CLOUD.md`](../../../XCODE_CLOUD.md) |
| Wiki area | Repository support |
| Exists in current checkout | True |
| Size | 2993 bytes |
| Binary | False |
| Line count | 81 |
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
| `7afc598` | 2026-04-15 | Automate releases and sharpen product positioning |
| `b4891fe` | 2026-04-14 | Refine public product and documentation copy |
| `011232b` | 2026-04-11 | Update website install video |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
# Xcode Cloud setup for Core-Monitor

Core-Monitor now has source-controlled GitHub Actions for CI and release automation. Use Xcode Cloud only if you specifically want Apple's hosted direct-distribution flow in parallel.

For Xcode Cloud, the repo-side prerequisites are:

- The shared scheme is `Core-Monitor`.
- The archive action uses the `Release` configuration.
- The `smc-helper` target is built as a dependency and embedded into `Core-Monitor.app`.
- `Core-MonitorTests` exists and can run in cloud workflows before archive/notarize steps.

Xcode Cloud workflows are stored in App Store Connect, not in a repository file. Use this checklist to create the workflow in Xcode or App Store Connect.

## Workflow

Name the workflow:

```text
Test, Archive, and Notarize
```

Use these workflow settings:

- Product: `Core-Monitor`
- Repository: this repository
- Branch start condition: run on every push to the branch you use for releases, or all branches if you truly want every push archived
- Environment: Latest stable Xcode and macOS, unless a specific Xcode version is required
- Build action: `Test` followed by `Archive`
- Scheme: `Core-Monitor`
- Platform: `macOS`
- Configuration: `Release`
- Post action: `Notarize`
- Distribution: `Direct Distribution`
- Tests: `Core-MonitorTests`

For this app, prefer a push workflow on your release branch over all branches. Notarizing every experimental branch will burn the monthly compute hours quickly and will also submit every branch build to Apple's notary service.

## Signing

Use automatic signing in Xcode Cloud with team:
```
