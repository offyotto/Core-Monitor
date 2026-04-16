import Foundation

enum NetworkThroughputFormatter {
    private static let rateUnits = ["B/s", "KB/s", "MB/s", "GB/s", "TB/s"]
    private static let abbreviatedUnits = ["B", "K", "M", "G", "T"]

    static func compactRate(bytesPerSecond: Double) -> String {
        formattedValue(bytesPerSecond, units: rateUnits)
    }

    static func abbreviatedRate(bytesPerSecond: Double) -> String {
        formattedValue(bytesPerSecond, units: abbreviatedUnits)
    }

    private static func formattedValue(_ bytesPerSecond: Double, units: [String]) -> String {
        let normalized = max(abs(bytesPerSecond), 0)
        guard normalized.isFinite else { return "0 \(units[0])" }

        var value = normalized
        var unitIndex = 0
        while value >= 1_000, unitIndex < units.count - 1 {
            value /= 1_000
            unitIndex += 1
        }

        let decimals: Int
        switch value {
        case 0..<10 where unitIndex > 0:
            decimals = 1
        default:
            decimals = 0
        }

        return String(format: "%.\(decimals)f %@", value, units[unitIndex])
    }
}
