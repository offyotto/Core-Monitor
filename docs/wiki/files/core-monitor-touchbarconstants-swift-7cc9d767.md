# File: Core-Monitor/TouchBarConstants.swift

## Current Role

- Area: Touch Bar and Pock widget runtime.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/TouchBarConstants.swift`](../../../Core-Monitor/TouchBarConstants.swift) |
| Wiki area | Touch Bar and Pock widget runtime |
| Exists in current checkout | True |
| Size | 5600 bytes |
| Binary | False |
| Line count | 106 |
| Extension | `.swift` |

## Imports

`AppKit`, `Foundation`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| enum | `TB` | 7 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `4db7203` | 2026-04-16 | Reduce redundant Touch Bar and menu refresh work |
| `2664fd1` | 2026-04-11 | Update Core Monitor |
| `011232b` | 2026-04-11 | Update website install video |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
// TouchBarConstants.swift
// CoreMonitor — single source of truth for every visual token.
// All values tuned from reference screenshots.

import AppKit
import Foundation

enum TB {
    static let refreshInterval: TimeInterval = 10

    // ── Physical Touch Bar geometry ───────────────────────────────────────
    /// Physical height of the Touch Bar strip in points.
    static let stripH: CGFloat = 30

    // ── Group pill ────────────────────────────────────────────────────────
    /// Vertical inset so the pill is shorter than the strip.
    static let pillVInset:  CGFloat = 2
    static let pillH:       CGFloat = stripH - pillVInset * 2   // = 24
    static let pillRadius:  CGFloat = 7.5

    // ── Inter-group gap ───────────────────────────────────────────────────
    static let groupGap:    CGFloat = 8

    // ── Horizontal padding inside a pill ─────────────────────────────────
    static let hPad:        CGFloat = 12
    static let innerGap:    CGFloat = 8

    // ── Typography — SF Pro across the board ─────────────────────────────
    /// Tiny uppercase label above a bar or beside a value (MEM / SSD / CPU / FPS / BAT)
    static let fontKey   = NSFont.systemFont(ofSize: 8,  weight: .semibold)
    /// Value text (13%, 45°, 12, Way Out)
    static let fontVal   = NSFont.systemFont(ofSize: 11, weight: .semibold)
    /// Large time / date (10:38 / Mon 3:03 / Apr 30th)
    static let fontBig   = NSFont.monospacedDigitSystemFont(ofSize: 16, weight: .bold)
    /// Network speed lines (↑ 13 KB/s)
    static let fontNet   = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
    /// Flag + time zone lines
    static let fontTZ    = NSFont.systemFont(ofSize: 11, weight: .semibold)
    /// Weather condition tiny label
    static let fontCond  = NSFont.systemFont(ofSize: 9,  weight: .regular)
```
