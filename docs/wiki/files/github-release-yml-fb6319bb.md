# File: .github/release.yml

## Current Role

- Area: GitHub automation.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`.github/release.yml`](../../../.github/release.yml) |
| Wiki area | GitHub automation |
| Exists in current checkout | True |
| Size | 363 bytes |
| Binary | False |
| Line count | 21 |
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
| `7afc598` | 2026-04-15 | Automate releases and sharpen product positioning |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
changelog:
  categories:
    - title: Product
      labels:
        - product
        - feature
        - ui
    - title: Fan Control and Helper
      labels:
        - helper
        - fan-control
        - thermals
    - title: Release and Ops
      labels:
        - release
        - ci
        - docs
    - title: Everything Else
      labels:
        - "*"
```
