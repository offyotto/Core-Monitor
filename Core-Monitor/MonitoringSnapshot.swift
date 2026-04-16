import Foundation

nonisolated enum MonitoringTrendRange: String, CaseIterable, Identifiable {
    case oneMinute
    case fiveMinutes
    case fifteenMinutes

    nonisolated var id: String { rawValue }

    nonisolated var title: String {
        switch self {
        case .oneMinute: return "1m"
        case .fiveMinutes: return "5m"
        case .fifteenMinutes: return "15m"
        }
    }

    nonisolated var duration: TimeInterval {
        switch self {
        case .oneMinute: return 60
        case .fiveMinutes: return 5 * 60
        case .fifteenMinutes: return 15 * 60
        }
    }
}

nonisolated enum MonitoringFreshness: Equatable {
    case waiting
    case live
    case delayed
    case stale
}

nonisolated struct MonitoringSnapshotHealth: Equatable {
    let freshness: MonitoringFreshness
    let sampledAt: Date?
    let age: TimeInterval?
    let expectedInterval: TimeInterval

    init(sampledAt: Date, expectedInterval: TimeInterval, now: Date = Date()) {
        let normalizedInterval = max(expectedInterval, 1)
        self.expectedInterval = normalizedInterval

        guard sampledAt != .distantPast else {
            self.freshness = .waiting
            self.sampledAt = nil
            self.age = nil
            return
        }

        let resolvedAge = max(0, now.timeIntervalSince(sampledAt))
        let liveThreshold = max(normalizedInterval * 1.5, 2.5)
        let staleThreshold = max(normalizedInterval * 4.0, 12.0)

        if resolvedAge <= liveThreshold {
            freshness = .live
        } else if resolvedAge <= staleThreshold {
            freshness = .delayed
        } else {
            freshness = .stale
        }

        self.sampledAt = sampledAt
        self.age = resolvedAge
    }

    var statusLabel: String {
        switch freshness {
        case .waiting: return "Waiting"
        case .live: return "Live"
        case .delayed: return "Delayed"
        case .stale: return "Stale"
        }
    }

    var ageDescription: String {
        guard let age else { return "Waiting for the first sample" }
        if age < 1.5 {
            return "Updated just now"
        }
        return "Updated \(Self.compactDurationDescription(age)) ago"
    }

    var cadenceDescription: String {
        "Cadence \(Self.compactDurationDescription(expectedInterval))"
    }

    static func compactDurationDescription(_ interval: TimeInterval) -> String {
        let rounded = max(Int(interval.rounded()), 1)
        if rounded < 60 {
            return "\(rounded)s"
        }

        let minutes = rounded / 60
        let seconds = rounded % 60
        if seconds == 0 {
            return "\(minutes)m"
        }
        return "\(minutes)m \(seconds)s"
    }
}

nonisolated struct MonitoringTrendPoint: Equatable {
    let timestamp: Date
    let value: Double
}

nonisolated struct MonitoringTrendSummary: Equatable {
    let latest: Double
    let minimum: Double
    let maximum: Double
    let average: Double
    let delta: Double
}

nonisolated struct MonitoringTrendSeries {
    private(set) var points: [MonitoringTrendPoint] = []
    let retention: TimeInterval

    init(retention: TimeInterval = MonitoringTrendRange.fifteenMinutes.duration) {
        self.retention = retention
    }

    mutating func append(_ value: Double?, at timestamp: Date = Date()) {
        trim(olderThan: timestamp.addingTimeInterval(-retention))
        guard let value else { return }
        points.append(MonitoringTrendPoint(timestamp: timestamp, value: value))
    }

    func values(for range: MonitoringTrendRange, now: Date = Date()) -> [Double] {
        relevantPoints(for: range, now: now).map(\.value)
    }

    func summary(for range: MonitoringTrendRange, now: Date = Date()) -> MonitoringTrendSummary? {
        let values = values(for: range, now: now)
        guard let first = values.first,
              let last = values.last,
              let minimum = values.min(),
              let maximum = values.max() else {
            return nil
        }

        let average = values.reduce(0, +) / Double(values.count)
        return MonitoringTrendSummary(
            latest: last,
            minimum: minimum,
            maximum: maximum,
            average: average,
            delta: last - first
        )
    }

    var count: Int {
        points.count
    }

    private func relevantPoints(for range: MonitoringTrendRange, now: Date) -> [MonitoringTrendPoint] {
        let cutoff = now.addingTimeInterval(-range.duration)
        return points.filter { $0.timestamp >= cutoff }
    }

    private mutating func trim(olderThan cutoff: Date) {
        points.removeAll { $0.timestamp < cutoff }
    }
}

nonisolated struct ProcessActivity: Codable, Equatable, Identifiable {
    let pid: Int32
    let name: String
    let cpuPercent: Double
    let memoryBytes: UInt64

    nonisolated var id: String { "\(pid)-\(name)" }
    nonisolated var memoryGB: Double { Double(memoryBytes) / 1_073_741_824.0 }
}

nonisolated struct TopProcessSnapshot: Codable, Equatable {
    var sampledAt: Date
    var topCPU: [ProcessActivity]
    var topMemory: [ProcessActivity]

    nonisolated static let empty = TopProcessSnapshot(sampledAt: .distantPast, topCPU: [], topMemory: [])
}

nonisolated struct SystemMonitorSnapshot {
    var sampledAt: Date = .distantPast
    var cpuTemperature: Double?
    var gpuTemperature: Double?
    var fanSpeeds: [Int] = []
    var fanMinSpeeds: [Int] = []
    var fanMaxSpeeds: [Int] = []
    var numberOfFans: Int = 0
    var cpuUsagePercent: Double = 0
    var performanceCoreUsagePercent: Double?
    var efficiencyCoreUsagePercent: Double?
    var memoryUsagePercent: Double = 0
    var memoryUsedGB: Double = 0
    var totalMemoryGB: Double = 0
    var memoryPressure: MemoryPressureLevel = .green
    var appMemoryGB: Double = 0
    var wiredMemoryGB: Double = 0
    var compressedMemoryGB: Double = 0
    var freeMemoryGB: Double = 0
    var pageInsBytes: UInt64 = 0
    var pageOutsBytes: UInt64 = 0
    var swapUsedBytes: UInt64 = 0
    var swapTotalBytes: UInt64 = 0
    var batteryInfo = BatteryInfo()
    var totalSystemWatts: Double?
    var currentVolume: Float = 0.5
    var currentBrightness: Float = 1.0
    var diskStats = DiskStats()
    var cpuPowerWatts: Double?
    var gpuPowerWatts: Double?
    var ssdTemperature: Double?
    var networkStats = SystemMonitor.NetworkStats()
    var thermalState: ProcessInfo.ThermalState = .nominal
    var topProcesses: TopProcessSnapshot = .empty
    var hasSMCAccess: Bool = false
    var lastError: String?

    nonisolated static let empty = SystemMonitorSnapshot()
}
