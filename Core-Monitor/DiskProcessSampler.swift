import AppKit
import Combine
import Darwin
import Foundation

struct DiskProcessActivity: Identifiable, Equatable {
    let name: String
    let readBytes: UInt64
    let writtenBytes: UInt64

    var id: String { name }
    var totalBytes: UInt64 { readBytes + writtenBytes }
    var readLabel: String { Self.formatBytes(readBytes) }
    var writeLabel: String { Self.formatBytes(writtenBytes) }

    static func formatBytes(_ bytes: UInt64) -> String {
        switch bytes {
        case 0..<1024:
            return "\(bytes)B"
        case 1024..<1_048_576:
            return String(format: "%.0fK", Double(bytes) / 1024.0)
        case 1_048_576..<1_073_741_824:
            return String(format: "%.1fM", Double(bytes) / 1_048_576.0)
        default:
            return String(format: "%.1fG", Double(bytes) / 1_073_741_824.0)
        }
    }
}

struct DiskProcessCounter: Equatable {
    let pid: pid_t
    let name: String
    let readBytes: UInt64
    let writtenBytes: UInt64
}

enum DiskProcessSampling {
    static func activities(
        from counters: [DiskProcessCounter],
        previousCounters: [pid_t: DiskProcessCounter],
        limit: Int
    ) -> [DiskProcessActivity] {
        var aggregatedByName: [String: DiskProcessActivity] = [:]

        for counter in counters {
            let readDelta = deltaBytes(current: counter.readBytes, previous: previousCounters[counter.pid]?.readBytes)
            let writeDelta = deltaBytes(current: counter.writtenBytes, previous: previousCounters[counter.pid]?.writtenBytes)
            guard readDelta > 0 || writeDelta > 0 else { continue }

            let current = aggregatedByName[counter.name] ?? DiskProcessActivity(
                name: counter.name,
                readBytes: 0,
                writtenBytes: 0
            )

            aggregatedByName[counter.name] = DiskProcessActivity(
                name: counter.name,
                readBytes: current.readBytes + readDelta,
                writtenBytes: current.writtenBytes + writeDelta
            )
        }

        return aggregatedByName.values
            .sorted { lhs, rhs in
                if lhs.totalBytes == rhs.totalBytes {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.totalBytes > rhs.totalBytes
            }
            .prefix(limit)
            .map { $0 }
    }

    static func collectProcessCounters() -> [DiskProcessCounter] {
        let bytesNeeded = Int(proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0))
        guard bytesNeeded > 0 else { return [] }

        let pidCount = max(1, bytesNeeded / MemoryLayout<pid_t>.stride)
        var pids = Array(repeating: pid_t(0), count: pidCount)
        let bytesWritten = pids.withUnsafeMutableBytes { buffer -> Int32 in
            guard let baseAddress = buffer.baseAddress else { return 0 }
            return proc_listpids(UInt32(PROC_ALL_PIDS), 0, baseAddress, Int32(buffer.count))
        }

        guard bytesWritten > 0 else { return [] }

        let actualCount = Int(bytesWritten) / MemoryLayout<pid_t>.stride
        return pids
            .prefix(actualCount)
            .filter { $0 > 0 }
            .compactMap { pid in
                var usage = rusage_info_current()
                let status = withUnsafeMutablePointer(to: &usage) { pointer -> Int32 in
                    pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { rebounded in
                        proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, rebounded)
                    }
                }

                guard status == 0 else { return nil }
                return DiskProcessCounter(
                    pid: pid,
                    name: displayName(for: pid),
                    readBytes: usage.ri_diskio_bytesread,
                    writtenBytes: usage.ri_diskio_byteswritten
                )
            }
    }

    static func deltaBytes(current: UInt64, previous: UInt64?) -> UInt64 {
        guard let previous, current >= previous else { return 0 }
        return current - previous
    }

    private static func displayName(for pid: pid_t) -> String {
        if let runningApp = NSRunningApplication(processIdentifier: pid) {
            let localizedName = runningApp.localizedName ?? ""
            if !localizedName.isEmpty {
                return localizedName
            }
        }

        var nameBuffer = [CChar](repeating: 0, count: Int(MAXCOMLEN) + 1)
        let procNameLength = proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
        if procNameLength > 0 {
            let name = String(cString: nameBuffer).trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                return name
            }
        }

        var pathBuffer = [CChar](repeating: 0, count: max(Int(PATH_MAX), 1024))
        let pathLength = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
        if pathLength > 0 {
            let path = String(cString: pathBuffer)
            let lastPathComponent = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            if !lastPathComponent.isEmpty {
                return lastPathComponent
            }
        }

        return "PID \(pid)"
    }
}

@MainActor
final class DiskProcessSampler: ObservableObject {
    @Published private(set) var processes: [DiskProcessActivity] = []
    @Published private(set) var hasSample = false

    private let samplingQueue = DispatchQueue(label: "CoreMonitor.DiskProcessSampler", qos: .utility)
    private var interval: TimeInterval
    private let limit: Int
    private var timer: Timer?
    private var isRunning = false
    private var previousCountersByPID: [pid_t: DiskProcessCounter] = [:]
    private var isSampling = false

    init(interval: TimeInterval = 5.0, limit: Int = 4) {
        self.interval = interval
        self.limit = limit
    }

    func start(interval: TimeInterval? = nil) {
        let requestedInterval = interval ?? self.interval
        guard Self.shouldRestartTimer(
            isRunning: isRunning,
            currentInterval: self.interval,
            requestedInterval: requestedInterval
        ) else {
            return
        }

        self.interval = requestedInterval
        timer?.invalidate()
        timer = nil
        isRunning = true

        sample()

        timer = Timer.scheduledTimer(withTimeInterval: self.interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sample()
            }
        }
        if let timer {
            timer.tolerance = min(1.0, self.interval * 0.2)
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    func stop(clear: Bool = true) {
        timer?.invalidate()
        timer = nil
        isRunning = false
        previousCountersByPID = [:]
        isSampling = false

        guard clear else { return }
        processes = []
        hasSample = false
    }

    static func shouldRestartTimer(
        isRunning: Bool,
        currentInterval: TimeInterval,
        requestedInterval: TimeInterval
    ) -> Bool {
        guard isRunning else { return true }
        return abs(currentInterval - requestedInterval) > .ulpOfOne
    }

    private func sample() {
        guard isRunning, !isSampling else { return }
        isSampling = true

        let previousCountersByPID = self.previousCountersByPID
        let limit = self.limit

        samplingQueue.async { [weak self] in
            let counters = DiskProcessSampling.collectProcessCounters()
            let activities = DiskProcessSampling.activities(
                from: counters,
                previousCounters: previousCountersByPID,
                limit: limit
            )
            let nextCountersByPID = Dictionary(uniqueKeysWithValues: counters.map { ($0.pid, $0) })

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isSampling = false
                guard self.isRunning else { return }
                self.previousCountersByPID = nextCountersByPID
                self.processes = activities
                self.hasSample = true
            }
        }
    }
}
