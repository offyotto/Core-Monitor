# File: docs/ARCHITECTURE.md

## Current Role

- Area: Website and documentation.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`docs/ARCHITECTURE.md`](../../../docs/ARCHITECTURE.md) |
| Wiki area | Website and documentation |
| Exists in current checkout | True |
| Size | 7485 bytes |
| Binary | False |
| Line count | 152 |
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
| `133d9ad` | 2026-04-16 | Replace alert surfaces with monitoring status |
| `16a0f40` | 2026-04-16 | Add contributor architecture guide |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
# Core Monitor Architecture

This document is the fast orientation map for contributors working on Core Monitor.

It focuses on the code paths that matter most for product quality, helper trust, and user-facing behavior.

## App shell and entry points

- `Core-Monitor/Core_MonitorApp.swift`
  - App entry point and top-level scene wiring.
  - Owns the shared long-lived objects that feed the dashboard, menu bar, onboarding, and fan control surfaces.
- `Core-Monitor/AppCoordinator.swift`
  - Coordinates launch behavior, dashboard visibility, and menu bar interactions.
  - Good first stop when the app starts in the wrong place or loses discoverability.
- `Core-Monitor/ContentView.swift`
  - Main dashboard surface.
  - Large file with the highest concentration of cross-feature UI, so changes here should stay tightly scoped.

## Monitoring pipeline

- `Core-Monitor/SystemMonitor.swift`
  - Core sampler for CPU, memory, thermal, battery, power, network, and SMC-backed sensor reads.
  - Maintains the live in-memory history buffers used by dashboard and menu bar surfaces.
  - Runs background sampling and publishes the latest `snapshot`.
- `Core-Monitor/MonitoringSnapshot.swift`
  - Shared point-in-time data model for the latest monitoring sample.
  - Keep new monitoring surfaces reading from this model rather than inventing parallel ad hoc state.
- `Core-Monitor/TopProcessSampler.swift`
  - Samples top CPU and memory processes for dashboard context and privacy-sensitive memory views.
  - Important privacy-sensitive path because it captures local process metadata.

## Fan control pipeline

- `Core-Monitor/FanController.swift`
  - Product-facing fan mode logic.
  - Decides when fan writes are needed, validates presets/curves, and falls back when helper or SMC access is unavailable.
- `Core-Monitor/FanCurveEditorView.swift`
  - Dedicated UI for custom curve editing.
  - Geometry and validation changes should normally come with tests.
- `Core-Monitor/SMCHelperManager.swift`
```
