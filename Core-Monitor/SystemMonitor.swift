import Foundation
import Combine
import IOKit
import IOKit.ps
import Darwin
import CoreAudio

extension Notification.Name {
    static let systemMonitorDidUpdate = Notification.Name("SystemMonitorDidUpdate")
}

struct CPUStats {
    let usagePercent: Double
    let performanceCoreUsagePercent: Double?
    let efficiencyCoreUsagePercent: Double?
}

enum MemoryPressureLevel {
    case green
    case yellow
    case red
}

struct MemoryStats {
    let usagePercent: Double
    let usedGB: Double
    let totalGB: Double
    let pressure: MemoryPressureLevel
    let appGB: Double
    let wiredGB: Double
    let compressedGB: Double
    let freeGB: Double
    let pageInsBytes: UInt64
    let pageOutsBytes: UInt64
    let swapUsedBytes: UInt64
    let swapTotalBytes: UInt64
}

struct BatteryInfo {
    var hasBattery: Bool = false
    var chargePercent: Int?
    var isCharging: Bool = false
    var isPluggedIn: Bool = false
    var powerWatts: Double?
    var cycleCount: Int?
    var healthPercent: Int?
    var temperatureC: Double?
    var voltageV: Double?
    var amperageA: Double?
    var currentCapacity: Int?
    var maxCapacity: Int?
    var source: String?
    var status: String?
    var timeRemainingMinutes: Int?
}

// MARK: - Disk stats
struct DiskStats {
    var totalGB: Double = 0
    var usedGB: Double = 0
    var freeGB: Double = 0
    var purgeableGB: Double = 0
    var usagePercent: Double = 0
}

private typealias SMCBytes = (
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
)

private struct SMCKeyData_vers_t {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

private struct SMCKeyData_pLimitData_t {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

private struct SMCKeyData_keyInfo_t {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

private struct SMCParamStruct {
    var key: UInt32 = 0
    var vers = SMCKeyData_vers_t()
    var pLimitData = SMCKeyData_pLimitData_t()
    var keyInfo = SMCKeyData_keyInfo_t()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCBytes = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
}

final class SystemMonitor: ObservableObject {
    private enum ActivitySamplingMode {
        case background
        case detailed

        var interval: TimeInterval {
            switch self {
            case .background:
                return 30.0
            case .detailed:
                return 5.0
            }
        }
    }

    var cpuTemperature: Double?
    var gpuTemperature: Double?
    var fanSpeeds: [Int] = []
    var fanMinSpeeds: [Int] = []
    var fanMaxSpeeds: [Int] = []
    @Published var numberOfFans: Int = 0
    var cpuUsagePercent: Double = 0
    var performanceCoreUsagePercent: Double?
    var efficiencyCoreUsagePercent: Double?
    @Published var hasSMCAccess: Bool = false
    @Published var lastError: String?

    var batteryInfo = BatteryInfo()
    var totalSystemWatts: Double?
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

    // System volume and display brightness (0–1), polled each cycle
    var currentVolume:     Float = 0.5
    var currentBrightness: Float = 1.0

    // NEW: extended sensor data
    var diskStats = DiskStats()
    var cpuPowerWatts: Double?
    var gpuPowerWatts: Double?
    var ssdTemperature: Double?

    // MARK: - Network throughput (bytes/sec since last sample)
    struct NetworkStats {
        var uploadBytesPerSec:   Double = 0
        var downloadBytesPerSec: Double = 0
    }
    private(set) var networkStats = NetworkStats()
    private var previousNetworkBytes: (sent: UInt64, received: UInt64) = (0, 0)
    private var previousNetworkTime: Date = Date()

    // MARK: - History buffers (60 samples, used by menu bar popovers)
    private(set) var cpuHistory:     [Double] = Array(repeating: 0, count: 60)
    private(set) var memHistory:     [Double] = Array(repeating: 0, count: 60)
    private(set) var cpuTempHistory: [Double] = Array(repeating: 0, count: 60)
    private(set) var cpuTemperatureTrend = MonitoringTrendSeries()
    private(set) var gpuTemperatureTrend = MonitoringTrendSeries()
    private(set) var totalPowerTrend = MonitoringTrendSeries()
    private(set) var primaryFanSpeedTrend = MonitoringTrendSeries()
    @Published private(set) var snapshot = SystemMonitorSnapshot.empty
    @Published private(set) var thermalState: ProcessInfo.ThermalState = .nominal
    private let activitySampler = TopProcessSampler()

    static var isAppleSilicon: Bool {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let result = sysctlbyname("hw.optional.arm64", &value, &size, nil, 0)
        return result == 0 && value == 1
    }

    static func hostModelIdentifier() -> String {
        sysctlString(named: "hw.model") ?? "Unknown Mac"
    }

    static func chipName() -> String {
        if let targetType = sysctlString(named: "hw.targettype"), !targetType.isEmpty {
            return targetType
        }
        if let brand = sysctlString(named: "machdep.cpu.brand_string"), !brand.isEmpty {
            return brand
        }
        return isAppleSilicon ? "Apple Silicon" : "Intel"
    }

    static func performanceCoreCount() -> Int {
        if let count = sysctlInt(named: "hw.perflevel0.logicalcpu"), count > 0 {
            return count
        }
        return totalLogicalCoreCount()
    }

    static func efficiencyCoreCount() -> Int {
        if let count = sysctlInt(named: "hw.perflevel1.logicalcpu"), count >= 0 {
            return count
        }
        return 0
    }

    static func totalLogicalCoreCount() -> Int {
        sysctlInt(named: "hw.logicalcpu") ?? ProcessInfo.processInfo.activeProcessorCount
    }

    private var smcConnection: io_connect_t = 0
    /// Interactive mode runs at 1 s. Background mode falls back to 30 s.
    private var monitoringInterval: TimeInterval = 1.0
    private var preferredMonitoringInterval: TimeInterval = 1.0
    private var timer: Timer?
    private var keyInfoCache: [UInt32: SMCKeyData_keyInfo_t] = [:]
    private let samplingQueue = DispatchQueue(label: "CoreMonitor.SystemMonitorSampling", qos: .utility)
    private var isSampling = false
    private var isMonitoringActive = false
    private var detailedSamplingReasons = Set<String>()
    private var interactiveMonitoringReasons = Set<String>()
    private var monitoringIntervalOverrides: [String: TimeInterval] = [:]

    // MARK: - Basic mode adaptive polling
    /// Called by ContentView when the user toggles Basic Mode.
    /// Restarts the timer at the appropriate interval so the change takes effect immediately.
    func setBasicMode(_ enabled: Bool) {
        preferredMonitoringInterval = enabled ? 30.0 : 1.0
        applyMonitoringIntervalIfNeeded()
    }

    private var previousCPULoadInfo = host_cpu_load_info_data_t()
    private var hasPreviousCPUInfo = false
    private var previousProcessorLoadInfo: [integer_t] = []
    private var hasPreviousProcessorInfo = false

    private let cpuTempKeys = [
        "TC0P", "TCXC", "TC0E", "TC0F", "TC0D", "TC1C", "TC2C", "TC3C", "TC4C",
        "Tp09", "Tp0T", "Tp01", "Tp05", "Tp0D", "Tp0b"
    ]

    private let gpuTempKeys = ["TGDD", "TG0P", "TG0D", "TG0E", "TG0F", "Tg0T", "Tg05"]

    // SSD / NAND temperature keys
    private let ssdTempKeys = ["TM0P", "Ts0S", "TH0A", "TH0B", "TH0C"]

    private let dataTypeFlt = fourCharCodeFrom("flt ")
    private let dataTypeSp78 = fourCharCodeFrom("sp78")
    private let dataTypeFpe2 = fourCharCodeFrom("fpe2")
    private let dataTypeUInt8 = fourCharCodeFrom("ui8 ")
    private let dataTypeUInt16 = fourCharCodeFrom("ui16")
    private let dataTypeUInt32 = fourCharCodeFrom("ui32")
    private let dataTypeSInt16 = fourCharCodeFrom("si16")

    private let smcReadBytes: UInt8 = 5
    private let smcReadKeyInfo: UInt8 = 9
    private let kernelIndexSmc: UInt32 = 2
    private let maxFanProbeCount = 12

    init() {
        hasSMCAccess = openSMCConnection()
        snapshot.hasSMCAccess = hasSMCAccess
        snapshot.lastError = lastError
        activitySampler.onUpdate = { [weak self] topProcesses in
            self?.updateTopProcesses(topProcesses)
        }
    }

    deinit {
        stopMonitoring()
        closeSMCConnection()
    }

    func startMonitoring() {
        isMonitoringActive = true
        _ = openSMCConnection()
        detectFans()
        updateReadings()
        updateActivitySamplingMode()

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            self?.updateReadings()
        }
        if let timer {
            timer.tolerance = monitoringInterval * 0.15
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    func stopMonitoring() {
        isMonitoringActive = false
        timer?.invalidate()
        timer = nil
        activitySampler.stop()
    }

    func setDetailedSamplingEnabled(_ enabled: Bool, reason: String) {
        guard !reason.isEmpty else { return }

        if enabled {
            detailedSamplingReasons.insert(reason)
        } else {
            detailedSamplingReasons.remove(reason)
        }

        updateActivitySamplingMode()
    }

    func setInteractiveMonitoringEnabled(_ enabled: Bool, reason: String) {
        guard !reason.isEmpty else { return }

        if enabled {
            interactiveMonitoringReasons.insert(reason)
        } else {
            interactiveMonitoringReasons.remove(reason)
        }

        applyMonitoringIntervalIfNeeded()
    }

    func setMonitoringIntervalOverride(_ interval: TimeInterval?, reason: String) {
        guard !reason.isEmpty else { return }

        if let interval {
            monitoringIntervalOverrides[reason] = interval
        } else {
            monitoringIntervalOverrides.removeValue(forKey: reason)
        }

        applyMonitoringIntervalIfNeeded()
    }

    private func openSMCConnection() -> Bool {
        if smcConnection != 0 {
            hasSMCAccess = true
            snapshot.hasSMCAccess = true
            return true
        }

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else {
            hasSMCAccess = false
            lastError = "AppleSMC service not found"
            snapshot.hasSMCAccess = false
            snapshot.lastError = lastError
            return false
        }

        defer { IOObjectRelease(service) }

        let result = IOServiceOpen(service, mach_task_self_, 0, &smcConnection)
        if result == kIOReturnSuccess {
            hasSMCAccess = true
            lastError = nil
            snapshot.hasSMCAccess = true
            snapshot.lastError = nil
            return true
        }

        hasSMCAccess = false
        lastError = "Failed to open SMC connection (\(result))"
        snapshot.hasSMCAccess = false
        snapshot.lastError = lastError
        return false
    }

    private func closeSMCConnection() {
        if smcConnection != 0 {
            IOServiceClose(smcConnection)
            smcConnection = 0
        }
    }

    private func detectFans() {
        if let directCount = readSMCValue(key: "FNum").map(Int.init), directCount > 0 {
            numberOfFans = directCount
            snapshot.numberOfFans = directCount
            return
        }

        var count = 0
        for i in 0..<maxFanProbeCount {
            let actualKey = String(format: "F%dAc", i)
            let minKey = String(format: "F%dMn", i)
            let maxKey = String(format: "F%dMx", i)
            if readSMCValue(key: actualKey) != nil ||
                readSMCValue(key: minKey) != nil ||
                readSMCValue(key: maxKey) != nil {
                count = i + 1
            }
        }
        numberOfFans = count
        snapshot.numberOfFans = count
    }

    private func updateReadings() {
        guard !isSampling else { return }
        isSampling = true

        samplingQueue.async { [weak self] in
            guard let self else { return }

            let cpuTemperature = self.readCPUTemperature()
            let gpuTemperature = self.readGPUTemperature()
            let fanReadings = self.readFanReadings()
            let cpuStats = self.readCPUUsage()
            let memoryStats = self.readMemoryStats()
            let batteryInfo = self.readBatteryInfo()
            let systemControls = self.readSystemControls()
            let diskStats = self.readDiskStats()
            let cpuPowerWatts = self.readSMCValue(key: "PCPU")
            let gpuPowerWatts = self.readSMCValue(key: "PGPU")
            let ssdTemperature = self.readSSDTemperature()
            let networkStats = self.readNetworkStats()
            let thermalState = ProcessInfo.processInfo.thermalState

            var snapshot = SystemMonitorSnapshot(
                sampledAt: Date(),
                cpuTemperature: cpuTemperature,
                gpuTemperature: gpuTemperature,
                fanSpeeds: fanReadings.speeds,
                fanMinSpeeds: fanReadings.mins,
                fanMaxSpeeds: fanReadings.maxs,
                numberOfFans: fanReadings.speeds.count,
                cpuUsagePercent: cpuStats.usagePercent,
                performanceCoreUsagePercent: cpuStats.performanceCoreUsagePercent,
                efficiencyCoreUsagePercent: cpuStats.efficiencyCoreUsagePercent,
                memoryUsagePercent: memoryStats.usagePercent,
                memoryUsedGB: memoryStats.usedGB,
                totalMemoryGB: memoryStats.totalGB,
                memoryPressure: memoryStats.pressure,
                appMemoryGB: memoryStats.appGB,
                wiredMemoryGB: memoryStats.wiredGB,
                compressedMemoryGB: memoryStats.compressedGB,
                freeMemoryGB: memoryStats.freeGB,
                pageInsBytes: memoryStats.pageInsBytes,
                pageOutsBytes: memoryStats.pageOutsBytes,
                swapUsedBytes: memoryStats.swapUsedBytes,
                swapTotalBytes: memoryStats.swapTotalBytes,
                batteryInfo: batteryInfo,
                totalSystemWatts: batteryInfo.powerWatts,
                currentVolume: systemControls.volume,
                currentBrightness: systemControls.brightness,
                diskStats: diskStats,
                cpuPowerWatts: cpuPowerWatts,
                gpuPowerWatts: gpuPowerWatts,
                ssdTemperature: ssdTemperature,
                networkStats: networkStats,
                thermalState: thermalState,
                topProcesses: self.snapshot.topProcesses,
                hasSMCAccess: self.hasSMCAccess,
                lastError: self.lastError
            )

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.objectWillChange.send()
                self.cpuTemperature = snapshot.cpuTemperature
                self.gpuTemperature = snapshot.gpuTemperature
                self.fanSpeeds = snapshot.fanSpeeds
                self.fanMinSpeeds = snapshot.fanMinSpeeds
                self.fanMaxSpeeds = snapshot.fanMaxSpeeds
                self.cpuUsagePercent = snapshot.cpuUsagePercent
                self.performanceCoreUsagePercent = snapshot.performanceCoreUsagePercent
                self.efficiencyCoreUsagePercent = snapshot.efficiencyCoreUsagePercent
                self.memoryUsagePercent = snapshot.memoryUsagePercent
                self.memoryUsedGB = snapshot.memoryUsedGB
                self.totalMemoryGB = snapshot.totalMemoryGB
                self.memoryPressure = snapshot.memoryPressure
                self.appMemoryGB = snapshot.appMemoryGB
                self.wiredMemoryGB = snapshot.wiredMemoryGB
                self.compressedMemoryGB = snapshot.compressedMemoryGB
                self.freeMemoryGB = snapshot.freeMemoryGB
                self.pageInsBytes = snapshot.pageInsBytes
                self.pageOutsBytes = snapshot.pageOutsBytes
                self.swapUsedBytes = snapshot.swapUsedBytes
                self.swapTotalBytes = snapshot.swapTotalBytes
                self.batteryInfo = snapshot.batteryInfo
                self.totalSystemWatts = snapshot.totalSystemWatts
                self.currentVolume = snapshot.currentVolume
                self.currentBrightness = snapshot.currentBrightness
                // New properties
                self.diskStats = snapshot.diskStats
                self.cpuPowerWatts = snapshot.cpuPowerWatts
                self.gpuPowerWatts = snapshot.gpuPowerWatts
                self.ssdTemperature = snapshot.ssdTemperature
                self.networkStats = snapshot.networkStats
                self.thermalState = snapshot.thermalState
                snapshot.hasSMCAccess = self.hasSMCAccess
                snapshot.lastError = self.lastError
                self.snapshot = snapshot
                // Update history buffers
                self.cpuHistory.removeFirst()
                self.cpuHistory.append(snapshot.cpuUsagePercent)
                self.memHistory.removeFirst()
                self.memHistory.append(snapshot.memoryUsagePercent)
                let normTemp = snapshot.cpuTemperature.map { min($0, 120) / 120 * 100 } ?? 0
                self.cpuTempHistory.removeFirst()
                self.cpuTempHistory.append(normTemp)
                let sampleTimestamp = snapshot.sampledAt == .distantPast ? Date() : snapshot.sampledAt
                self.cpuTemperatureTrend.append(snapshot.cpuTemperature, at: sampleTimestamp)
                self.gpuTemperatureTrend.append(snapshot.gpuTemperature, at: sampleTimestamp)
                self.totalPowerTrend.append(snapshot.totalSystemWatts.map(abs), at: sampleTimestamp)
                self.primaryFanSpeedTrend.append(snapshot.fanSpeeds.first.map(Double.init), at: sampleTimestamp)

                self.isSampling = false
                NotificationCenter.default.post(name: .systemMonitorDidUpdate, object: self)
            }
        }
    }

    private func updateTopProcesses(_ topProcesses: TopProcessSnapshot) {
        var updatedSnapshot = snapshot
        updatedSnapshot.topProcesses = topProcesses
        snapshot = updatedSnapshot
    }

    private func applyMonitoringIntervalIfNeeded() {
        let desiredInteractiveInterval: TimeInterval = interactiveMonitoringReasons.isEmpty ? 30.0 : 1.0
        let overrideInterval = monitoringIntervalOverrides.values.min() ?? 30.0
        let desiredMonitoringInterval = min(desiredInteractiveInterval, overrideInterval)
        let newInterval = max(preferredMonitoringInterval, desiredMonitoringInterval)
        guard abs(newInterval - monitoringInterval) > .ulpOfOne else { return }

        monitoringInterval = newInterval

        guard timer != nil else { return }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            self?.updateReadings()
        }
        if let timer {
            timer.tolerance = monitoringInterval * 0.15
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    private func updateActivitySamplingMode() {
        guard isMonitoringActive else {
            activitySampler.stop()
            return
        }

        let mode: ActivitySamplingMode = detailedSamplingReasons.isEmpty ? .background : .detailed
        activitySampler.start(interval: mode.interval)
    }

    private func readCPUTemperature() -> Double? {
        for key in cpuTempKeys {
            if let temp = readSMCValue(key: key), temp > 0, temp < 150 {
                return temp
            }
        }
        return nil
    }

    private func readGPUTemperature() -> Double? {
        for key in gpuTempKeys {
            if let temp = readSMCValue(key: key), temp > 0, temp < 150 {
                return temp
            }
        }
        return nil
    }

    private func readSSDTemperature() -> Double? {
        for key in ssdTempKeys {
            if let temp = readSMCValue(key: key), temp > 0, temp < 100 {
                return temp
            }
        }
        return nil
    }

    // MARK: - Network throughput via getifaddrs
    private func readNetworkStats() -> NetworkStats {
        var totalSent: UInt64 = 0
        var totalReceived: UInt64 = 0

        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0, let firstAddr = ifap else { return networkStats }
        defer { freeifaddrs(ifap) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let ifa = cursor {
            let interface = ifa.pointee

            if let data = interface.ifa_data {
                let name = String(cString: interface.ifa_name)

                // Skip loopback, only count physical / WiFi interfaces
                if name != "lo0" {
                    let stats = data.assumingMemoryBound(to: if_data.self).pointee
                    totalSent += UInt64(stats.ifi_obytes)
                    totalReceived += UInt64(stats.ifi_ibytes)
                }
            }

            cursor = interface.ifa_next
        }

        let now = Date()
        let elapsed = now.timeIntervalSince(previousNetworkTime)
        guard elapsed > 0, previousNetworkBytes.sent > 0 || previousNetworkBytes.received > 0 else {
            previousNetworkBytes = (totalSent, totalReceived)
            previousNetworkTime = now
            return networkStats
        }

        let sentDelta = totalSent >= previousNetworkBytes.sent ? totalSent - previousNetworkBytes.sent : 0
        let receivedDelta = totalReceived >= previousNetworkBytes.received ? totalReceived - previousNetworkBytes.received : 0

        previousNetworkBytes = (totalSent, totalReceived)
        previousNetworkTime = now

        return NetworkStats(
            uploadBytesPerSec: Double(sentDelta) / elapsed,
            downloadBytesPerSec: Double(receivedDelta) / elapsed
        )
    }
    // MARK: - Disk stats (via FileManager)
    private func readDiskStats() -> DiskStats {
        var stats = DiskStats()
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            guard
                let totalRaw = attrs[.systemSize] as? Int64,
                let freeRaw  = attrs[.systemFreeSize] as? Int64
            else { return stats }

            let totalBytes = Double(totalRaw)
            let freeBytes  = Double(freeRaw)

            // Purgeable = available-for-important-usage minus truly-free
            var purgeableBytes: Double = 0
            let url = URL(fileURLWithPath: NSHomeDirectory())
            if let vals = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
               let importantAvail = vals.volumeAvailableCapacityForImportantUsage {
                purgeableBytes = max(0, Double(importantAvail) - freeBytes)
            }

            let usedBytes = max(0, totalBytes - freeBytes - purgeableBytes)

            stats.totalGB       = totalBytes       / 1_073_741_824
            stats.usedGB        = usedBytes        / 1_073_741_824
            stats.freeGB        = freeBytes        / 1_073_741_824
            stats.purgeableGB   = purgeableBytes   / 1_073_741_824
            stats.usagePercent  = totalBytes > 0 ? usedBytes / totalBytes * 100 : 0
        } catch {}
        return stats
    }

    private func readFanReadings() -> (speeds: [Int], mins: [Int], maxs: [Int]) {
        guard numberOfFans > 0 else {
            return ([], [], [])
        }

        var speeds: [Int] = []
        var mins: [Int] = []
        var maxs: [Int] = []

        for i in 0..<numberOfFans {
            let actualKey = String(format: "F%dAc", i)
            let minKey = String(format: "F%dMn", i)
            let maxKey = String(format: "F%dMx", i)

            if let speed = readSMCValue(key: actualKey) {
                speeds.append(Int(speed))
            } else {
                speeds.append(0)
            }
            mins.append(Int(readSMCValue(key: minKey) ?? 1000))
            maxs.append(Int(readSMCValue(key: maxKey) ?? 6500))
        }

        return (speeds, mins, maxs)
    }

    private func readCPUUsage() -> CPUStats {
        var loadInfo = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &loadInfo) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPointer in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, intPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return CPUStats(
                usagePercent: cpuUsagePercent,
                performanceCoreUsagePercent: performanceCoreUsagePercent,
                efficiencyCoreUsagePercent: efficiencyCoreUsagePercent
            )
        }

        if !hasPreviousCPUInfo {
            previousCPULoadInfo = loadInfo
            hasPreviousCPUInfo = true
            return CPUStats(
                usagePercent: cpuUsagePercent,
                performanceCoreUsagePercent: performanceCoreUsagePercent,
                efficiencyCoreUsagePercent: efficiencyCoreUsagePercent
            )
        }

        let user = Double(loadInfo.cpu_ticks.0 - previousCPULoadInfo.cpu_ticks.0)
        let system = Double(loadInfo.cpu_ticks.1 - previousCPULoadInfo.cpu_ticks.1)
        let idle = Double(loadInfo.cpu_ticks.2 - previousCPULoadInfo.cpu_ticks.2)
        let nice = Double(loadInfo.cpu_ticks.3 - previousCPULoadInfo.cpu_ticks.3)

        previousCPULoadInfo = loadInfo

        let total = user + system + idle + nice
        guard total > 0 else {
            return CPUStats(
                usagePercent: cpuUsagePercent,
                performanceCoreUsagePercent: performanceCoreUsagePercent,
                efficiencyCoreUsagePercent: efficiencyCoreUsagePercent
            )
        }

        let used = user + system + nice
        let perClusterUsage = readCPUClusterUsage()
        return CPUStats(
            usagePercent: max(0, min(100, (used / total) * 100)),
            performanceCoreUsagePercent: perClusterUsage.performance,
            efficiencyCoreUsagePercent: perClusterUsage.efficiency
        )
    }

    private func readCPUClusterUsage() -> (performance: Double?, efficiency: Double?) {
        var processorInfo: processor_info_array_t?
        var processorInfoCount: mach_msg_type_number_t = 0
        var processorCount: natural_t = 0

        let result = host_processor_info(
            mach_host_self(),
            processor_flavor_t(PROCESSOR_CPU_LOAD_INFO),
            &processorCount,
            &processorInfo,
            &processorInfoCount
        )

        guard result == KERN_SUCCESS, let processorInfo else {
            return (performanceCoreUsagePercent, efficiencyCoreUsagePercent)
        }

        defer {
            let byteCount = vm_size_t(Int(processorInfoCount) * MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: processorInfo), byteCount)
        }

        let sample = Array(UnsafeBufferPointer(start: processorInfo, count: Int(processorInfoCount)))
        let cpuCount = Int(processorCount)
        guard cpuCount > 0, sample.count >= cpuCount * Int(CPU_STATE_MAX) else {
            return (performanceCoreUsagePercent, efficiencyCoreUsagePercent)
        }

        if !hasPreviousProcessorInfo || previousProcessorLoadInfo.count != sample.count {
            previousProcessorLoadInfo = sample
            hasPreviousProcessorInfo = true
            return (performanceCoreUsagePercent, efficiencyCoreUsagePercent)
        }

        defer { previousProcessorLoadInfo = sample }

        let pCoreCount = min(SystemMonitor.performanceCoreCount(), cpuCount)
        let eCoreCount = min(SystemMonitor.efficiencyCoreCount(), max(0, cpuCount - pCoreCount))
        guard pCoreCount > 0, pCoreCount + eCoreCount <= cpuCount else {
            return (performanceCoreUsagePercent, efficiencyCoreUsagePercent)
        }

        let performanceUsage = usageForProcessorRange(0..<pCoreCount, current: sample, previous: previousProcessorLoadInfo)
        let efficiencyUsage: Double?
        if eCoreCount > 0 {
            efficiencyUsage = usageForProcessorRange(pCoreCount..<(pCoreCount + eCoreCount), current: sample, previous: previousProcessorLoadInfo)
        } else {
            efficiencyUsage = nil
        }

        return (performanceUsage, efficiencyUsage)
    }

    private func usageForProcessorRange(
        _ range: Range<Int>,
        current: [integer_t],
        previous: [integer_t]
    ) -> Double? {
        var used: Double = 0
        var total: Double = 0
        let stride = Int(CPU_STATE_MAX)

        for processor in range {
            let base = processor * stride
            let user = max(0, Int(current[base + Int(CPU_STATE_USER)] - previous[base + Int(CPU_STATE_USER)]))
            let system = max(0, Int(current[base + Int(CPU_STATE_SYSTEM)] - previous[base + Int(CPU_STATE_SYSTEM)]))
            let idle = max(0, Int(current[base + Int(CPU_STATE_IDLE)] - previous[base + Int(CPU_STATE_IDLE)]))
            let nice = max(0, Int(current[base + Int(CPU_STATE_NICE)] - previous[base + Int(CPU_STATE_NICE)]))

            used += Double(user + system + nice)
            total += Double(user + system + idle + nice)
        }

        guard total > 0 else { return nil }
        return max(0, min(100, (used / total) * 100))
    }

    private func readMemoryStats() -> MemoryStats {
        var vmStats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)

        let kr = withUnsafeMutablePointer(to: &vmStats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPointer, &count)
            }
        }

        let totalBytes = Double(ProcessInfo.processInfo.physicalMemory)
        guard kr == KERN_SUCCESS, totalBytes > 0 else {
            return MemoryStats(
                usagePercent: memoryUsagePercent,
                usedGB: memoryUsedGB,
                totalGB: totalMemoryGB,
                pressure: memoryPressure,
                appGB: appMemoryGB,
                wiredGB: wiredMemoryGB,
                compressedGB: compressedMemoryGB,
                freeGB: freeMemoryGB,
                pageInsBytes: pageInsBytes,
                pageOutsBytes: pageOutsBytes,
                swapUsedBytes: swapUsedBytes,
                swapTotalBytes: swapTotalBytes
            )
        }

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        let page = Double(pageSize)

        let appBytes = Double(vmStats.active_count) * page
        let wiredBytes = Double(vmStats.wire_count) * page
        let compressedBytes = Double(vmStats.compressor_page_count) * page
        let usedBytes = appBytes + wiredBytes + compressedBytes
        let availableBytes = max(0, totalBytes - usedBytes)

        let usagePercent = max(0, min(100, (usedBytes / totalBytes) * 100))
        let usedGB = usedBytes / 1_073_741_824.0
        let totalGB = totalBytes / 1_073_741_824.0
        let appGB = appBytes / 1_073_741_824.0
        let wiredGB = wiredBytes / 1_073_741_824.0
        let compressedGB = compressedBytes / 1_073_741_824.0
        let freeGB = availableBytes / 1_073_741_824.0

        let availableRatio = max(0, min(1, availableBytes / totalBytes))
        let pressure: MemoryPressureLevel
        if availableRatio > 0.25 {
            pressure = .green
        } else if availableRatio > 0.12 {
            pressure = .yellow
        } else {
            pressure = .red
        }

        let pageInsBytes = UInt64(Double(vmStats.pageins) * page)
        let pageOutsBytes = UInt64(Double(vmStats.pageouts) * page)

        var swapUsedBytes: UInt64 = 0
        var swapTotalBytes: UInt64 = 0
        var swapUsage = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.stride
        if sysctlbyname("vm.swapusage", &swapUsage, &swapSize, nil, 0) == 0 {
            swapUsedBytes = swapUsage.xsu_used
            swapTotalBytes = swapUsage.xsu_total
        }

        return MemoryStats(
            usagePercent: usagePercent,
            usedGB: usedGB,
            totalGB: totalGB,
            pressure: pressure,
            appGB: appGB,
            wiredGB: wiredGB,
            compressedGB: compressedGB,
            freeGB: freeGB,
            pageInsBytes: pageInsBytes,
            pageOutsBytes: pageOutsBytes,
            swapUsedBytes: swapUsedBytes,
            swapTotalBytes: swapTotalBytes
        )
    }

    private func readBatteryInfo() -> BatteryInfo {
        var info = BatteryInfo()

        if let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
           let first = sources.first,
           let description = IOPSGetPowerSourceDescription(snapshot, first)?.takeUnretainedValue() as? [String: Any] {
            info.hasBattery = true

            let current = description[kIOPSCurrentCapacityKey as String] as? Int
            let max = description[kIOPSMaxCapacityKey as String] as? Int
            info.currentCapacity = current
            info.maxCapacity = max

            if let current, let max, max > 0 {
                info.chargePercent = Int((Double(current) / Double(max) * 100.0).rounded())
            }

            info.isCharging = (description[kIOPSIsChargingKey as String] as? Bool) ?? false
            let sourceState = description[kIOPSPowerSourceStateKey as String] as? String
            info.isPluggedIn = sourceState == (kIOPSACPowerValue as String)
            info.source = sourceState

            if let tte = description[kIOPSTimeToEmptyKey as String] as? Int, tte >= 0 {
                info.timeRemainingMinutes = tte
            } else if let ttf = description[kIOPSTimeToFullChargeKey as String] as? Int, ttf >= 0 {
                info.timeRemainingMinutes = ttf
            }

            if info.isCharging {
                info.status = "Charging"
            } else if info.isPluggedIn {
                info.status = "AC"
            } else {
                info.status = "Battery"
            }
        }

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        if service != 0 {
            defer { IOObjectRelease(service) }

            var propertiesRef: Unmanaged<CFMutableDictionary>?
            let result = IORegistryEntryCreateCFProperties(service, &propertiesRef, kCFAllocatorDefault, 0)
            if result == KERN_SUCCESS,
               let properties = propertiesRef?.takeRetainedValue() as? [String: Any] {
                info.hasBattery = true

                if let cycle = properties["CycleCount"] as? Int {
                    info.cycleCount = cycle
                }

                let smartMax = (properties["AppleRawMaxCapacity"] as? Int) ?? (properties["MaxCapacity"] as? Int)
                let smartDesign = (properties["DesignCapacity"] as? Int) ?? (properties["NominalChargeCapacity"] as? Int)
                if let smartMax, var smartDesign, smartDesign > 0 {
                    if smartDesign > 100_000, smartMax < 20_000 {
                        smartDesign /= 1000
                    }
                    let health = Int((Double(smartMax) / Double(smartDesign) * 100.0).rounded())
                    if (20...120).contains(health) {
                        info.healthPercent = health
                    }
                }

                if let tempRaw = properties["Temperature"] as? Int {
                    let candidates = [
                        (Double(tempRaw) / 10.0) - 273.15,
                        (Double(tempRaw) / 100.0) - 273.15
                    ]
                    if let celsius = candidates.first(where: { $0 > -40 && $0 < 120 }) {
                        info.temperatureC = celsius
                    }
                }

                if let mv = properties["Voltage"] as? Int {
                    info.voltageV = Double(mv) / 1000.0
                }

                if let ma = properties["Amperage"] as? Int {
                    info.amperageA = Double(ma) / 1000.0
                }

                if let volts = info.voltageV, let amps = info.amperageA {
                    info.powerWatts = volts * amps
                }
            }
        }

        return info
    }

    func readSMCValue(key: String) -> Double? {
        guard smcConnection != 0 || openSMCConnection() else { return nil }

        let keyCode = fourCharCodeFrom(key)
        let keyInfo: SMCKeyData_keyInfo_t

        if let cached = keyInfoCache[keyCode] {
            keyInfo = cached
        } else {
            var input = SMCParamStruct()
            input.key = keyCode
            input.data8 = smcReadKeyInfo

            var output = SMCParamStruct()
            var outputSize = MemoryLayout<SMCParamStruct>.size

            let result = IOConnectCallStructMethod(
                smcConnection,
                kernelIndexSmc,
                &input,
                MemoryLayout<SMCParamStruct>.size,
                &output,
                &outputSize
            )

            guard result == kIOReturnSuccess, output.result == 0 else {
                return nil
            }

            guard output.keyInfo.dataSize > 0, output.keyInfo.dataSize <= 32 else {
                return nil
            }

            keyInfo = output.keyInfo
            keyInfoCache[keyCode] = output.keyInfo
        }

        var input = SMCParamStruct()
        input.key = keyCode
        input.keyInfo = keyInfo
        input.data8 = smcReadBytes

        var output = SMCParamStruct()
        var outputSize = MemoryLayout<SMCParamStruct>.size

        let result = IOConnectCallStructMethod(
            smcConnection,
            kernelIndexSmc,
            &input,
            MemoryLayout<SMCParamStruct>.size,
            &output,
            &outputSize
        )

        guard result == kIOReturnSuccess, output.result == 0 else {
            return nil
        }

        return parseSMCBytes(output.bytes, dataType: keyInfo.dataType, dataSize: keyInfo.dataSize)
    }

    private func parseSMCBytes(_ bytes: SMCBytes, dataType: UInt32, dataSize: UInt32) -> Double? {
        let raw = [
            bytes.0, bytes.1, bytes.2, bytes.3, bytes.4, bytes.5, bytes.6, bytes.7,
            bytes.8, bytes.9, bytes.10, bytes.11, bytes.12, bytes.13, bytes.14, bytes.15,
            bytes.16, bytes.17, bytes.18, bytes.19, bytes.20, bytes.21, bytes.22, bytes.23,
            bytes.24, bytes.25, bytes.26, bytes.27, bytes.28, bytes.29, bytes.30, bytes.31
        ]

        switch dataType {
        case dataTypeFlt:
            if dataSize == 4 {
                let value = raw.withUnsafeBufferPointer {
                    $0.baseAddress!.withMemoryRebound(to: Float32.self, capacity: 1) { $0.pointee }
                }
                return Double(value)
            }

        case dataTypeSp78:
            if dataSize == 2 {
                let value = (Int(raw[0]) << 8) | Int(raw[1])
                return Double(Int16(bitPattern: UInt16(value))) / 256.0
            }

        case dataTypeFpe2:
            if dataSize == 2 {
                let value = (Int(raw[0]) << 6) + (Int(raw[1]) >> 2)
                return Double(value)
            }

        case dataTypeUInt8:
            if dataSize == 1 {
                return Double(raw[0])
            }

        case dataTypeUInt16:
            if dataSize == 2 {
                return Double((Int(raw[0]) << 8) | Int(raw[1]))
            }

        case dataTypeUInt32:
            if dataSize == 4 {
                let value = (UInt32(raw[0]) << 24) | (UInt32(raw[1]) << 16) | (UInt32(raw[2]) << 8) | UInt32(raw[3])
                return Double(value)
            }

        case dataTypeSInt16:
            if dataSize == 2 {
                let value = (UInt16(raw[0]) << 8) | UInt16(raw[1])
                return Double(Int16(bitPattern: value))
            }

        default:
            break
        }

        if dataSize == 2 {
            return Double((Int(raw[0]) << 8) | Int(raw[1]))
        }

        return nil
    }
    private func readSystemControls() -> (volume: Float, brightness: Float) {
        var volume = currentVolume
        var brightness = currentBrightness

        // Volume
        var dev = AudioDeviceID(kAudioObjectUnknown)
        var sz  = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope:    kAudioObjectPropertyScopeGlobal,
            mElement:  kAudioObjectPropertyElementMain)
        if AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                      &addr, 0, nil, &sz, &dev) == noErr,
           dev != kAudioObjectUnknown {
            if let deviceVolume = readOutputVolume(for: dev) {
                volume = deviceVolume
            }
        }

        // Brightness
        var svc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IODisplayConnect"))
        if svc == 0 {
            svc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleBacklightDisplay"))
        }
        if svc != 0 {
            var bri: Float = brightness
            IODisplayGetFloatParameter(svc, 0, kIODisplayBrightnessKey as CFString, &bri)
            brightness = bri
            IOObjectRelease(svc)
        }

        return (volume, brightness)
    }

    private func readOutputVolume(for deviceID: AudioDeviceID) -> Float? {
        if let main = readVolumeScalar(for: deviceID, element: kAudioObjectPropertyElementMain) {
            return main
        }

        let left = readVolumeScalar(for: deviceID, element: 1)
        let right = readVolumeScalar(for: deviceID, element: 2)

        switch (left, right) {
        case let (.some(l), .some(r)):
            return (l + r) / 2
        case let (.some(l), .none):
            return l
        case let (.none, .some(r)):
            return r
        case (.none, .none):
            return nil
        }
    }

    private func readVolumeScalar(for deviceID: AudioDeviceID, element: AudioObjectPropertyElement) -> Float? {
        var vol: Float32 = currentVolume
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: element
        )

        guard AudioObjectHasProperty(deviceID, &address) else { return nil }
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &vol)
        guard status == noErr else { return nil }
        return vol
    }

}

func fourCharCodeFrom(_ string: String) -> UInt32 {
    var result: UInt32 = 0
    for (index, byte) in string.utf8.prefix(4).enumerated() {
        result |= UInt32(byte) << (8 * (3 - index))
    }
    return result
}

private func sysctlString(named name: String) -> String? {
    var size: size_t = 0
    guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 1 else { return nil }
    var buffer = [CChar](repeating: 0, count: size)
    guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
    return String(cString: buffer)
}

private func sysctlInt(named name: String) -> Int? {
    var value: Int32 = 0
    var size = MemoryLayout<Int32>.size
    guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
    return Int(value)
}
