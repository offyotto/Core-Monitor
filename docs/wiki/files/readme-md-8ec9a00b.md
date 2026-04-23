# File: README.md

## Current Role

- Primary public positioning page for GitHub users, installers, and AI/search discovery.
- Current README describes macOS 13+, helper-optional monitoring, DMG/ZIP/Homebrew installs, fan modes, Touch Bar customization, and Mac App Store edition differences.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`README.md`](../../../README.md) |
| Wiki area | Repository support |
| Exists in current checkout | True |
| Size | 15915 bytes |
| Binary | False |
| Line count | 338 |
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
| `4dc3880` | 2026-04-21 | Update GitHub username references |
| `772d62c` | 2026-04-21 | Update README.md |
| `e5a80e9` | 2026-04-19 | Refine App Store support page |
| `a4e037f` | 2026-04-18 | Update README.md |
| `d5cfafc` | 2026-04-18 | Update README.md |
| `236af94` | 2026-04-18 | Improve AI discovery assets |
| `b829f82` | 2026-04-18 | Add Touch Bar overlay showcase |
| `69cc386` | 2026-04-18 | Add DMG release packaging |
| `3fe35bf` | 2026-04-18 | Add DMG release packaging |
| `55affba` | 2026-04-18 | mention that macOS 12 aint supported no mo |
| `675fabf` | 2026-04-17 | Ship 14.0.5 helper recovery release |
| `5b26198` | 2026-04-17 | Align release asset and add Homebrew guide |
| `52c06bc` | 2026-04-16 | Update README.md |
| `9dfd85c` | 2026-04-16 | Restore README from 7 hours ago |
| `099460c` | 2026-04-16 | Refine overview alert status strip |
| `ebf3e12` | 2026-04-16 | Retire redundant silent fan mode |
| `a5b84af` | 2026-04-16 | Clarify README product stance and install flow |
| `0836e11` | 2026-04-16 | Clarify README product positioning |
| `133d9ad` | 2026-04-16 | Replace alert surfaces with monitoring status |
| `7c0c8d6` | 2026-04-16 | Add dashboard shortcut and app menu access |
| `b8fd8a6` | 2026-04-16 | Clarify silent mode helper handoff semantics |
| `25e286f` | 2026-04-16 | Sharpen README product positioning |
| `bdf7f51` | 2026-04-16 | Align minimum macOS support with launch requirements |
| `8bfc685` | 2026-04-16 | Stabilize signing and WeatherKit release packaging |
| `ef6fa04` | 2026-04-16 | Fix Homebrew install docs |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
<p align="center">
  <img src="./Core-Monitor/Assets.xcassets/AppIcon.appiconset/icon-512.png" alt="Core-Monitor icon" width="180">
</p>

<h1 align="center">Core-Monitor</h1>

<p align="center">
  A native Apple Silicon system monitor and fan-control app for macOS.
</p>

<p align="center">
  <a href="https://github.com/offyotto/Core-Monitor/releases/latest">
    <img src="https://img.shields.io/badge/Download-Latest%20Release-2ea44f?style=for-the-badge" alt="Download latest release">
  </a>
</p>

<p align="center">
  <a href="https://github.com/offyotto/Core-Monitor/releases/latest">Latest release</a>
  ·
  <a href="https://github.com/offyotto/Core-Monitor/releases">All releases</a>
  ·
  <a href="./LICENSE">License</a>
</p>

<p align="center">
  <a href="https://offyotto.github.io/Core-Monitor/">
    <img src="https://img.shields.io/badge/Website-Core--Monitor-8A2BE2?style=flat" alt="Website">
  </a>
  <a href="https://github.com/offyotto/Core-Monitor/releases/latest">
    <img src="https://img.shields.io/badge/Download-latest-brightgreen?style=flat" alt="Download latest">
  </a>
  <a href="./LICENSE">
    <img src="https://img.shields.io/badge/License-GPL--3.0-blue?style=flat" alt="GPL-3.0 license">
  </a>
  <img src="https://img.shields.io/badge/macOS-13%2B-black?style=flat&logo=apple" alt="macOS 13+">
</p>

---

Core-Monitor reads sensor data from the Apple SMC and standard macOS system APIs, then presents it in the menu bar, dashboard, and, on supported hardware, the Touch Bar. CPU, GPU, memory, battery, temperatures, power draw, and fan speeds update continuously in the native app. The Touch Bar layer stays over the app you are already using, so quick stats and launchers remain available without dragging you back to the dashboard.
```
