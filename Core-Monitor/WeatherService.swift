// WeatherService.swift
// Core-Monitor — WeatherKit data layer
// Requires: WeatherKit entitlement + Privacy Usage string in Info.plist

import Foundation
import Combine
import WeatherKit
import CoreLocation
import Security

// MARK: - Domain model

struct WeatherSnapshot: Sendable {
    let locationName: String
    let symbolName: String      // SF Symbol name
    let temperature: Double     // Celsius
    let condition: String       // Short label e.g. "Partly Cloudy"
    let nextRainSummary: String
    let high: Double
    let low: Double
    let feelsLike: Double
    let humidity: Int           // 0-100
    let updatedAt: Date
}

struct WeatherAttributionSnapshot: Sendable {
    let legalPageURL: URL
    let markURL: URL
    let serviceName: String
    let legalText: String?
}

enum WeatherKitCapability {
    private static let entitlementKey = "com.apple.developer.weatherkit"

    static func isEnabled() -> Bool {
        guard let task = SecTaskCreateFromSelf(nil),
              let entitlement = SecTaskCopyValueForEntitlement(task, entitlementKey as CFString, nil) else {
            return false
        }

        guard CFGetTypeID(entitlement) == CFBooleanGetTypeID() else {
            return false
        }

        return CFBooleanGetValue((entitlement as! CFBoolean))
    }
}

// MARK: - Protocol (enables mock injection)

protocol WeatherProviding: AnyObject {
    func currentWeather(for location: CLLocation) async throws -> WeatherSnapshot
}

@MainActor
protocol WeatherLocationAccessControlling: AnyObject {
    var authorizationStatus: CLAuthorizationStatus { get }
    var currentLocation: CLLocation? { get }
    var changePublisher: AnyPublisher<Void, Never> { get }
    func requestAccess()
    func refreshStatus()
    func requestCurrentLocation() async -> CLLocation?
}

@MainActor
final class WeatherLocationAccessController: NSObject, ObservableObject, CLLocationManagerDelegate, WeatherLocationAccessControlling {
    static let shared = WeatherLocationAccessController()

    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var currentLocation: CLLocation?

    private let changeSubject = PassthroughSubject<Void, Never>()
    private let locationManager: CLLocationManager
    private var pendingLocationContinuations: [CheckedContinuation<CLLocation?, Never>] = []
    private var locationRequestTimeoutTask: Task<Void, Never>?
    private var isRequestingLocation = false

    private override init() {
        let locationManager = CLLocationManager()
        self.locationManager = locationManager
        self.authorizationStatus = locationManager.authorizationStatus
        self.currentLocation = locationManager.location
        super.init()
        locationManager.delegate = self
    }

    var changePublisher: AnyPublisher<Void, Never> {
        changeSubject.eraseToAnyPublisher()
    }

    func requestAccess() {
        guard authorizationStatus == .notDetermined else { return }
        locationManager.requestWhenInUseAuthorization()
    }

    func refreshStatus() {
        applyLocationManagerState(from: locationManager, emitChanges: false)
    }

    func requestCurrentLocation() async -> CLLocation? {
        refreshStatus()

        if let currentLocation, Self.isLocationFresh(currentLocation) {
            return currentLocation
        }

        guard Self.isAuthorized(authorizationStatus) else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            pendingLocationContinuations.append(continuation)
            requestLocationIfNeeded(force: true)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            self?.applyLocationManagerState(from: manager, emitChanges: true)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let latestLocation = locations.last ?? manager.location
        Task { @MainActor [weak self] in
            self?.applyResolvedLocation(latestLocation)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let clError = error as? CLError, clError.code == .locationUnknown {
                return
            }
            self.finishLocationRequests(with: self.currentLocation)
        }
    }

    private func applyLocationManagerState(from manager: CLLocationManager, emitChanges: Bool) {
        let nextStatus = manager.authorizationStatus
        let nextLocation = Self.isAuthorized(nextStatus) ? manager.location : nil
        var didChange = false

        if authorizationStatus != nextStatus {
            authorizationStatus = nextStatus
            didChange = true
        }

        if Self.locationsMatch(currentLocation, nextLocation) == false {
            currentLocation = nextLocation
            didChange = true
        }

        if Self.isAuthorized(nextStatus) {
            requestLocationIfNeeded()
        } else {
            finishLocationRequests(with: nil)
        }

        if emitChanges && didChange {
            changeSubject.send()
        }
    }

    private func applyResolvedLocation(_ location: CLLocation?) {
        let didChange = Self.locationsMatch(currentLocation, location) == false
        currentLocation = location
        finishLocationRequests(with: location)
        if didChange {
            changeSubject.send()
        }
    }

    private func requestLocationIfNeeded(force: Bool = false) {
        guard Self.isAuthorized(authorizationStatus) else {
            finishLocationRequests(with: nil)
            return
        }
        if force == false, let currentLocation, Self.isLocationFresh(currentLocation) {
            return
        }
        guard isRequestingLocation == false else { return }

        isRequestingLocation = true
        locationManager.requestLocation()

        locationRequestTimeoutTask?.cancel()
        locationRequestTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard let self else { return }
            self.finishLocationRequests(with: self.currentLocation)
        }
    }

    private func finishLocationRequests(with location: CLLocation?) {
        isRequestingLocation = false
        locationRequestTimeoutTask?.cancel()
        locationRequestTimeoutTask = nil

        let continuations = pendingLocationContinuations
        pendingLocationContinuations.removeAll()
        for continuation in continuations {
            continuation.resume(returning: location)
        }
    }

    private nonisolated static func isAuthorized(_ status: CLAuthorizationStatus) -> Bool {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }

    private nonisolated static func isLocationFresh(_ location: CLLocation) -> Bool {
        abs(location.timestamp.timeIntervalSinceNow) < 900
    }

    private nonisolated static func locationsMatch(_ lhs: CLLocation?, _ rhs: CLLocation?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (lhs?, rhs?):
            return lhs.distance(from: rhs) < 1
        default:
            return false
        }
    }
}

// MARK: - Live implementation

@available(macOS 13.0, *)
@MainActor
final class LiveWeatherService: WeatherProviding {

    private let service = WeatherService()

    nonisolated func currentWeather(for location: CLLocation) async throws -> WeatherSnapshot {
        let weather = try await service.weather(for: location)
        let current = weather.currentWeather
        let locationName = await Self.locationName(for: location)
        let nextRainSummary = Self.nextRainSummary(from: weather)

        return WeatherSnapshot(
            locationName: locationName,
            symbolName:  current.symbolName,
            temperature: current.temperature.converted(to: .celsius).value,
            condition:   current.condition.description,
            nextRainSummary: nextRainSummary,
            high:        weather.dailyForecast.first?.highTemperature.converted(to: .celsius).value
                             ?? current.temperature.converted(to: .celsius).value,
            low:         weather.dailyForecast.first?.lowTemperature.converted(to: .celsius).value
                             ?? current.temperature.converted(to: .celsius).value,
            feelsLike:   current.apparentTemperature.converted(to: .celsius).value,
            humidity:    Int((current.humidity * 100).rounded()),
            updatedAt:   Date()
        )
    }

    private nonisolated static func nextRainSummary(from weather: Weather) -> String {
        let now = Date()

        if let currentHour = weather.hourlyForecast.forecast.first(where: { $0.date >= now }),
           isRainy(currentHour.condition) {
            return "Raining now"
        }

        if let nextRain = weather.hourlyForecast.forecast.first(where: { hour in
            hour.date >= now && isRainy(hour.condition)
        }) {
            let formatter = DateFormatter()
            formatter.locale = Locale.current
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            return "Next rain at \(formatter.string(from: nextRain.date))"
        }

        if let nextPrecip = weather.hourlyForecast.forecast.first(where: { hour in
            hour.date >= now && hour.precipitationChance >= 0.35
        }) {
            let formatter = DateFormatter()
            formatter.locale = Locale.current
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            let pct = Int((nextPrecip.precipitationChance * 100).rounded())
            return "Rain likely at \(formatter.string(from: nextPrecip.date)) (\(pct)%)"
        }

        return "No rain expected soon"
    }

    private nonisolated static func isRainy(_ condition: WeatherCondition) -> Bool {
        let raw = String(describing: condition).lowercased()
        return raw.contains("rain") || raw.contains("drizzle") || raw.contains("thunder")
    }

    private nonisolated static func locationName(for location: CLLocation) async -> String {
        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            if let place = placemarks.first {
                return place.locality
                    ?? place.subAdministrativeArea
                    ?? place.name
                    ?? "Weather"
            }
        } catch {
            // Keep the WeatherKit fetch path intact and fall back to a generic title.
        }
        return "Weather"
    }
}

// MARK: - Mock implementation

final class MockWeatherService: WeatherProviding {

    func currentWeather(for location: CLLocation) async throws -> WeatherSnapshot {
        // Simulate a slight network delay so loading state is visible
        try await Task.sleep(nanoseconds: 400_000_000)
        return WeatherSnapshot(
            locationName: "Cupertino",
            symbolName:  "cloud.sun.rain.fill",
            temperature: 22.4,
            condition:   "Partly Cloudy",
            nextRainSummary: "Rain likely at 4:00 PM (40%)",
            high:        26.0,
            low:         18.5,
            feelsLike:   21.0,
            humidity:    63,
            updatedAt:   Date()
        )
    }
}

@available(macOS 13.0, *)
func loadWeatherAttribution(isDarkAppearance: Bool) async throws -> WeatherAttributionSnapshot {
    let attribution = try await WeatherService.shared.attribution
    let markURL = isDarkAppearance ? attribution.combinedMarkDarkURL : attribution.combinedMarkLightURL
    let legalText: String?

    if #available(macOS 13.3, *) {
        legalText = attribution.legalAttributionText
    } else {
        legalText = nil
    }

    return WeatherAttributionSnapshot(
        legalPageURL: attribution.legalPageURL,
        markURL: markURL,
        serviceName: attribution.serviceName,
        legalText: legalText
    )
}

// MARK: - View model

enum WeatherState {
    case idle
    case loading
    case loaded(WeatherSnapshot)
    case error(String)
}

@MainActor
final class WeatherViewModel: ObservableObject {

    @Published private(set) var state: WeatherState = .idle

    private let provider: WeatherProviding
    private let locationAccess: WeatherLocationAccessControlling
    private let fallbackProvider: WeatherProviding?
    private let weatherCapabilityEnabled: @MainActor @Sendable () -> Bool
    private var cancellables = Set<AnyCancellable>()
    private var refreshTask: Task<Void, Never>?
    private var isRunning = false
    private var lastSnapshot: WeatherSnapshot?

    private static let fallbackLocation = CLLocation(latitude: 37.3346, longitude: -122.0090)

    /// Refresh interval in seconds (default 10 min)
    var refreshInterval: TimeInterval = 600

    init(provider: WeatherProviding) {
        self.provider = provider
        self.locationAccess = WeatherLocationAccessController.shared
        self.fallbackProvider = provider is MockWeatherService ? nil : MockWeatherService()
        self.weatherCapabilityEnabled = WeatherKitCapability.isEnabled
        bindLocationAccess()
    }

    init(
        provider: WeatherProviding,
        locationAccess: WeatherLocationAccessControlling,
        fallbackProvider: WeatherProviding? = nil,
        weatherCapabilityEnabled: @escaping @MainActor @Sendable () -> Bool = WeatherKitCapability.isEnabled
    ) {
        self.provider = provider
        self.locationAccess = locationAccess
        self.fallbackProvider = fallbackProvider
        self.weatherCapabilityEnabled = weatherCapabilityEnabled
        bindLocationAccess()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        locationAccess.refreshStatus()
        scheduleRefresh()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        refreshTask?.cancel()
        refreshTask = nil
        state = .idle
    }

    // MARK: Private

    private func bindLocationAccess() {
        locationAccess.changePublisher
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] in
                guard let self, self.isRunning else { return }
                Task { @MainActor [weak self] in
                    await self?.refreshNow()
                }
            }
            .store(in: &cancellables)
    }

    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refreshNow()
                try? await Task.sleep(nanoseconds: UInt64(self.refreshInterval * 1_000_000_000))
            }
        }
    }

    func refreshNow() async {
        guard weatherCapabilityEnabled() else {
            await refreshFallbackWeather()
            return
        }

        locationAccess.refreshStatus()

        let authorizationStatus = locationAccess.authorizationStatus
        let location: CLLocation

        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if let currentLocation = locationAccess.currentLocation {
                location = currentLocation
            } else {
                location = await locationAccess.requestCurrentLocation() ?? Self.fallbackLocation
            }
        case .notDetermined, .denied, .restricted:
            location = Self.fallbackLocation
        @unknown default:
            location = Self.fallbackLocation
        }

        state = .loading

        do {
            try await loadWeatherSnapshot(using: provider, location: location)
        } catch {
            if let lastSnapshot {
                state = .loaded(lastSnapshot)
                return
            }

            if let fallbackProvider,
               let fallbackSnapshot = try? await fetchWeatherSnapshot(
                    using: fallbackProvider,
                    location: Self.fallbackLocation
               ) {
                applyLoadedSnapshot(fallbackSnapshot)
                return
            }

            state = .error(errorMessage(for: authorizationStatus, underlyingError: error))
        }
    }

    private func errorMessage(
        for authorizationStatus: CLAuthorizationStatus,
        underlyingError: Error
    ) -> String {
        switch authorizationStatus {
        case .notDetermined:
            return "Weather fallback is unavailable right now. Request location from Touch Bar settings for live local weather."
        case .denied, .restricted:
            return "Weather fallback is unavailable right now. Enable location in System Settings for live local weather."
        default:
            return underlyingError.localizedDescription
        }
    }

    private func refreshFallbackWeather() async {
        state = .loading

        do {
            let snapshot = try await fetchWeatherSnapshot(
                using: fallbackProvider ?? provider,
                location: Self.fallbackLocation
            )
            applyLoadedSnapshot(snapshot)
        } catch {
            if let lastSnapshot {
                state = .loaded(lastSnapshot)
                return
            }

            state = .error("Weather fallback is unavailable right now.")
        }
    }

    private func loadWeatherSnapshot(using provider: WeatherProviding, location: CLLocation) async throws {
        let snapshot = try await fetchWeatherSnapshot(using: provider, location: location)
        applyLoadedSnapshot(snapshot)
    }

    private func fetchWeatherSnapshot(
        using provider: WeatherProviding,
        location: CLLocation
    ) async throws -> WeatherSnapshot {
        try await provider.currentWeather(for: location)
    }

    private func applyLoadedSnapshot(_ snapshot: WeatherSnapshot) {
        lastSnapshot = snapshot
        state = .loaded(snapshot)
    }
}
