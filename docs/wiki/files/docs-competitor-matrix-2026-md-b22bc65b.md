# File: docs/COMPETITOR_MATRIX_2026.md

## Current Role

- Area: Website and documentation.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`docs/COMPETITOR_MATRIX_2026.md`](../../../docs/COMPETITOR_MATRIX_2026.md) |
| Wiki area | Website and documentation |
| Exists in current checkout | True |
| Size | 10300 bytes |
| Binary | False |
| Line count | 144 |
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
| `70ef30c` | 2026-04-16 | Refresh competitor supportability notes |
| `133d9ad` | 2026-04-16 | Replace alert surfaces with monitoring status |
| `8fbb65c` | 2026-04-16 | Polish README positioning and competitor evidence |
| `f7b2ac8` | 2026-04-16 | Clarify menu bar visibility recovery in support docs |
| `2332898` | 2026-04-16 | Refresh competitive positioning and README framing |
| `5f86848` | 2026-04-15 | Add sourced competitor matrix for product decisions |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
# Core-Monitor Competitor Matrix

Date: 2026-04-16

This document captures the current public positioning of the main macOS monitoring and fan-control competitors that Core-Monitor is most likely to be compared against. It is meant to support product decisions, repo messaging, and roadmap prioritization.

## Snapshot

| Product | Current strength | Publicly documented fan-control model | Important tradeoff | What Core-Monitor should beat |
| --- | --- | --- | --- | --- |
| Stats | Broad open-source menu bar monitoring with a large public user base and easy Homebrew/manual install | Fan control is still present, but the project README says it is in legacy mode and does not receive updates or fixes | Broad feature surface, but weaker trust story around actively maintained fan control | Thermal focus, helper trust, and clearer “monitoring only vs helper required” messaging |
| iStat Menus 7 | Mature menu bar monitoring and polished fan-control UI | Official help documents Automatic, Custom fan curve, and Manual modes; Automatic acts as if iStat Menus is not installed | Broad and polished, but intentionally wider in scope than a thermal-first product | Simpler thermal workflows and less menu bar sprawl by default |
| TG Pro | Strongest “serious fan control” posture and explicit helper/onboarding language | Official docs show per-fan override, Manual mode, and Auto Boost rules; official FAQ separates monitoring-only from helper-backed control | Powerful, but more admin-heavy and rule-oriented than many users need | Open-source transparency, clearer support exports, and a cleaner daily-use dashboard/menu bar experience |
| Macs Fan Control | Simple mental model, strong reputation, broad Mac model support, and clear fan presets story | Official site documents Auto vs Custom, sensor-based control, saved presets, configurable menu bar display, and restoring fans to Auto on quit | UI is intentionally simple and narrow; custom presets are a Pro feature | Modern UI polish, better local diagnostics, and a more informative Apple Silicon dashboard |

## Current source-backed notes

### Stats

- The public repository page shows roughly 38k GitHub stars and a latest release tag of `v2.12.9` dated April 12, 2026.
- The public GitHub README still describes Stats as a macOS system monitor in the menu bar.
- The same README says fan control is in legacy mode and does not receive updates or fixes.
- The README also documents external API usage for update checks and public IP retrieval.
- The README explicitly calls Sensors and Bluetooth among the most expensive modules and suggests disabling them to reduce energy impact.
- GitHub’s security advisory page documents a past local privilege-escalation issue in the privileged helper path.

Implication for Core-Monitor:

- Core-Monitor can be more convincing on fan-control trust if the helper remains actively maintained, clearly scoped, and explained in plain language.
- Core-Monitor should stay local-first and keep the “no telemetry / no external dependency for core monitoring” story crisp.

### iStat Menus 7

- Bjango’s official fan help page documents three modes: Automatic, Custom fan curve, and Manual.
- The same page explicitly says Automatic means fans behave as if iStat Menus is not installed.
- Manual mode is documented as not being saved across reboots.

Implication for Core-Monitor:

- Core-Monitor should preserve the same clarity around when the app is actually controlling fans and when macOS is fully in charge.
```
