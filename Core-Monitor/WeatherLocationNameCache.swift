import CoreLocation
import Foundation

/// An in-memory cache of the most recent place name. Location changes, language
/// changes, and expiry invalidate it; failed lookups are never cached.
actor WeatherLocationNameCache {
    private struct Entry {
        let location: CLLocation
        let localeIdentifier: String
        let name: String
        let fetchedAt: Date
    }
    private struct Pending {
        let id: UUID
        let location: CLLocation
        let localeIdentifier: String
        let task: Task<String?, Error>
    }

    private let lifetime: TimeInterval
    private let distanceThreshold: CLLocationDistance
    private var cached: Entry?
    private var pending: Pending?

    init(lifetime: TimeInterval = 3_600, distanceThreshold: CLLocationDistance = 500) {
        self.lifetime = lifetime
        self.distanceThreshold = distanceThreshold
    }

    func name(
        for location: CLLocation,
        locale: Locale,
        now: Date = Date(),
        resolve: @escaping @Sendable (CLLocation, Locale) async throws -> String?
    ) async -> String {
        if let cached, cached.localeIdentifier == locale.identifier,
           now.timeIntervalSince(cached.fetchedAt) >= 0,
           now.timeIntervalSince(cached.fetchedAt) < lifetime,
           location.distance(from: cached.location) <= distanceThreshold {
            return cached.name
        }
        if let pending, pending.localeIdentifier == locale.identifier,
           location.distance(from: pending.location) <= distanceThreshold {
            let resolved = try? await pending.task.value
            return resolved.flatMap { $0.isEmpty ? nil : $0 } ?? "Weather"
        }

        let id = UUID()
        let task = Task { try await resolve(location, locale) }
        pending = Pending(id: id, location: location, localeIdentifier: locale.identifier, task: task)
        let resolved = try? await task.value
        if pending?.id == id {
            pending = nil
            if let resolved, !resolved.isEmpty {
                cached = Entry(location: location, localeIdentifier: locale.identifier, name: resolved, fetchedAt: now)
            }
        }
        return resolved.flatMap { $0.isEmpty ? nil : $0 } ?? "Weather"
    }
}
