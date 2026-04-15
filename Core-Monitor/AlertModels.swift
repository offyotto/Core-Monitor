import Foundation

enum AlertCategory: String, Codable, CaseIterable, Identifiable {
    case thermal
    case performance
    case fanSafety
    case battery
    case services

    nonisolated var id: String { rawValue }

    nonisolated var title: String {
        switch self {
        case .thermal: return "Thermal"
        case .performance: return "Performance"
        case .fanSafety: return "Fan Safety"
        case .battery: return "Battery"
        case .services: return "Services"
        }
    }
}

enum AlertSeverity: Int, Codable, CaseIterable, Comparable, Identifiable {
    case none = 0
    case info = 1
    case warning = 2
    case critical = 3

    nonisolated var id: Int { rawValue }

    nonisolated static func < (lhs: AlertSeverity, rhs: AlertSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    nonisolated var title: String {
        switch self {
        case .none: return "Stable"
        case .info: return "Info"
        case .warning: return "Warning"
        case .critical: return "Critical"
        }
    }
}

enum AlertRuleKind: String, Codable, CaseIterable, Identifiable {
    case cpuTemperature
    case gpuTemperature
    case overallThermalState
    case cpuUsage
    case memoryPressure
    case swapUsage
    case fanTooLowUnderHeat
    case batteryTemperature
    case batteryHealth
    case lowBatteryDischarging
    case smcUnavailable
    case helperUnavailable

    nonisolated var id: String { rawValue }

    nonisolated var category: AlertCategory {
        switch self {
        case .cpuTemperature, .gpuTemperature, .overallThermalState:
            return .thermal
        case .cpuUsage, .memoryPressure, .swapUsage:
            return .performance
        case .fanTooLowUnderHeat:
            return .fanSafety
        case .batteryTemperature, .batteryHealth, .lowBatteryDischarging:
            return .battery
        case .smcUnavailable, .helperUnavailable:
            return .services
        }
    }

    nonisolated var title: String {
        switch self {
        case .cpuTemperature: return "CPU Temperature"
        case .gpuTemperature: return "GPU Temperature"
        case .overallThermalState: return "Overall Thermal"
        case .cpuUsage: return "CPU Usage"
        case .memoryPressure: return "Memory Pressure"
        case .swapUsage: return "Swap Usage"
        case .fanTooLowUnderHeat: return "Fan Stalled / Too Low"
        case .batteryTemperature: return "Battery Temperature"
        case .batteryHealth: return "Battery Health"
        case .lowBatteryDischarging: return "Low Battery"
        case .smcUnavailable: return "SMC Access"
        case .helperUnavailable: return "Helper Availability"
        }
    }

    nonisolated var subtitle: String {
        switch self {
        case .cpuTemperature: return "Protect against sustained CPU heat."
        case .gpuTemperature: return "Protect against sustained GPU heat."
        case .overallThermalState: return "Uses macOS thermal pressure, not a guessed sensor."
        case .cpuUsage: return "Flags sustained CPU saturation with top-app context."
        case .memoryPressure: return "Flags yellow and red memory pressure."
        case .swapUsage: return "Tracks swap growth that typically hurts responsiveness."
        case .fanTooLowUnderHeat: return "Detects stalled fans or fan RPM that stays too low while hot."
        case .batteryTemperature: return "Warn when pack temperature rises above safe comfort."
        case .batteryHealth: return "Warn when reported health falls below target."
        case .lowBatteryDischarging: return "Warn on low charge while unplugged."
        case .smcUnavailable: return "Warn when AppleSMC cannot be opened."
        case .helperUnavailable: return "Warn when privileged fan control cannot be used."
        }
    }

    nonisolated var systemImageName: String {
        switch self {
        case .cpuTemperature, .gpuTemperature, .batteryTemperature:
            return "thermometer.medium"
        case .overallThermalState:
            return "waveform.path.ecg"
        case .cpuUsage:
            return "cpu"
        case .memoryPressure:
            return "memorychip"
        case .swapUsage:
            return "arrow.left.arrow.right.square"
        case .fanTooLowUnderHeat:
            return "fanblades.fill"
        case .batteryHealth, .lowBatteryDischarging:
            return "battery.75"
        case .smcUnavailable:
            return "cpu.fill"
        case .helperUnavailable:
            return "lock.shield"
        }
    }

    nonisolated var unitLabel: String? {
        switch self {
        case .cpuTemperature, .gpuTemperature, .batteryTemperature:
            return "°C"
        case .cpuUsage:
            return "%"
        case .swapUsage:
            return "GB"
        case .batteryHealth, .lowBatteryDischarging:
            return "%"
        default:
            return nil
        }
    }

    nonisolated var supportsThresholdEditing: Bool {
        switch self {
        case .cpuTemperature, .gpuTemperature, .cpuUsage, .swapUsage, .batteryTemperature, .batteryHealth, .lowBatteryDischarging:
            return true
        default:
            return false
        }
    }

    nonisolated var supportsDesktopNotifications: Bool {
        switch self {
        case .batteryHealth:
            return false
        default:
            return true
        }
    }
}

struct AlertThreshold: Codable, Equatable {
    var warning: Double?
    var critical: Double?
    var hysteresis: Double

    nonisolated static let disabled = AlertThreshold(warning: nil, critical: nil, hysteresis: 0)
}

struct AlertRuleConfig: Codable, Equatable, Identifiable {
    let kind: AlertRuleKind
    var isEnabled: Bool
    var threshold: AlertThreshold
    var cooldownMinutes: Int
    var debounceSamples: Int
    var desktopNotificationsEnabled: Bool

    nonisolated var id: String { kind.rawValue }
}

enum AlertPreset: String, Codable, CaseIterable, Identifiable {
    case `default`
    case quiet
    case performance
    case aggressiveThermalSafety

    nonisolated var id: String { rawValue }

    nonisolated var title: String {
        switch self {
        case .default: return "Default"
        case .quiet: return "Quiet"
        case .performance: return "Performance"
        case .aggressiveThermalSafety: return "Aggressive Thermal Safety"
        }
    }

    nonisolated var subtitle: String {
        switch self {
        case .default: return "Balanced thresholds with critical desktop alerts."
        case .quiet: return "Fewer desktop notifications and longer repeat windows."
        case .performance: return "Earlier CPU, memory, and swap warnings."
        case .aggressiveThermalSafety: return "Earlier heat and fan warnings."
        }
    }
}

enum AlertNotificationPolicy: String, Codable, CaseIterable, Identifiable {
    case inAppOnly
    case criticalOnly
    case warningsAndCritical

    nonisolated var id: String { rawValue }

    nonisolated var title: String {
        switch self {
        case .inAppOnly: return "In-App Only"
        case .criticalOnly: return "Critical Only"
        case .warningsAndCritical: return "Warnings + Critical"
        }
    }
}

struct AlertEvent: Codable, Equatable, Identifiable {
    let id: UUID
    let kind: AlertRuleKind
    let severity: AlertSeverity
    let title: String
    let message: String
    let context: String?
    let timestamp: Date
    let isRecovery: Bool
}

struct AlertRuleRuntime: Codable, Equatable {
    let kind: AlertRuleKind
    var activeSeverity: AlertSeverity
    var pendingSeverity: AlertSeverity
    var pendingSampleCount: Int
    var lastEventDate: Date?
    var lastNotificationDate: Date?
    var snoozedUntil: Date?
    var dismissUntilRecovery: Bool
    var lastMetricValue: Double?

    nonisolated static func initial(for kind: AlertRuleKind) -> AlertRuleRuntime {
        AlertRuleRuntime(
            kind: kind,
            activeSeverity: .none,
            pendingSeverity: .none,
            pendingSampleCount: 0,
            lastEventDate: nil,
            lastNotificationDate: nil,
            snoozedUntil: nil,
            dismissUntilRecovery: false,
            lastMetricValue: nil
        )
    }
}

struct AlertActiveState: Equatable, Identifiable {
    let kind: AlertRuleKind
    let severity: AlertSeverity
    let title: String
    let message: String
    let context: String?
    let startedAt: Date
    let updatedAt: Date
    let metricValue: Double?

    nonisolated var id: String { kind.rawValue }
}

struct AlertStore: Codable {
    var selectedPreset: AlertPreset
    var notificationPolicy: AlertNotificationPolicy
    var desktopNotificationsEnabled: Bool
    var notificationsMutedUntil: Date?
    var ruleConfigs: [AlertRuleConfig]
    var runtimes: [AlertRuleRuntime]
    var history: [AlertEvent]

    nonisolated static let historyLimit = 120

    nonisolated static func `default`() -> AlertStore {
        let configs = AlertPreset.default.configurations()
        return AlertStore(
            selectedPreset: .default,
            notificationPolicy: .criticalOnly,
            desktopNotificationsEnabled: true,
            notificationsMutedUntil: nil,
            ruleConfigs: configs,
            runtimes: AlertRuleKind.allCases.map { AlertRuleRuntime.initial(for: $0) },
            history: []
        )
    }
}

extension AlertPreset {
    nonisolated func configurations() -> [AlertRuleConfig] {
        AlertRuleKind.allCases.map { kind in
            switch (self, kind) {
            case (.default, .cpuTemperature):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 85, critical: 95, hysteresis: 3), cooldownMinutes: 20, debounceSamples: 2, desktopNotificationsEnabled: true)
            case (.default, .gpuTemperature):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 82, critical: 92, hysteresis: 3), cooldownMinutes: 20, debounceSamples: 2, desktopNotificationsEnabled: true)
            case (.default, .overallThermalState):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 2, critical: 3, hysteresis: 0), cooldownMinutes: 15, debounceSamples: 1, desktopNotificationsEnabled: true)
            case (.default, .cpuUsage):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 88, critical: 98, hysteresis: 8), cooldownMinutes: 20, debounceSamples: 3, desktopNotificationsEnabled: true)
            case (.default, .memoryPressure):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 1, critical: 2, hysteresis: 0), cooldownMinutes: 15, debounceSamples: 2, desktopNotificationsEnabled: true)
            case (.default, .swapUsage):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 4, critical: 10, hysteresis: 1), cooldownMinutes: 20, debounceSamples: 2, desktopNotificationsEnabled: true)
            case (.default, .fanTooLowUnderHeat):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 85, critical: 95, hysteresis: 3), cooldownMinutes: 10, debounceSamples: 2, desktopNotificationsEnabled: true)
            case (.default, .batteryTemperature):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 38, critical: 45, hysteresis: 2), cooldownMinutes: 20, debounceSamples: 2, desktopNotificationsEnabled: true)
            case (.default, .batteryHealth):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 82, critical: 70, hysteresis: 0), cooldownMinutes: 1_440, debounceSamples: 1, desktopNotificationsEnabled: false)
            case (.default, .lowBatteryDischarging):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 18, critical: 10, hysteresis: 3), cooldownMinutes: 30, debounceSamples: 1, desktopNotificationsEnabled: true)
            case (.default, .smcUnavailable):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .disabled, cooldownMinutes: 30, debounceSamples: 1, desktopNotificationsEnabled: true)
            case (.default, .helperUnavailable):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .disabled, cooldownMinutes: 30, debounceSamples: 1, desktopNotificationsEnabled: true)

            case (.quiet, .cpuTemperature):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 90, critical: 100, hysteresis: 3), cooldownMinutes: 35, debounceSamples: 3, desktopNotificationsEnabled: true)
            case (.quiet, .gpuTemperature):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 88, critical: 98, hysteresis: 3), cooldownMinutes: 35, debounceSamples: 3, desktopNotificationsEnabled: true)
            case (.quiet, .overallThermalState):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 2, critical: 3, hysteresis: 0), cooldownMinutes: 30, debounceSamples: 2, desktopNotificationsEnabled: true)
            case (.quiet, .cpuUsage):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 93, critical: 99, hysteresis: 8), cooldownMinutes: 35, debounceSamples: 4, desktopNotificationsEnabled: false)
            case (.quiet, .memoryPressure):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 2, critical: 2, hysteresis: 0), cooldownMinutes: 25, debounceSamples: 2, desktopNotificationsEnabled: false)
            case (.quiet, .swapUsage):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 8, critical: 14, hysteresis: 1), cooldownMinutes: 35, debounceSamples: 3, desktopNotificationsEnabled: false)
            case (.quiet, .fanTooLowUnderHeat):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 90, critical: 98, hysteresis: 3), cooldownMinutes: 15, debounceSamples: 3, desktopNotificationsEnabled: true)
            case (.quiet, .batteryTemperature):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 40, critical: 46, hysteresis: 2), cooldownMinutes: 35, debounceSamples: 2, desktopNotificationsEnabled: false)
            case (.quiet, .batteryHealth):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 80, critical: 68, hysteresis: 0), cooldownMinutes: 1_440, debounceSamples: 1, desktopNotificationsEnabled: false)
            case (.quiet, .lowBatteryDischarging):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 12, critical: 7, hysteresis: 3), cooldownMinutes: 40, debounceSamples: 1, desktopNotificationsEnabled: true)
            case (.quiet, .smcUnavailable), (.quiet, .helperUnavailable):
                var config = AlertPreset.default.configurations().first { $0.kind == kind } ?? AlertRuleConfig(kind: kind, isEnabled: true, threshold: .disabled, cooldownMinutes: 30, debounceSamples: 1, desktopNotificationsEnabled: true)
                config.cooldownMinutes = 40
                return config

            case (.performance, .cpuTemperature):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 82, critical: 92, hysteresis: 3), cooldownMinutes: 15, debounceSamples: 2, desktopNotificationsEnabled: true)
            case (.performance, .gpuTemperature):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 80, critical: 90, hysteresis: 3), cooldownMinutes: 15, debounceSamples: 2, desktopNotificationsEnabled: true)
            case (.performance, .overallThermalState):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 1, critical: 2, hysteresis: 0), cooldownMinutes: 12, debounceSamples: 1, desktopNotificationsEnabled: true)
            case (.performance, .cpuUsage):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 80, critical: 94, hysteresis: 7), cooldownMinutes: 12, debounceSamples: 2, desktopNotificationsEnabled: true)
            case (.performance, .memoryPressure):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 1, critical: 2, hysteresis: 0), cooldownMinutes: 12, debounceSamples: 1, desktopNotificationsEnabled: true)
            case (.performance, .swapUsage):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 2, critical: 6, hysteresis: 1), cooldownMinutes: 15, debounceSamples: 2, desktopNotificationsEnabled: true)
            case (.performance, .fanTooLowUnderHeat):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 82, critical: 92, hysteresis: 3), cooldownMinutes: 8, debounceSamples: 2, desktopNotificationsEnabled: true)
            case (.performance, .batteryTemperature):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 37, critical: 43, hysteresis: 2), cooldownMinutes: 18, debounceSamples: 2, desktopNotificationsEnabled: true)
            case (.performance, .batteryHealth):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 82, critical: 70, hysteresis: 0), cooldownMinutes: 1_440, debounceSamples: 1, desktopNotificationsEnabled: false)
            case (.performance, .lowBatteryDischarging):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 20, critical: 12, hysteresis: 3), cooldownMinutes: 30, debounceSamples: 1, desktopNotificationsEnabled: true)
            case (.performance, .smcUnavailable), (.performance, .helperUnavailable):
                return AlertPreset.default.configurations().first { $0.kind == kind } ?? AlertRuleConfig(kind: kind, isEnabled: true, threshold: .disabled, cooldownMinutes: 30, debounceSamples: 1, desktopNotificationsEnabled: true)

            case (.aggressiveThermalSafety, .cpuTemperature):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 78, critical: 88, hysteresis: 3), cooldownMinutes: 8, debounceSamples: 1, desktopNotificationsEnabled: true)
            case (.aggressiveThermalSafety, .gpuTemperature):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 76, critical: 86, hysteresis: 3), cooldownMinutes: 8, debounceSamples: 1, desktopNotificationsEnabled: true)
            case (.aggressiveThermalSafety, .overallThermalState):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 1, critical: 2, hysteresis: 0), cooldownMinutes: 8, debounceSamples: 1, desktopNotificationsEnabled: true)
            case (.aggressiveThermalSafety, .cpuUsage):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 82, critical: 95, hysteresis: 6), cooldownMinutes: 10, debounceSamples: 2, desktopNotificationsEnabled: true)
            case (.aggressiveThermalSafety, .memoryPressure):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 1, critical: 2, hysteresis: 0), cooldownMinutes: 10, debounceSamples: 1, desktopNotificationsEnabled: true)
            case (.aggressiveThermalSafety, .swapUsage):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 3, critical: 7, hysteresis: 1), cooldownMinutes: 10, debounceSamples: 1, desktopNotificationsEnabled: true)
            case (.aggressiveThermalSafety, .fanTooLowUnderHeat):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 78, critical: 88, hysteresis: 3), cooldownMinutes: 5, debounceSamples: 1, desktopNotificationsEnabled: true)
            case (.aggressiveThermalSafety, .batteryTemperature):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 36, critical: 42, hysteresis: 2), cooldownMinutes: 10, debounceSamples: 1, desktopNotificationsEnabled: true)
            case (.aggressiveThermalSafety, .batteryHealth):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 84, critical: 72, hysteresis: 0), cooldownMinutes: 1_440, debounceSamples: 1, desktopNotificationsEnabled: false)
            case (.aggressiveThermalSafety, .lowBatteryDischarging):
                return AlertRuleConfig(kind: kind, isEnabled: true, threshold: .init(warning: 18, critical: 10, hysteresis: 3), cooldownMinutes: 20, debounceSamples: 1, desktopNotificationsEnabled: true)
            case (.aggressiveThermalSafety, .smcUnavailable), (.aggressiveThermalSafety, .helperUnavailable):
                var config = AlertPreset.default.configurations().first { $0.kind == kind } ?? AlertRuleConfig(kind: kind, isEnabled: true, threshold: .disabled, cooldownMinutes: 30, debounceSamples: 1, desktopNotificationsEnabled: true)
                config.cooldownMinutes = 10
                return config
            }
        }
    }
}
