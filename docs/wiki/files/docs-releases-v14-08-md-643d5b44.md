# File: docs/releases/v14.08.md

## Current Role

- Area: Website and documentation.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`docs/releases/v14.08.md`](../../../docs/releases/v14.08.md) |
| Wiki area | Website and documentation |
| Exists in current checkout | True |
| Size | 1064 bytes |
| Binary | False |
| Line count | 29 |
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
| `aca5d59` | 2026-04-19 | Add Kernel Panic release payload |
| `210356e` | 2026-04-19 | Add Kernel Panic release payload |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
# Core-Monitor 14.08

## Summary

This release ships the current Weird Mode overhaul with **Kernel Panic**, a raw monochrome parody boss rush built directly into the app, plus bundled retro phase music.

## Highlights

- Replaced the previous easter egg implementation with **Kernel Panic**
- Added the ILOVEYOU, WannaCry, and Stuxnet boss sequence with escalating difficulty
- Added a phase skip control for fast testing and replay
- Added bundled local phase music for the game:
  - phase 1 / ILOVEYOU
  - phase 2 / WannaCry
  - Stuxnet final phase
- Kept the soundtrack legally clean with bundled CC0 tracks documented in `docs/THIRD_PARTY_AUDIO.md`

## Safety Note

Kernel Panic is a fictional parody game. It uses historical malware names only as themes and jokes. It does not implement real malware behavior, encryption, propagation, persistence, privilege escalation, scanning, or destructive payloads.

## Planned Release Assets

- `Core-Monitor.dmg`
- `Core-Monitor.dmg.sha256`
- `Core-Monitor.app.zip`
- `Core-Monitor.app.zip.sha256`
- `core-monitor.rb`
```
