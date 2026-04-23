# File: Core-Monitor/WeatherTouchBarView.swift

## Current Role

- Area: Touch Bar and Pock widget runtime.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/WeatherTouchBarView.swift`](../../../Core-Monitor/WeatherTouchBarView.swift) |
| Wiki area | Touch Bar and Pock widget runtime |
| Exists in current checkout | True |
| Size | 10583 bytes |
| Binary | False |
| Line count | 272 |
| Extension | `.swift` |

## Imports

`AppKit`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| enum | `WeatherTBLayout` | 14 |
| class | `WeatherTouchBarView` | 28 |
| func | `commonInit` | 60 |
| func | `configureLabel` | 91 |
| func | `estimatedWidth` | 107 |
| func | `hideAll` | 222 |
| func | `showAll` | 226 |
| func | `temperatureString` | 230 |
| func | `timeString` | 239 |
| func | `shortCondition` | 246 |
| func | `weatherErrorTitle` | 250 |
| func | `symbolImage` | 261 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `29afd92` | 2026-04-18 | Ship 14.0.7 localization update |
| `44eb999` | 2026-04-16 | Harden touch bar customization and weather fallback |
| `311dc52` | 2026-04-15 | Refine first-run onboarding and weather permissions |
| `b09dbec` | 2026-04-14 | Tighten app copy and weather privacy behavior |
| `2664fd1` | 2026-04-11 | Update Core Monitor |
| `011232b` | 2026-04-11 | Update website install video |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
// WeatherTouchBarView.swift
// Core-Monitor
//
// Renders the weather group:
//
//   ┌─────────────────────────────────────────────┐  h=30pt
//   │  [SF Symbol 18pt]  [22.4°]  [Mon 3:03]      │
//   └─────────────────────────────────────────────┘
//   background: NSColor(white:0.18 alpha:1)  cornerRadius: 5

import AppKit

// MARK: - Layout constants (tweak here to pixel-push)

private enum WeatherTBLayout {
    static let height:          CGFloat = 30
    static let hPad:            CGFloat = 8      // left/right inset inside pill
    static let spacing:         CGFloat = 5      // gap between elements
    static let iconSize:        CGFloat = 16     // SF Symbol pt size
    static let cornerRadius:    CGFloat = 5
    static let pillColor        = NSColor(white: 0.18, alpha: 1.0)
    static let primaryFont      = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
    static let secondaryFont    = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
    static let dimFont          = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
}

// MARK: - View

final class WeatherTouchBarView: NSView {

    // ── Public state ───────────────────────────────────────────────────────

    var state: WeatherState = .idle {
        didSet { needsLayout = true; needsDisplay = true }
    }

    /// Whether to show °C or °F
    var useCelsius: Bool = true {
        didSet { needsDisplay = true }
    }
```
