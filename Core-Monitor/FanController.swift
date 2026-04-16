import Foundation
import Combine
import AppKit

// MARK: - Fan Control Modes

enum FanControlMode: String, CaseIterable {
    case smart
    case silent
    case balanced
    case performance
    case max
    case manual
    case custom
    case automatic

    static var quickModes: [FanControlMode] {
        [.smart, .silent, .balanced, .performance, .max, .manual, .custom, .automatic]
    }

    var title: String {
        switch self {
        case .smart:       return "SMART"
        case .silent:      return "SILENT"
        case .balanced:    return "BALANCED"
        case .performance: return "PERFORMANCE"
        case .max:         return "MAX"
        case .manual:      return "MANUAL"
        case .custom:      return "CUSTOM"
        case .automatic:   return "SYSTEM"
        }
    }

    var shortTitle: String {
        switch self {
        case .smart:       return "SMART"
        case .silent:      return "SILENT"
        case .balanced:    return "BAL"
        case .performance: return "PERF"
        case .max:         return "MAX"
        case .manual:      return "MANUAL"
        case .custom:      return "CODE"
        case .automatic:   return "SYSTEM"
        }
    }

    var usesManualSlider: Bool { self == .manual }
    var isManagedProfile: Bool { guidance.ownership == .coreMonitor }
    var requiresPrivilegedHelper: Bool { guidance.requiresHelper }

    var guidance: FanModeGuidance {
        switch self {
        case .smart:
            return FanModeGuidance(
                summary: "Blends the hottest CPU or GPU reading with system watt draw and keeps adjusting while Core Monitor runs.",
                detail: "Best daily default for sustained mixed workloads that need extra cooling before throttling shows up.",
                ownership: .coreMonitor,
                requiresHelper: true,
                restoresSystemAutomaticOnExit: true,
                showsAppleSiliconDelayedResponseNote: true
            )
        case .silent:
            return FanModeGuidance(
                summary: "Leaves the firmware curve in charge instead of holding a custom RPM target.",
                detail: "Best when you want monitoring and alerts without an ongoing fan override.",
                ownership: .system,
                requiresHelper: false,
                restoresSystemAutomaticOnExit: false,
                showsAppleSiliconDelayedResponseNote: false
            )
        case .balanced:
            return FanModeGuidance(
                summary: "Pins every controllable fan close to 60% of its reported maximum.",
                detail: "Useful for longer compile, render, and emulator sessions where steady cooling matters more than acoustics.",
                ownership: .coreMonitor,
                requiresHelper: true,
                restoresSystemAutomaticOnExit: true,
                showsAppleSiliconDelayedResponseNote: true
            )
        case .performance:
            return FanModeGuidance(
                summary: "Pins every controllable fan close to 85% for aggressive sustained cooling.",
                detail: "Good for heavy GPU or all-core work when you want lower temperatures without going full blast.",
                ownership: .coreMonitor,
                requiresHelper: true,
                restoresSystemAutomaticOnExit: true,
                showsAppleSiliconDelayedResponseNote: true
            )
        case .max:
            return FanModeGuidance(
                summary: "Pins every controllable fan at the reported maximum RPM.",
                detail: "Use only when you want the strongest possible cooling and do not care about noise.",
                ownership: .coreMonitor,
                requiresHelper: true,
                restoresSystemAutomaticOnExit: true,
                showsAppleSiliconDelayedResponseNote: true
            )
        case .manual:
            return FanModeGuidance(
                summary: "Writes one fixed RPM target across every controllable fan until you reset or quit.",
                detail: "Best for short debugging sessions when you know the exact airflow target you want.",
                ownership: .coreMonitor,
                requiresHelper: true,
                restoresSystemAutomaticOnExit: true,
                showsAppleSiliconDelayedResponseNote: true
            )
        case .custom:
            return FanModeGuidance(
                summary: "Follows your saved temperature curve with optional power-based boost and smoothing.",
                detail: "Best when you want repeatable ramp behavior that matches one machine and one workload profile.",
                ownership: .coreMonitor,
                requiresHelper: true,
                restoresSystemAutomaticOnExit: true,
                showsAppleSiliconDelayedResponseNote: true
            )
        case .automatic:
            return FanModeGuidance(
                summary: "Restores every fan to the firmware's automatic curve.",
                detail: "Use this any time you want macOS to own cooling again immediately.",
                ownership: .system,
                requiresHelper: false,
                restoresSystemAutomaticOnExit: false,
                showsAppleSiliconDelayedResponseNote: false
            )
        }
    }
}

enum FanControlOwnership: Equatable {
    case system
    case coreMonitor
}

struct FanModeGuidance: Equatable {
    let summary: String
    let detail: String
    let ownership: FanControlOwnership
    let requiresHelper: Bool
    let restoresSystemAutomaticOnExit: Bool
    let showsAppleSiliconDelayedResponseNote: Bool
}

// MARK: - Custom Fan Preset Model

struct CustomFanPreset: Codable, Equatable {
    enum Sensor: String, Codable, CaseIterable, Identifiable {
        case cpu
        case gpu
        case max

        var id: String { rawValue }

        var title: String {
            switch self {
            case .cpu: return "CPU"
            case .gpu: return "GPU"
            case .max: return "Hottest"
            }
        }
    }

    struct CurvePoint: Codable, Equatable, Identifiable {
        let id: UUID
        var temperatureC: Double
        var speedPercent: Double

        private enum CodingKeys: String, CodingKey {
            case id
            case temperatureC
            case speedPercent
        }

        init(id: UUID = UUID(), temperatureC: Double, speedPercent: Double) {
            self.id = id
            self.temperatureC = temperatureC
            self.speedPercent = speedPercent
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
            temperatureC = try container.decode(Double.self, forKey: .temperatureC)
            speedPercent = try container.decode(Double.self, forKey: .speedPercent)
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(temperatureC, forKey: .temperatureC)
            try container.encode(speedPercent, forKey: .speedPercent)
        }
    }

    struct PowerBoost: Codable, Equatable {
        var enabled: Bool = true
        var wattsAtMaxBoost: Double = 40
        var maxAddedTemperatureC: Double = 8
    }

    var name: String
    var version: Int
    var sensor: Sensor
    var updateIntervalSeconds: Double?
    var smoothingStepRPM: Int?
    var minimumRPM: Int?
    var maximumRPM: Int?
    var perFanRPMOffset: [Int]?
    var powerBoost: PowerBoost?
    var points: [CurvePoint]

    static let starter = CustomFanPreset(
        name: "Quiet ramp with thermal boost",
        version: 1,
        sensor: .max,
        updateIntervalSeconds: 2,
        smoothingStepRPM: 100,
        minimumRPM: 1400,
        maximumRPM: 6200,
        perFanRPMOffset: [0, 0],
        powerBoost: PowerBoost(enabled: true, wattsAtMaxBoost: 42, maxAddedTemperatureC: 8),
        points: [
            CurvePoint(temperatureC: 38, speedPercent: 24),
            CurvePoint(temperatureC: 50, speedPercent: 32),
            CurvePoint(temperatureC: 65, speedPercent: 50),
            CurvePoint(temperatureC: 78, speedPercent: 72),
            CurvePoint(temperatureC: 88, speedPercent: 100),
        ]
    )

    var resolvedUpdateInterval: TimeInterval {
        let raw = updateIntervalSeconds ?? 2.0
        return min(max(raw, 0.5), 10.0)
    }

    var resolvedSmoothingStepRPM: Int {
        let raw = smoothingStepRPM ?? 75
        return min(max(raw, 0), 2000)
    }

    var resolvedPerFanOffsets: [Int] {
        (perFanRPMOffset ?? []).map { min(max($0, -3000), 3000) }
    }

    func validationErrors(globalMinRPM: Int, globalMaxRPM: Int) -> [String] {
        var errors: [String] = []

        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Preset name cannot be empty.")
        }

        if version < 1 {
            errors.append("version must be 1 or greater.")
        }

        if points.count < 2 {
            errors.append("At least two curve points are required.")
        }

        var previousTemp = -Double.infinity
        for (index, point) in points.enumerated() {
            if point.temperatureC < 0 || point.temperatureC > 120 {
                errors.append("points[\(index)].temperatureC must be between 0 and 120.")
            }
            if point.speedPercent < 0 || point.speedPercent > 100 {
                errors.append("points[\(index)].speedPercent must be between 0 and 100.")
            }
            if point.temperatureC <= previousTemp {
                errors.append("Curve temperatures must be strictly increasing.")
                break
            }
            previousTemp = point.temperatureC
        }

        if let minimumRPM, minimumRPM < globalMinRPM {
            errors.append("minimumRPM cannot be below the app safety floor of \(globalMinRPM) RPM.")
        }

        if let maximumRPM, maximumRPM > globalMaxRPM {
            errors.append("maximumRPM cannot exceed the app safety ceiling of \(globalMaxRPM) RPM.")
        }

        if let minimumRPM, let maximumRPM, minimumRPM > maximumRPM {
            errors.append("minimumRPM cannot be greater than maximumRPM.")
        }

        if let powerBoost {
            if powerBoost.wattsAtMaxBoost <= 0 {
                errors.append("powerBoost.wattsAtMaxBoost must be greater than 0.")
            }
            if powerBoost.maxAddedTemperatureC < 0 || powerBoost.maxAddedTemperatureC > 30 {
                errors.append("powerBoost.maxAddedTemperatureC must be between 0 and 30.")
            }
        }

        if let updateIntervalSeconds, updateIntervalSeconds < 0.5 || updateIntervalSeconds > 10 {
            errors.append("updateIntervalSeconds must be between 0.5 and 10 seconds.")
        }

        if let smoothingStepRPM, smoothingStepRPM < 0 || smoothingStepRPM > 2000 {
            errors.append("smoothingStepRPM must be between 0 and 2000 RPM.")
        }

        if let perFanRPMOffset {
            for (index, offset) in perFanRPMOffset.enumerated() where abs(offset) > 3000 {
                errors.append("perFanRPMOffset[\(index)] must stay between -3000 and 3000 RPM.")
            }
        }

        return errors
    }

    func interpolatedSpeedPercent(for effectiveTemperature: Double) -> Double {
        guard let first = points.first, let last = points.last else { return 0 }

        if effectiveTemperature <= first.temperatureC {
            return first.speedPercent
        }

        if effectiveTemperature >= last.temperatureC {
            return last.speedPercent
        }

        for index in 0..<(points.count - 1) {
            let left = points[index]
            let right = points[index + 1]
            guard effectiveTemperature >= left.temperatureC, effectiveTemperature <= right.temperatureC else { continue }
            let span = right.temperatureC - left.temperatureC
            guard span > 0 else { return right.speedPercent }
            let ratio = (effectiveTemperature - left.temperatureC) / span
            return left.speedPercent + (right.speedPercent - left.speedPercent) * ratio
        }

        return last.speedPercent
    }

    var sortedPoints: [CurvePoint] {
        points.sorted { lhs, rhs in
            if lhs.temperatureC == rhs.temperatureC {
                return lhs.speedPercent < rhs.speedPercent
            }
            return lhs.temperatureC < rhs.temperatureC
        }
    }
}

enum CustomPresetSaveOutcome {
    case success(String)
    case failure([String])
}

// MARK: - Fan Controller

@MainActor
final class FanController: ObservableObject {
    static let defaultMode: FanControlMode = .automatic

    @Published var mode: FanControlMode = FanController.defaultMode
    @Published var manualSpeed: Int = 2200
    @Published var autoAggressiveness: Double = 1.5
    @Published var autoMaxSpeed: Int = 6500
    @Published var statusMessage: String = "Idle"
    @Published var calibrationStatus: String = "No fan key scan run yet."
    @Published var isCalibrating: Bool = false
    @Published var customPresetSource: String = FanController.defaultCustomPresetSource
    @Published var customPresetStatus: String = "No custom preset saved yet."
    @Published var customPresetLastError: String?
    @Published var needsCustomPresetRestart: Bool = false

    let minSpeed = 1000
    let maxSpeed = 6500

    private weak var systemMonitor: SystemMonitor?
    private var controlTimer: Timer?
    private var lastAppliedSpeed: Int = 0
    private let helperManager = SMCHelperManager.shared
    private var workspaceObservers: [NSObjectProtocol] = []
    private var customPreset: CustomFanPreset?

    init(systemMonitor: SystemMonitor) {
        self.systemMonitor = systemMonitor
        loadSettings()
        loadCustomPresetFromDisk()
        if statusMessage == "Idle" {
            statusMessage = passiveStatusMessage(for: mode)
        }
        registerForWakeNotifications()
    }

    deinit {
        controlTimer?.invalidate()
        controlTimer = nil
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    static var defaultCustomPresetSource: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(CustomFanPreset.starter) else {
            return "{}"
        }
        return String(decoding: data, as: UTF8.self)
    }

    var customPresetFilePath: String {
        customPresetFileURL().path
    }

    // MARK: - Public API

    /// Best-effort shutdown cleanup so managed fan targets do not outlive the app process.
    func restoreSystemAutomaticOnTermination() {
        stopControlLoop()

        guard mode != .automatic else { return }
        guard helperManager.isInstalled else { return }

        let fanCount = resolvedFanCount()
        guard fanCount > 0 else { return }

        for fanID in 0..<fanCount {
            _ = helperManager.executeIfInstalled(arguments: ["auto", "\(fanID)"], timeout: 1.0)
        }
    }

    func setMode(_ mode: FanControlMode) {
        if mode.requiresPrivilegedHelper {
            guard canActivatePrivilegedMode() else { return }
        }
        self.mode = mode
        lastAppliedSpeed = 0
        saveSettings()
        applyCurrentMode(force: true)
    }

    func setManualSpeed(_ speed: Int) {
        manualSpeed = max(minSpeed, min(maxSpeed, speed))
        saveSettings()
        guard mode == .manual else { return }
        applyFanSpeed(manualSpeed)
    }

    func setAutoAggressiveness(_ value: Double) {
        autoAggressiveness = max(0.0, min(3.0, value))
        saveSettings()
        if mode == .smart {
            lastAppliedSpeed = 0
            updateManagedControl()
        }
    }

    func setAutoMaxSpeed(_ speed: Int) {
        autoMaxSpeed = max(minSpeed, min(maxSpeed, speed))
        saveSettings()
        if mode == .smart || mode == .automatic {
            lastAppliedSpeed = 0
            updateManagedControl()
        }
    }

    func validateCustomPresetSource(_ source: String) -> [String] {
        do {
            let preset = try decodeCustomPreset(from: source)
            return preset.validationErrors(globalMinRPM: minSpeed, globalMaxRPM: maxSpeed)
        } catch {
            return [error.localizedDescription]
        }
    }

    func currentCustomPresetDraft() -> CustomFanPreset {
        if let customPreset {
            return customPreset
        }
        if let preset = try? decodeCustomPreset(from: customPresetSource) {
            return preset
        }
        return .starter
    }

    func validateCustomPreset(_ preset: CustomFanPreset) -> [String] {
        preset.validationErrors(globalMinRPM: minSpeed, globalMaxRPM: maxSpeed)
    }

    @discardableResult
    func saveCustomPreset(_ preset: CustomFanPreset) -> CustomPresetSaveOutcome {
        do {
            let source = try prettyPrintedJSONString(from: preset)
            return saveCustomPresetSource(source)
        } catch {
            let message = error.localizedDescription
            customPresetLastError = message
            customPresetStatus = "Preset validation failed."
            return .failure([message])
        }
    }

    func prettyPrintedPresetSource(for preset: CustomFanPreset) -> String {
        (try? prettyPrintedJSONString(from: preset)) ?? Self.defaultCustomPresetSource
    }

    @discardableResult
    func saveCustomPresetSource(_ source: String) -> CustomPresetSaveOutcome {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(["Preset source is empty."])
        }

        do {
            let preset = try decodeCustomPreset(from: trimmed)
            let validationErrors = preset.validationErrors(globalMinRPM: minSpeed, globalMaxRPM: maxSpeed)
            guard validationErrors.isEmpty else {
                customPresetLastError = validationErrors.joined(separator: " ")
                customPresetStatus = "Preset validation failed."
                return .failure(validationErrors)
            }

            let prettySource = try prettyPrintedJSONString(from: preset)
            let url = customPresetFileURL()
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            guard let data = prettySource.data(using: .utf8) else {
                throw NSError(domain: "CoreMonitor.CustomFanPreset", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to encode preset as UTF-8."])
            }
            try data.write(to: url, options: .atomic)

            customPresetSource = prettySource
            customPresetStatus = "Saved custom preset \"\(preset.name)\". Applying now."
            customPresetLastError = nil
            needsCustomPresetRestart = false
            // Hot-reload: parse and activate immediately without restart
            self.customPreset = preset
            if mode == .custom {
                lastAppliedSpeed = 0
                applyCurrentMode(force: true)
            }
            if mode == .custom {
                statusMessage = "Custom preset \"\(preset.name)\" applied."
            }
            return .success(customPresetStatus)
        } catch {
            let message = error.localizedDescription
            customPresetLastError = message
            customPresetStatus = "Preset validation failed."
            return .failure([message])
        }
    }

    @discardableResult
    func restartAppToApplyCustomPreset() -> Bool {
        guard FileManager.default.fileExists(atPath: customPresetFilePath) else {
            let message = "No saved preset exists yet. Save the preset before restarting."
            customPresetLastError = message
            customPresetStatus = message
            statusMessage = message
            return false
        }

        let bundlePath = Bundle.main.bundlePath
        guard !bundlePath.isEmpty else {
            let message = "Unable to determine the current app bundle path."
            customPresetLastError = message
            customPresetStatus = message
            statusMessage = message
            return false
        }

        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = [bundlePath]
            try process.run()
            statusMessage = "Restarting Core Monitor to apply the custom preset…"

            for window in NSApp.windows {
                if let attachedSheet = window.attachedSheet {
                    window.endSheet(attachedSheet)
                    attachedSheet.orderOut(nil)
                }
            }
            NSApp.abortModal()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                for window in NSApp.windows {
                    window.orderOut(nil)
                }
                NSApp.terminate(nil)
            }
            return true
        } catch {
            let message = "Failed to restart app: \(error.localizedDescription)"
            customPresetLastError = message
            customPresetStatus = message
            statusMessage = message
            return false
        }
    }

    func resetToSystemAutomatic() {
        guard ensureHelperInstalledIfNeeded() else { return }
        let fanCount = resolvedFanCount()
        guard fanCount > 0 else {
            statusMessage = helperUnavailableMessage()
            return
        }
        var allSuccess = true
        for fanID in 0..<fanCount {
            if !runSmcHelper(arguments: ["auto", "\(fanID)"]) {
                allSuccess = false
            }
        }
        if allSuccess {
        }
        statusMessage = allSuccess ? "System automatic control restored" : "Failed to restore automatic control"
    }

    func calibrateFanControl() {
        guard !isCalibrating else { return }
        guard ensureHelperInstalledIfNeeded() else {
            calibrationStatus = helperUnavailableMessage()
            return
        }

        let keys = fanCalibrationCandidateKeys()
        isCalibrating = true
        calibrationStatus = "Scanning fan-related SMC keys 0/\(keys.count)"

        Task { @MainActor [weak self] in
            guard let self else { return }
            var responsiveKeys: [String] = []

            for (index, key) in keys.enumerated() {
                if helperManager.readValue(key: key) != nil {
                    responsiveKeys.append(key)
                }

                let completed = index + 1
                calibrationStatus = "Scanning fan-related SMC keys \(completed)/\(keys.count) - \(responsiveKeys.count) responsive"
                if completed % 8 == 0 {
                    await Task.yield()
                }
            }

            let preview = responsiveKeys.prefix(10).joined(separator: ", ")
            calibrationStatus = responsiveKeys.isEmpty
                ? "Fan key scan finished: 0/\(keys.count) keys responded"
                : "Fan key scan finished: \(responsiveKeys.count)/\(keys.count) keys responded - \(preview)"
            statusMessage = calibrationStatus
            isCalibrating = false
        }
    }

    // MARK: - Control Loop

    private func startControlLoop() {
        stopControlLoop()
        updateManagedControl()

        let interval = controlLoopInterval()
        controlTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateManagedControl()
            }
        }

        if let controlTimer {
            controlTimer.tolerance = min(0.3, interval * 0.25)
            RunLoop.current.add(controlTimer, forMode: .common)
        }
    }

    private func stopControlLoop() {
        controlTimer?.invalidate()
        controlTimer = nil
    }

    private func controlLoopInterval() -> TimeInterval {
        guard mode == .custom else { return 2.0 }
        return customPreset?.resolvedUpdateInterval ?? 2.0
    }

    private func applyCurrentMode(force: Bool = false) {
        if force { stopControlLoop() }

        switch mode {
        case .automatic:
            resetToSystemAutomatic()
            statusMessage = "System automatic control restored"
        case .silent:
            updateManagedControl()
        case .manual:
            applyFanSpeed(manualSpeed)
            lastAppliedSpeed = manualSpeed
            statusMessage = "Manual: \(manualSpeed) RPM"
            startControlLoop()
        case .smart, .balanced, .performance, .max, .custom:
            startControlLoop()
        }
    }

    private func updateManagedControl() {
        guard let _ = systemMonitor else { return }

        switch mode {
        case .manual:
            if abs(manualSpeed - lastAppliedSpeed) >= 50 || lastAppliedSpeed == 0 {
                applyFanSpeed(manualSpeed)
                lastAppliedSpeed = manualSpeed
            }
            statusMessage = "Manual: \(manualSpeed) RPM"

        case .automatic:
            break

        case .silent:
            if helperManager.isInstalled, lastAppliedSpeed > 0 {
                resetToSystemAutomatic()
                if statusMessage == "System automatic control restored" {
                    statusMessage = "Silent: system automatic"
                }
            } else {
                statusMessage = helperManager.isInstalled ? "Silent: system automatic" : "Silent: monitoring only"
            }
            lastAppliedSpeed = -1

        case .balanced:
            applyFixedPercentProfile(0.60, label: "Balanced")

        case .performance:
            applyFixedPercentProfile(0.85, label: "Performance")

        case .max:
            applyFixedPercentProfile(1.0, label: "Max")

        case .smart:
            updateSmartProfile()

        case .custom:
            updateCustomProfile()
        }
    }

    // MARK: - Smart Profile (temperature + power aware)

    private func updateSmartProfile() {
        guard let monitor = systemMonitor else { return }

        let cpuTemp = monitor.cpuTemperature ?? 0
        let gpuTemp = monitor.gpuTemperature ?? 0
        let maxTemp = max(cpuTemp, gpuTemp)
        guard maxTemp > 0 else { return }

        let systemWatts = abs(monitor.totalSystemWatts ?? 0)
        let wattBoost = min(1.0, systemWatts / 40.0) * 8.0
        let effectiveTemp = min(maxTemp + wattBoost, 105.0)

        let tempFloor = 35.0
        let tempCeiling = 92.0
        let ratio = max(0.0, min(1.0, (effectiveTemp - tempFloor) / (tempCeiling - tempFloor)))
        let tempBasedSpeed = Double(minSpeed) + Double(autoMaxSpeed - minSpeed) * ratio

        let response = autoAggressiveness
        let midpoint = 1.5
        let target: Double

        if response <= midpoint {
            let blend = response / midpoint
            target = Double(minSpeed) * (1.0 - blend) + tempBasedSpeed * blend
        } else {
            let blend = (response - midpoint) / (3.0 - midpoint)
            target = tempBasedSpeed * (1.0 - blend) + Double(autoMaxSpeed) * blend
        }

        let finalSpeed = Int(max(Double(minSpeed), min(Double(autoMaxSpeed), target)))
        if abs(finalSpeed - lastAppliedSpeed) >= 50 || lastAppliedSpeed == 0 {
            applyFanSpeed(finalSpeed)
            lastAppliedSpeed = finalSpeed
            let tempStr = gpuTemp > cpuTemp
                ? String(format: "GPU %.0f°C", gpuTemp)
                : String(format: "CPU %.0f°C", cpuTemp)
            statusMessage = "Smart: \(finalSpeed) RPM (\(tempStr))"
        }
    }

    // MARK: - Custom Profile

    private func updateCustomProfile() {
        guard let monitor = systemMonitor else { return }
        guard let preset = customPreset else {
            let message = customPresetLastError ?? "No custom preset has been saved yet."
            statusMessage = "Custom preset unavailable: \(message)"
            customPresetStatus = message
            return
        }

        let cpuTemp = monitor.cpuTemperature ?? 0
        let gpuTemp = monitor.gpuTemperature ?? 0

        let baseTemperature: Double
        let sensorLabel: String
        switch preset.sensor {
        case .cpu:
            baseTemperature = cpuTemp
            sensorLabel = "CPU"
        case .gpu:
            baseTemperature = gpuTemp
            sensorLabel = "GPU"
        case .max:
            baseTemperature = max(cpuTemp, gpuTemp)
            sensorLabel = gpuTemp > cpuTemp ? "GPU" : "CPU"
        }

        guard baseTemperature > 0 else {
            statusMessage = "Custom preset waiting for live temperature data"
            return
        }

        let powerBoost = resolvedPowerBoost(for: preset, monitor: monitor)
        let effectiveTemperature = min(baseTemperature + powerBoost, 120)
        let percent = max(0, min(100, preset.interpolatedSpeedPercent(for: effectiveTemperature)))

        let fanCount = max(resolvedFanCount(), 1)
        let fallbackMin = monitor.fanMinSpeeds.first ?? minSpeed
        let fallbackMax = monitor.fanMaxSpeeds.first ?? maxSpeed
        let presetMin = max(preset.minimumRPM ?? fallbackMin, minSpeed)
        let presetMax = min(preset.maximumRPM ?? fallbackMax, maxSpeed)
        let safeMin = min(presetMin, presetMax)
        let safeMax = max(presetMin, presetMax)
        let targetBaseRPM = Int((Double(safeMin) + (Double(safeMax - safeMin) * (percent / 100.0))).rounded())

        let smoothingStep = preset.resolvedSmoothingStepRPM
        let smoothedTarget: Int
        if smoothingStep > 0 && lastAppliedSpeed > 0 {
            let delta = targetBaseRPM - lastAppliedSpeed
            if abs(delta) > smoothingStep {
                smoothedTarget = lastAppliedSpeed + (delta > 0 ? smoothingStep : -smoothingStep)
            } else {
                smoothedTarget = targetBaseRPM
            }
        } else {
            smoothedTarget = targetBaseRPM
        }

        let offsets = preset.resolvedPerFanOffsets
        let requestedSpeeds = (0..<fanCount).map { index in
            smoothedTarget + (index < offsets.count ? offsets[index] : 0)
        }

        if abs(smoothedTarget - lastAppliedSpeed) >= 50 || lastAppliedSpeed == 0 {
            _ = applyPerFanSpeeds(requestedSpeeds, successMessage: "Custom: \(preset.name)")
            lastAppliedSpeed = smoothedTarget
        }

        customPresetStatus = "Loaded \"\(preset.name)\" from \(customPresetFilePath)"
        statusMessage = String(
            format: "Custom: %@ %.0f°C → %d RPM",
            sensorLabel,
            effectiveTemperature,
            smoothedTarget
        )
    }

    private func resolvedPowerBoost(for preset: CustomFanPreset, monitor: SystemMonitor) -> Double {
        guard let powerBoost = preset.powerBoost, powerBoost.enabled else { return 0 }
        let watts = abs(monitor.totalSystemWatts ?? 0)
        let ratio = min(max(watts / max(powerBoost.wattsAtMaxBoost, 0.1), 0), 1)
        return ratio * powerBoost.maxAddedTemperatureC
    }

    // MARK: - Fixed Percent Profile

    private func applyFixedPercentProfile(_ percent: Double, label: String) {
        guard let monitor = systemMonitor else { return }
        let fanCount = resolvedFanCount()
        guard fanCount > 0 else {
            statusMessage = helperUnavailableMessage()
            return
        }

        let firstMax = monitor.fanMaxSpeeds.first ?? maxSpeed
        let target = Int((Double(firstMax) * percent).rounded())
        if abs(target - lastAppliedSpeed) >= 50 || lastAppliedSpeed == 0 {
            applyFanSpeed(target)
            lastAppliedSpeed = target
        }
        statusMessage = "\(label): \(target) RPM"
    }

    // MARK: - Speed Application

    private func applyFanSpeed(_ speed: Int) {
        let fanCount = max(resolvedFanCount(), 1)
        let speeds = Array(repeating: speed, count: fanCount)
        _ = applyPerFanSpeeds(speeds, successMessage: "Applied \(speed) RPM")
    }

    @discardableResult
    private func applyPerFanSpeeds(_ requestedSpeeds: [Int], successMessage: String?) -> Bool {
        guard let monitor = systemMonitor else { return false }
        let fanCount = resolvedFanCount()
        guard fanCount > 0 else {
            statusMessage = helperUnavailableMessage()
            return false
        }
        guard ensureHelperInstalledIfNeeded() else { return false }

        var allSuccess = true
        for fanID in 0..<fanCount {
            let perFanMin = fanID < monitor.fanMinSpeeds.count ? monitor.fanMinSpeeds[fanID] : minSpeed
            let perFanMax = fanID < monitor.fanMaxSpeeds.count ? monitor.fanMaxSpeeds[fanID] : maxSpeed
            let requested = fanID < requestedSpeeds.count ? requestedSpeeds[fanID] : (requestedSpeeds.last ?? requestedSpeeds.first ?? minSpeed)
            let clamped = max(perFanMin, min(perFanMax, requested))
            if !runSmcHelper(arguments: ["set", "\(fanID)", "\(clamped)"]) {
                allSuccess = false
            }
        }

        if allSuccess {
            statusMessage = successMessage ?? "Applied fan speeds"
        } else {
            statusMessage = "Failed to apply fan speed"
        }

        return allSuccess
    }

    private func canActivatePrivilegedMode() -> Bool {
        guard ensureHelperInstalledIfNeeded() else { return false }
        guard resolvedFanCount() > 0 else {
            statusMessage = helperUnavailableMessage()
            return false
        }
        return true
    }

    // MARK: - Helper Execution

    private func runSmcHelper(arguments: [String]) -> Bool {
        let ok = helperManager.execute(arguments: arguments)
        if !ok, let message = helperManager.statusMessage {
            statusMessage = message
        }
        return ok
    }

    private func ensureHelperInstalledIfNeeded() -> Bool {
        let ok = helperManager.ensureInstalledIfNeeded()
        if !ok, let message = helperManager.statusMessage {
            statusMessage = message
        }
        return ok
    }

    private func resolvedFanCount() -> Int {
        if let monitor = systemMonitor, monitor.numberOfFans > 0 {
            return monitor.numberOfFans
        }

        if let directCount = helperManager.readValue(key: "FNum").map(Int.init), directCount > 0 {
            return directCount
        }

        for fanID in 0..<12 {
            let actualKey = String(format: "F%dAc", fanID)
            let minKey = String(format: "F%dMn", fanID)
            let maxKey = String(format: "F%dMx", fanID)
            if helperManager.readValue(key: actualKey) != nil ||
                helperManager.readValue(key: minKey) != nil ||
                helperManager.readValue(key: maxKey) != nil {
                return fanID + 1
            }
        }

        return 0
    }

    private func helperUnavailableMessage() -> String {
        if let monitor = systemMonitor, !monitor.hasSMCAccess {
            return helperManager.statusMessage ?? monitor.lastError ?? "SMC access unavailable."
        }
        return helperManager.statusMessage ?? "No fan detected"
    }

    private func passiveStatusMessage(for mode: FanControlMode) -> String {
        switch mode {
        case .automatic:
            return "System automatic mode is active"
        case .silent:
            return "Silent mode keeps the firmware fan curve in charge"
        case .balanced:
            return "Balanced mode is ready to target 60% fan speed"
        case .performance:
            return "Performance mode is ready to target 85% fan speed"
        case .max:
            return "Max mode is ready to target full fan speed"
        case .manual:
            return "Manual target: \(manualSpeed) RPM"
        case .smart:
            return "Smart mode is ready for helper-backed fan control"
        case .custom:
            return customPreset.map { "Custom preset ready: \($0.name)" } ?? "Custom mode needs a saved preset"
        }
    }

    private func fanCalibrationCandidateKeys() -> [String] {
        let fanSuffixes = [
            "Ac", "Mn", "Mx", "Tg", "Md", "Mt", "ID",
            "Sf", "Ss", "Fl", "Fc", "Fn", "F0", "F1",
            "F2", "F3", "F4", "F5", "F6", "F7", "F8",
            "F9", "S0", "S1", "S2", "S3", "M0", "M1"
        ]

        let fanKeys = (0..<10).flatMap { fanID in
            fanSuffixes.map { "F\(fanID)\($0)" }
        }

        let globalKeys = [
            "FNum", "FS! ", "FSW0", "FSW1", "FAdj", "FSts", "FSys",
            "FDrv", "FCal", "FSpd", "FMde", "FSet", "FTgt", "FMin"
        ]

        return fanKeys + globalKeys
    }

    // MARK: - Wake Notifications

    private func registerForWakeNotifications() {
        let center = NSWorkspace.shared.notificationCenter

        let wakeObserver = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.lastAppliedSpeed = 0
                self.applyCurrentMode(force: true)
                if self.mode != .automatic {
                    self.statusMessage = "Re-applied \(self.mode.title.lowercased()) after wake"
                }
            }
        }

        workspaceObservers.append(wakeObserver)
    }

    // MARK: - Preset IO

    private func customPresetFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base
            .appendingPathComponent("Core Monitor", isDirectory: true)
            .appendingPathComponent("custom-fan-preset.json", isDirectory: false)
    }

    private func loadCustomPresetFromDisk() {
        let url = customPresetFileURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            customPreset = nil
            customPresetSource = Self.defaultCustomPresetSource
            customPresetStatus = "No custom preset saved yet. Open the code editor to create one."
            customPresetLastError = nil
            needsCustomPresetRestart = false
            if mode == .custom {
                mode = .automatic
                saveSettings()
            }
            return
        }

        do {
            let source = try String(contentsOf: url, encoding: .utf8)
            let preset = try decodeCustomPreset(from: source)
            let validationErrors = preset.validationErrors(globalMinRPM: minSpeed, globalMaxRPM: maxSpeed)
            guard validationErrors.isEmpty else {
                throw NSError(domain: "CoreMonitor.CustomFanPreset", code: 2, userInfo: [NSLocalizedDescriptionKey: validationErrors.joined(separator: " ")])
            }
            customPreset = preset
            customPresetSource = try prettyPrintedJSONString(from: preset)
            customPresetStatus = "Loaded \"\(preset.name)\" from \(url.path)"
            customPresetLastError = nil
            needsCustomPresetRestart = false
        } catch {
            customPreset = nil
            customPresetSource = (try? String(contentsOf: url, encoding: .utf8)) ?? Self.defaultCustomPresetSource
            customPresetStatus = "Saved preset has errors."
            customPresetLastError = error.localizedDescription
            if mode == .custom {
                mode = .automatic
                saveSettings()
                statusMessage = "Custom preset failed to load. Fell back to system automatic."
            }
        }
    }

    private func decodeCustomPreset(from source: String) throws -> CustomFanPreset {
        let data = Data(source.utf8)
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(CustomFanPreset.self, from: data)
        } catch {
            let message = "JSON parse error: \(error.localizedDescription)"
            throw NSError(domain: "CoreMonitor.CustomFanPreset", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    private func prettyPrintedJSONString(from preset: CustomFanPreset) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(preset)
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - Settings Persistence

    private func loadSettings() {
        let defaults = UserDefaults.standard

        if let raw = defaults.string(forKey: "fanControlMode"),
           let savedMode = FanControlMode(rawValue: raw) {
            mode = savedMode
        } else {
            mode = Self.defaultMode
        }

        let savedSpeed = defaults.integer(forKey: "manualFanSpeed")
        if savedSpeed >= minSpeed && savedSpeed <= maxSpeed {
            manualSpeed = savedSpeed
        }

        let savedAggr = defaults.double(forKey: "autoAggressiveness")
        if savedAggr >= 0.0 && savedAggr <= 3.0 {
            autoAggressiveness = savedAggr
        }

        let savedMaxSpeed = defaults.integer(forKey: "autoMaxSpeed")
        if savedMaxSpeed >= minSpeed && savedMaxSpeed <= maxSpeed {
            autoMaxSpeed = savedMaxSpeed
        }
    }

    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(mode.rawValue, forKey: "fanControlMode")
        defaults.set(manualSpeed, forKey: "manualFanSpeed")
        defaults.set(autoAggressiveness, forKey: "autoAggressiveness")
        defaults.set(autoMaxSpeed, forKey: "autoMaxSpeed")
    }
}
