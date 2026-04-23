# File: .github/workflows/ci.yml

## Current Role

- Area: GitHub automation.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`.github/workflows/ci.yml`](../../../.github/workflows/ci.yml) |
| Wiki area | GitHub automation |
| Exists in current checkout | True |
| Size | 658 bytes |
| Binary | False |
| Line count | 34 |
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
| `7afc598` | 2026-04-15 | Automate releases and sharpen product positioning |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
name: CI

on:
  push:
    branches:
      - main
      - codex/**
      - feature/**
      - release/**
  pull_request:

jobs:
  macos-tests:
    name: Build and Test
    runs-on: macos-14
    timeout-minutes: 30

    steps:
      - name: Check out repository
        uses: actions/checkout@v4

      - name: Select Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: latest-stable

      - name: Run macOS test suite
        run: |
          xcodebuild test \
            -project Core-Monitor.xcodeproj \
            -scheme Core-Monitor \
            -destination 'platform=macOS' \
            CODE_SIGNING_ALLOWED=NO
```
