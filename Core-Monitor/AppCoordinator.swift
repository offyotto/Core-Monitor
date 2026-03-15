import Foundation
import Combine

final class AppCoordinator: ObservableObject {
    let systemMonitor: SystemMonitor
    let fanController: FanController

    private let touchBarPresenter = TouchBarPrivatePresenter()
    private var touchBarTimer: Timer?

    private var cpuUsageHistory: [Double] = []
    private var cpuTempHistory: [Double] = []
    private var memoryUsageHistory: [Double] = []
    private var fanHistory: [Double] = []
    private let touchBarHistoryLimit = 24

    init() {
        let monitor = SystemMonitor()
        self.systemMonitor = monitor
        self.fanController = FanController(systemMonitor: monitor)
        DispatchQueue.main.async { [weak self] in
            self?.start()
        }
    }

    deinit {
        stop()
    }

    func start() {
        systemMonitor.startMonitoring()
        touchBarPresenter.present()
        updateTouchBar()

        touchBarTimer?.invalidate()
        touchBarTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.updateTouchBar()
        }
        if let touchBarTimer {
            touchBarTimer.tolerance = 0.25
        }
    }

    func stop() {
        touchBarTimer?.invalidate()
        touchBarTimer = nil

        touchBarPresenter.dismiss()
        systemMonitor.stopMonitoring()
    }

    private func updateTouchBar() {
        let cpuUsage = max(0, min(100, systemMonitor.cpuUsagePercent))
        let cpuTemp = systemMonitor.cpuTemperature.map { max(0, min(120, $0)) }

        let memUsage = max(0, min(100, systemMonitor.memoryUsagePercent))
        let memPressure = memoryPressureEmoji(systemMonitor.memoryPressure)

        let fanRPM = Double(systemMonitor.fanSpeeds.first ?? 0)
        let fanMin = Double(systemMonitor.fanMinSpeeds.first ?? fanController.minSpeed)
        let fanMax = Double(systemMonitor.fanMaxSpeeds.first ?? fanController.maxSpeed)
        let fanRange = max(1, fanMax - fanMin)
        let fanPercent = max(0, min(100, ((fanRPM - fanMin) / fanRange) * 100))

        append(&cpuUsageHistory, cpuUsage)
        if let cpuTemp {
            append(&cpuTempHistory, cpuTemp)
        } else if let lastTemp = cpuTempHistory.last {
            append(&cpuTempHistory, lastTemp)
        }
        append(&memoryUsageHistory, memUsage)
        append(&fanHistory, fanPercent)

        let cpuTempText = cpuTemp.map { String(format: "%.0f°", $0) } ?? "--"
        let topText = "CPU \(cpuTempText) \(Int(cpuUsage.rounded()))%   MEM \(Int(memUsage.rounded()))% \(memPressure)   FAN \(Int(fanRPM.rounded()))rpm"

        let graphText = "T \(sparkline(cpuTempHistory, maxScale: 110))  M \(sparkline(memoryUsageHistory))  C \(sparkline(cpuUsageHistory))  F \(sparkline(fanHistory))"

        touchBarPresenter.update(topText: topText, graphText: graphText)
    }

    private func append(_ history: inout [Double], _ value: Double) {
        history.append(value)
        if history.count > touchBarHistoryLimit {
            history.removeFirst(history.count - touchBarHistoryLimit)
        }
    }

    private func memoryPressureEmoji(_ pressure: MemoryPressureLevel) -> String {
        switch pressure {
        case .green: return "🟢"
        case .yellow: return "🟡"
        case .red: return "🔴"
        }
    }

    private func sparkline(_ values: [Double], maxScale: Double = 100) -> String {
        let blocks = Array("▁▂▃▄▅▆▇█")
        guard !values.isEmpty else { return "------" }

        return values.suffix(8).map { value in
            let normalized = max(0, min(1, value / maxScale))
            let idx = Int((normalized * Double(blocks.count - 1)).rounded())
            return String(blocks[idx])
        }.joined()
    }
}
