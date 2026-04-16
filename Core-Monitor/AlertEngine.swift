import Foundation

struct AlertEvaluationInput {
    let snapshot: SystemMonitorSnapshot
    let fanMode: FanControlMode
    let helperInstalled: Bool
    let helperConnectionState: SMCHelperManager.ConnectionState
    let helperStatusMessage: String?
    let processInsightsEnabled: Bool
    let now: Date
}

struct AlertMeasurement {
    let severity: AlertSeverity
    let metricValue: Double?
    let title: String
    let message: String
    let context: String?
    let isAvailable: Bool
    let unavailableReason: String?
}

struct AlertEvaluationOutcome {
    let runtime: AlertRuleRuntime
    let activeState: AlertActiveState?
    let event: AlertEvent?
    let shouldNotify: Bool
    let availabilityReason: String?
}

enum AlertEvaluator {
    nonisolated static func evaluate(
        config: AlertRuleConfig,
        runtime: AlertRuleRuntime,
        input: AlertEvaluationInput
    ) -> AlertEvaluationOutcome {
        guard config.isEnabled else {
            return AlertEvaluationOutcome(
                runtime: runtimeReset(from: runtime),
                activeState: nil,
                event: nil,
                shouldNotify: false,
                availabilityReason: nil
            )
        }

        let measurement = measurement(for: config.kind, config: config, input: input, runtime: runtime)
        guard measurement.isAvailable else {
            let recoveredRuntime = runtimeReset(from: runtime)
            return AlertEvaluationOutcome(
                runtime: recoveredRuntime,
                activeState: nil,
                event: nil,
                shouldNotify: false,
                availabilityReason: measurement.unavailableReason
            )
        }

        var nextRuntime = runtime
        nextRuntime.lastMetricValue = measurement.metricValue

        if measurement.severity == .none {
            nextRuntime.pendingSeverity = .none
            nextRuntime.pendingSampleCount = 0

            if runtime.activeSeverity != .none {
                nextRuntime.activeSeverity = .none
                nextRuntime.dismissUntilRecovery = false
                nextRuntime.snoozedUntil = nil

                return AlertEvaluationOutcome(
                    runtime: nextRuntime,
                    activeState: nil,
                    event: nil,
                    shouldNotify: false,
                    availabilityReason: nil
                )
            }

            return AlertEvaluationOutcome(
                runtime: nextRuntime,
                activeState: nil,
                event: nil,
                shouldNotify: false,
                availabilityReason: nil
            )
        }

        if runtime.dismissUntilRecovery, runtime.activeSeverity != .none {
            nextRuntime.activeSeverity = runtime.activeSeverity.rawValue >= measurement.severity.rawValue
                ? runtime.activeSeverity
                : measurement.severity
            nextRuntime.pendingSeverity = measurement.severity
            nextRuntime.pendingSampleCount = 0
            nextRuntime.lastMetricValue = measurement.metricValue
            return AlertEvaluationOutcome(
                runtime: nextRuntime,
                activeState: nil,
                event: nil,
                shouldNotify: false,
                availabilityReason: nil
            )
        }

        if runtime.activeSeverity == measurement.severity {
            nextRuntime.pendingSeverity = measurement.severity
            nextRuntime.pendingSampleCount = 0

            let activeState = makeActiveState(
                kind: config.kind,
                severity: measurement.severity,
                measurement: measurement,
                startedAt: runtime.lastEventDate ?? input.now,
                updatedAt: input.now
            )

            if shouldRepeatEvent(config: config, runtime: runtime, input: input) {
                let event = AlertEvent(
                    id: UUID(),
                    kind: config.kind,
                    severity: measurement.severity,
                    title: measurement.title,
                    message: measurement.message,
                    context: measurement.context,
                    timestamp: input.now,
                    isRecovery: false
                )
                let shouldNotify = shouldNotify(config: config, runtime: runtime, severity: measurement.severity, input: input)
                if shouldNotify {
                    nextRuntime.lastNotificationDate = input.now
                }
                nextRuntime.lastEventDate = input.now

                return AlertEvaluationOutcome(
                    runtime: nextRuntime,
                    activeState: activeState,
                    event: event,
                    shouldNotify: shouldNotify,
                    availabilityReason: nil
                )
            }

            return AlertEvaluationOutcome(
                runtime: nextRuntime,
                activeState: activeState,
                event: nil,
                shouldNotify: false,
                availabilityReason: nil
            )
        }

        if nextRuntime.pendingSeverity == measurement.severity {
            nextRuntime.pendingSampleCount += 1
        } else {
            nextRuntime.pendingSeverity = measurement.severity
            nextRuntime.pendingSampleCount = 1
        }

        let debounceTarget = max(1, config.debounceSamples)
        if nextRuntime.pendingSampleCount < debounceTarget {
            let activeState = runtime.activeSeverity == .none ? nil : makeActiveState(
                kind: config.kind,
                severity: runtime.activeSeverity,
                measurement: measurement,
                startedAt: runtime.lastEventDate ?? input.now,
                updatedAt: input.now
            )

            return AlertEvaluationOutcome(
                runtime: nextRuntime,
                activeState: activeState,
                event: nil,
                shouldNotify: false,
                availabilityReason: nil
            )
        }

        nextRuntime.activeSeverity = measurement.severity
        nextRuntime.pendingSampleCount = 0
        nextRuntime.pendingSeverity = measurement.severity
        nextRuntime.lastEventDate = input.now

        let event = AlertEvent(
            id: UUID(),
            kind: config.kind,
            severity: measurement.severity,
            title: measurement.title,
            message: measurement.message,
            context: measurement.context,
            timestamp: input.now,
            isRecovery: false
        )
        let shouldNotify = shouldNotify(config: config, runtime: runtime, severity: measurement.severity, input: input)
        if shouldNotify {
            nextRuntime.lastNotificationDate = input.now
        }

        return AlertEvaluationOutcome(
            runtime: nextRuntime,
            activeState: makeActiveState(
                kind: config.kind,
                severity: measurement.severity,
                measurement: measurement,
                startedAt: input.now,
                updatedAt: input.now
            ),
            event: event,
            shouldNotify: shouldNotify,
            availabilityReason: nil
        )
    }

    nonisolated static func availabilityReason(
        for kind: AlertRuleKind,
        snapshot: SystemMonitorSnapshot
    ) -> String? {
        measurement(
            for: kind,
            config: AlertPreset.default.configurations().first { $0.kind == kind } ?? AlertRuleConfig(kind: kind, isEnabled: true, threshold: .disabled, cooldownMinutes: 1, debounceSamples: 1, desktopNotificationsEnabled: true),
            input: AlertEvaluationInput(
                snapshot: snapshot,
                fanMode: .automatic,
                helperInstalled: true,
                helperConnectionState: .reachable,
                helperStatusMessage: nil,
                processInsightsEnabled: true,
                now: Date()
            ),
            runtime: .initial(for: kind)
        ).unavailableReason
    }

    nonisolated private static func measurement(
        for kind: AlertRuleKind,
        config: AlertRuleConfig,
        input: AlertEvaluationInput,
        runtime: AlertRuleRuntime
    ) -> AlertMeasurement {
        switch kind {
        case .cpuTemperature:
            guard let value = input.snapshot.cpuTemperature else {
                return unavailable(kind, reason: "CPU temperature is unavailable on this Mac.")
            }
            let severity = severityForHighValue(value, threshold: config.threshold, activeSeverity: runtime.activeSeverity)
            return AlertMeasurement(
                severity: severity,
                metricValue: value,
                title: severity == .critical ? "CPU temperature is critical" : "CPU temperature is elevated",
                message: String(format: "CPU temperature reached %.0f°C.", value),
                context: topCPUContext(from: input.snapshot.topProcesses, enabled: input.processInsightsEnabled),
                isAvailable: true,
                unavailableReason: nil
            )

        case .gpuTemperature:
            guard let value = input.snapshot.gpuTemperature else {
                return unavailable(kind, reason: "GPU temperature is unavailable on this Mac.")
            }
            let severity = severityForHighValue(value, threshold: config.threshold, activeSeverity: runtime.activeSeverity)
            return AlertMeasurement(
                severity: severity,
                metricValue: value,
                title: severity == .critical ? "GPU temperature is critical" : "GPU temperature is elevated",
                message: String(format: "GPU temperature reached %.0f°C.", value),
                context: topCPUContext(from: input.snapshot.topProcesses, enabled: input.processInsightsEnabled),
                isAvailable: true,
                unavailableReason: nil
            )

        case .overallThermalState:
            let value = Double(thermalStateLevel(input.snapshot.thermalState))
            let severity = severityForHighValue(value, threshold: config.threshold, activeSeverity: runtime.activeSeverity)
            return AlertMeasurement(
                severity: severity,
                metricValue: value,
                title: severity == .critical ? "macOS reports critical thermal pressure" : "macOS reports elevated thermal pressure",
                message: "Overall thermal state is \(thermalStateLabel(input.snapshot.thermalState)).",
                context: topCPUContext(from: input.snapshot.topProcesses, enabled: input.processInsightsEnabled),
                isAvailable: true,
                unavailableReason: nil
            )

        case .cpuUsage:
            let value = input.snapshot.cpuUsagePercent
            let severity = severityForHighValue(value, threshold: config.threshold, activeSeverity: runtime.activeSeverity)
            return AlertMeasurement(
                severity: severity,
                metricValue: value,
                title: severity == .critical ? "CPU usage is pinned" : "CPU usage is elevated",
                message: String(format: "CPU usage is %.0f%%.", value),
                context: topCPUContext(from: input.snapshot.topProcesses, enabled: input.processInsightsEnabled),
                isAvailable: true,
                unavailableReason: nil
            )

        case .memoryPressure:
            let value = Double(memoryPressureLevel(input.snapshot.memoryPressure))
            let severity = severityForHighValue(value, threshold: config.threshold, activeSeverity: runtime.activeSeverity)
            return AlertMeasurement(
                severity: severity,
                metricValue: value,
                title: severity == .critical ? "Memory pressure is critical" : "Memory pressure is elevated",
                message: "Memory pressure is \(memoryPressureLabel(input.snapshot.memoryPressure)).",
                context: topMemoryContext(from: input.snapshot.topProcesses, enabled: input.processInsightsEnabled),
                isAvailable: true,
                unavailableReason: nil
            )

        case .swapUsage:
            let swapGB = Double(input.snapshot.swapUsedBytes) / 1_073_741_824.0
            let severity = severityForHighValue(swapGB, threshold: config.threshold, activeSeverity: runtime.activeSeverity)
            return AlertMeasurement(
                severity: severity,
                metricValue: swapGB,
                title: severity == .critical ? "Swap usage is heavy" : "Swap usage is growing",
                message: String(format: "Swap usage reached %.1f GB.", swapGB),
                context: topMemoryContext(from: input.snapshot.topProcesses, enabled: input.processInsightsEnabled),
                isAvailable: true,
                unavailableReason: nil
            )

        case .fanTooLowUnderHeat:
            guard input.snapshot.numberOfFans > 0 else {
                return unavailable(kind, reason: "No fan sensors were detected on this Mac.")
            }
            let hottest = max(input.snapshot.cpuTemperature ?? 0, input.snapshot.gpuTemperature ?? 0)
            guard hottest > 0 else {
                return AlertMeasurement(
                    severity: .none,
                    metricValue: nil,
                    title: "Fan speed is normal",
                    message: "Waiting for live thermal data before evaluating fan safety.",
                    context: nil,
                    isAvailable: true,
                    unavailableReason: nil
                )
            }
            let stalledFanIndex = input.snapshot.fanSpeeds.firstIndex { $0 <= 0 }
            if let stalledFanIndex, hottest >= (config.threshold.warning ?? 0) {
                return AlertMeasurement(
                    severity: .critical,
                    metricValue: hottest,
                    title: "A fan appears stalled while the Mac is hot",
                    message: "Fan \(stalledFanIndex + 1) reported 0 RPM while the hottest sensor is \(Int(hottest.rounded()))°C.",
                    context: nil,
                    isAvailable: true,
                    unavailableReason: nil
                )
            }

            let lowFanIndex = zip(input.snapshot.fanSpeeds, input.snapshot.fanMinSpeeds)
                .enumerated()
                .first { _, pair in
                    let floor = max(pair.1 + 150, 1_200)
                    return pair.0 < floor
                }?
                .offset

            let severity: AlertSeverity
            if hottest >= (config.threshold.critical ?? .greatestFiniteMagnitude), lowFanIndex != nil {
                severity = .critical
            } else if hottest >= (config.threshold.warning ?? .greatestFiniteMagnitude), lowFanIndex != nil {
                severity = .warning
            } else {
                severity = .none
            }

            return AlertMeasurement(
                severity: severity,
                metricValue: hottest,
                title: severity == .critical ? "Fan speed is too low for current heat" : "Fan safety margin is shrinking",
                message: lowFanIndex == nil
                    ? "Fan speed is tracking heat normally."
                    : "Fan \(lowFanIndex! + 1) is under target while the hottest sensor is \(Int(hottest.rounded()))°C.",
                context: nil,
                isAvailable: true,
                unavailableReason: nil
            )

        case .batteryTemperature:
            guard input.snapshot.batteryInfo.hasBattery else {
                return unavailable(kind, reason: "This Mac does not report a battery.")
            }
            guard let value = input.snapshot.batteryInfo.temperatureC else {
                return unavailable(kind, reason: "Battery temperature is unavailable on this Mac.")
            }
            let severity = severityForHighValue(value, threshold: config.threshold, activeSeverity: runtime.activeSeverity)
            return AlertMeasurement(
                severity: severity,
                metricValue: value,
                title: severity == .critical ? "Battery temperature is critical" : "Battery temperature is elevated",
                message: String(format: "Battery temperature reached %.0f°C.", value),
                context: nil,
                isAvailable: true,
                unavailableReason: nil
            )

        case .batteryHealth:
            guard input.snapshot.batteryInfo.hasBattery else {
                return unavailable(kind, reason: "This Mac does not report a battery.")
            }
            guard let value = input.snapshot.batteryInfo.healthPercent.map(Double.init) else {
                return unavailable(kind, reason: "Battery health is unavailable on this Mac.")
            }
            let severity = severityForLowValue(value, threshold: config.threshold, activeSeverity: runtime.activeSeverity)
            return AlertMeasurement(
                severity: severity,
                metricValue: value,
                title: severity == .critical ? "Battery health is below the critical threshold" : "Battery health is below target",
                message: String(format: "Battery health is %.0f%%.", value),
                context: input.snapshot.batteryInfo.cycleCount.map { "\($0) cycles" },
                isAvailable: true,
                unavailableReason: nil
            )

        case .lowBatteryDischarging:
            guard input.snapshot.batteryInfo.hasBattery else {
                return unavailable(kind, reason: "This Mac does not report a battery.")
            }
            guard input.snapshot.batteryInfo.isPluggedIn == false else {
                return AlertMeasurement(
                    severity: .none,
                    metricValue: nil,
                    title: "Battery is not discharging",
                    message: "Low-battery alerts only apply while unplugged.",
                    context: nil,
                    isAvailable: true,
                    unavailableReason: nil
                )
            }
            let value = Double(input.snapshot.batteryInfo.chargePercent ?? 100)
            let severity = severityForLowValue(value, threshold: config.threshold, activeSeverity: runtime.activeSeverity)
            return AlertMeasurement(
                severity: severity,
                metricValue: value,
                title: severity == .critical ? "Battery is critically low" : "Battery is running low",
                message: String(format: "Battery charge is %.0f%% while discharging.", value),
                context: input.snapshot.batteryInfo.timeRemainingMinutes.map { "\($0) min remaining" },
                isAvailable: true,
                unavailableReason: nil
            )

        case .smcUnavailable:
            let isUnavailable = input.snapshot.hasSMCAccess == false
            return AlertMeasurement(
                severity: isUnavailable ? .critical : .none,
                metricValue: isUnavailable ? 1 : 0,
                title: "AppleSMC access is unavailable",
                message: input.snapshot.lastError ?? "Core Monitor could not open AppleSMC.",
                context: nil,
                isAvailable: true,
                unavailableReason: nil
            )

        case .helperUnavailable:
            let modeNeedsHelper = input.fanMode.requiresPrivilegedHelper
            let severity: AlertSeverity
            if modeNeedsHelper {
                switch input.helperConnectionState {
                case .unreachable:
                    severity = .critical
                case .missing:
                    severity = .warning
                case .unknown where input.helperInstalled == false:
                    severity = .warning
                case .unknown, .checking, .reachable:
                    severity = .none
                }
            } else {
                severity = .none
            }

            let message: String
            switch input.helperConnectionState {
            case .unreachable:
                message = input.helperStatusMessage ?? "Core Monitor cannot use the privileged fan helper for the current fan mode."
            case .missing:
                message = "Install the privileged helper before using manual or managed fan modes."
            case .unknown where input.helperInstalled == false:
                message = "Install the privileged helper before using manual or managed fan modes."
            case .unknown, .checking, .reachable:
                message = input.helperStatusMessage ?? "Core Monitor cannot use the privileged fan helper for the current fan mode."
            }

            return AlertMeasurement(
                severity: severity,
                metricValue: severity == .none ? 0 : 1,
                title: severity == .critical ? "Fan helper connection failed" : "Fan helper is unavailable",
                message: message,
                context: "Current mode: \(input.fanMode.title)",
                isAvailable: true,
                unavailableReason: nil
            )
        }
    }

    nonisolated private static func unavailable(_ kind: AlertRuleKind, reason: String) -> AlertMeasurement {
        AlertMeasurement(
            severity: .none,
            metricValue: nil,
            title: kind.title,
            message: kind.subtitle,
            context: nil,
            isAvailable: false,
            unavailableReason: reason
        )
    }

    nonisolated private static func makeActiveState(
        kind: AlertRuleKind,
        severity: AlertSeverity,
        measurement: AlertMeasurement,
        startedAt: Date,
        updatedAt: Date
    ) -> AlertActiveState {
        AlertActiveState(
            kind: kind,
            severity: severity,
            title: measurement.title,
            message: measurement.message,
            context: measurement.context,
            startedAt: startedAt,
            updatedAt: updatedAt,
            metricValue: measurement.metricValue
        )
    }

    nonisolated private static func runtimeReset(from runtime: AlertRuleRuntime) -> AlertRuleRuntime {
        var nextRuntime = runtime
        nextRuntime.activeSeverity = .none
        nextRuntime.pendingSeverity = .none
        nextRuntime.pendingSampleCount = 0
        nextRuntime.lastMetricValue = nil
        nextRuntime.dismissUntilRecovery = false
        return nextRuntime
    }

    nonisolated private static func shouldNotify(
        config: AlertRuleConfig,
        runtime: AlertRuleRuntime,
        severity: AlertSeverity,
        input: AlertEvaluationInput
    ) -> Bool {
        guard config.desktopNotificationsEnabled, config.kind.supportsDesktopNotifications else { return false }
        if let snoozedUntil = runtime.snoozedUntil, snoozedUntil > input.now { return false }
        if runtime.dismissUntilRecovery { return false }
        if let lastNotificationDate = runtime.lastNotificationDate,
           input.now.timeIntervalSince(lastNotificationDate) < Double(config.cooldownMinutes * 60) {
            return false
        }
        switch severity {
        case .critical:
            return true
        case .warning:
            return true
        case .info:
            return false
        case .none:
            return false
        }
    }

    nonisolated private static func shouldRepeatEvent(
        config: AlertRuleConfig,
        runtime: AlertRuleRuntime,
        input: AlertEvaluationInput
    ) -> Bool {
        guard runtime.activeSeverity != .none else { return false }
        guard let lastEventDate = runtime.lastEventDate else { return false }
        return input.now.timeIntervalSince(lastEventDate) >= Double(config.cooldownMinutes * 60)
    }

    nonisolated private static func severityForHighValue(
        _ value: Double,
        threshold: AlertThreshold,
        activeSeverity: AlertSeverity
    ) -> AlertSeverity {
        let criticalThreshold = threshold.critical ?? .greatestFiniteMagnitude
        let warningThreshold = threshold.warning ?? .greatestFiniteMagnitude

        if value >= criticalThreshold { return .critical }
        if activeSeverity == .critical {
            let recoveryFloor = criticalThreshold - threshold.hysteresis
            if value >= recoveryFloor {
                return .critical
            }
        }

        if value >= warningThreshold { return .warning }
        if activeSeverity == .warning {
            let recoveryFloor = warningThreshold - threshold.hysteresis
            if value >= recoveryFloor {
                return .warning
            }
        }

        return .none
    }

    nonisolated private static func severityForLowValue(
        _ value: Double,
        threshold: AlertThreshold,
        activeSeverity: AlertSeverity
    ) -> AlertSeverity {
        let criticalThreshold = threshold.critical ?? -.greatestFiniteMagnitude
        let warningThreshold = threshold.warning ?? -.greatestFiniteMagnitude

        if value <= criticalThreshold { return .critical }
        if activeSeverity == .critical {
            let recoveryCeiling = criticalThreshold + threshold.hysteresis
            if value <= recoveryCeiling {
                return .critical
            }
        }

        if value <= warningThreshold { return .warning }
        if activeSeverity == .warning {
            let recoveryCeiling = warningThreshold + threshold.hysteresis
            if value <= recoveryCeiling {
                return .warning
            }
        }

        return .none
    }

    nonisolated private static func topCPUContext(from topProcesses: TopProcessSnapshot, enabled: Bool) -> String? {
        guard enabled else { return nil }
        guard let process = topProcesses.topCPU.first, process.cpuPercent > 0 else { return nil }
        return String(format: "Top CPU: %@ (%.0f%%)", process.name, process.cpuPercent)
    }

    nonisolated private static func topMemoryContext(from topProcesses: TopProcessSnapshot, enabled: Bool) -> String? {
        guard enabled else { return nil }
        guard let process = topProcesses.topMemory.first, process.memoryBytes > 0 else { return nil }
        return String(format: "Top Memory: %@ (%.1f GB)", process.name, process.memoryGB)
    }

    nonisolated private static func thermalStateLevel(_ thermalState: ProcessInfo.ThermalState) -> Int {
        switch thermalState {
        case .nominal: return 0
        case .fair: return 1
        case .serious: return 2
        case .critical: return 3
        @unknown default: return 0
        }
    }

    nonisolated static func thermalStateLabel(_ thermalState: ProcessInfo.ThermalState) -> String {
        switch thermalState {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }

    nonisolated private static func memoryPressureLevel(_ pressure: MemoryPressureLevel) -> Int {
        switch pressure {
        case .green: return 0
        case .yellow: return 1
        case .red: return 2
        }
    }

    nonisolated static func memoryPressureLabel(_ pressure: MemoryPressureLevel) -> String {
        switch pressure {
        case .green: return "Normal"
        case .yellow: return "Elevated"
        case .red: return "Critical"
        }
    }
}
