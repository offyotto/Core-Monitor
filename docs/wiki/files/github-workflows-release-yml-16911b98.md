# File: .github/workflows/release.yml

## Current Role

- Area: GitHub automation.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`.github/workflows/release.yml`](../../../.github/workflows/release.yml) |
| Wiki area | GitHub automation |
| Exists in current checkout | True |
| Size | 8469 bytes |
| Binary | False |
| Line count | 190 |
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
| `7024fe1` | 2026-04-22 | Fix release metadata plist lookup |
| `171c3c6` | 2026-04-22 | Install archive provisioning profile for release CI |
| `04afad0` | 2026-04-22 | Fix release notarization credential fallback |
| `c6a29d4` | 2026-04-18 | Fix release workflow for lightweight tags |
| `69cc386` | 2026-04-18 | Add DMG release packaging |
| `3fe35bf` | 2026-04-18 | Add DMG release packaging |
| `675fabf` | 2026-04-17 | Ship 14.0.5 helper recovery release |
| `5b26198` | 2026-04-17 | Align release asset and add Homebrew guide |
| `7afc598` | 2026-04-15 | Automate releases and sharpen product positioning |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
name: Release

on:
  workflow_dispatch:
    inputs:
      tag:
        description: Existing git tag to release, for example v14.0.0
        required: true
      create_release:
        description: Create or update the GitHub Release after notarization
        required: false
        default: "true"
  push:
    tags:
      - "v*"

permissions:
  contents: write

jobs:
  notarized-release:
    name: Build, Notarize, and Publish
    runs-on: macos-14
    timeout-minutes: 60
    env:
      RELEASE_TAG: ${{ github.event_name == 'workflow_dispatch' && github.event.inputs.tag || github.ref_name }}

    steps:
      - name: Check out repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
          ref: ${{ github.event_name == 'workflow_dispatch' && github.event.inputs.tag || github.ref }}

      - name: Select Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: latest-stable

      - name: Verify release tag exists
```
