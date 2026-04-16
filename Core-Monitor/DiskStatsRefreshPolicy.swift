import Foundation

enum DiskStatsRefreshPolicy {
    static let minimumRefreshInterval: TimeInterval = 30

    static func shouldRefresh(
        lastUpdatedAt: Date?,
        now: Date,
        minimumInterval: TimeInterval = minimumRefreshInterval
    ) -> Bool {
        guard let lastUpdatedAt else { return true }
        return now.timeIntervalSince(lastUpdatedAt) >= minimumInterval
    }
}
