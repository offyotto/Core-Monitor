import Foundation
import Combine
import SwiftUI

enum TouchBarWidgetPreset: String, CaseIterable, Identifiable {
    case virtualMachines
    case battery
    case power
    case volume
    case brightness
    case fanMode

    var id: String { rawValue }

    var title: String {
        switch self {
        case .virtualMachines: return "Virtual Machines"
        case .battery: return "Battery"
        case .power: return "Power"
        case .volume: return "Volume"
        case .brightness: return "Brightness"
        case .fanMode: return "Fan Mode"
        }
    }
}

@MainActor
final class TouchBarWidgetSettings: ObservableObject {
    @Published var selectedPreset: TouchBarWidgetPreset {
        didSet {
            UserDefaults.standard.set(selectedPreset.rawValue, forKey: Self.selectedPresetKey)
        }
    }

    private static let selectedPresetKey = "coremonitor.touchBarWidgetPreset"

    init() {
        let rawValue = UserDefaults.standard.string(forKey: Self.selectedPresetKey)
        selectedPreset = TouchBarWidgetPreset(rawValue: rawValue ?? "") ?? .virtualMachines
    }
}

@MainActor
final class AppCoordinator: ObservableObject {
    private enum TouchBarMode: String {
        case app
        case system
    }

    let systemMonitor: SystemMonitor
    let fanController: FanController
    let coreVisorManager: CoreVisorManager
    let touchBarWidgetSettings = TouchBarWidgetSettings()

    private let touchBarPresenter = TouchBarPrivatePresenter()
    private var touchBarTimer: Timer?
    private var vmBoostObserver: AnyCancellable?
    private var touchBarWidgetObserver: AnyCancellable?
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

        touchBarWidgetObserver = touchBarWidgetSettings.$selectedPreset
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.pushTouchBarUpdate()
            }
    }

    func stop() {
        stopAppTouchBar()
        systemMonitor.stopMonitoring()
        vmBoostObserver?.cancel()
        touchBarWidgetObserver?.cancel()
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
        let batteryPercent = systemMonitor.batteryInfo.chargePercent
        let customWidget = touchBarCustomWidget(vmCount: vmCount, batteryPercent: batteryPercent)

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
            customWidget: customWidget,
            volume:      systemMonitor.currentVolume,
            brightness:  systemMonitor.currentBrightness
        )
    }

    private func touchBarCustomWidget(vmCount: Int, batteryPercent: Int?) -> TouchBarCustomWidget {
        switch touchBarWidgetSettings.selectedPreset {
        case .virtualMachines:
            return TouchBarCustomWidget(
                label: "VM",
                value: "\(vmCount) VM\(vmCount == 1 ? "" : "s")",
                symbolName: "server.rack",
                color: .systemOrange,
                alerting: false
            )
        case .battery:
            let value: String
            if let batteryPercent {
                value = "\(batteryPercent)%\(systemMonitor.batteryInfo.isCharging ? " charging" : "")"
            } else {
                value = "No battery"
            }
            let color: NSColor = {
                guard let batteryPercent else { return .systemGray }
                if batteryPercent < 20 { return .systemRed }
                if batteryPercent < 40 { return .systemOrange }
                return systemMonitor.batteryInfo.isCharging ? .systemYellow : .systemGreen
            }()
            return TouchBarCustomWidget(
                label: "BAT",
                value: value,
                symbolName: systemMonitor.batteryInfo.isCharging ? "battery.100.bolt" : "battery.75",
                color: color,
                alerting: (batteryPercent ?? 100) < 15
            )
        case .power:
            let watts = systemMonitor.totalSystemWatts.map { abs($0) }
            return TouchBarCustomWidget(
                label: "PWR",
                value: watts.map { String(format: "%.1f W", $0) } ?? "--",
                symbolName: "bolt.fill",
                color: .systemBlue,
                alerting: (watts ?? 0) > 90
            )
        case .volume:
            let percent = Int((systemMonitor.currentVolume * 100).rounded())
            return TouchBarCustomWidget(
                label: "VOL",
                value: "\(percent)%",
                symbolName: percent == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill",
                color: .systemYellow,
                alerting: false
            )
        case .brightness:
            let percent = Int((systemMonitor.currentBrightness * 100).rounded())
            return TouchBarCustomWidget(
                label: "BRT",
                value: "\(percent)%",
                symbolName: "sun.max.fill",
                color: .systemBlue,
                alerting: false
            )
        case .fanMode:
            let color: NSColor = (fanController.mode == .manual || fanController.mode == .max)
                ? .systemOrange
                : .systemTeal
            return TouchBarCustomWidget(
                label: "MODE",
                value: fanController.mode.shortTitle,
                symbolName: "fanblades.fill",
                color: color,
                alerting: fanController.mode == .manual || fanController.mode == .max
            )
        }
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
        touchBarTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pushTouchBarUpdate()
            }
        }
        touchBarTimer?.tolerance = 0.15
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
