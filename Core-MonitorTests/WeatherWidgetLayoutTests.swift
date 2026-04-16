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
            locationName: "Karachi",
            symbolName: "cloud.sun.fill",
            temperature: 31,
            condition: "Partly Cloudy",
            nextRainSummary: "Dry for the next hour",
            high: 34,
            low: 27,
            feelsLike: 33,
            humidity: 59,
            updatedAt: Date()
        )
    }
}
