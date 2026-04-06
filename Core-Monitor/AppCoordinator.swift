import AppKit
import Foundation
import Combine
import SwiftUI

enum TouchBarWidgetPreset: String, CaseIterable, Identifiable {
    case battery
    case power
    case volume
    case brightness
    case fanMode
    case nowPlaying

    var id: String { rawValue }

    var title: String {
        switch self {
        case .battery: return "Battery"
        case .power: return "Power"
        case .volume: return "Volume"
        case .brightness: return "Brightness"
        case .fanMode: return "Fan Mode"
        case .nowPlaying: return "Now Playing"
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
        selectedPreset = .nowPlaying
        UserDefaults.standard.set(TouchBarWidgetPreset.nowPlaying.rawValue, forKey: Self.selectedPresetKey)
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
    let touchBarWidgetSettings = TouchBarWidgetSettings()

    private let touchBarPresenter = TouchBarPrivatePresenter()
    private var touchBarTimer: Timer?
    private var touchBarWidgetObserver: AnyCancellable?
    private let touchBarModeKey = "coremonitor.touchBarMode"
    private let touchBarModeMigrationKey = "coremonitor.touchBarMode.pockMigrationV1"
    private var launchObserver: NSObjectProtocol?
    private var activationObserver: NSObjectProtocol?
    private var terminateObserver: NSObjectProtocol?
    private var bootstrapWorkItem: DispatchWorkItem?

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
        start()
    }

    nonisolated deinit { }

    // MARK: - Lifecycle

    func start() {
        systemMonitor.startMonitoring()
        normalizeTouchBarModePreference()
        installTouchBarBootstrapObservers()
        applySavedTouchBarMode()

        touchBarWidgetObserver = touchBarWidgetSettings.$selectedPreset
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.pushTouchBarUpdate()
            }
    }

    func stop() {
        bootstrapWorkItem?.cancel()
        bootstrapWorkItem = nil
        if let launchObserver {
            NotificationCenter.default.removeObserver(launchObserver)
            self.launchObserver = nil
        }
        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
            self.activationObserver = nil
        }
        if let terminateObserver {
            NotificationCenter.default.removeObserver(terminateObserver)
            self.terminateObserver = nil
        }
        stopAppTouchBar()
        systemMonitor.stopMonitoring()
        touchBarWidgetObserver?.cancel()
    }

    func revertToSystemTouchBar() {
        saveTouchBarMode(.system)
        touchBarPresenter.dismissToSystemTouchBar()
        touchBarTimer?.invalidate()
        touchBarTimer = nil
    }

    func revertToAppTouchBar() {
        saveTouchBarMode(.app)
        startAppTouchBar()
    }

    func attachTouchBar(to window: NSWindow) {
        touchBarPresenter.attach(to: window)
        if savedTouchBarMode == .app {
            startAppTouchBar()
        } else {
            stopAppTouchBar()
        }
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

        let batteryPercent = systemMonitor.batteryInfo.chargePercent
        let customWidget = touchBarCustomWidget(batteryPercent: batteryPercent)

        touchBarPresenter.updateMetrics(
            cpuPercent:  cpuUsage,
            cpuTempC:    cpuTemp,
            memPercent:  memUsage,
            memPressure: systemMonitor.memoryPressure,
            fanRPM:      fanRPM,
            fanFrac:     fanFrac,
            cpuHistory:  cpuUsageHistory,
            memHistory:  memUsageHistory,
            fanHistory:  fanHistory,
            customWidget: customWidget,
            volume:      systemMonitor.currentVolume,
            brightness:  systemMonitor.currentBrightness,
            netBytesIn:  systemMonitor.netBytesInPerSec,
            netBytesOut: systemMonitor.netBytesOutPerSec,
            diskReadBPS: systemMonitor.diskReadBytesPerSec,
            diskWriteBPS: systemMonitor.diskWriteBytesPerSec
        )
    }

    private func touchBarCustomWidget(batteryPercent: Int?) -> TouchBarCustomWidget {
        switch touchBarWidgetSettings.selectedPreset {
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
                secondaryValue: nil,
                symbolName: systemMonitor.batteryInfo.isCharging ? "battery.100.bolt" : "battery.75",
                color: color,
                alerting: (batteryPercent ?? 100) < 15,
                style: .symbol,
                artwork: nil
            )
        case .power:
            let watts = systemMonitor.totalSystemWatts.map { abs($0) }
            return TouchBarCustomWidget(
                label: "PWR",
                value: watts.map { String(format: "%.1f W", $0) } ?? "--",
                secondaryValue: nil,
                symbolName: "bolt.fill",
                color: .systemBlue,
                alerting: (watts ?? 0) > 90,
                style: .symbol,
                artwork: nil
            )
        case .volume:
            let percent = Int((systemMonitor.currentVolume * 100).rounded())
            return TouchBarCustomWidget(
                label: "VOL",
                value: "\(percent)%",
                secondaryValue: nil,
                symbolName: percent == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill",
                color: .systemYellow,
                alerting: false,
                style: .volumeSlider,
                artwork: nil
            )
        case .brightness:
            let percent = Int((systemMonitor.currentBrightness * 100).rounded())
            return TouchBarCustomWidget(
                label: "BRT",
                value: "\(percent)%",
                secondaryValue: nil,
                symbolName: "sun.max.fill",
                color: .systemBlue,
                alerting: false,
                style: .symbol,
                artwork: nil
            )
        case .fanMode:
            let color: NSColor = (fanController.mode == .manual || fanController.mode == .max)
                ? .systemOrange
                : .systemTeal
            return TouchBarCustomWidget(
                label: "MODE",
                value: fanController.mode.shortTitle,
                secondaryValue: nil,
                symbolName: "fanblades.fill",
                color: color,
                alerting: fanController.mode == .manual || fanController.mode == .max,
                style: .symbol,
                artwork: nil
            )
        case .nowPlaying:
            let nowPlaying = SystemNowPlayingBridge.snapshot()
            return TouchBarCustomWidget(
                label: "NOW",
                value: nowPlaying?.title ?? "Nothing Playing",
                secondaryValue: nowPlaying?.subtitle,
                symbolName: "music.note",
                color: .white,
                alerting: false,
                style: .nowPlaying,
                artwork: nowPlaying?.artwork
            )
        }
    }

    private func append(_ history: inout [Double], _ value: Double) {
        history.append(value)
        if history.count > historyLimit {
            history.removeFirst(history.count - historyLimit)
        }
    }

    private func normalizeTouchBarModePreference() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: touchBarModeMigrationKey) == false else { return }
        if savedTouchBarMode == .system {
            saveTouchBarMode(.app)
        }
        defaults.set(true, forKey: touchBarModeMigrationKey)
    }

    private func applySavedTouchBarMode() {
        switch savedTouchBarMode {
        case .app:
            scheduleTouchBarBootstrap()
        case .system:
            stopAppTouchBar()
        }
    }

    private func installTouchBarBootstrapObservers() {
        guard launchObserver == nil, activationObserver == nil, terminateObserver == nil else { return }

        launchObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didFinishLaunchingNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleTouchBarBootstrap()
            }
        }

        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard self?.savedTouchBarMode == .app else { return }
                self?.startAppTouchBar()
            }
        }

        terminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.touchBarPresenter.dismissToSystemTouchBar()
                self?.touchBarTimer?.invalidate()
                self?.touchBarTimer = nil
            }
        }
    }

    private func scheduleTouchBarBootstrap() {
        bootstrapWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard self?.savedTouchBarMode == .app else { return }
                self?.startAppTouchBar()
            }
        }
        bootstrapWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
    }

    private func startAppTouchBar() {
        if touchBarTimer != nil {
            pushTouchBarUpdate()
            return
        }

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
