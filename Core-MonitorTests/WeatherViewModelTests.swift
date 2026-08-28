import XCTest
import CoreLocation
import Combine
@testable import Core_Monitor

@MainActor
final class WeatherViewModelTests: XCTestCase {
    func testRefreshNowDoesNotFetchWithoutLocationAuthorization() async {
        let provider = RecordingWeatherProvider()
        let locationAccess = MockWeatherLocationAccess(status: .notDetermined, currentLocation: nil)
        let viewModel = WeatherViewModel(
            provider: provider,
            locationAccess: locationAccess,
            weatherCapabilityEnabled: { true }
        )

        await viewModel.refreshNow()

        XCTAssertNil(provider.requestedLocation)

        switch viewModel.state {
        case .error(let message):
            XCTAssertEqual(message, "Allow location access to load live weather.")
        default:
            XCTFail("Expected weather to remain gated by location authorization.")
        }

        XCTAssertEqual(locationAccess.requestAccessCallCount, 0)
        XCTAssertEqual(locationAccess.requestCurrentLocationCallCount, 0)
    }

    func testRefreshNowDoesNotFetchWhenWeatherKitCapabilityIsMissing() async {
        let provider = RecordingWeatherProvider()
        let fallbackProvider = RecordingWeatherProvider()
        let locationAccess = MockWeatherLocationAccess(status: .authorizedAlways, currentLocation: nil)
        let viewModel = WeatherViewModel(
            provider: provider,
            locationAccess: locationAccess,
            fallbackProvider: fallbackProvider,
            weatherCapabilityEnabled: { false }
        )

        await viewModel.refreshNow()

        XCTAssertNil(provider.requestedLocation)
        XCTAssertNil(fallbackProvider.requestedLocation)

        switch viewModel.state {
        case .error(let message):
            XCTAssertEqual(message, "WeatherKit is unavailable in this build.")
        default:
            XCTFail("Expected a WeatherKit capability error.")
        }

        XCTAssertEqual(locationAccess.refreshCallCount, 0)
        XCTAssertEqual(locationAccess.requestCurrentLocationCallCount, 0)
    }

    func testRefreshNowRequestsLiveLocationBeforeFetchingWeather() async {
        let provider = RecordingWeatherProvider()
        let currentLocation = CLLocation(latitude: 24.8607, longitude: 67.0011)
        let locationAccess = MockWeatherLocationAccess(
            status: .authorizedAlways,
            currentLocation: nil,
            requestedCurrentLocation: currentLocation
        )
        let viewModel = WeatherViewModel(
            provider: provider,
            locationAccess: locationAccess,
            weatherCapabilityEnabled: { true }
        )

        await viewModel.refreshNow()

        guard let requestedLocation = provider.requestedLocation else {
            return XCTFail("Expected the weather provider to receive a live location.")
        }

        XCTAssertEqual(requestedLocation.coordinate.latitude, currentLocation.coordinate.latitude, accuracy: 0.0001)
        XCTAssertEqual(requestedLocation.coordinate.longitude, currentLocation.coordinate.longitude, accuracy: 0.0001)
        XCTAssertEqual(locationAccess.requestCurrentLocationCallCount, 1)
    }

    func testRefreshNowDoesNotFetchWhenCurrentLocationIsUnavailable() async {
        let provider = RecordingWeatherProvider()
        let locationAccess = MockWeatherLocationAccess(status: .authorizedAlways, currentLocation: nil)
        let viewModel = WeatherViewModel(
            provider: provider,
            locationAccess: locationAccess,
            weatherCapabilityEnabled: { true }
        )

        await viewModel.refreshNow()

        XCTAssertNil(provider.requestedLocation)
        XCTAssertEqual(locationAccess.requestCurrentLocationCallCount, 1)

        switch viewModel.state {
        case .error(let message):
            XCTAssertEqual(message, "Current location is unavailable. Try again after macOS resolves your location.")
        default:
            XCTFail("Expected an unavailable-location error.")
        }
    }

    func testStartRequestsLocationAfterExplicitWeatherOptIn() async {
        let provider = RecordingWeatherProvider()
        let locationAccess = MockWeatherLocationAccess(status: .notDetermined, currentLocation: nil)
        let viewModel = WeatherViewModel(
            provider: provider,
            locationAccess: locationAccess,
            weatherCapabilityEnabled: { true }
        )
        viewModel.refreshInterval = 3_600

        viewModel.start()
        try? await Task.sleep(nanoseconds: 50_000_000)
        viewModel.stop()

        XCTAssertEqual(locationAccess.requestAccessCallCount, 1)
        XCTAssertNil(provider.requestedLocation)
    }

    func testStartRefreshesImmediatelyWhenLocationAccessChanges() async {
        let provider = RecordingWeatherProvider()
        let refreshExpectation = expectation(description: "Weather refreshes after location access changes")
        provider.onRequest = { _ in
            refreshExpectation.fulfill()
        }

        let locationAccess = MockWeatherLocationAccess(status: .notDetermined, currentLocation: nil)
        let viewModel = WeatherViewModel(
            provider: provider,
            locationAccess: locationAccess,
            weatherCapabilityEnabled: { true }
        )
        viewModel.refreshInterval = 3_600

        viewModel.start()
        try? await Task.sleep(nanoseconds: 50_000_000)

        let currentLocation = CLLocation(latitude: 24.8607, longitude: 67.0011)
        locationAccess.emitChange(
            status: .authorizedAlways,
            currentLocation: currentLocation
        )

        await fulfillment(of: [refreshExpectation], timeout: 1.5)

        switch viewModel.state {
        case .loaded(let snapshot):
            XCTAssertEqual(snapshot.locationName, "Recorded")
        default:
            XCTFail("Expected a loaded weather snapshot after opt-in.")
        }

        viewModel.stop()
    }

    func testRefreshNowUsesFallbackProviderWhenLiveProviderFails() async {
        let provider = FailingWeatherProvider()
        let fallbackProvider = RecordingWeatherProvider()
        let currentLocation = CLLocation(latitude: 24.8607, longitude: 67.0011)
        let locationAccess = MockWeatherLocationAccess(
            status: .authorizedAlways,
            currentLocation: currentLocation
        )
        let viewModel = WeatherViewModel(
            provider: provider,
            locationAccess: locationAccess,
            fallbackProvider: fallbackProvider,
            weatherCapabilityEnabled: { true }
        )

        await viewModel.refreshNow()

        guard let requestedLocation = fallbackProvider.requestedLocation else {
            return XCTFail("Expected the fallback weather provider to be used.")
        }

        XCTAssertEqual(requestedLocation.coordinate.latitude, currentLocation.coordinate.latitude, accuracy: 0.0001)
        XCTAssertEqual(requestedLocation.coordinate.longitude, currentLocation.coordinate.longitude, accuracy: 0.0001)

        switch viewModel.state {
        case .loaded(let snapshot):
            XCTAssertEqual(snapshot.locationName, "Recorded")
        default:
            XCTFail("Expected a loaded weather snapshot from the fallback provider.")
        }
    }
}

private final class RecordingWeatherProvider: WeatherProviding {
    private(set) var requestedLocation: CLLocation?
    var onRequest: ((CLLocation) -> Void)?

    func currentWeather(for location: CLLocation) async throws -> WeatherSnapshot {
        requestedLocation = location
        onRequest?(location)
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

private final class FailingWeatherProvider: WeatherProviding {
    struct TestError: LocalizedError {
        var errorDescription: String? { "Live weather failed." }
    }

    func currentWeather(for location: CLLocation) async throws -> WeatherSnapshot {
        throw TestError()
    }
}

@MainActor
private final class MockWeatherLocationAccess: WeatherLocationAccessControlling {
    var authorizationStatus: CLAuthorizationStatus
    var currentLocation: CLLocation?
    var changePublisher: AnyPublisher<Void, Never> {
        changeSubject.eraseToAnyPublisher()
    }
    private(set) var requestAccessCallCount = 0
    private(set) var refreshCallCount = 0
    private(set) var requestCurrentLocationCallCount = 0
    private let changeSubject = PassthroughSubject<Void, Never>()
    private var requestedCurrentLocation: CLLocation?

    init(
        status: CLAuthorizationStatus,
        currentLocation: CLLocation?,
        requestedCurrentLocation: CLLocation? = nil
    ) {
        self.authorizationStatus = status
        self.currentLocation = currentLocation
        self.requestedCurrentLocation = requestedCurrentLocation
    }

    func requestAccess() {
        requestAccessCallCount += 1
    }

    func refreshStatus() {
        refreshCallCount += 1
    }

    func requestCurrentLocation() async -> CLLocation? {
        requestCurrentLocationCallCount += 1
        return requestedCurrentLocation ?? currentLocation
    }

    func emitChange(
        status: CLAuthorizationStatus? = nil,
        currentLocation: CLLocation? = nil,
        requestedCurrentLocation: CLLocation? = nil
    ) {
        if let status {
            authorizationStatus = status
        }
        if let requestedCurrentLocation {
            self.requestedCurrentLocation = requestedCurrentLocation
        }
        self.currentLocation = currentLocation
        changeSubject.send(())
    }
}
