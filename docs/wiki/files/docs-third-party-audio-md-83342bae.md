# File: docs/THIRD_PARTY_AUDIO.md

## Current Role

- Area: Website and documentation.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`docs/THIRD_PARTY_AUDIO.md`](../../../docs/THIRD_PARTY_AUDIO.md) |
| Wiki area | Website and documentation |
| Exists in current checkout | True |
| Size | 749 bytes |
| Binary | False |
| Line count | 22 |
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
| `4372e29` | 2026-04-19 | Optimize 14.08 release packaging |
| `608ea0c` | 2026-04-19 | Optimize 14.08 release packaging |
| `aca5d59` | 2026-04-19 | Add Kernel Panic release payload |
| `210356e` | 2026-04-19 | Add Kernel Panic release payload |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
# Kernel Panic Audio Sources

`Kernel Panic` now bundles three local AAC `.m4a` phase tracks. To keep the app small, the shipped files are compact local conversions derived from the original CC0 OpenGameArt tracks below.

- `kernelpanic_phase1.m4a`
  Source: [8-Bit Curious Theme](https://opengameart.org/content/8-bit-curious-theme)
  Author: emanresU
  License: CC0
  In-game use: phase 1 warmup + ILOVEYOU

- `kernelpanic_phase2.m4a`
  Source: [Charge!](https://opengameart.org/content/charge)
  Author: Centurion_of_war
  License: CC0
  In-game use: phase 2 warmup + WannaCry

- `kernelpanic_phase3.m4a`
  Source: [Great Boss](https://opengameart.org/content/great-boss)
  Author: Spring Spring
  License: CC0
  In-game use: Stuxnet final phase
```
