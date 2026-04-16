import Foundation

enum BatteryDetailFormatter {
    static func powerStateDescription(for info: BatteryInfo) -> String {
        if info.isCharging {
            return "Charging"
        }
        if info.isPluggedIn {
            return "AC Power"
        }
        return "Battery Power"
    }

    static func sourceDescription(for info: BatteryInfo) -> String? {
        if let source = info.source?.trimmingCharacters(in: .whitespacesAndNewlines), !source.isEmpty {
            switch source {
            case "AC Power":
                return "Power Adapter"
            case "Battery Power":
                return "Internal Battery"
            default:
                return source
            }
        }

        guard info.hasBattery else { return nil }
        return info.isPluggedIn ? "Power Adapter" : "Internal Battery"
    }

    static func runtimeDescription(for info: BatteryInfo) -> String? {
        guard let minutes = info.timeRemainingMinutes, minutes >= 0 else { return nil }
        if minutes == 0 {
            return info.isCharging ? "Finishing soon" : "Less than 1m remaining"
        }

        let formattedDuration = durationDescription(minutes: minutes)
        if info.isCharging {
            return "\(formattedDuration) until full"
        }
        return "\(formattedDuration) remaining"
    }

    static func durationDescription(minutes: Int) -> String {
        let clampedMinutes = max(minutes, 0)
        if clampedMinutes < 60 {
            return "\(clampedMinutes)m"
        }

        let hours = clampedMinutes / 60
        let remainingMinutes = clampedMinutes % 60
        if remainingMinutes == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(remainingMinutes)m"
    }

    static func temperatureDescription(_ temperature: Double?) -> String? {
        guard let temperature else { return nil }
        return String(format: "%.1f °C", temperature)
    }

    static func voltageDescription(_ voltage: Double?) -> String? {
        guard let voltage else { return nil }
        return String(format: "%.2f V", voltage)
    }

    static func amperageDescription(_ amperage: Double?) -> String? {
        guard let amperage else { return nil }
        return String(format: "%.2f A", amperage)
    }
}
