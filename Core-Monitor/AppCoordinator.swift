import Foundation
import Combine
import SwiftUI

@MainActor
final class AppCoordinator: ObservableObject {
    private enum TouchBarMode: String {
        case app
        case system
    }

    let systemMonitor: SystemMonitor
    let fanController: FanController
    let coreVisorManager: CoreVisorManager

    private let touchBarPresenter = TouchBarPrivatePresenter()
    private var touchBarTimer: Timer?
    private var vmBoostObserver: AnyCancellable?
    private let touchBarModeKey = "coremonitor.touchBarMode"

    // Rolling histories (0–100 normalised)
    private var cpuUsageHistory: [Double] = []
    private var cpuTempHistory:  [Double] = []
    private var memUsageHistory: [Double] = []
    private var fanHistory:      [Double] = []
    private let historyLimit = 28

    init() {
        let monitor = SystemMonitor()
        self.systemMonitor = monitor
        self.fanController = FanController(systemMonitor: monitor)
        self.coreVisorManager = CoreVisorManager()
        start()
    }

    nonisolated deinit { }

    // MARK: - Lifecycle

    func start() {
        systemMonitor.startMonitoring()
        applySavedTouchBarMode()

        vmBoostObserver = coreVisorManager.$machineStates
            .receive(on: RunLoop.main)
            .sink { [weak self] states in
                guard let self else { return }
                let anyRunning = states.values.contains { $0 == .running || $0 == .starting }
                self.fanController.setVMBoost(anyRunning)
            }
    }

    func stop() {
        stopAppTouchBar()
        systemMonitor.stopMonitoring()
        vmBoostObserver?.cancel()
    }

    func revertToSystemTouchBar() {
        saveTouchBarMode(.system)
        stopAppTouchBar()
    }

    func revertToAppTouchBar() {
        saveTouchBarMode(.app)
        startAppTouchBar()
    }

    // MARK: - Push Touch Bar update

    private func pushTouchBarUpdate() {
        let cpuUsage = max(0, min(100, systemMonitor.cpuUsagePercent))
        let cpuTemp  = systemMonitor.cpuTemperature.map { max(0, min(120, $0)) }
        let memUsage = max(0, min(100, systemMonitor.memoryUsagePercent))

        let fanRPM  = systemMonitor.fanSpeeds.first ?? 0
        let fanMin  = Double(systemMonitor.fanMinSpeeds.first  ?? fanController.minSpeed)
        let fanMax  = Double(systemMonitor.fanMaxSpeeds.first  ?? fanController.maxSpeed)
        let fanFrac = max(0, min(1, (Double(fanRPM) - fanMin) / max(1, fanMax - fanMin)))

        append(&cpuUsageHistory, cpuUsage)
        append(&cpuTempHistory,  cpuTemp.map { $0 / 120.0 * 100.0 } ?? (cpuTempHistory.last ?? 0))
        append(&memUsageHistory, memUsage)
        append(&fanHistory,      fanFrac * 100)

        let vmCount = coreVisorManager.machines.filter {
            coreVisorManager.runtimeState(for: $0) == .running
        }.count

        touchBarPresenter.updateMetrics(
            cpuPercent:  cpuUsage,
            cpuTempC:    cpuTemp,
            memPercent:  memUsage,
            memPressure: systemMonitor.memoryPressure,
            fanRPM:      fanRPM,
            fanFrac:     fanFrac,
            vmCount:     vmCount,
            cpuHistory:  cpuUsageHistory,
            memHistory:  memUsageHistory,
            fanHistory:  fanHistory,
            volume:      systemMonitor.currentVolume,
            brightness:  systemMonitor.currentBrightness
        )
    }

    private func append(_ history: inout [Double], _ value: Double) {
        history.append(value)
        if history.count > historyLimit {
            history.removeFirst(history.count - historyLimit)
        }
    }

    private func applySavedTouchBarMode() {
        switch savedTouchBarMode {
        case .app:
            startAppTouchBar()
        case .system:
            stopAppTouchBar()
        }
    }

    private func startAppTouchBar() {
        touchBarPresenter.present()
        pushTouchBarUpdate()

        touchBarTimer?.invalidate()
        touchBarTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pushTouchBarUpdate()
            }
        }
        touchBarTimer?.tolerance = 0.25
    }

    private func stopAppTouchBar() {
        touchBarTimer?.invalidate()
        touchBarTimer = nil
        touchBarPresenter.dismiss()
    }

    private var savedTouchBarMode: TouchBarMode {
        let raw = UserDefaults.standard.string(forKey: touchBarModeKey) ?? TouchBarMode.app.rawValue
        return TouchBarMode(rawValue: raw) ?? .app
    }

    private func saveTouchBarMode(_ mode: TouchBarMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: touchBarModeKey)
    }
}
