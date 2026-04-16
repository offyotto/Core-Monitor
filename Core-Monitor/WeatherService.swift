// WeatherService.swift
// Core-Monitor — WeatherKit data layer
// Requires: WeatherKit entitlement + Privacy Usage string in Info.plist

import Foundation
import Combine
import WeatherKit
import CoreLocation

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

// MARK: - Protocol (enables mock injection)

protocol WeatherProviding: AnyObject {
    func currentWeather(for location: CLLocation) async throws -> WeatherSnapshot
}

@MainActor
protocol WeatherLocationAccessControlling: AnyObject {
    var authorizationStatus: CLAuthorizationStatus { get }
    var currentLocation: CLLocation? { get }
    func requestAccess()
    func refreshStatus()
}

@MainActor
final class WeatherLocationAccessController: NSObject, ObservableObject, CLLocationManagerDelegate, WeatherLocationAccessControlling {
    static let shared = WeatherLocationAccessController()

    @Published private(set) var authorizationStatus: CLAuthorizationStatus

    private let locationManager: CLLocationManager

    private override init() {
        let locationManager = CLLocationManager()
        self.locationManager = locationManager
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
    }

    var currentLocation: CLLocation? {
        locationManager.location
    }

    func requestAccess() {
        guard authorizationStatus == .notDetermined else { return }
        locationManager.requestWhenInUseAuthorization()
    }

    func refreshStatus() {
        authorizationStatus = locationManager.authorizationStatus
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            self?.authorizationStatus = status
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
    private var refreshTask: Task<Void, Never>?
    private var isRunning = false

    /// Refresh interval in seconds (default 10 min)
    var refreshInterval: TimeInterval = 600

    init(provider: WeatherProviding) {
        self.provider = provider
        self.locationAccess = WeatherLocationAccessController.shared
    }

    init(
        provider: WeatherProviding,
        locationAccess: WeatherLocationAccessControlling
    ) {
        self.provider = provider
        self.locationAccess = locationAccess
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
        locationAccess.refreshStatus()

        switch locationAccess.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            break
        case .notDetermined:
            state = .error("Location access is optional. Request it from Touch Bar settings for live local weather.")
            return
        case .denied, .restricted:
            state = .error("Location access is off. Enable it in System Settings for live local weather.")
            return
        @unknown default:
            state = .error("Location access is unavailable right now.")
            return
        }

        state = .loading

        // Use last known location or a default (Cupertino) for simulator
        let location: CLLocation = locationAccess.currentLocation
            ?? CLLocation(latitude: 37.3346, longitude: -122.0090)

        do {
            let snapshot = try await provider.currentWeather(for: location)
            state = .loaded(snapshot)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}
