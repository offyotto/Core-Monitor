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
    case automatic

    static var quickModes: [FanControlMode] {
        [.smart, .silent, .balanced, .performance, .max, .manual, .automatic]
    }

    var title: String {
        switch self {
        case .smart:       return "SMART"
        case .silent:      return "SILENT"
        case .balanced:    return "BALANCED"
        case .performance: return "PERFORMANCE"
        case .max:         return "MAX"
        case .manual:      return "MANUAL"
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
        case .automatic:   return "SYSTEM"
        }
    }

    var usesManualSlider: Bool { self == .manual }
    var isManagedProfile: Bool { self != .manual && self != .automatic }
}

// MARK: - Fan Controller

@MainActor
final class FanController: ObservableObject {
    @Published var mode: FanControlMode = .smart
    @Published var manualSpeed: Int = 2200
    @Published var autoAggressiveness: Double = 1.5
    @Published var autoMaxSpeed: Int = 6500
    @Published var statusMessage: String = "Idle"
    @Published var calibrationStatus: String = "Not calibrated"
    @Published var isCalibrating: Bool = false

    let minSpeed = 1000
    let maxSpeed = 6500

    private weak var systemMonitor: SystemMonitor?
    private var controlTimer: Timer?
    private var lastAppliedSpeed: Int = 0
    private let helperManager = SMCHelperManager.shared
    private var workspaceObservers: [NSObjectProtocol] = []

    init(systemMonitor: SystemMonitor) {
        self.systemMonitor = systemMonitor
        loadSettings()
        registerForWakeNotifications()
    }

    deinit {
        controlTimer?.invalidate()
        controlTimer = nil
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    // MARK: - Public API

    func setMode(_ mode: FanControlMode) {
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
        calibrationStatus = "Calibrating fan SMC keys 0/\(keys.count)"

        Task { @MainActor [weak self] in
            guard let self else { return }
            var responsiveKeys: [String] = []

            for (index, key) in keys.enumerated() {
                if helperManager.readValue(key: key) != nil {
                    responsiveKeys.append(key)
                }

                let completed = index + 1
                calibrationStatus = "Calibrating fan SMC keys \(completed)/\(keys.count) - \(responsiveKeys.count) responsive"
                if completed % 8 == 0 {
                    await Task.yield()
                }
            }

            let preview = responsiveKeys.prefix(10).joined(separator: ", ")
            calibrationStatus = responsiveKeys.isEmpty
                ? "Fan calibration finished: 0/\(keys.count) keys responded"
                : "Fan calibration finished: \(responsiveKeys.count)/\(keys.count) keys responded - \(preview)"
            statusMessage = calibrationStatus
            isCalibrating = false
        }
    }

    // MARK: - Control Loop

    private func startControlLoop() {
        stopControlLoop()
        updateManagedControl()

        controlTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateManagedControl()
            }
        }

        if let controlTimer {
            controlTimer.tolerance = 0.3
            RunLoop.current.add(controlTimer, forMode: .common)
        }
    }

    private func stopControlLoop() {
        controlTimer?.invalidate()
        controlTimer = nil
    }

    private func applyCurrentMode(force: Bool = false) {
        if force { stopControlLoop() }

        switch mode {
        case .automatic:
            resetToSystemAutomatic()
            statusMessage = "System automatic control restored"
        case .manual:
            applyFanSpeed(manualSpeed)
            lastAppliedSpeed = manualSpeed
            statusMessage = "Manual: \(manualSpeed) RPM"
            startControlLoop()
        case .silent, .smart, .balanced, .performance, .max:
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
            // Silent delegates entirely to the system SMC auto curve
            if lastAppliedSpeed != -1 {
                resetToSystemAutomatic()
                lastAppliedSpeed = -1
            }
            statusMessage = "Silent: system automatic"

        case .balanced:
            applyFixedPercentProfile(0.60, label: "Balanced")

        case .performance:
            applyFixedPercentProfile(0.85, label: "Performance")

        case .max:
            applyFixedPercentProfile(1.0, label: "Max")

        case .smart:
            updateSmartProfile()
        }
    }

    // MARK: - Smart Profile (temperature + power aware)

    private func updateSmartProfile() {
        guard let monitor = systemMonitor else { return }

        let cpuTemp = monitor.cpuTemperature ?? 0
        let gpuTemp = monitor.gpuTemperature ?? 0
        let maxTemp = max(cpuTemp, gpuTemp)
        guard maxTemp > 0 else { return }

        // Boost target based on system power draw (ffan-style watts aware)
        let systemWatts = abs(monitor.totalSystemWatts ?? 0)
        let wattBoost   = min(1.0, systemWatts / 40.0) * 8.0

        let effectiveTemp = min(maxTemp + wattBoost, 105.0)

        // Temperature curve: 35°C floor, 92°C ceiling
        let tempFloor   = 35.0
        let tempCeiling = 92.0
        let ratio = max(0.0, min(1.0, (effectiveTemp - tempFloor) / (tempCeiling - tempFloor)))
        let tempBasedSpeed = Double(minSpeed) + Double(autoMaxSpeed - minSpeed) * ratio

        // ffan blending architecture:
        //   aggressiveness 0.0 → always min speed
        //   aggressiveness 1.5 → pure temperature-based
        //   aggressiveness 3.0 → always max speed
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
        guard let monitor = systemMonitor else { return }
        let fanCount = resolvedFanCount()
        guard fanCount > 0 else {
            statusMessage = helperUnavailableMessage()
            return
        }
        guard ensureHelperInstalledIfNeeded() else { return }

        var allSuccess = true
        for fanID in 0..<fanCount {
            let perFanMin = fanID < monitor.fanMinSpeeds.count ? monitor.fanMinSpeeds[fanID] : minSpeed
            let perFanMax = fanID < monitor.fanMaxSpeeds.count ? monitor.fanMaxSpeeds[fanID] : maxSpeed
            let clamped = max(perFanMin, min(perFanMax, speed))
            if !runSmcHelper(arguments: ["set", "\(fanID)", "\(clamped)"]) {
                allSuccess = false
            }
        }

        if allSuccess {
            statusMessage = "Applied \(speed) RPM"
        } else {
            statusMessage = "Failed to apply fan speed"
        }
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

    // MARK: - Settings Persistence

    private func loadSettings() {
        let defaults = UserDefaults.standard

        if let raw = defaults.string(forKey: "fanControlMode"),
           let savedMode = FanControlMode(rawValue: raw) {
            mode = savedMode
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
