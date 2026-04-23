# File: Core-Monitor/TouchBarUtilityWidgets.swift

## Current Role

- Area: Touch Bar and Pock widget runtime.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/TouchBarUtilityWidgets.swift`](../../../Core-Monitor/TouchBarUtilityWidgets.swift) |
| Wiki area | Touch Bar and Pock widget runtime |
| Exists in current checkout | True |
| Size | 24869 bytes |
| Binary | False |
| Line count | 722 |
| Extension | `.swift` |

## Imports

`AppKit`, `CoreAudio`, `Foundation`, `IOKit`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| protocol | `TouchBarThemable` | 6 |
| struct | `TouchBarTheme` | 10 |
| func | `hash` | 41 |
| class | `ControlCenterTouchBarWidget` | 50 |
| enum | `ActionTag` | 55 |
| func | `setup` | 81 |
| func | `invokeAction` | 118 |
| func | `adjustVolume` | 133 |
| func | `applyTheme` | 138 |
| enum | `SystemVolume` | 150 |
| enum | `SystemBrightness` | 211 |
| class | `ControlCenterSliderPresenter` | 231 |
| enum | `SliderKind` | 233 |
| func | `present` | 267 |
| func | `dismiss` | 284 |
| func | `touchBar` | 292 |
| class | `ControlCenterSliderView` | 306 |
| func | `setup` | 329 |
| func | `configureButton` | 355 |
| func | `currentValue` | 370 |
| func | `setValue` | 379 |
| func | `applyTheme` | 389 |
| func | `stepDown` | 398 |
| func | `stepUp` | 403 |
| func | `sliderChanged` | 408 |
| func | `closePressed` | 412 |
| class | `MeterControl` | 417 |
| func | `set` | 465 |
| class | `RAMPressureTouchBarWidget` | 471 |
| func | `setup` | 489 |
| func | `update` | 505 |
| func | `applyTheme` | 517 |
| class | `DockTouchBarWidget` | 523 |
| func | `setup` | 543 |
| func | `reload` | 575 |
| func | `applyTheme` | 582 |
| func | `rebuildStack` | 587 |
| func | `mergedItems` | 643 |
| func | `launchItem` | 668 |
| func | `loadDockItems` | 680 |
| func | `loadPersistentItems` | 696 |
| struct | `DockTouchBarItem` | 713 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `ce9e812` | 2026-04-16 | Fix Xcode 16.2 CI compatibility |
| `3fff2ff` | 2026-04-16 | Fix Xcode 16.2 CI compatibility |
| `5b96f6f` | 2026-04-16 | Fix Xcode 16.2 CI compatibility |
| `0ef6575` | 2026-04-16 | Unify monitor refresh delivery paths |
| `4db7203` | 2026-04-16 | Reduce redundant Touch Bar and menu refresh work |
| `6675114` | 2026-04-13 | e |
| `679aae6` | 2026-04-12 | changes. |
| `2664fd1` | 2026-04-11 | Update Core Monitor |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import AppKit
import Foundation
import CoreAudio
import IOKit
import IOKit.graphics

protocol TouchBarThemable: AnyObject {
    var theme: TouchBarTheme { get set }
}

struct TouchBarTheme: Equatable, Hashable {
    let primaryTextColor: NSColor
    let secondaryTextColor: NSColor
    let pillBackgroundColor: NSColor
    let pillBorderColor: NSColor
    let barOutlineColor: NSColor

    static let dark = TouchBarTheme(
        primaryTextColor: .white,
        secondaryTextColor: NSColor.white.withAlphaComponent(0.72),
        pillBackgroundColor: NSColor.white.withAlphaComponent(0.08),
        pillBorderColor: NSColor.white.withAlphaComponent(0.15),
        barOutlineColor: NSColor.white.withAlphaComponent(0.35)
    )

    static let light = TouchBarTheme(
        primaryTextColor: .labelColor,
        secondaryTextColor: NSColor.secondaryLabelColor,
        pillBackgroundColor: NSColor.black.withAlphaComponent(0.06),
        pillBorderColor: NSColor.black.withAlphaComponent(0.12),
        barOutlineColor: NSColor.black.withAlphaComponent(0.25)
    )

    static func == (lhs: TouchBarTheme, rhs: TouchBarTheme) -> Bool {
        lhs.primaryTextColor == rhs.primaryTextColor &&
        lhs.secondaryTextColor == rhs.secondaryTextColor &&
        lhs.pillBackgroundColor == rhs.pillBackgroundColor &&
        lhs.pillBorderColor == rhs.pillBorderColor &&
        lhs.barOutlineColor == rhs.barOutlineColor
    }
```
