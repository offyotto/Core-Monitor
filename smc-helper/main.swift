import Foundation
import IOKit

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
    var bytes: SMCBytes = (
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    )
}

private final class SMCController {
    private var connection: io_connect_t = 0
    private var keyInfoCache: [UInt32: SMCKeyData_keyInfo_t] = [:]

    private let smcReadBytes: UInt8 = 5
    private let smcWriteBytes: UInt8 = 6
    private let smcReadKeyInfo: UInt8 = 9
    private let kernelIndexSmc: UInt32 = 2

    private let typeFpe2 = fourCharCodeFrom("fpe2")
    private let typeFlt = fourCharCodeFrom("flt ")
    private let typeUi8 = fourCharCodeFrom("ui8 ")
    private let typeUi16 = fourCharCodeFrom("ui16")

    deinit {
        close()
    }

    func open() throws {
        if connection != 0 { return }

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else {
            throw HelperError("AppleSMC service not found")
        }
        defer { IOObjectRelease(service) }

        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        guard result == kIOReturnSuccess else {
            throw HelperError("Failed to open AppleSMC (\(result))")
        }
    }

    func close() {
        if connection != 0 {
            IOServiceClose(connection)
            connection = 0
        }
    }

    func setFanManual(_ fanID: Int, rpm: Int) throws {
        let modeKey = String(format: "F%dMd", fanID)
        let targetKey = String(format: "F%dTg", fanID)

        try writeValue(key: modeKey, value: 1)
        try writeValue(key: targetKey, value: rpm)
    }

    func setFanAuto(_ fanID: Int) throws {
        let modeKey = String(format: "F%dMd", fanID)
        try writeValue(key: modeKey, value: 0)
    }

    func readValue(_ key: String) throws -> Double {
        let keyCode = fourCharCodeFrom(key)
        let keyInfo = try getKeyInfo(keyCode)

        var input = SMCParamStruct()
        input.key = keyCode
        input.keyInfo = keyInfo
        input.data8 = smcReadBytes

        var output = SMCParamStruct()
        var outputSize = MemoryLayout<SMCParamStruct>.size

        let result = IOConnectCallStructMethod(
            connection,
            kernelIndexSmc,
            &input,
            MemoryLayout<SMCParamStruct>.size,
            &output,
            &outputSize
        )

        guard result == kIOReturnSuccess, output.result == 0 else {
            throw HelperError("SMC read failed (\(result))")
        }

        guard let parsed = parseSMCBytes(output.bytes, dataType: keyInfo.dataType, dataSize: keyInfo.dataSize) else {
            throw HelperError("Unsupported key type for \(key)")
        }

        return parsed
    }

    private func writeValue(key: String, value: Int) throws {
        let keyCode = fourCharCodeFrom(key)
        let keyInfo = try getKeyInfo(keyCode)

        let encoded = try encode(value: value, dataType: keyInfo.dataType, dataSize: keyInfo.dataSize)

        var input = SMCParamStruct()
        input.key = keyCode
        input.keyInfo = keyInfo
        input.data8 = smcWriteBytes
        input.bytes = encoded

        var output = SMCParamStruct()
        var outputSize = MemoryLayout<SMCParamStruct>.size

        let result = IOConnectCallStructMethod(
            connection,
            kernelIndexSmc,
            &input,
            MemoryLayout<SMCParamStruct>.size,
            &output,
            &outputSize
        )

        guard result == kIOReturnSuccess, output.result == 0 else {
            throw HelperError("SMC write failed for \(key) (\(result))")
        }
    }

    private func getKeyInfo(_ keyCode: UInt32) throws -> SMCKeyData_keyInfo_t {
        if let cached = keyInfoCache[keyCode] {
            return cached
        }

        var input = SMCParamStruct()
        input.key = keyCode
        input.data8 = smcReadKeyInfo

        var output = SMCParamStruct()
        var outputSize = MemoryLayout<SMCParamStruct>.size

        let result = IOConnectCallStructMethod(
            connection,
            kernelIndexSmc,
            &input,
            MemoryLayout<SMCParamStruct>.size,
            &output,
            &outputSize
        )

        guard result == kIOReturnSuccess, output.result == 0 else {
            throw HelperError("SMC key info read failed (\(result))")
        }

        keyInfoCache[keyCode] = output.keyInfo
        return output.keyInfo
    }

    private func encode(value: Int, dataType: UInt32, dataSize: UInt32) throws -> SMCBytes {
        var raw = [UInt8](repeating: 0, count: 32)

        if dataType == typeUi8, dataSize >= 1 {
            raw[0] = UInt8(max(0, min(255, value)))
        } else if dataType == typeUi16, dataSize >= 2 {
            let v = UInt16(max(0, min(Int(UInt16.max), value)))
            raw[0] = UInt8((v >> 8) & 0xFF)
            raw[1] = UInt8(v & 0xFF)
        } else if dataType == typeFpe2, dataSize >= 2 {
            let v = UInt16(max(0, min(16383, value)))
            raw[0] = UInt8((v >> 6) & 0xFF)
            raw[1] = UInt8((v & 0x3F) << 2)
        } else if dataType == typeFlt, dataSize >= 4 {
            let bits = Float(value).bitPattern.littleEndian
            raw[0] = UInt8((bits >> 0) & 0xFF)
            raw[1] = UInt8((bits >> 8) & 0xFF)
            raw[2] = UInt8((bits >> 16) & 0xFF)
            raw[3] = UInt8((bits >> 24) & 0xFF)
        } else {
            throw HelperError("Unsupported write type for key")
        }

        return (
            raw[0], raw[1], raw[2], raw[3], raw[4], raw[5], raw[6], raw[7],
            raw[8], raw[9], raw[10], raw[11], raw[12], raw[13], raw[14], raw[15],
            raw[16], raw[17], raw[18], raw[19], raw[20], raw[21], raw[22], raw[23],
            raw[24], raw[25], raw[26], raw[27], raw[28], raw[29], raw[30], raw[31]
        )
    }

    private func parseSMCBytes(_ bytes: SMCBytes, dataType: UInt32, dataSize: UInt32) -> Double? {
        let raw = [
            bytes.0, bytes.1, bytes.2, bytes.3, bytes.4, bytes.5, bytes.6, bytes.7,
            bytes.8, bytes.9, bytes.10, bytes.11, bytes.12, bytes.13, bytes.14, bytes.15,
            bytes.16, bytes.17, bytes.18, bytes.19, bytes.20, bytes.21, bytes.22, bytes.23,
            bytes.24, bytes.25, bytes.26, bytes.27, bytes.28, bytes.29, bytes.30, bytes.31
        ]

        let typeSp78 = fourCharCodeFrom("sp78")
        let typeFlt = fourCharCodeFrom("flt ")

        if dataType == typeSp78, dataSize == 2 {
            let value = (Int(raw[0]) << 8) | Int(raw[1])
            return Double(Int16(bitPattern: UInt16(value))) / 256.0
        }

        if dataType == typeFpe2, dataSize == 2 {
            return Double((Int(raw[0]) << 6) + (Int(raw[1]) >> 2))
        }

        if dataType == typeUi8, dataSize == 1 {
            return Double(raw[0])
        }

        if dataType == typeUi16, dataSize == 2 {
            return Double((Int(raw[0]) << 8) | Int(raw[1]))
        }

        if dataType == typeFlt, dataSize == 4 {
            let bigEndianBits = (UInt32(raw[0]) << 24)
                | (UInt32(raw[1]) << 16)
                | (UInt32(raw[2]) << 8)
                | UInt32(raw[3])
            let littleEndianBits = (UInt32(raw[3]) << 24)
                | (UInt32(raw[2]) << 16)
                | (UInt32(raw[1]) << 8)
                | UInt32(raw[0])

            let be = Double(Float(bitPattern: bigEndianBits))
            let le = Double(Float(bitPattern: littleEndianBits))
            let beValid = be.isFinite && abs(be) < 100_000
            let leValid = le.isFinite && abs(le) < 100_000
            if beValid && !leValid { return be }
            if leValid && !beValid { return le }
            if beValid && leValid { return abs(be) <= abs(le) ? be : le }
            return be.isFinite ? be : (le.isFinite ? le : nil)
        }

        return nil
    }
}

private struct HelperError: Error, LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

private func fourCharCodeFrom(_ string: String) -> UInt32 {
    var result: UInt32 = 0
    for (index, byte) in string.utf8.prefix(4).enumerated() {
        result |= UInt32(byte) << (8 * (3 - index))
    }
    return result
}

private func printUsageAndExit() -> Never {
    FileHandle.standardError.write(Data("Usage:\n  smc-helper set <fanID> <rpm>\n  smc-helper auto <fanID>\n  smc-helper read <key>\n".utf8))
    Foundation.exit(64)
}

let args = CommandLine.arguments
guard args.count >= 2 else { printUsageAndExit() }

let command = args[1]
private let controller = SMCController()

do {
    try controller.open()

    switch command {
    case "set":
        guard args.count == 4, let fanID = Int(args[2]), let rpm = Int(args[3]) else { printUsageAndExit() }
        try controller.setFanManual(fanID, rpm: rpm)
        print("ok")

    case "auto":
        guard args.count == 3, let fanID = Int(args[2]) else { printUsageAndExit() }
        try controller.setFanAuto(fanID)
        print("ok")

    case "read":
        guard args.count == 3 else { printUsageAndExit() }
        let value = try controller.readValue(args[2])
        print(value)

    default:
        printUsageAndExit()
    }
} catch {
    FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
    Foundation.exit(1)
}
