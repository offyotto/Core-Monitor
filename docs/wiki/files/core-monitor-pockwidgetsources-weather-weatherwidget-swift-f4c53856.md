# File: Core-Monitor/PockWidgetSources/Weather/WeatherWidget.swift

## Current Role

- Area: Touch Bar and Pock widget runtime.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/PockWidgetSources/Weather/WeatherWidget.swift`](../../../Core-Monitor/PockWidgetSources/Weather/WeatherWidget.swift) |
| Wiki area | Touch Bar and Pock widget runtime |
| Exists in current checkout | True |
| Size | 14130 bytes |
| Binary | False |
| Line count | 339 |
| Extension | `.swift` |

## Imports

`AppKit`, `Foundation`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `WeatherWidget` | 10 |
| enum | `DisplayMode` | 12 |
| func | `apply` | 46 |
| func | `setup` | 98 |
| func | `applyTheme` | 193 |
| func | `handleTap` | 203 |
| func | `toggleMode` | 207 |
| func | `refreshLayout` | 212 |
| func | `estimatedWidth` | 238 |
| func | `defaultImage` | 252 |
| func | `icon` | 261 |
| func | `weatherAssetName` | 275 |
| func | `weatherTooltip` | 311 |
| func | `expandedSummary` | 318 |
| func | `weatherErrorPresentation` | 327 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `44eb999` | 2026-04-16 | Harden touch bar customization and weather fallback |
| `1eea57f` | 2026-04-16 | Tighten Touch Bar weather widget layout |
| `311dc52` | 2026-04-15 | Refine first-run onboarding and weather permissions |
| `b09dbec` | 2026-04-14 | Tighten app copy and weather privacy behavior |
| `6675114` | 2026-04-13 | e |
| `679aae6` | 2026-04-12 | changes. |
| `2664fd1` | 2026-04-11 | Update Core Monitor |
| `011232b` | 2026-04-11 | Update website install video |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
//
//  WeatherWidget.swift
//  Weather
//
//  Weather widget source for Core Monitor.
//

import AppKit
import Foundation

final class WeatherWidget: NSView, TouchBarThemable {
    private enum DisplayMode {
        case compact
        case expanded
    }

    var theme: TouchBarTheme = .dark {
        didSet { applyTheme() }
    }

    private let compactIconView = NSImageView(frame: .zero)
    private let expandedIconView = NSImageView(frame: .zero)
    private let compactTitleLabel = NSTextField(labelWithString: "Weather")
    private let compactSubtitleLabel = NSTextField(labelWithString: "Updating weather")
    private let expandedTitleLabel = NSTextField(labelWithString: "Weather")
    private let expandedSubtitleLabel = NSTextField(labelWithString: "Updating weather")
    private let detailLabel = NSTextField(labelWithString: "")
    private let compactLabelsStack = NSStackView(frame: .zero)
    private let expandedLabelsStack = NSStackView(frame: .zero)
    private let compactStack = NSStackView(frame: .zero)
    private let expandedTextStack = NSStackView(frame: .zero)
    private let expandedStack = NSStackView(frame: .zero)
    private let tapButton = NSButton(frame: .zero)
    private var displayMode: DisplayMode = .compact
    private var currentState: WeatherState = .idle

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
```
