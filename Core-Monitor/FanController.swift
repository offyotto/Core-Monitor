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

    let minSpeed = 1000
    let maxSpeed = 6500

    private weak var systemMonitor: SystemMonitor?
    private var autoTimer: Timer?
    private var lastAppliedSpeed: Int = 0
    private let helperManager = SMCHelperManager.shared

    init(systemMonitor: SystemMonitor) {
        self.systemMonitor = systemMonitor
    }

    deinit {
        stopAutoControl()
    }

    func setMode(_ mode: FanControlMode) {
        self.mode = mode

        if mode == .automatic {
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
        autoAggressiveness = max(0.0, min(3.0, value))
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
        guard let cpuTemp = monitor.cpuTemperature else { return }

        let tempFloor = 30.0
        let tempCeiling = 90.0
        let ratio = max(0.0, min(1.0, (cpuTemp - tempFloor) / (tempCeiling - tempFloor)))
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
        }
    }

    private func applyFanSpeed(_ speed: Int) {
        guard let monitor = systemMonitor, monitor.numberOfFans > 0 else {
            statusMessage = "No fan detected"
            return
        }

        var allSuccess = true
        for fanID in 0..<monitor.numberOfFans {
            if !runSmcHelper(arguments: ["set", "\(fanID)", "\(speed)"]) {
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
