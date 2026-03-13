import Foundation
import Combine
import IOKit
import IOKit.ps
import Darwin

struct CPUStats {
    let usagePercent: Double
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
    @Published var cpuTemperature: Double?
    @Published var gpuTemperature: Double?
    @Published var fanSpeeds: [Int] = []
    @Published var fanMinSpeeds: [Int] = []
    @Published var fanMaxSpeeds: [Int] = []
    @Published var numberOfFans: Int = 0
    @Published var cpuUsagePercent: Double = 0
    @Published var hasSMCAccess: Bool = false
    @Published var lastError: String?

    @Published var batteryInfo = BatteryInfo()
    @Published var totalSystemWatts: Double?
    @Published var memoryUsagePercent: Double = 0
    @Published var memoryUsedGB: Double = 0
    @Published var totalMemoryGB: Double = 0
    @Published var memoryPressure: MemoryPressureLevel = .green

    static var isAppleSilicon: Bool {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let result = sysctlbyname("hw.optional.arm64", &value, &size, nil, 0)
        return result == 0 && value == 1
    }

    private var smcConnection: io_connect_t = 0
    private let monitoringInterval: TimeInterval = 2.0
    private var timer: Timer?
    private var keyInfoCache: [UInt32: SMCKeyData_keyInfo_t] = [:]

    private var previousCPULoadInfo = host_cpu_load_info_data_t()
    private var hasPreviousCPUInfo = false

    private let cpuTempKeys = [
        "TC0P", "TCXC", "TC0E", "TC0F", "TC0D", "TC1C", "TC2C", "TC3C", "TC4C",
        "Tp09", "Tp0T", "Tp01", "Tp05", "Tp0D", "Tp0b"
    ]

    private let gpuTempKeys = ["TGDD", "TG0P", "TG0D", "TG0E", "TG0F", "Tg0T", "Tg05"]

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

    init() {
        hasSMCAccess = openSMCConnection()
    }

    deinit {
        stopMonitoring()
        closeSMCConnection()
    }

    func startMonitoring() {
        _ = openSMCConnection()
        detectFans()
        updateReadings()

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            self?.updateReadings()
        }
        if let timer {
            timer.tolerance = 0.3
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func openSMCConnection() -> Bool {
        if smcConnection != 0 {
            hasSMCAccess = true
            return true
        }

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else {
            hasSMCAccess = false
            lastError = "AppleSMC service not found"
            return false
        }

        defer { IOObjectRelease(service) }

        let result = IOServiceOpen(service, mach_task_self_, 0, &smcConnection)
        if result == kIOReturnSuccess {
            hasSMCAccess = true
            lastError = nil
            return true
        }

        hasSMCAccess = false
        lastError = "Failed to open SMC connection (\(result))"
        return false
    }

    private func closeSMCConnection() {
        if smcConnection != 0 {
            IOServiceClose(smcConnection)
            smcConnection = 0
        }
    }

    private func detectFans() {
        var count = 0
        for i in 0..<8 {
            let key = String(format: "F%dAc", i)
            if readSMCValue(key: key) != nil {
                count += 1
            } else {
                break
            }
        }
        numberOfFans = count
    }

    private func updateReadings() {
        cpuTemperature = readCPUTemperature()
        gpuTemperature = readGPUTemperature()
        updateFanReadings()
        cpuUsagePercent = readCPUUsage().usagePercent

        let memoryStats = readMemoryStats()
        memoryUsagePercent = memoryStats.usagePercent
        memoryUsedGB = memoryStats.usedGB
        totalMemoryGB = memoryStats.totalGB
        memoryPressure = memoryStats.pressure

        let newBattery = readBatteryInfo()
        batteryInfo = newBattery
        totalSystemWatts = newBattery.powerWatts
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

    private func updateFanReadings() {
        guard numberOfFans > 0 else {
            fanSpeeds = []
            fanMinSpeeds = []
            fanMaxSpeeds = []
            return
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

        fanSpeeds = speeds
        fanMinSpeeds = mins
        fanMaxSpeeds = maxs
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
            return CPUStats(usagePercent: cpuUsagePercent)
        }

        if !hasPreviousCPUInfo {
            previousCPULoadInfo = loadInfo
            hasPreviousCPUInfo = true
            return CPUStats(usagePercent: cpuUsagePercent)
        }

        let user = Double(loadInfo.cpu_ticks.0 - previousCPULoadInfo.cpu_ticks.0)
        let system = Double(loadInfo.cpu_ticks.1 - previousCPULoadInfo.cpu_ticks.1)
        let idle = Double(loadInfo.cpu_ticks.2 - previousCPULoadInfo.cpu_ticks.2)
        let nice = Double(loadInfo.cpu_ticks.3 - previousCPULoadInfo.cpu_ticks.3)

        previousCPULoadInfo = loadInfo

        let total = user + system + idle + nice
        guard total > 0 else {
            return CPUStats(usagePercent: 0)
        }

        let used = user + system + nice
        return CPUStats(usagePercent: max(0, min(100, (used / total) * 100)))
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
            return MemoryStats(usagePercent: memoryUsagePercent, usedGB: memoryUsedGB, totalGB: totalMemoryGB, pressure: memoryPressure)
        }

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        let page = Double(pageSize)

        let usedPages = Double(vmStats.active_count + vmStats.wire_count + vmStats.compressor_page_count)
        let availablePages = Double(vmStats.free_count + vmStats.inactive_count + vmStats.speculative_count)

        let usedBytes = usedPages * page
        let availableBytes = availablePages * page

        let usagePercent = max(0, min(100, (usedBytes / totalBytes) * 100))
        let usedGB = usedBytes / 1_073_741_824.0
        let totalGB = totalBytes / 1_073_741_824.0

        let availableRatio = max(0, min(1, availableBytes / totalBytes))
        let pressure: MemoryPressureLevel
        if availableRatio > 0.25 {
            pressure = .green
        } else if availableRatio > 0.12 {
            pressure = .yellow
        } else {
            pressure = .red
        }

        return MemoryStats(usagePercent: usagePercent, usedGB: usedGB, totalGB: totalGB, pressure: pressure)
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
                    // Some machines report design in a different scale; normalize obvious outliers.
                    if smartDesign > 100_000, smartMax < 20_000 {
                        smartDesign /= 1000
                    }
                    let health = Int((Double(smartMax) / Double(smartDesign) * 100.0).rounded())
                    if (20...120).contains(health) {
                        info.healthPercent = health
                    }
                }

                if let tempRaw = properties["Temperature"] as? Int {
                    let celsius = (Double(tempRaw) / 100.0) - 273.15
                    if celsius > -40, celsius < 120 {
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
                    info.powerWatts = abs(volts * amps)
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
                var value: Float32 = 0
                withUnsafeMutableBytes(of: &value) { buffer in
                    buffer[0] = raw[0]
                    buffer[1] = raw[1]
                    buffer[2] = raw[2]
                    buffer[3] = raw[3]
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
}

private func fourCharCodeFrom(_ string: String) -> UInt32 {
    var result: UInt32 = 0
    for (index, byte) in string.utf8.prefix(4).enumerated() {
        result |= UInt32(byte) << (8 * (3 - index))
    }
    return result
}
