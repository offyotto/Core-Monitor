import Foundation

struct SMCStorageTemperatureSensor: Equatable, Sendable {
    let key: String
    let label: String
}

struct SMCTemperatureSensorSet: Equatable, Sendable {
    let cpuKeys: [String]
    let gpuKeys: [String]
    let storageSensors: [SMCStorageTemperatureSensor]
}

enum SMCTemperatureSensorCatalog {
    private nonisolated static let intelCPUKeys = [
        "TC0P", "TCXC", "TC0E", "TC0F", "TC0D", "TC1C", "TC2C", "TC3C", "TC4C"
    ]

    private nonisolated static let intelGPUKeys = [
        "TGDD", "TG0P", "TG0D", "TG0E", "TG0F"
    ]

    private nonisolated static let m1CPUKeys = [
        "Tp09", "Tp0T", "Tp01", "Tp05", "Tp0D", "Tp0H", "Tp0L", "Tp0P", "Tp0X", "Tp0b"
    ]

    private nonisolated static let m1GPUKeys = [
        "Tg05", "Tg0D", "Tg0L", "Tg0T"
    ]

    private nonisolated static let m2CPUKeys = [
        "Tp1h", "Tp1t", "Tp1p", "Tp1l",
        "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0X", "Tp0b", "Tp0f", "Tp0j"
    ]

    private nonisolated static let m2GPUKeys = [
        "Tg0f", "Tg0j"
    ]

    private nonisolated static let m3CPUKeys = [
        "Te05", "Te0L", "Te0P", "Te0S",
        "Tf04", "Tf09", "Tf0A", "Tf0B", "Tf0D", "Tf0E",
        "Tf44", "Tf49", "Tf4A", "Tf4B", "Tf4D", "Tf4E"
    ]

    private nonisolated static let m3GPUKeys = [
        "Tf14", "Tf18", "Tf19", "Tf1A", "Tf24", "Tf28", "Tf29", "Tf2A"
    ]

    private nonisolated static let m4CPUKeys = [
        "Te05", "Te0S", "Te09", "Te0H",
        "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0V", "Tp0Y", "Tp0b", "Tp0e"
    ]

    private nonisolated static let m4GPUKeys = [
        "Tg0G", "Tg0H", "Tg1U", "Tg1k",
        "Tg0K", "Tg0L", "Tg0d", "Tg0e", "Tg0j", "Tg0k"
    ]

    private nonisolated static let m5CPUKeys = [
        "Tp00", "Tp04", "Tp08", "Tp0C", "Tp0G", "Tp0K",
        "Tp0O", "Tp0R", "Tp0U", "Tp0X", "Tp0a", "Tp0d",
        "Tp0g", "Tp0j", "Tp0m", "Tp0p", "Tp0u", "Tp0y"
    ]

    private nonisolated static let m5GPUKeys = [
        "Tg0U", "Tg0X", "Tg0d", "Tg0g", "Tg0j", "Tg1Y", "Tg1c", "Tg1g"
    ]

    private nonisolated static let appleStorageSensors = [
        SMCStorageTemperatureSensor(key: "TH0x", label: "NAND (SMC)")
    ]

    private nonisolated static let intelStorageSensors = [
        SMCStorageTemperatureSensor(key: "TH0A", label: "Drive A (SMC)"),
        SMCStorageTemperatureSensor(key: "TH0B", label: "Drive B (SMC)"),
        SMCStorageTemperatureSensor(key: "TH0C", label: "Drive C (SMC)")
    ]

    nonisolated static func sensors(chipName: String, isAppleSilicon: Bool) -> SMCTemperatureSensorSet {
        guard isAppleSilicon else {
            return SMCTemperatureSensorSet(
                cpuKeys: intelCPUKeys,
                gpuKeys: intelGPUKeys,
                storageSensors: intelStorageSensors
            )
        }

        let keys: (cpu: [String], gpu: [String])
        switch generation(in: chipName) {
        case 1:
            keys = (m1CPUKeys, m1GPUKeys)
        case 2:
            keys = (m2CPUKeys, m2GPUKeys)
        case 3:
            keys = (m3CPUKeys, m3GPUKeys)
        case 4:
            keys = (m4CPUKeys, m4GPUKeys)
        case 5:
            keys = (m5CPUKeys, m5GPUKeys)
        default:
            keys = (
                unique(m1CPUKeys + m2CPUKeys + m3CPUKeys + m4CPUKeys + m5CPUKeys),
                unique(m1GPUKeys + m2GPUKeys + m3GPUKeys + m4GPUKeys + m5GPUKeys)
            )
        }

        return SMCTemperatureSensorSet(
            cpuKeys: keys.cpu,
            gpuKeys: keys.gpu,
            storageSensors: appleStorageSensors
        )
    }

    nonisolated static func averageTemperature(
        for keys: [String],
        readValue: (String) -> Double?
    ) -> Double? {
        let values = keys.compactMap { key -> Double? in
            guard let value = readValue(key), isValidTemperature(value, upperBound: 150) else {
                return nil
            }
            return value
        }

        guard values.isEmpty == false else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Returns the hottest reading among the given sensor keys instead of the average,
    /// so a single hot core isn't masked by cooler sensors when reporting overall temperature.
    nonisolated static func peakTemperature(
        for keys: [String],
        readValue: (String) -> Double?
    ) -> Double? {
        let values = keys.compactMap { key -> Double? in
            guard let value = readValue(key), isValidTemperature(value, upperBound: 150) else {
                return nil
            }
            return value
        }

        return values.max()
    }

    nonisolated static func firstStorageTemperature(
        for sensors: [SMCStorageTemperatureSensor],
        readValue: (String) -> Double?
    ) -> (sensor: SMCStorageTemperatureSensor, value: Double)? {
        for sensor in sensors {
            guard let value = readValue(sensor.key), isValidTemperature(value, upperBound: 100) else {
                continue
            }
            return (sensor, value)
        }
        return nil
    }

    private nonisolated static func generation(in chipName: String) -> Int? {
        let tokens = chipName.uppercased().split { $0.isLetter == false && $0.isNumber == false }
        for value in 1...5 where tokens.contains(Substring("M\(value)")) {
            return value
        }
        return nil
    }

    private nonisolated static func isValidTemperature(_ value: Double, upperBound: Double) -> Bool {
        value.isFinite && value > 0 && value < upperBound
    }

    private nonisolated static func unique(_ keys: [String]) -> [String] {
        var seen = Set<String>()
        return keys.filter { seen.insert($0).inserted }
    }
}

enum SMCIOFloatDecoder {
    nonisolated static func decode(_ bytes: [UInt8], dataSize: UInt32) -> Double? {
        guard dataSize == 8, bytes.count >= 8 else { return nil }

        var rawValue: UInt64 = 0
        for index in (0..<8).reversed() {
            rawValue = (rawValue << 8) | UInt64(bytes[index])
        }
        return Double(rawValue) / 65_536.0
    }
}
