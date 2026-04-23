# File: .github/ISSUE_TEMPLATE/bug_report.yml

## Current Role

- Area: GitHub automation.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`.github/ISSUE_TEMPLATE/bug_report.yml`](../../../.github/ISSUE_TEMPLATE/bug_report.yml) |
| Wiki area | GitHub automation |
| Exists in current checkout | True |
| Size | 4046 bytes |
| Binary | False |
| Line count | 123 |
| Extension | `.yml` |

## Imports

None detected.

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| None detected |  |  |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `133d9ad` | 2026-04-16 | Replace alert surfaces with monitoring status |
| `d7d5269` | 2026-04-16 | Add helper diagnostics support docs |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
name: Bug report
description: Report a Core Monitor defect with the context needed to reproduce and fix it.
title: "[Bug] "
labels:
  - bug
body:
  - type: markdown
    attributes:
      value: |
        Thanks for reporting a problem.

        If the issue involves fan control, helper installation, or the app saying the helper is unavailable, export the helper diagnostics report first and attach it here.

        In Core Monitor:
        1. Open `Help`
        2. Choose `Open Welcome Guide`
        3. Use `Export Report` in the readiness panel

        The report is a local JSON file with app signing, helper install/connectivity, launch-at-login, and menu bar context.
  - type: dropdown
    id: area
    attributes:
      label: Area
      description: Which part of Core Monitor is failing?
      options:
        - Fan control / helper
        - Monitoring / sensors
        - Status / diagnostics
        - Menu bar
        - Dashboard UI
        - Touch Bar
        - Weather
        - Startup / launch at login
        - Documentation / repo
        - Other
    validations:
      required: true
  - type: input
    id: app_version
    attributes:
```
