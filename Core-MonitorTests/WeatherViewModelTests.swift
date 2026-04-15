import XCTest
import CoreLocation
@testable import Core_Monitor

@MainActor
final class WeatherViewModelTests: XCTestCase {
    func testRefreshNowShowsOptionalLocationMessageWhenAccessIsNotDetermined() async {
        let provider = RecordingWeatherProvider()
        let locationAccess = MockWeatherLocationAccess(status: .notDetermined, currentLocation: nil)
        let viewModel = WeatherViewModel(provider: provider, locationAccess: locationAccess)

        await viewModel.refreshNow()

        switch viewModel.state {
        case .error(let message):
            XCTAssertEqual(
                message,
                "Location access is optional. Request it from Touch Bar settings for live local weather."
            )
        default:
            XCTFail("Expected an optional-location error state.")
        }

        XCTAssertNil(provider.requestedLocation)
        XCTAssertEqual(locationAccess.requestAccessCallCount, 0)
    }

    func testRefreshNowUsesFallbackLocationWhenAuthorizedWithoutKnownFix() async {
        let provider = RecordingWeatherProvider()
        let locationAccess = MockWeatherLocationAccess(status: .authorizedWhenInUse, currentLocation: nil)
        let viewModel = WeatherViewModel(provider: provider, locationAccess: locationAccess)

        await viewModel.refreshNow()

        guard let requestedLocation = provider.requestedLocation else {
            return XCTFail("Expected the weather provider to receive a fallback location.")
        }

        XCTAssertEqual(requestedLocation.coordinate.latitude, 37.3346, accuracy: 0.0001)
        XCTAssertEqual(requestedLocation.coordinate.longitude, -122.0090, accuracy: 0.0001)

        switch viewModel.state {
        case .loaded(let snapshot):
            XCTAssertEqual(snapshot.locationName, "Recorded")
        default:
            XCTFail("Expected a loaded weather snapshot.")
        }
    }

    func testStartDoesNotRequestLocationAuthorizationOnLaunch() async {
        let provider = RecordingWeatherProvider()
        let locationAccess = MockWeatherLocationAccess(status: .notDetermined, currentLocation: nil)
        let viewModel = WeatherViewModel(provider: provider, locationAccess: locationAccess)
        viewModel.refreshInterval = 3_600

        viewModel.start()
        try? await Task.sleep(nanoseconds: 50_000_000)
        viewModel.stop()

        XCTAssertEqual(locationAccess.requestAccessCallCount, 0)
    }
}

private final class RecordingWeatherProvider: WeatherProviding {
    private(set) var requestedLocation: CLLocation?

    func currentWeather(for location: CLLocation) async throws -> WeatherSnapshot {
        requestedLocation = location
        return WeatherSnapshot(
            locationName: "Recorded",
            symbolName: "cloud.sun.fill",
            temperature: 21,
            condition: "Clear",
            nextRainSummary: "No rain expected soon",
            high: 24,
            low: 18,
            feelsLike: 20,
            humidity: 52,
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
    }
}

@MainActor
private final class MockWeatherLocationAccess: WeatherLocationAccessControlling {
    var authorizationStatus: CLAuthorizationStatus
    var currentLocation: CLLocation?
    private(set) var requestAccessCallCount = 0
    private(set) var refreshCallCount = 0

    init(status: CLAuthorizationStatus, currentLocation: CLLocation?) {
        self.authorizationStatus = status
        self.currentLocation = currentLocation
    }

    func requestAccess() {
        requestAccessCallCount += 1
    }

    func refreshStatus() {
        refreshCallCount += 1
    }
}
