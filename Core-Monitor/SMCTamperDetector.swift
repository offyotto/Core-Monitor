import AppKit
import Combine
import Foundation
import IOKit

private typealias ProbeSMCBytes = (
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
)

private struct ProbeSMCKeyDataVers {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

private struct ProbeSMCKeyDataPLimit {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

private struct ProbeSMCKeyInfo {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

private struct ProbeSMCParamStruct {
    var key: UInt32 = 0
    var vers = ProbeSMCKeyDataVers()
    var pLimitData = ProbeSMCKeyDataPLimit()
    var keyInfo = ProbeSMCKeyInfo()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: ProbeSMCBytes = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
}

@MainActor
final class SMCTamperDetector: ObservableObject {
    static let shared = SMCTamperDetector()

    @Published private(set) var isTampered = false
    @Published private(set) var tamperLabel: String?

    private var baselineModes: [String: Double] = [:]

    private init() {
        baselineModes = captureFanModes()
        inspect()
    }

    func inspect() {
        let currentModes = captureFanModes()
        let apps = knownFanControlApplications()
        let keysChanged = baselineModes.contains { key, baseline in
            guard let current = currentModes[key] else { return false }
            return abs(current - baseline) > 0.001
        }

        if !apps.isEmpty || keysChanged {
            isTampered = true
            tamperLabel = "Custom Fan Control"
        } else {
            isTampered = false
            tamperLabel = nil
        }
    }

    private func knownFanControlApplications() -> [NSRunningApplication] {
        let names = [
            "Macs Fan Control",
            "TG Pro",
            "System Monitor",
            "smcFanControl",
            "Stats"
        ]
        return NSWorkspace.shared.runningApplications.filter { app in
            let name = app.localizedName ?? ""
            return names.contains(where: { name.localizedCaseInsensitiveContains($0) })
        }
    }

    private func captureFanModes() -> [String: Double] {
        guard let controller = SMCProbeController() else { return [:] }
        var result: [String: Double] = [:]
        let count = Int(controller.readValue("FNum") ?? 0)
        guard count > 0 else { return result }
        for fan in 0..<count {
            let key = "F\(fan)Md"
            if let value = controller.readValue(key) {
                result[key] = value
            }
        }
        return result
    }
}

private final class SMCProbeController {
    private var connection: io_connect_t = 0
    private var keyInfoCache: [UInt32: ProbeSMCKeyInfo] = [:]
    private let smcReadBytes: UInt8 = 5
    private let smcReadKeyInfo: UInt8 = 9

    init?() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard IOServiceOpen(service, mach_task_self_, 0, &connection) == kIOReturnSuccess else { return nil }
    }

    deinit {
        if connection != 0 { IOServiceClose(connection) }
    }

    func readValue(_ key: String) -> Double? {
        let keyCode = fourCharCodeFrom(key)
        let keyInfo = keyInfo(for: keyCode)
        guard var info = keyInfo else { return nil }

        var input = ProbeSMCParamStruct()
        input.key = keyCode
        input.keyInfo = info
        input.data8 = smcReadBytes

        var output = ProbeSMCParamStruct()
        var outputSize = MemoryLayout<ProbeSMCParamStruct>.size
        let status = IOConnectCallStructMethod(
            connection, 2, &input, MemoryLayout<ProbeSMCParamStruct>.size, &output, &outputSize
        )
        guard status == kIOReturnSuccess, output.result == 0 else { return nil }
        info = output.keyInfo
        return parseSMCBytes(output.bytes, dataType: info.dataType, dataSize: info.dataSize)
    }

    private func keyInfo(for keyCode: UInt32) -> ProbeSMCKeyInfo? {
        if let cached = keyInfoCache[keyCode] { return cached }
        var input = ProbeSMCParamStruct()
        input.key = keyCode
        input.data8 = smcReadKeyInfo
        var output = ProbeSMCParamStruct()
        var outputSize = MemoryLayout<ProbeSMCParamStruct>.size
        let status = IOConnectCallStructMethod(
            connection, 2, &input, MemoryLayout<ProbeSMCParamStruct>.size, &output, &outputSize
        )
        guard status == kIOReturnSuccess, output.result == 0 else { return nil }
        keyInfoCache[keyCode] = output.keyInfo
        return output.keyInfo
    }

    private func parseSMCBytes(_ bytes: ProbeSMCBytes, dataType: UInt32, dataSize: UInt32) -> Double? {
        let raw = [
            bytes.0, bytes.1, bytes.2, bytes.3, bytes.4, bytes.5, bytes.6, bytes.7,
            bytes.8, bytes.9, bytes.10, bytes.11, bytes.12, bytes.13, bytes.14, bytes.15,
            bytes.16, bytes.17, bytes.18, bytes.19, bytes.20, bytes.21, bytes.22, bytes.23,
            bytes.24, bytes.25, bytes.26, bytes.27, bytes.28, bytes.29, bytes.30, bytes.31
        ]
        let flt = fourCharCodeFrom("flt ")
        let sp78 = fourCharCodeFrom("sp78")
        let fpe2 = fourCharCodeFrom("fpe2")
        let ui8 = fourCharCodeFrom("ui8 ")
        let ui16 = fourCharCodeFrom("ui16")
        let ui32 = fourCharCodeFrom("ui32")
        if dataType == flt, dataSize == 4 {
            let bits = UInt32(raw[3]) << 24 | UInt32(raw[2]) << 16 | UInt32(raw[1]) << 8 | UInt32(raw[0])
            return Double(Float(bitPattern: bits))
        }
        if dataType == sp78, dataSize == 2 {
            let value = (Int(raw[0]) << 8) | Int(raw[1])
            return Double(Int16(bitPattern: UInt16(value))) / 256.0
        }
        if dataType == fpe2, dataSize == 2 {
            return Double((Int(raw[0]) << 6) + (Int(raw[1]) >> 2))
        }
        if dataType == ui8, dataSize == 1 { return Double(raw[0]) }
        if dataType == ui16, dataSize == 2 { return Double((Int(raw[0]) << 8) | Int(raw[1])) }
        if dataType == ui32, dataSize == 4 {
            let value = (UInt32(raw[0]) << 24) | (UInt32(raw[1]) << 16) | (UInt32(raw[2]) << 8) | UInt32(raw[3])
            return Double(value)
        }
        return nil
    }
}
