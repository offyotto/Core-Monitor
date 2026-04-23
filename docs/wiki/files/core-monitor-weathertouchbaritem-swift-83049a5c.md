# File: Core-Monitor/WeatherTouchBarItem.swift

## Current Role

- Area: Touch Bar and Pock widget runtime.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/WeatherTouchBarItem.swift`](../../../Core-Monitor/WeatherTouchBarItem.swift) |
| Wiki area | Touch Bar and Pock widget runtime |
| Exists in current checkout | True |
| Size | 1543 bytes |
| Binary | False |
| Line count | 62 |
| Extension | `.swift` |

## Imports

`AppKit`, `Combine`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| extension | `NSTouchBarItem.Identifier` | 8 |
| extension | `Notification.Name` | 14 |
| class | `WeatherTouchBarItem` | 20 |
| func | `bindViewModel` | 43 |
| func | `handleTap` | 56 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `011232b` | 2026-04-11 | Update website install video |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
// WeatherTouchBarItem.swift
// Core-Monitor

import AppKit
import Combine

// MARK: - Identifier

extension NSTouchBarItem.Identifier {
    static let weather = NSTouchBarItem.Identifier("com.coremon.touchbar.weather")
}

// MARK: - Notification

extension Notification.Name {
    static let weatherTouchBarTapped = Notification.Name("com.coremon.weatherTouchBarTapped")
}

// MARK: - Item

final class WeatherTouchBarItem: NSCustomTouchBarItem {

    private let weatherView = WeatherTouchBarView(frame: .zero)
    private var viewModel: WeatherViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: Init

    init(viewModel: WeatherViewModel) {
        self.viewModel = viewModel
        super.init(identifier: .weather)

        // Touch Bar height is always 30pt
        weatherView.frame = NSRect(x: 0, y: 0, width: 140, height: 30)
        view = weatherView

        bindViewModel()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }
```
