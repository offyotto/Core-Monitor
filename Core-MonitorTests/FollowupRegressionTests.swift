import Combine
import CoreLocation
import Darwin
import XCTest
@testable import Core_Monitor

@MainActor
final class FollowupRegressionTests: XCTestCase {
    func testPrivacyRedactionFromBackgroundPublisherRunsOnMainThread() async throws {
        let suite = "CoreMonitor.PrivacyTest.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let privacy = PrivacySettings(defaults: defaults)
        privacy.processInsightsEnabled = true
        var store = AlertStore.default()
        store.desktopNotificationsEnabled = false
        store.ruleConfigs = store.ruleConfigs.map { config in
            var config = config
            config.isEnabled = false
            return config
        }
        let eventID = UUID()
        store.history = [AlertEvent(id: eventID, kind: .cpuUsage, severity: .warning,
            title: "CPU", message: "Busy", context: "PrivateProcess", timestamp: Date(), isRecovery: false)]
        defaults.set(try JSONEncoder().encode(store), forKey: "coremonitor.alertStore.v1")
        let monitor = SystemMonitor(privacySettings: privacy)
        let manager = AlertManager(systemMonitor: monitor, fanController: FanController(systemMonitor: monitor),
                                   privacySettings: privacy, userDefaults: defaults)
        XCTAssertEqual(manager.history.first(where: { $0.id == eventID })?.context, "PrivateProcess")
        let redacted = expectation(description: "History redacted on main thread")
        let subscription = manager.$history.dropFirst()
            .filter { $0.contains { $0.id == eventID && $0.context == nil } }
            .prefix(1)
            .sink { _ in
            XCTAssertTrue(Thread.isMainThread)
            redacted.fulfill()
        }
        DispatchQueue.global().async { privacy.processInsightsEnabled = false }
        await fulfillment(of: [redacted], timeout: 3)
        subscription.cancel()
        XCTAssertFalse(manager.processInsightsEnabled)
        let persisted = try JSONDecoder().decode(AlertStore.self, from: XCTUnwrap(defaults.data(forKey: "coremonitor.alertStore.v1")))
        let savedEvent = try XCTUnwrap(persisted.history.first(where: { $0.id == eventID }))
        XCTAssertNil(savedEvent.context)
    }

    func testReusedPIDStartsNewDiskBaselineEvenWhenCountersIncrease() {
        let old = DiskProcessCounter(pid: 42, name: "Old", readBytes: 100, writtenBytes: 100, startTime: 1)
        let replacement = DiskProcessCounter(pid: 42, name: "New", readBytes: 1_000, writtenBytes: 2_000, startTime: 2)
        XCTAssertTrue(DiskProcessSampling.activities(from: [replacement], previousCounters: [42: old], limit: 4).isEmpty)
        let later = DiskProcessCounter(pid: 42, name: "New", readBytes: 1_200, writtenBytes: 2_050, startTime: 2)
        XCTAssertEqual(DiskProcessSampling.activities(from: [later], previousCounters: [42: replacement], limit: 4),
                       [DiskProcessActivity(name: "New", readBytes: 200, writtenBytes: 50)])
    }

    func testLockExcludesOtherHandlesAndProcessesAndCanBeReacquired() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("instance.lock")
        let first = SingleInstanceLock(fileURL: url)
        let second = SingleInstanceLock(fileURL: url)
        XCTAssertTrue(try first.acquire())
        XCTAssertFalse(try second.acquire())
        XCTAssertEqual(second.ownerPID, getpid())

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["-c", """
        import fcntl, sys
        with open(sys.argv[1], 'a') as handle:
            try:
                fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                sys.exit(73)
        """, url.path]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 73)

        first.release()
        XCTAssertTrue(try second.acquire())
        second.release()
    }

    func testLockRejectsSymlinkInsteadOfFollowingIt() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let target = directory.appendingPathComponent("target")
        let link = directory.appendingPathComponent("link")
        try Data("unchanged".utf8).write(to: target)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        XCTAssertThrowsError(try SingleInstanceLock(fileURL: link).acquire())
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "unchanged")
    }

    func testLocationNameCacheExpiresAndRespectsLocationAndLanguage() async {
        let cache = WeatherLocationNameCache(lifetime: 60, distanceThreshold: 500)
        let resolver = CountingPlaceResolver()
        let nearby = CLLocation(latitude: 59.3293, longitude: 18.0686)
        let distant = CLLocation(latitude: 57.7089, longitude: 11.9746)
        let time = Date(timeIntervalSince1970: 100)
        let resolve: @Sendable (CLLocation, Locale) async throws -> String? = { _, _ in await resolver.next() }
        let first = await cache.name(for: nearby, locale: Locale(identifier: "en"), now: time, resolve: resolve)
        let cached = await cache.name(for: nearby, locale: Locale(identifier: "en"), now: time.addingTimeInterval(59), resolve: resolve)
        XCTAssertEqual(first, cached)
        let expired = await cache.name(for: nearby, locale: Locale(identifier: "en"), now: time.addingTimeInterval(60), resolve: resolve)
        XCTAssertNotEqual(first, expired)
        _ = await cache.name(for: distant, locale: Locale(identifier: "en"), now: time.addingTimeInterval(61), resolve: resolve)
        _ = await cache.name(for: distant, locale: Locale(identifier: "sv"), now: time.addingTimeInterval(62), resolve: resolve)
        let count = await resolver.count
        XCTAssertEqual(count, 4)
    }

    func testConcurrentPlaceRequestsShareLookupAndFailuresAreRetried() async {
        let cache = WeatherLocationNameCache()
        let resolver = CountingPlaceResolver()
        let location = CLLocation(latitude: 1, longitude: 1)
        let locale = Locale(identifier: "en")
        let resolve: @Sendable (CLLocation, Locale) async throws -> String? = { _, _ in
            try await Task.sleep(nanoseconds: 20_000_000)
            return await resolver.next()
        }
        async let first = cache.name(for: location, locale: locale, resolve: resolve)
        async let second = cache.name(for: location, locale: locale, resolve: resolve)
        let values = await (first, second)
        XCTAssertEqual(values.0, values.1)
        let count = await resolver.count
        XCTAssertEqual(count, 1)

        let failing = WeatherLocationNameCache()
        let failed = await failing.name(for: location, locale: locale) { _, _ in nil }
        XCTAssertEqual(failed, "Weather")
        let recovered = await failing.name(for: location, locale: locale) { _, _ in "Recovered" }
        XCTAssertEqual(recovered, "Recovered")
    }
}

private actor CountingPlaceResolver {
    private(set) var count = 0
    func next() -> String { count += 1; return "Place \(count)" }
}
