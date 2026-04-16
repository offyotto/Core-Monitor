import AppKit
import Carbon
import Combine
import Foundation

extension Notification.Name {
    static let dashboardShortcutDidActivate = Notification.Name("CoreMonitor.DashboardShortcutDidActivate")
}

enum DashboardShortcutConfiguration {
    static let enabledDefaultsKey = "coremonitor.dashboardShortcut.enabled"
    static let keyEquivalent = "m"
    static let modifierFlags: NSEvent.ModifierFlags = [.command, .option]
    static let displayLabel = "Option-Command-M"

    fileprivate static let keyCode = UInt32(kVK_ANSI_M)
    fileprivate static let hotKeyID = EventHotKeyID(signature: fourCharCode("CMON"), id: 1)

    static func carbonModifiers(for flags: NSEvent.ModifierFlags = modifierFlags) -> UInt32 {
        var carbonFlags: UInt32 = 0

        if flags.contains(.command) {
            carbonFlags |= UInt32(cmdKey)
        }
        if flags.contains(.option) {
            carbonFlags |= UInt32(optionKey)
        }
        if flags.contains(.control) {
            carbonFlags |= UInt32(controlKey)
        }
        if flags.contains(.shift) {
            carbonFlags |= UInt32(shiftKey)
        }

        return carbonFlags
    }

    private static func fourCharCode(_ string: String) -> OSType {
        string.utf8.prefix(4).reduce(0) { partialResult, character in
            (partialResult << 8) | OSType(character)
        }
    }
}

@MainActor
final class DashboardShortcutManager: ObservableObject {
    static let shared = DashboardShortcutManager()

    @Published private(set) var isEnabled: Bool
    @Published private(set) var registrationError: String?

    private let defaults: UserDefaults
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isEnabled = defaults.object(forKey: DashboardShortcutConfiguration.enabledDefaultsKey) as? Bool ?? false

        installEventHandlerIfNeeded()
        updateRegistration()
    }

    func setEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: DashboardShortcutConfiguration.enabledDefaultsKey)
        isEnabled = enabled
        updateRegistration()
    }

    private func updateRegistration() {
        unregisterHotKey()

        guard isEnabled else {
            registrationError = nil
            return
        }

        installEventHandlerIfNeeded()

        let status = RegisterEventHotKey(
            DashboardShortcutConfiguration.keyCode,
            DashboardShortcutConfiguration.carbonModifiers(),
            DashboardShortcutConfiguration.hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr else {
            hotKeyRef = nil
            registrationError = "Core Monitor could not register \(DashboardShortcutConfiguration.displayLabel). Another app may already be using it."
            isEnabled = false
            defaults.set(false, forKey: DashboardShortcutConfiguration.enabledDefaultsKey)
            return
        }

        registrationError = nil
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, _ in
                guard let eventRef else { return noErr }

                var hotKeyID = EventHotKeyID()
                let result = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard result == noErr,
                      hotKeyID.signature == DashboardShortcutConfiguration.hotKeyID.signature,
                      hotKeyID.id == DashboardShortcutConfiguration.hotKeyID.id else {
                    return noErr
                }

                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .dashboardShortcutDidActivate, object: nil)
                }
                return noErr
            },
            1,
            &eventSpec,
            nil,
            &eventHandlerRef
        )

        if status != noErr {
            registrationError = "Core Monitor could not listen for the dashboard shortcut."
        }
    }

    private func unregisterHotKey() {
        guard let hotKeyRef else { return }
        UnregisterEventHotKey(hotKeyRef)
        self.hotKeyRef = nil
    }

    private func removeEventHandler() {
        guard let eventHandlerRef else { return }
        RemoveEventHandler(eventHandlerRef)
        self.eventHandlerRef = nil
    }
}
