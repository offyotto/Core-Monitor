import Foundation
import Combine

enum FanControlMode: String, CaseIterable {
    case manual
    case automatic
}

final class FanController: ObservableObject {
    @Published var mode: FanControlMode = .manual
    @Published var manualSpeed: Int = 2200
    @Published var autoAggressiveness: Double = 1.5
    @Published var autoMaxSpeed: Int = 6500
    @Published var statusMessage: String = "Idle"
    /// When true, auto mode adds +0.5 to aggressiveness to compensate for VM thermal load.
    @Published private(set) var vmBoostActive: Bool = false

    let minSpeed = 1000
    let maxSpeed = 6500

    private weak var systemMonitor: SystemMonitor?
    private var autoTimer: Timer?
    private var lastAppliedSpeed: Int = 0
    private let helperManager = SMCHelperManager.shared
    private var baseAggressiveness: Double = 1.5  // user's chosen value, pre-boost

    init(systemMonitor: SystemMonitor) {
        self.systemMonitor = systemMonitor
    }

    deinit {
        stopAutoControl()
    }

    func setMode(_ mode: FanControlMode) {
        self.mode = mode

        if mode == .automatic {
            resetToSystemAutomatic()
            startAutoControl()
        } else {
            stopAutoControl()
            applyFanSpeed(manualSpeed)
        }
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
        if mode == .automatic {
            lastAppliedSpeed = 0
            updateAutoControl()
        }
    }

    /// Called by AppCoordinator when VMs start/stop to bump fan aggressiveness.
    func setVMBoost(_ active: Bool) {
        guard vmBoostActive != active else { return }
        vmBoostActive = active
        autoAggressiveness = active
            ? min(3.0, baseAggressiveness + 0.5)
            : baseAggressiveness
        if mode == .automatic {
            lastAppliedSpeed = 0
            updateAutoControl()
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

    private func startAutoControl() {
        stopAutoControl()
        updateAutoControl()

        autoTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateAutoControl()
        }

        if let autoTimer {
            RunLoop.current.add(autoTimer, forMode: .common)
        }
    }

    private func stopAutoControl() {
        autoTimer?.invalidate()
        autoTimer = nil
    }

    private func updateAutoControl() {
        guard mode == .automatic, let monitor = systemMonitor else { return }

        // Use the highest thermal signal across CPU and GPU
        let cpuTemp  = monitor.cpuTemperature ?? 0
        let gpuTemp  = monitor.gpuTemperature ?? 0
        let maxTemp  = max(cpuTemp, gpuTemp)
        guard maxTemp > 0 else { return }

        // Watt-based pre-heat: if the chip is drawing hard, ramp up earlier
        let systemWatts   = abs(monitor.totalSystemWatts ?? 0)
        let wattBoost     = min(1.0, systemWatts / 40.0) * 8.0  // up to +8 °C equivalent

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
            statusMessage = "Auto: \(finalSpeed) RPM (\(tempStr))"
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

    private func runSmcHelper(arguments: [String]) -> Bool {
        let ok = helperManager.execute(arguments: arguments, allowPrivilegePrompt: true)
        if !ok, let message = helperManager.statusMessage {
            statusMessage = message
        }
        return ok
    }
}

