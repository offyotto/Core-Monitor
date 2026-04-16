import Foundation

struct SystemMonitorRefreshGate {
    let minimumInterval: TimeInterval
    private(set) var lastRefreshAt: Date?

    init(minimumInterval: TimeInterval, lastRefreshAt: Date? = nil) {
        self.minimumInterval = minimumInterval
        self.lastRefreshAt = lastRefreshAt
    }

    mutating func shouldRefresh(now: Date, monitoringInterval: TimeInterval) -> Bool {
        let requiredInterval = max(minimumInterval, monitoringInterval)
        guard let lastRefreshAt else {
            self.lastRefreshAt = now
            return true
        }

        guard now.timeIntervalSince(lastRefreshAt) >= requiredInterval else {
            return false
        }

        self.lastRefreshAt = now
        return true
    }

    mutating func reset() {
        lastRefreshAt = nil
    }
}

struct SystemMonitorSupplementalSamplingState {
    private var batteryRefreshGate = SystemMonitorRefreshGate(minimumInterval: 10.0)
    private var systemControlsRefreshGate = SystemMonitorRefreshGate(minimumInterval: 5.0)

    mutating func shouldRefreshBattery(now: Date, monitoringInterval: TimeInterval) -> Bool {
        batteryRefreshGate.shouldRefresh(now: now, monitoringInterval: monitoringInterval)
    }

    mutating func shouldRefreshSystemControls(now: Date, monitoringInterval: TimeInterval) -> Bool {
        systemControlsRefreshGate.shouldRefresh(now: now, monitoringInterval: monitoringInterval)
    }

    mutating func reset() {
        batteryRefreshGate.reset()
        systemControlsRefreshGate.reset()
    }
}
