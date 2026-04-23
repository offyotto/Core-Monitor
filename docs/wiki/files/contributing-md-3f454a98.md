# File: CONTRIBUTING.md

## Current Role

- Area: Repository support.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`CONTRIBUTING.md`](../../../CONTRIBUTING.md) |
| Wiki area | Repository support |
| Exists in current checkout | True |
| Size | 3777 bytes |
| Binary | False |
| Line count | 99 |
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
| `ebc1125` | 2026-04-16 | Add contributor workflow guide |
| `b4891fe` | 2026-04-14 | Refine public product and documentation copy |
| `3226fec` | 2026-04-12 | Update section title and emphasize AI contribution policy |
| `f987989` | 2026-04-11 | Correct capitalization in contribution guidelines (wow great job on my garbage spelling) |
| `18d283e` | 2026-04-11 | Update CONTRIBUTING.md |
| `2fc184d` | 2026-04-11 | Add contributing guidelines |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
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
