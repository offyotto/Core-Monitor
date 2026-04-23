# File: Core-MonitorTests/WeatherWidgetLayoutTests.swift

## Current Role

- Area: Tests.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-MonitorTests/WeatherWidgetLayoutTests.swift`](../../../Core-MonitorTests/WeatherWidgetLayoutTests.swift) |
| Wiki area | Tests |
| Exists in current checkout | True |
| Size | 1405 bytes |
| Binary | False |
| Line count | 46 |
| Extension | `.swift` |

## Imports

`AppKit`, `XCTest`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `WeatherWidgetLayoutTests` | 3 |
| func | `testCompactWeatherWidgetFitsTouchBarHeight` | 7 |
| func | `testExpandedWeatherWidgetFitsTouchBarHeight` | 13 |
| func | `makeWidget` | 23 |
| func | `sampleSnapshot` | 30 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `32f6f43` | 2026-04-18 | Ship 14.0.6 Cupertino Touch Bar fix |
| `1eea57f` | 2026-04-16 | Tighten Touch Bar weather widget layout |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import AppKit
import XCTest
@testable import Core_Monitor

@MainActor
final class WeatherWidgetLayoutTests: XCTestCase {
    func testCompactWeatherWidgetFitsTouchBarHeight() {
        let widget = makeWidget()

        XCTAssertLessThanOrEqual(widget.fittingSize.height, TB.stripH)
        XCTAssertEqual(widget.intrinsicContentSize.height, TB.pillH)
    }

    func testExpandedWeatherWidgetFitsTouchBarHeight() {
        let widget = makeWidget()

        _ = widget.perform(NSSelectorFromString("handleTap:"), with: nil)
        widget.layoutSubtreeIfNeeded()

        XCTAssertLessThanOrEqual(widget.fittingSize.height, TB.stripH)
        XCTAssertEqual(widget.intrinsicContentSize.height, TB.pillH)
    }

    private func makeWidget() -> WeatherWidget {
        let widget = WeatherWidget(frame: NSRect(x: 0, y: 0, width: 280, height: TB.stripH))
        widget.apply(state: .loaded(sampleSnapshot()))
        widget.layoutSubtreeIfNeeded()
        return widget
    }

    private func sampleSnapshot() -> WeatherSnapshot {
        WeatherSnapshot(
            locationName: "Cupertino",
            symbolName: "cloud.sun.fill",
            temperature: 31,
            condition: "Partly Cloudy",
            nextRainSummary: "Dry for the next hour",
            high: 34,
            low: 27,
            feelsLike: 33,
```
