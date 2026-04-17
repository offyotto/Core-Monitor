import XCTest
import CoreLocation
import Combine
@testable import Core_Monitor

@MainActor
final class WeatherViewModelTests: XCTestCase {
    func testRefreshNowUsesFallbackLocationWhenAccessIsNotDetermined() async {
        let provider = RecordingWeatherProvider()
        let locationAccess = MockWeatherLocationAccess(status: .notDetermined, currentLocation: nil)
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
            XCTFail("Expected a loaded fallback weather snapshot.")
        }

        XCTAssertEqual(locationAccess.requestAccessCallCount, 0)
        XCTAssertEqual(locationAccess.requestCurrentLocationCallCount, 0)
    }

    func testRefreshNowUsesFallbackProviderWhenWeatherKitCapabilityIsMissing() async {
        let provider = RecordingWeatherProvider()
        let fallbackProvider = RecordingWeatherProvider()
        let locationAccess = MockWeatherLocationAccess(status: .authorizedWhenInUse, currentLocation: nil)
        let viewModel = WeatherViewModel(
            provider: provider,
            locationAccess: locationAccess,
            fallbackProvider: fallbackProvider,
            weatherCapabilityEnabled: { false }
        )

        await viewModel.refreshNow()

        XCTAssertNil(provider.requestedLocation)

        guard let requestedLocation = fallbackProvider.requestedLocation else {
            return XCTFail("Expected the fallback weather provider to receive a fallback location.")
        }

        XCTAssertEqual(requestedLocation.coordinate.latitude, 37.3346, accuracy: 0.0001)
        XCTAssertEqual(requestedLocation.coordinate.longitude, -122.0090, accuracy: 0.0001)

        switch viewModel.state {
        case .loaded(let snapshot):
            XCTAssertEqual(snapshot.locationName, "Recorded")
        default:
            XCTFail("Expected a loaded fallback weather snapshot.")
        }

        XCTAssertEqual(locationAccess.refreshCallCount, 0)
        XCTAssertEqual(locationAccess.requestCurrentLocationCallCount, 0)
    }

    func testRefreshNowRequestsLiveLocationBeforeUsingFallback() async {
        let provider = RecordingWeatherProvider()
        let currentLocation = CLLocation(latitude: 24.8607, longitude: 67.0011)
        let locationAccess = MockWeatherLocationAccess(
            status: .authorizedWhenInUse,
            currentLocation: nil,
            requestedCurrentLocation: currentLocation
        )
        let viewModel = WeatherViewModel(provider: provider, locationAccess: locationAccess)

        await viewModel.refreshNow()

        guard let requestedLocation = provider.requestedLocation else {
            return XCTFail("Expected the weather provider to receive a live location.")
        }

        XCTAssertEqual(requestedLocation.coordinate.latitude, currentLocation.coordinate.latitude, accuracy: 0.0001)
        XCTAssertEqual(requestedLocation.coordinate.longitude, currentLocation.coordinate.longitude, accuracy: 0.0001)
        XCTAssertEqual(locationAccess.requestCurrentLocationCallCount, 1)
    }

    func testRefreshNowUsesFallbackLocationWhenAuthorizedWithoutAvailableCurrentLocation() async {
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

    func testStartRefreshesImmediatelyWhenLocationAccessChanges() async {
        let provider = RecordingWeatherProvider()
        let refreshExpectation = expectation(description: "Weather refreshes after location access changes")
        provider.onRequest = { _ in
            refreshExpectation.fulfill()
        }

        let locationAccess = MockWeatherLocationAccess(status: .notDetermined, currentLocation: nil)
        let viewModel = WeatherViewModel(provider: provider, locationAccess: locationAccess)
        viewModel.refreshInterval = 3_600

        viewModel.start()
        try? await Task.sleep(nanoseconds: 50_000_000)

        let currentLocation = CLLocation(latitude: 24.8607, longitude: 67.0011)
        locationAccess.emitChange(
            status: .authorizedWhenInUse,
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
        let locationAccess = MockWeatherLocationAccess(status: .authorizedWhenInUse, currentLocation: nil)
        let viewModel = WeatherViewModel(
            provider: provider,
            locationAccess: locationAccess,
            fallbackProvider: fallbackProvider
        )

        await viewModel.refreshNow()

        guard let requestedLocation = fallbackProvider.requestedLocation else {
            return XCTFail("Expected the fallback weather provider to be used.")
        }

        XCTAssertEqual(requestedLocation.coordinate.latitude, 37.3346, accuracy: 0.0001)
        XCTAssertEqual(requestedLocation.coordinate.longitude, -122.0090, accuracy: 0.0001)

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
