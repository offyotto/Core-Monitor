import AppKit
import Darwin
import Foundation

final class TopProcessSampler {
    private struct SampledProcess {
        let pid: pid_t
        let name: String
        let cpuPercent: Double
        let memoryBytes: UInt64
    }

    private struct AggregatedProcess {
        let pid: pid_t
        let name: String
        var cpuPercent: Double
        var memoryBytes: UInt64
    }

    var onUpdate: ((TopProcessSnapshot) -> Void)?

    private let samplingQueue = DispatchQueue(label: "CoreMonitor.TopProcessSampler", qos: .utility)
    private var interval: TimeInterval
    private let limit: Int
    private var timer: Timer?
    private var isRunning = false
    private var previousCPUTimeByPID: [pid_t: UInt64] = [:]
    private var previousSampleDate = Date()
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

    func updateInterval(_ interval: TimeInterval) {
        guard abs(self.interval - interval) > .ulpOfOne else { return }
        start(interval: interval)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
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
        guard !isSampling else { return }
        isSampling = true

        let now = Date()
        let elapsed = max(now.timeIntervalSince(previousSampleDate), 1)
        let previousCPUTimeByPID = self.previousCPUTimeByPID
        let processorCount = max(1, SystemMonitor.totalLogicalCoreCount())

        samplingQueue.async { [weak self] in
            guard let self else { return }

            let sampled = self.collectProcesses(
                elapsed: elapsed,
                processorCount: processorCount,
                previousCPUTimeByPID: previousCPUTimeByPID
            )

            let grouped = self.aggregateProcesses(sampled)
            let snapshot = TopProcessSnapshot(
                sampledAt: now,
                topCPU: grouped
                    .sorted { $0.cpuPercent > $1.cpuPercent }
                    .prefix(self.limit)
                    .map { ProcessActivity(pid: $0.pid, name: $0.name, cpuPercent: $0.cpuPercent, memoryBytes: $0.memoryBytes) },
                topMemory: grouped
                    .sorted { $0.memoryBytes > $1.memoryBytes }
                    .prefix(self.limit)
                    .map { ProcessActivity(pid: $0.pid, name: $0.name, cpuPercent: $0.cpuPercent, memoryBytes: $0.memoryBytes) }
            )

            let nextCPUTimeByPID = Dictionary(uniqueKeysWithValues: sampled.map { ($0.pid, self.cpuTime(for: $0.pid) ?? 0) })

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.previousSampleDate = now
                self.previousCPUTimeByPID = nextCPUTimeByPID
                self.isSampling = false
                self.onUpdate?(snapshot)
            }
        }
    }

    private func collectProcesses(
        elapsed: TimeInterval,
        processorCount: Int,
        previousCPUTimeByPID: [pid_t: UInt64]
    ) -> [SampledProcess] {
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
                guard let taskInfo = taskInfo(for: pid) else { return nil }
                let memoryBytes = UInt64(taskInfo.pti_resident_size)
                let cpuTime = cpuTime(for: pid) ?? 0
                let previousCPUTime = previousCPUTimeByPID[pid] ?? cpuTime
                let delta = cpuTime >= previousCPUTime ? cpuTime - previousCPUTime : 0
                let cpuPercent = elapsed > 0
                    ? min(100.0, (Double(delta) / 1_000_000_000.0) / (elapsed * Double(processorCount)) * 100.0)
                    : 0

                return SampledProcess(
                    pid: pid,
                    name: displayName(for: pid),
                    cpuPercent: cpuPercent,
                    memoryBytes: memoryBytes
                )
            }
    }

    private func aggregateProcesses(_ processes: [SampledProcess]) -> [AggregatedProcess] {
        var grouped: [String: AggregatedProcess] = [:]

        for process in processes {
            var entry = grouped[process.name] ?? AggregatedProcess(
                pid: process.pid,
                name: process.name,
                cpuPercent: 0,
                memoryBytes: 0
            )
            entry.cpuPercent += process.cpuPercent
            entry.memoryBytes += process.memoryBytes
            grouped[process.name] = entry
        }

        return grouped
            .values
            .filter { $0.cpuPercent >= 0.5 || $0.memoryBytes > 0 }
    }

    private func taskInfo(for pid: pid_t) -> proc_taskinfo? {
        var info = proc_taskinfo()
        let result = withUnsafeMutablePointer(to: &info) { pointer -> Int32 in
            pointer.withMemoryRebound(to: Int8.self, capacity: MemoryLayout<proc_taskinfo>.stride) { rebounded in
                proc_pidinfo(pid, PROC_PIDTASKINFO, 0, rebounded, Int32(MemoryLayout<proc_taskinfo>.stride))
            }
        }

        guard result == Int32(MemoryLayout<proc_taskinfo>.stride) else { return nil }
        return info
    }

    private func cpuTime(for pid: pid_t) -> UInt64? {
        var usage = rusage_info_current()
        let status = withUnsafeMutablePointer(to: &usage) { pointer -> Int32 in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { rebounded in
                proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, rebounded)
            }
        }

        guard status == 0 else { return nil }
        return usage.ri_user_time + usage.ri_system_time
    }

    private func displayName(for pid: pid_t) -> String {
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
