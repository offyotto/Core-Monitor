import Combine
import Foundation
import UserNotifications

@MainActor
final class AlertManager: NSObject, ObservableObject {
    @Published private(set) var activeAlerts: [AlertActiveState] = []
    @Published private(set) var history: [AlertEvent] = []
    @Published private(set) var availabilityReasons: [AlertRuleKind: String] = [:]
    @Published private(set) var selectedPreset: AlertPreset
    @Published private(set) var notificationPolicy: AlertNotificationPolicy
    @Published private(set) var desktopNotificationsEnabled: Bool
    @Published private(set) var notificationsMutedUntil: Date?
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var lastNotificationError: String?

    private let storageKey = "coremonitor.alertStore.v1"
    private let userDefaults: UserDefaults
    private let notificationCenter: UNUserNotificationCenter
    private let systemMonitor: SystemMonitor
    private let fanController: FanController
    private let helperManager: SMCHelperManager

    private var store: AlertStore
    private var cancellables = Set<AnyCancellable>()

    init(
        systemMonitor: SystemMonitor,
        fanController: FanController,
        helperManager: SMCHelperManager? = nil,
        userDefaults: UserDefaults = .standard,
        notificationCenter: UNUserNotificationCenter = .current()
    ) {
        self.systemMonitor = systemMonitor
        self.fanController = fanController
        self.helperManager = helperManager ?? .shared
        self.userDefaults = userDefaults
        self.notificationCenter = notificationCenter
        self.store = Self.loadStore(from: userDefaults, key: storageKey)
        self.selectedPreset = store.selectedPreset
        self.notificationPolicy = store.notificationPolicy
        self.desktopNotificationsEnabled = store.desktopNotificationsEnabled
        self.notificationsMutedUntil = store.notificationsMutedUntil
        self.history = store.history.sorted { $0.timestamp > $1.timestamp }
        super.init()
        self.notificationCenter.delegate = self
        observeInputs()
        refreshNotificationSettings()
        evaluateAlerts()
    }

    var highestActiveSeverity: AlertSeverity {
        activeAlerts.map(\.severity).max() ?? .none
    }

    var hasCriticalAlert: Bool {
        highestActiveSeverity == .critical
    }

    var summaryLine: String {
        if let alert = activeAlerts.first {
            return alert.title
        }
        return "No active alerts"
    }

    var groupedConfigs: [AlertCategory: [AlertRuleConfig]] {
        Dictionary(grouping: store.ruleConfigs.sorted { $0.kind.title < $1.kind.title }, by: \.kind.category)
    }

    func config(for kind: AlertRuleKind) -> AlertRuleConfig {
        store.ruleConfigs.first { $0.kind == kind }
            ?? AlertPreset.default.configurations().first { $0.kind == kind }
            ?? AlertRuleConfig(kind: kind, isEnabled: true, threshold: .disabled, cooldownMinutes: 20, debounceSamples: 1, desktopNotificationsEnabled: true)
    }

    func setRuleEnabled(_ enabled: Bool, for kind: AlertRuleKind) {
        updateConfig(for: kind) { config in
            config.isEnabled = enabled
        }
    }

    func setWarningThreshold(_ value: Double, for kind: AlertRuleKind) {
        updateConfig(for: kind) { config in
            config.threshold.warning = value
        }
    }

    func setCriticalThreshold(_ value: Double, for kind: AlertRuleKind) {
        updateConfig(for: kind) { config in
            config.threshold.critical = value
        }
    }

    func setCooldownMinutes(_ minutes: Int, for kind: AlertRuleKind) {
        updateConfig(for: kind) { config in
            config.cooldownMinutes = max(1, minutes)
        }
    }

    func setRuleDesktopNotificationsEnabled(_ enabled: Bool, for kind: AlertRuleKind) {
        updateConfig(for: kind) { config in
            config.desktopNotificationsEnabled = enabled
        }
    }

    func applyPreset(_ preset: AlertPreset) {
        store.selectedPreset = preset
        store.ruleConfigs = preset.configurations()
        persistStore()
        selectedPreset = preset
        evaluateAlerts()
    }

    func setNotificationPolicy(_ policy: AlertNotificationPolicy) {
        store.notificationPolicy = policy
        persistStore()
        notificationPolicy = policy
    }

    func setDesktopNotificationsEnabled(_ enabled: Bool) {
        store.desktopNotificationsEnabled = enabled
        persistStore()
        desktopNotificationsEnabled = enabled
    }

    func muteNotifications(for interval: TimeInterval) {
        let until = Date().addingTimeInterval(interval)
        store.notificationsMutedUntil = until
        persistStore()
        notificationsMutedUntil = until
    }

    func clearNotificationMute() {
        store.notificationsMutedUntil = nil
        persistStore()
        notificationsMutedUntil = nil
    }

    func snooze(_ kind: AlertRuleKind, for interval: TimeInterval) {
        updateRuntime(for: kind) { runtime in
            runtime.snoozedUntil = Date().addingTimeInterval(interval)
        }
        evaluateAlerts()
    }

    func dismissUntilRecovery(_ kind: AlertRuleKind) {
        updateRuntime(for: kind) { runtime in
            runtime.dismissUntilRecovery = true
        }
        evaluateAlerts()
    }

    func requestNotificationAuthorization() {
        notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] _, error in
            DispatchQueue.main.async {
                self?.lastNotificationError = error?.localizedDescription
                self?.refreshNotificationSettings()
            }
        }
    }

    func evaluateAlerts() {
        var runtimesByKind = Dictionary(uniqueKeysWithValues: store.runtimes.map { ($0.kind, $0) })
        var activeByKind: [AlertRuleKind: AlertActiveState] = [:]
        var nextAvailabilityReasons: [AlertRuleKind: String] = [:]
        var generatedEvents: [(AlertEvent, Bool)] = []

        let input = AlertEvaluationInput(
            snapshot: systemMonitor.snapshot,
            fanMode: fanController.mode,
            helperInstalled: helperManager.isInstalled,
            helperStatusMessage: helperManager.statusMessage,
            now: Date()
        )

        for config in store.ruleConfigs {
            let runtime = runtimesByKind[config.kind] ?? .initial(for: config.kind)
            let outcome = AlertEvaluator.evaluate(config: config, runtime: runtime, input: input)
            runtimesByKind[config.kind] = outcome.runtime
            nextAvailabilityReasons[config.kind] = outcome.availabilityReason

            if let activeState = outcome.activeState {
                activeByKind[config.kind] = activeState
            }
            if let event = outcome.event {
                generatedEvents.append((event, outcome.shouldNotify))
            }
        }

        store.runtimes = AlertRuleKind.allCases.map { runtimesByKind[$0] ?? .initial(for: $0) }
        availabilityReasons = nextAvailabilityReasons
        activeAlerts = activeByKind.values.sorted {
            if $0.severity == $1.severity {
                return $0.updatedAt > $1.updatedAt
            }
            return $0.severity > $1.severity
        }

        if !generatedEvents.isEmpty {
            var updatedHistory = store.history
            for (event, shouldNotify) in generatedEvents {
                updatedHistory.insert(event, at: 0)
                if shouldNotify, shouldDeliverDesktopNotification(for: event) {
                    deliverDesktopNotification(for: event)
                }
            }
            store.history = Array(updatedHistory.prefix(AlertStore.historyLimit))
            persistStore()
            history = store.history
        }
    }

    private func observeInputs() {
        systemMonitor.$snapshot
            .sink { [weak self] _ in
                self?.evaluateAlerts()
            }
            .store(in: &cancellables)

        fanController.$mode
            .sink { [weak self] _ in
                self?.evaluateAlerts()
            }
            .store(in: &cancellables)

        helperManager.$isInstalled
            .sink { [weak self] _ in
                self?.evaluateAlerts()
            }
            .store(in: &cancellables)

        helperManager.$statusMessage
            .sink { [weak self] _ in
                self?.evaluateAlerts()
            }
            .store(in: &cancellables)
    }

    private func shouldDeliverDesktopNotification(for event: AlertEvent) -> Bool {
        guard desktopNotificationsEnabled else { return false }
        if let mutedUntil = notificationsMutedUntil, mutedUntil > Date() {
            return false
        }

        switch notificationPolicy {
        case .inAppOnly:
            return false
        case .criticalOnly:
            return event.severity == .critical
        case .warningsAndCritical:
            return event.severity >= .warning
        }
    }

    private func deliverDesktopNotification(for event: AlertEvent) {
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = [event.message, event.context].compactMap { $0 }.joined(separator: " ")
        content.sound = .default
        content.userInfo = [
            "kind": event.kind.rawValue,
            "severity": event.severity.rawValue
        ]

        let request = UNNotificationRequest(
            identifier: "coremonitor.alert.\(event.id.uuidString)",
            content: content,
            trigger: nil
        )
        notificationCenter.add(request) { [weak self] error in
            DispatchQueue.main.async {
                self?.lastNotificationError = error?.localizedDescription
            }
        }
    }

    private func refreshNotificationSettings() {
        notificationCenter.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.authorizationStatus = settings.authorizationStatus
            }
        }
    }

    private func updateConfig(for kind: AlertRuleKind, mutate: (inout AlertRuleConfig) -> Void) {
        var configs = store.ruleConfigs
        guard let index = configs.firstIndex(where: { $0.kind == kind }) else { return }
        mutate(&configs[index])
        store.ruleConfigs = configs
        persistStore()
        evaluateAlerts()
    }

    private func updateRuntime(for kind: AlertRuleKind, mutate: (inout AlertRuleRuntime) -> Void) {
        var runtimes = store.runtimes
        guard let index = runtimes.firstIndex(where: { $0.kind == kind }) else { return }
        mutate(&runtimes[index])
        store.runtimes = runtimes
        persistStore()
    }

    private func persistStore() {
        do {
            let data = try JSONEncoder().encode(store)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            lastNotificationError = error.localizedDescription
        }

        selectedPreset = store.selectedPreset
        notificationPolicy = store.notificationPolicy
        desktopNotificationsEnabled = store.desktopNotificationsEnabled
        notificationsMutedUntil = store.notificationsMutedUntil
        history = store.history
    }

    private static func loadStore(from userDefaults: UserDefaults, key: String) -> AlertStore {
        guard let data = userDefaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(AlertStore.self, from: data) else {
            return .default()
        }
        return normalize(decoded)
    }

    private static func normalize(_ store: AlertStore) -> AlertStore {
        let defaults = AlertStore.default()
        let configMap = Dictionary(uniqueKeysWithValues: store.ruleConfigs.map { ($0.kind, $0) })
        let runtimeMap = Dictionary(uniqueKeysWithValues: store.runtimes.map { ($0.kind, $0) })

        return AlertStore(
            selectedPreset: store.selectedPreset,
            notificationPolicy: store.notificationPolicy,
            desktopNotificationsEnabled: store.desktopNotificationsEnabled,
            notificationsMutedUntil: store.notificationsMutedUntil,
            ruleConfigs: AlertRuleKind.allCases.map { kind in
                configMap[kind]
                    ?? defaults.ruleConfigs.first(where: { $0.kind == kind })
                    ?? AlertRuleConfig(kind: kind, isEnabled: true, threshold: .disabled, cooldownMinutes: 20, debounceSamples: 1, desktopNotificationsEnabled: true)
            },
            runtimes: AlertRuleKind.allCases.map { runtimeMap[$0] ?? .initial(for: $0) },
            history: Array(store.history.filter { !$0.isRecovery }.prefix(AlertStore.historyLimit))
        )
    }
}

extension AlertManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.list, .banner, .sound])
    }
}
