import Foundation

enum CoreMonitorPlatformCopy {
    static func welcomeIntroSubheadline(isAppleSilicon: Bool = SystemMonitor.isAppleSilicon) -> String {
        isAppleSilicon ? "Your M-series Mac, fully visible." : "Your Mac, fully visible."
    }

    static func welcomeIntroBody(isAppleSilicon: Bool = SystemMonitor.isAppleSilicon) -> String {
        if isAppleSilicon {
            return "Core Monitor gives you deep, real-time insight into your Apple Silicon Mac: thermals, memory pressure, fan behavior, power draw, and a customizable Touch Bar surface."
        }

        return "Core Monitor gives you deep, real-time insight into your Mac: thermals, memory pressure, fan behavior, power draw, and a customizable Touch Bar surface."
    }

    static func thermalMetricsBullet(isAppleSilicon: Bool = SystemMonitor.isAppleSilicon) -> String {
        isAppleSilicon
            ? "P-core and E-core usage, plus CPU temperature"
            : "CPU usage and temperature"
    }

    static func thermalStatusDetail(isAppleSilicon: Bool = SystemMonitor.isAppleSilicon) -> String {
        if isAppleSilicon {
            return "macOS thermal pressure on Apple Silicon."
        }

        return "macOS thermal pressure reported by the system."
    }
}
