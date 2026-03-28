import Foundation
import Combine
import AppKit

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
        case .smart: return "SMART"
        case .silent: return "SILENT"
        case .balanced: return "BALANCED"
        case .performance: return "PERFORMANCE"
        case .max: return "MAX"
        case .manual: return "MANUAL"
        case .automatic: return "SYSTEM"
        }
    }

    var shortTitle: String {
        switch self {
        case .smart: return "SMART"
        case .silent: return "SILENT"
        case .balanced: return "BAL"
        case .performance: return "PERF"
        case .max: return "MAX"
        case .manual: return "MANUAL"
        case .automatic: return "SYSTEM"
        }
    }

    var usesManualSlider: Bool { self == .manual }
    var isManagedProfile: Bool { self != .manual && self != .automatic }
}

@MainActor
final class FanController: ObservableObject {
    @Published var mode: FanControlMode = .smart
    @Published var manualSpeed: Int = 2200
    @Published var autoAggressiveness: Double = 1.5
    @Published var autoMaxSpeed: Int = 6500
    @Published var statusMessage: String = "Idle"
    /// When true, auto mode adds +0.5 to aggressiveness to compensate for VM thermal load.
    @Published private(set) var vmBoostActive: Bool = false
    let minSpeed = 1000
    let maxSpeed = 6500

    private weak var systemMonitor: SystemMonitor?
    private var controlTimer: Timer?
    private var lastAppliedSpeed: Int = 0
    private let helperManager = SMCHelperManager.shared
    private var baseAggressiveness: Double = 1.5  // user's chosen value, pre-boost
    private var workspaceObservers: [NSObjectProtocol] = []
    init(systemMonitor: SystemMonitor) {
        self.systemMonitor = systemMonitor
        registerForWakeNotifications()
    }

    deinit {
        controlTimer?.invalidate()
        controlTimer = nil
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    func setMode(_ mode: FanControlMode) {
        self.mode = mode
        lastAppliedSpeed = 0
        applyCurrentMode(force: true)
    }

    func setManualSpeed(_ speed: Int) {
        manualSpeed = max(minSpeed, min(maxSpeed, speed))
        guard mode == .manual else { return }
        applyFanSpeed(manualSpeed)
    }

    func setAutoAggressiveness(_ value: Double) {
        baseAggressiveness = max(0.0, min(3.0, value))
        autoAggressiveness = vmBoostActive
            ? min(3.0, baseAggressiveness + 0.5)
            : baseAggressiveness
        if mode == .smart {
            lastAppliedSpeed = 0
            updateManagedControl()
        }
    }

    /// Called by AppCoordinator when VMs start/stop to bump fan aggressiveness.
    func setVMBoost(_ active: Bool) {
        guard vmBoostActive != active else { return }
        vmBoostActive = active
        autoAggressiveness = active
            ? min(3.0, baseAggressiveness + 0.5)
            : baseAggressiveness
        if mode == .smart {
            lastAppliedSpeed = 0
            updateManagedControl()
        }
    }

    func resetToSystemAutomatic() {
        guard let monitor = systemMonitor, monitor.numberOfFans > 0 else { return }
        var allSuccess = true
        for fanID in 0..<monitor.numberOfFans {
            if !runSmcHelper(arguments: ["auto", "\(fanID)"]) {
                allSuccess = false
            }
        }
        statusMessage = allSuccess ? "System automatic control restored" : "Failed to restore automatic control"
    }

    private func startControlLoop() {
        stopControlLoop()
        updateManagedControl()

        controlTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateManagedControl()
            }
        }

        if let controlTimer {
            RunLoop.current.add(controlTimer, forMode: .common)
        }
    }

    private func stopControlLoop() {
        controlTimer?.invalidate()
        controlTimer = nil
    }

    private func updateManagedControl() {
        guard let monitor = systemMonitor else { return }
        guard mode.isManagedProfile || mode == .manual || mode == .silent else { return }

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

    private func updateSmartProfile() {
        guard let monitor = systemMonitor else { return }

        let cpuTemp  = monitor.cpuTemperature ?? 0
        let gpuTemp  = monitor.gpuTemperature ?? 0
        let maxTemp  = max(cpuTemp, gpuTemp)
        guard maxTemp > 0 else { return }

        let systemWatts   = abs(monitor.totalSystemWatts ?? 0)
        let wattBoost     = min(1.0, systemWatts / 40.0) * 8.0

        let effectiveTemp = min(maxTemp + wattBoost, 105.0)

        let tempFloor   = 35.0
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

    private func applyFixedPercentProfile(_ percent: Double, label: String) {
        guard let monitor = systemMonitor, monitor.numberOfFans > 0 else {
            statusMessage = "No fan detected"
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

    private func applyCurrentMode(force: Bool = false) {
        if force {
            stopControlLoop()
        }

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

    private func applyFanSpeed(_ speed: Int) {
        guard let monitor = systemMonitor, monitor.numberOfFans > 0 else {
            statusMessage = "No fan detected"
            return
        }
        var allSuccess = true
        for fanID in 0..<monitor.numberOfFans {
            let perFanMin = fanID < monitor.fanMinSpeeds.count ? monitor.fanMinSpeeds[fanID] : minSpeed
            let perFanMax = fanID < monitor.fanMaxSpeeds.count ? monitor.fanMaxSpeeds[fanID] : maxSpeed
            let clamped = max(perFanMin, min(perFanMax, speed))
            if !runSmcHelper(arguments: ["set", "\(fanID)", "\(clamped)"]) {
                allSuccess = false
            }
        }
        statusMessage = allSuccess ? "Applied \(speed) RPM" : "Failed to apply fan speed"
    }

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

    private func runSmcHelper(arguments: [String]) -> Bool {
        let ok = helperManager.execute(arguments: arguments, allowPrivilegePrompt: true)
        if !ok, let message = helperManager.statusMessage {
            statusMessage = message
        }
        return ok
    }
}
