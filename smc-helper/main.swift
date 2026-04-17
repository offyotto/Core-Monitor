import Foundation
import IOKit
import Security

// Apple Silicon fan-control mode detection and Ftst unlock behavior are based on
// the MIT-licensed research implementation from agoodkind/macos-smc-fan.

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

private struct SMCControlMetadata {
    let modeKeyTemplate: String
    let hasForceTestKey: Bool
}

private final class SMCController {
    private var connection: io_connect_t = 0
    private var keyInfoCache: [UInt32: SMCKeyData_keyInfo_t] = [:]
    private var detectedModeKeyTemplate: String?
    private var hasForceTestKey: Bool?

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

        detectHardwareCapabilities()
    }

    func close() {
        if connection != 0 {
            IOServiceClose(connection)
            connection = 0
        }
        detectedModeKeyTemplate = nil
        hasForceTestKey = nil
    }

    func setFanManual(_ fanID: Int, rpm: Int) throws {
        let modeKey = try modeKey(for: fanID)
        let targetKey = String(format: "F%dTg", fanID)

        try unlockFansIfNeeded(for: fanID)
        try writeValue(key: modeKey, value: 1)
        try writeValue(key: targetKey, value: rpm)
    }

    func setFanAuto(_ fanID: Int) throws {
        let modeKey = try modeKey(for: fanID)
        let otherFansStillManual = manualFanCount(excluding: fanID)
        try writeValue(key: modeKey, value: 0)
        try? writeValue(key: String(format: "F%dTg", fanID), value: 0)
        if hasForceTest(), otherFansStillManual == 0, isForceTestEnabled() {
            try? writeValue(key: "Ftst", value: 0)
        }
    }

    func controlMetadata() -> SMCControlMetadata {
        detectHardwareCapabilities()
        return SMCControlMetadata(
            modeKeyTemplate: detectedModeKeyTemplate ?? "F%dMd",
            hasForceTestKey: hasForceTestKey == true
        )
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

        guard let parsed = parseSMCBytes(output.bytes, key: key, dataType: keyInfo.dataType, dataSize: keyInfo.dataSize) else {
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

    private func detectHardwareCapabilities() {
        if detectedModeKeyTemplate == nil {
            let lower = String(format: "F%dmd", 0)
            let upper = String(format: "F%dMd", 0)
            if keyExists(lower) {
                detectedModeKeyTemplate = "F%dmd"
            } else if keyExists(upper) {
                detectedModeKeyTemplate = "F%dMd"
            } else {
                detectedModeKeyTemplate = "F%dMd"
            }
        }

        if hasForceTestKey == nil {
            hasForceTestKey = keyExists("Ftst")
        }
    }

    private func keyExists(_ key: String) -> Bool {
        let keyCode = fourCharCodeFrom(key)
        return (try? getKeyInfo(keyCode)) != nil
    }

    private func modeKey(for fanID: Int) throws -> String {
        detectHardwareCapabilities()
        let template = detectedModeKeyTemplate ?? "F%dMd"
        return String(format: template, fanID)
    }

    private func hasForceTest() -> Bool {
        detectHardwareCapabilities()
        return hasForceTestKey == true
    }

    private func isForceTestEnabled() -> Bool {
        guard hasForceTest() else { return false }
        guard let value = try? readValue("Ftst") else { return false }
        return value.rounded() != 0
    }

    private func manualFanCount(excluding excludedFanID: Int) -> Int {
        let fanCount = resolvedFanCount()
        guard fanCount > 0 else { return 0 }

        var manualCount = 0
        for fanID in 0..<fanCount where fanID != excludedFanID {
            guard let modeKey = try? modeKey(for: fanID),
                  let value = try? readValue(modeKey) else { continue }
            if Int(value.rounded()) == 1 {
                manualCount += 1
            }
        }

        return manualCount
    }

    private func resolvedFanCount() -> Int {
        if let directCount = try? readValue("FNum"),
           Int(directCount.rounded()) > 0 {
            return Int(directCount.rounded())
        }

        for fanID in 0..<12 {
            let actualKey = String(format: "F%dAc", fanID)
            let minKey = String(format: "F%dMn", fanID)
            let maxKey = String(format: "F%dMx", fanID)
            if keyExists(actualKey) || keyExists(minKey) || keyExists(maxKey) {
                return fanID + 1
            }
        }

        return 0
    }

    private func unlockFansIfNeeded(for fanID: Int) throws {
        if hasForceTest() {
            try? writeValue(key: "Ftst", value: 1)
            Thread.sleep(forTimeInterval: 0.5)
        }

        let modeKey = try modeKey(for: fanID)
        var lastError: Error?
        let deadline = Date().addingTimeInterval(5.0)
        while Date() < deadline {
            do {
                try writeValue(key: modeKey, value: 1)
                return
            } catch {
                lastError = error
                Thread.sleep(forTimeInterval: 0.1)
            }
        }

        if let lastError {
            throw lastError
        }
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

    private func parseSMCBytes(_ bytes: SMCBytes, key: String? = nil, dataType: UInt32, dataSize: UInt32) -> Double? {
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
            return decodeSMCFloat(raw, key: key)
        }

        return nil
    }

    private func decodeSMCFloat(_ raw: [UInt8], key: String?) -> Double? {
        guard raw.count >= 4 else { return nil }

        let bigEndianBits = (UInt32(raw[0]) << 24)
            | (UInt32(raw[1]) << 16)
            | (UInt32(raw[2]) << 8)
            | UInt32(raw[3])
        let littleEndianBits = (UInt32(raw[3]) << 24)
            | (UInt32(raw[2]) << 16)
            | (UInt32(raw[1]) << 8)
            | UInt32(raw[0])

        let bigEndianValue = Double(Float(bitPattern: bigEndianBits))
        let littleEndianValue = Double(Float(bitPattern: littleEndianBits))

        func isValid(_ value: Double) -> Bool {
            value.isFinite && value.magnitude < 100_000
        }

        let bigEndianValid = isValid(bigEndianValue)
        let littleEndianValid = isValid(littleEndianValue)

        switch (bigEndianValid, littleEndianValid) {
        case (true, false):
            return bigEndianValue
        case (false, true):
            return littleEndianValue
        case (false, false):
            return nil
        case (true, true):
            break
        }

        if let preferredRange = preferredFloatRange(for: key) {
            let bigEndianPreferred = preferredRange.contains(bigEndianValue)
            let littleEndianPreferred = preferredRange.contains(littleEndianValue)
            if bigEndianPreferred != littleEndianPreferred {
                return bigEndianPreferred ? bigEndianValue : littleEndianValue
            }
        }

        func isSubnormalLike(_ value: Double) -> Bool {
            value != 0 && value.magnitude < 1e-12
        }

        let bigEndianSubnormal = isSubnormalLike(bigEndianValue)
        let littleEndianSubnormal = isSubnormalLike(littleEndianValue)
        if bigEndianSubnormal != littleEndianSubnormal {
            return bigEndianSubnormal ? littleEndianValue : bigEndianValue
        }

        func isCommonSensorMagnitude(_ value: Double) -> Bool {
            value == 0 || (0.01...20_000).contains(value.magnitude)
        }

        let bigEndianCommon = isCommonSensorMagnitude(bigEndianValue)
        let littleEndianCommon = isCommonSensorMagnitude(littleEndianValue)
        if bigEndianCommon != littleEndianCommon {
            return bigEndianCommon ? bigEndianValue : littleEndianValue
        }

        return bigEndianValue.magnitude >= littleEndianValue.magnitude ? bigEndianValue : littleEndianValue
    }

    private func preferredFloatRange(for key: String?) -> ClosedRange<Double>? {
        guard let key, key.count == 4 else { return nil }

        if key.hasPrefix("F"), ["Ac", "Mn", "Mx", "Tg"].contains(String(key.suffix(2))) {
            return 100...10_000
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

private func validatedFanID(_ rawValue: String) throws -> Int {
    guard let fanID = Int(rawValue) else {
        throw HelperError("Fan ID must be between 0 and 11")
    }
    return try validatedFanID(fanID)
}

private func validatedFanID(_ fanID: Int) throws -> Int {
    guard (0..<12).contains(fanID) else {
        throw HelperError("Fan ID must be between 0 and 11")
    }
    return fanID
}

private func validatedRPM(_ rawValue: String) throws -> Int {
    guard let rpm = Int(rawValue) else {
        throw HelperError("RPM must be between 500 and 10000")
    }
    return try validatedRPM(rpm)
}

private func validatedRPM(_ rpm: Int) throws -> Int {
    guard (500...10_000).contains(rpm) else {
        throw HelperError("RPM must be between 500 and 10000")
    }
    return rpm
}

private func validatedSMCKey(_ rawValue: String) throws -> String {
    let bytes = Array(rawValue.utf8)
    guard bytes.count == 4, bytes.allSatisfy({ (0x20...0x7E).contains($0) }) else {
        throw HelperError("SMC key must be exactly 4 printable ASCII characters")
    }
    return rawValue
}

private final class HelperClientValidator {
    private let requirementString: String
    private let requirement: SecRequirement

    init?(bundle: Bundle = .main) {
        guard let candidates = bundle.object(forInfoDictionaryKey: "SMAuthorizedClients") as? [String],
              let firstRequirement = candidates.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            return nil
        }

        var requirementRef: SecRequirement?
        let status = SecRequirementCreateWithString(firstRequirement as CFString, SecCSFlags(), &requirementRef)
        guard status == errSecSuccess, let requirementRef else {
            return nil
        }

        self.requirementString = firstRequirement
        self.requirement = requirementRef
    }

    func authorize(_ connection: NSXPCConnection) -> Bool {
        guard validateProcess(pid: connection.processIdentifier) else {
            return false
        }

        if #available(macOS 13.0, *) {
            connection.setCodeSigningRequirement(requirementString)
        }

        return true
    }

    private func validateProcess(pid: pid_t) -> Bool {
        let attributes = [kSecGuestAttributePid as String: NSNumber(value: pid)] as CFDictionary
        var guestCode: SecCode?
        let copyStatus = SecCodeCopyGuestWithAttributes(nil, attributes, SecCSFlags(), &guestCode)
        guard copyStatus == errSecSuccess, let guestCode else {
            return false
        }

        return SecCodeCheckValidity(guestCode, SecCSFlags(), requirement) == errSecSuccess
    }
}

private let helperMachServiceName = Bundle.main.bundleIdentifier ?? "ventaphobia.smc-helper"

private final class SMCHelperXPCService: NSObject, NSXPCListenerDelegate, SMCHelperXPCProtocol {
    private let controller = SMCController()
    private let clientValidator = HelperClientValidator()

    override init() {
        super.init()
        try? controller.open()
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        guard let clientValidator, clientValidator.authorize(newConnection) else {
            NSLog("smc-helper rejected unauthorized XPC client from pid %d", newConnection.processIdentifier)
            return false
        }

        newConnection.exportedInterface = NSXPCInterface(with: SMCHelperXPCProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }

    func setFanManual(_ fanID: Int, rpm: Int, withReply reply: @escaping (NSString?) -> Void) {
        do {
            let validatedFanID = try validatedFanID(fanID)
            let validatedRPM = try validatedRPM(rpm)
            try controller.open()
            try controller.setFanManual(validatedFanID, rpm: validatedRPM)
            reply(nil)
        } catch {
            reply(error.localizedDescription as NSString)
        }
    }

    func setFanAuto(_ fanID: Int, withReply reply: @escaping (NSString?) -> Void) {
        do {
            let validatedFanID = try validatedFanID(fanID)
            try controller.open()
            try controller.setFanAuto(validatedFanID)
            reply(nil)
        } catch {
            reply(error.localizedDescription as NSString)
        }
    }

    func readValue(_ key: String, withReply reply: @escaping (NSNumber?, NSString?) -> Void) {
        do {
            let validatedKey = try validatedSMCKey(key)
            try controller.open()
            let value = try controller.readValue(validatedKey)
            reply(NSNumber(value: value), nil)
        } catch {
            reply(nil, error.localizedDescription as NSString)
        }
    }

    func readControlMetadata(withReply reply: @escaping (NSString?, NSNumber?, NSString?) -> Void) {
        do {
            try controller.open()
            let metadata = controller.controlMetadata()
            reply(
                metadata.modeKeyTemplate as NSString,
                NSNumber(value: metadata.hasForceTestKey),
                nil
            )
        } catch {
            reply(nil, nil, error.localizedDescription as NSString)
        }
    }
}

private func runCommandLineMode(arguments: [String]) -> Never {
    guard arguments.count >= 2 else { printUsageAndExit() }

    let command = arguments[1]
    let controller = SMCController()

    do {
        try controller.open()

        switch command {
        case "set":
            guard arguments.count == 4 else { printUsageAndExit() }
            let fanID = try validatedFanID(arguments[2])
            let rpm = try validatedRPM(arguments[3])
            try controller.setFanManual(fanID, rpm: rpm)
            print("ok")

        case "auto":
            guard arguments.count == 3 else { printUsageAndExit() }
            let fanID = try validatedFanID(arguments[2])
            try controller.setFanAuto(fanID)
            print("ok")

        case "read":
            guard arguments.count == 3 else { printUsageAndExit() }
            let key = try validatedSMCKey(arguments[2])
            let value = try controller.readValue(key)
            print(value)

        default:
            printUsageAndExit()
        }
    } catch {
        FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
        Foundation.exit(1)
    }

    Foundation.exit(0)
}

private func runXPCServiceMode() -> Never {
    let service = SMCHelperXPCService()
    let listener = NSXPCListener(machServiceName: helperMachServiceName)
    listener.delegate = service
    listener.resume()
    RunLoop.current.run()
    Foundation.exit(0)
}

let args = CommandLine.arguments
if args.count > 1 {
    runCommandLineMode(arguments: args)
} else {
    runXPCServiceMode()
}
