import AppKit
import Combine
import Foundation

struct HardwareRescueSnapshot {
    let sampledAt: Date
    let usbControllers: [USBPortControllerReport]
    let usbErrorMessage: String?
    let smartctlPath: String?
    let storageHealth: StorageHealthReport
    let usbcfwflasherAvailable: Bool

    var usbStatusTitle: String {
        guard usbControllers.isEmpty == false else { return "Unavailable" }
        if usbControllers.contains(where: { $0.severity == .attention }) {
            return "Attention"
        }
        if usbControllers.contains(where: { $0.severity == .watch }) {
            return "Watch"
        }
        return "Healthy"
    }

    var usbStatusDetail: String {
        guard usbControllers.isEmpty == false else {
            return usbErrorMessage ?? "Core Monitor could not read AppleSmartBattery PortControllerInfo."
        }

        let bootSuspects = usbControllers.filter { $0.firmwareVersionRaw == 0 }.count
        if bootSuspects > 0 {
            return "\(bootSuspects) controller(s) are not reporting APP firmware."
        }
        return "All visible USB-C controllers report loaded firmware and zero I2C errors."
    }

    var reportText: String {
        var lines: [String] = []
        lines.append("Core Monitor advanced hardware report")
        lines.append("Sampled: \(HardwareRescueFormatters.date(sampledAt))")
        lines.append("USB-C flasher: \(usbcfwflasherAvailable ? "available at /usr/bin/usbcfwflasher" : "not found")")
        lines.append("")
        lines.append("USB-C controllers")
        if usbControllers.isEmpty {
            lines.append("- unavailable: \(usbErrorMessage ?? "PortControllerInfo missing")")
        } else {
            for controller in usbControllers {
                lines.append("- \(controller.displayName): \(controller.stateTitle), firmware \(controller.firmwareVersionDescription), I2C errors \(controller.i2cErrorCountDescription), boot flags \(controller.bootFlagsDescription)")
            }
        }
        lines.append("")
        lines.append("Storage")
        lines.append("- SMART: \(storageHealth.statusTitle)")
        if let model = storageHealth.model {
            lines.append("- Model: \(model)")
        }
        if let percentageUsed = storageHealth.percentageUsed {
            lines.append("- Percentage used: \(percentageUsed)%")
        }
        if let dataWritten = storageHealth.dataUnitsWritten {
            lines.append("- Data written: \(dataWritten)")
        }
        if let unsafeShutdowns = storageHealth.unsafeShutdowns {
            lines.append("- Unsafe shutdowns: \(unsafeShutdowns)")
        }
        if let mediaErrors = storageHealth.mediaErrors {
            lines.append("- Media/data errors: \(mediaErrors)")
        }
        if let reason = storageHealth.unavailableReason {
            lines.append("- Unavailable: \(reason)")
        }
        return lines.joined(separator: "\n")
    }
}

struct USBPortControllerReport: Identifiable, Equatable {
    enum Severity {
        case ok
        case watch
        case attention
    }

    let slot: Int
    let ridHint: Int?
    let addressHint: String?
    let firmwareVersionRaw: Int?
    let i2cErrorCount: Int?
    let bootFlags: Int?
    let stuckCommandCount: Int?
    let surpriseNackCount: Int?
    let wakeFailCount: Int?
    let attachCount: Int?
    let detachCount: Int?
    let maxPowerMilliwatts: Int?
    let powerState: Int?
    let pdState: Int?

    var id: Int { slot }

    var displayName: String {
        var parts = ["Controller \(slot + 1)"]
        if let ridHint {
            parts.append("RID \(ridHint)")
        }
        if let addressHint {
            parts.append(addressHint)
        }
        return parts.joined(separator: " / ")
    }

    var firmwareVersionDescription: String {
        guard let raw = firmwareVersionRaw else { return "Unknown" }
        guard raw > 0 else { return "0 / not loaded" }
        return Self.displayVersion(fromRawValue: raw)
    }

    var i2cErrorCountDescription: String {
        guard let i2cErrorCount else { return "Unknown" }
        return String(i2cErrorCount)
    }

    var bootFlagsDescription: String {
        guard let bootFlags else { return "Unknown" }
        return String(format: "0x%X", bootFlags)
    }

    var maxPowerDescription: String {
        guard let maxPowerMilliwatts, maxPowerMilliwatts > 0 else { return "No active contract" }
        return String(format: "%.1f W", Double(maxPowerMilliwatts) / 1000.0)
    }

    var stateTitle: String {
        switch severity {
        case .ok:
            return "APP"
        case .watch:
            return "Watch"
        case .attention:
            return "BOOT suspected"
        }
    }

    var stateDetail: String {
        if firmwareVersionRaw == 0 {
            return "The controller is visible but is not reporting loaded APP firmware."
        }
        if (i2cErrorCount ?? 0) > 0 {
            return "The controller reports I2C transaction errors. A rising count can point to a stuck controller or bus problem."
        }
        if (stuckCommandCount ?? 0) > 0 || (surpriseNackCount ?? 0) > 0 || (wakeFailCount ?? 0) > 0 {
            return "The controller is running firmware, but one of the reliability counters is non-zero."
        }
        return "Firmware is loaded and the exposed error counters are clear."
    }

    var severity: Severity {
        if firmwareVersionRaw == 0 {
            return .attention
        }
        if (i2cErrorCount ?? 0) > 0 ||
            (stuckCommandCount ?? 0) > 0 ||
            (surpriseNackCount ?? 0) > 0 ||
            (wakeFailCount ?? 0) > 0 ||
            (bootFlags ?? 0) != 0 {
            return .watch
        }
        return .ok
    }

    static func displayVersion(fromRawValue rawValue: Int) -> String {
        let hex = String(format: "%08X", rawValue)
        let characters = Array(hex)
        guard characters.count == 8 else {
            return String(format: "0x%X", rawValue)
        }

        let major = String(characters[2])
        let minor = String(characters[3...5])
        let patch = String(characters[6])
        return "\(major).\(minor).\(patch)"
    }
}

struct StorageHealthReport: Equatable {
    let model: String?
    let serial: String?
    let firmware: String?
    let healthPassed: Bool?
    let criticalWarning: String?
    let temperature: String?
    let availableSpare: String?
    let percentageUsed: Int?
    let dataUnitsRead: String?
    let dataUnitsWritten: String?
    let powerCycles: Int?
    let powerOnHours: Int?
    let unsafeShutdowns: Int?
    let mediaErrors: Int?
    let errorLogEntries: Int?
    let unavailableReason: String?

    static func unavailable(_ reason: String) -> StorageHealthReport {
        StorageHealthReport(
            model: nil,
            serial: nil,
            firmware: nil,
            healthPassed: nil,
            criticalWarning: nil,
            temperature: nil,
            availableSpare: nil,
            percentageUsed: nil,
            dataUnitsRead: nil,
            dataUnitsWritten: nil,
            powerCycles: nil,
            powerOnHours: nil,
            unsafeShutdowns: nil,
            mediaErrors: nil,
            errorLogEntries: nil,
            unavailableReason: reason
        )
    }

    var statusTitle: String {
        if let healthPassed {
            return healthPassed ? "Passed" : "Warning"
        }
        return "Unavailable"
    }

    var statusDetail: String {
        if let unavailableReason {
            return unavailableReason
        }
        var parts: [String] = []
        if let percentageUsed {
            parts.append("\(percentageUsed)% used")
        }
        if let temperature {
            parts.append(temperature)
        }
        if let mediaErrors {
            parts.append("\(mediaErrors) media errors")
        }
        return parts.isEmpty ? "SMART health page parsed successfully." : parts.joined(separator: " / ")
    }
}

@MainActor
final class HardwareRescueViewModel: ObservableObject {
    @Published private(set) var snapshot: HardwareRescueSnapshot?
    @Published private(set) var isRefreshing = false
    @Published private(set) var pasteboardMessage: String?

    func refresh() {
        isRefreshing = true
        pasteboardMessage = nil
        snapshot = HardwareRescueDiagnostics.collect()
        isRefreshing = false
    }

    func copyReport() {
        guard let snapshot else { return }
        copy(snapshot.reportText, message: "Copied report")
    }

    func copyDiagnosisCommands() {
        copy(Self.diagnosisCommands, message: "Copied commands")
    }

    func copyRecoveryTemplate() {
        copy(Self.recoveryCommandTemplate, message: "Copied template")
    }

    private func copy(_ text: String, message: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        pasteboardMessage = message
    }

    static let diagnosisCommands = """
    /usr/bin/usbcfwflasher --verbose
    ioreg -rw0 -c AppleSmartBattery | grep PortControllerInfo
    /usr/local/bin/smartctl -a /dev/disk0
    """

    static let recoveryCommandTemplate = """
    # Use only when a USB-C controller is stuck in BOOT / firmware 0.
    # Replace <RID> and the firmware path with the exact Apple firmware for that controller.
    sudo /usr/bin/usbcfwflasher --rid=<RID> --flash="/path/to/matching-Apple-USB-C-firmware.bin" --reset --noretries
    """
}

enum HardwareRescueDiagnostics {
    static func collect(now: Date = Date()) -> HardwareRescueSnapshot {
        let ioregResult = HardwareCommandRunner.run("/usr/sbin/ioreg", arguments: ["-rw0", "-c", "AppleSmartBattery"])
        let controllers = HardwareRescueTextParser.parsePortControllers(from: ioregResult.combinedOutput)
        let usbError: String?
        if controllers.isEmpty {
            usbError = ioregResult.exitCode == 0
                ? "PortControllerInfo was not present in AppleSmartBattery."
                : ioregResult.trimmedCombinedOutput
        } else {
            usbError = nil
        }

        let smartctlPath = HardwareCommandRunner.firstExecutablePath(in: [
            "/usr/local/bin/smartctl",
            "/usr/local/sbin/smartctl",
            "/opt/homebrew/bin/smartctl",
            "/opt/homebrew/sbin/smartctl",
        ])

        let storageHealth: StorageHealthReport
        if let smartctlPath {
            let smartResult = HardwareCommandRunner.run(smartctlPath, arguments: ["-a", "/dev/disk0"])
            storageHealth = HardwareRescueTextParser.parseStorageHealth(from: smartResult.combinedOutput)
        } else {
            storageHealth = .unavailable("Install smartmontools to show exact NVMe SMART health.")
        }

        return HardwareRescueSnapshot(
            sampledAt: now,
            usbControllers: controllers,
            usbErrorMessage: usbError,
            smartctlPath: smartctlPath,
            storageHealth: storageHealth,
            usbcfwflasherAvailable: FileManager.default.isExecutableFile(atPath: "/usr/bin/usbcfwflasher")
        )
    }
}

enum HardwareCommandRunner {
    struct Result {
        let exitCode: Int32
        let stdout: String
        let stderr: String

        var combinedOutput: String {
            [stdout, stderr]
                .filter { $0.isEmpty == false }
                .joined(separator: "\n")
        }

        var trimmedCombinedOutput: String {
            combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    static func firstExecutablePath(in candidates: [String]) -> String? {
        candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static func run(_ executablePath: String, arguments: [String]) -> Result {
        guard FileManager.default.isExecutableFile(atPath: executablePath) else {
            return Result(exitCode: 127, stdout: "", stderr: "\(executablePath) is not executable.")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.environment = [
            "PATH": "/usr/local/bin:/usr/local/sbin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin",
        ]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return Result(exitCode: 126, stdout: "", stderr: error.localizedDescription)
        }

        return Result(
            exitCode: process.terminationStatus,
            stdout: String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "",
            stderr: String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        )
    }
}

enum HardwareRescueTextParser {
    private static let ridHints = [0, 1, 2, 5]
    private static let addressHints = ["0x38", "0x3f", "0x3b", "0x3a"]

    static func parsePortControllers(from text: String) -> [USBPortControllerReport] {
        guard let line = text
            .components(separatedBy: .newlines)
            .first(where: { $0.contains("\"PortControllerInfo\"") }) else {
            return []
        }

        guard let prefixRange = line.range(of: "\"PortControllerInfo\" = (") else {
            return []
        }

        var body = String(line[prefixRange.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if body.hasSuffix(")") {
            body.removeLast()
        }

        guard body.isEmpty == false else { return [] }

        return body
            .components(separatedBy: "},{")
            .enumerated()
            .map { index, rawEntry in
                var entry = rawEntry
                if entry.hasPrefix("{") == false {
                    entry = "{\(entry)"
                }
                if entry.hasSuffix("}") == false {
                    entry = "\(entry)}"
                }

                return USBPortControllerReport(
                    slot: index,
                    ridHint: ridHints.indices.contains(index) ? ridHints[index] : nil,
                    addressHint: addressHints.indices.contains(index) ? addressHints[index] : nil,
                    firmwareVersionRaw: integerValue(for: "PortControllerFwVersion", in: entry),
                    i2cErrorCount: integerValue(for: "PortControllerI2cErrCount", in: entry),
                    bootFlags: integerValue(for: "PortControllerBootFlags", in: entry),
                    stuckCommandCount: integerValue(for: "PortControllerStuckCmdCount", in: entry),
                    surpriseNackCount: integerValue(for: "PortControllerSurpriseNackCount", in: entry),
                    wakeFailCount: integerValue(for: "PortControllerWakeFailCount", in: entry),
                    attachCount: integerValue(for: "PortControllerAttachCount", in: entry),
                    detachCount: integerValue(for: "PortControllerDetachCount", in: entry),
                    maxPowerMilliwatts: integerValue(for: "PortControllerMaxPower", in: entry),
                    powerState: integerValue(for: "PortControllerPowerState", in: entry),
                    pdState: integerValue(for: "PortControllerPDst", in: entry)
                )
            }
    }

    static func parseStorageHealth(from text: String) -> StorageHealthReport {
        let health = value(forLineStartingWith: "SMART overall-health self-assessment test result:", in: text)
        let mediaErrors = integerLineValue("Media and Data Integrity Errors:", in: text)
        let errorEntries = integerLineValue("Error Information Log Entries:", in: text)

        return StorageHealthReport(
            model: value(forLineStartingWith: "Model Number:", in: text),
            serial: value(forLineStartingWith: "Serial Number:", in: text),
            firmware: value(forLineStartingWith: "Firmware Version:", in: text),
            healthPassed: health.map { $0.uppercased().contains("PASSED") },
            criticalWarning: value(forLineStartingWith: "Critical Warning:", in: text),
            temperature: value(forLineStartingWith: "Temperature:", in: text),
            availableSpare: value(forLineStartingWith: "Available Spare:", in: text),
            percentageUsed: percentLineValue("Percentage Used:", in: text),
            dataUnitsRead: value(forLineStartingWith: "Data Units Read:", in: text),
            dataUnitsWritten: value(forLineStartingWith: "Data Units Written:", in: text),
            powerCycles: integerLineValue("Power Cycles:", in: text),
            powerOnHours: integerLineValue("Power On Hours:", in: text),
            unsafeShutdowns: integerLineValue("Unsafe Shutdowns:", in: text),
            mediaErrors: mediaErrors,
            errorLogEntries: errorEntries,
            unavailableReason: health == nil ? "smartctl output did not include an NVMe SMART health section." : nil
        )
    }

    private static func integerValue(for key: String, in entry: String) -> Int? {
        guard let keyRange = entry.range(of: "\"\(key)\"=") else { return nil }
        let remainder = entry[keyRange.upperBound...]
        let digits = remainder.prefix { $0.isNumber }
        return Int(digits)
    }

    private static func value(forLineStartingWith prefix: String, in text: String) -> String? {
        text
            .components(separatedBy: .newlines)
            .first { $0.trimmingCharacters(in: .whitespaces).hasPrefix(prefix) }
            .flatMap { line in
                guard let range = line.range(of: prefix) else { return nil }
                let value = line[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                return value.isEmpty ? nil : value
            }
    }

    private static func integerLineValue(_ prefix: String, in text: String) -> Int? {
        guard let value = value(forLineStartingWith: prefix, in: text) else { return nil }
        let digits = value.filter { $0.isNumber }
        return Int(digits)
    }

    private static func percentLineValue(_ prefix: String, in text: String) -> Int? {
        guard let value = value(forLineStartingWith: prefix, in: text) else { return nil }
        let digits = value.prefix { $0.isNumber }
        return Int(digits)
    }
}

enum HardwareRescueFormatters {
    static func date(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .standard)
    }
}
