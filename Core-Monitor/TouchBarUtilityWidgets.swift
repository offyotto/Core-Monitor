import AppKit
import Foundation
import CoreAudio
import IOKit
import IOKit.graphics

final class ControlCenterTouchBarWidget: NSStackView, TouchBarThemable {
    var theme: TouchBarTheme = .dark {
        didSet { applyTheme() }
    }

    private enum ActionTag: Int {
        case sleep = 1
        case lock = 2
        case screensaver = 3
        case doNotDisturb = 4
        case volumeDown = 5
        case volumeToggle = 6
        case volumeUp = 7
    }

    private let buttons: [NSButton]
    private let volumeMeter = MeterControl()

    override init(frame frameRect: NSRect) {
        buttons = [
            Self.makeButton(symbol: "moon.zzz.fill", tag: .sleep),
            Self.makeButton(symbol: "lock.fill", tag: .lock),
            Self.makeButton(symbol: "display", tag: .screensaver),
            Self.makeButton(symbol: "moon.fill", tag: .doNotDisturb),
            Self.makeButton(symbol: "minus", tag: .volumeDown),
            Self.makeButton(symbol: "speaker.wave.2.fill", tag: .volumeToggle),
            Self.makeButton(symbol: "plus", tag: .volumeUp)
        ]
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        buttons = []
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        orientation = .horizontal
        alignment = .centerY
        spacing = 6
        translatesAutoresizingMaskIntoConstraints = false

        let grouped: [[NSView]] = [
            Array(buttons[0...3]),
            [volumeMeter, buttons[4], buttons[5], buttons[6]]
        ]

        for (index, group) in grouped.enumerated() {
            for view in group {
                addArrangedSubview(view)
            }
            if index < grouped.count - 1 {
                addArrangedSubview(Self.spacer())
            }
        }

        applyTheme()
        refreshState()
    }

    private static func makeButton(symbol: String, tag: ActionTag) -> NSButton {
        let button = NSButton(title: "", target: nil, action: #selector(ControlCenterTouchBarWidget.invokeAction(_:)))
        button.tag = tag.rawValue
        button.target = nil
        button.isBordered = false
        button.bezelStyle = .shadowlessSquare
        button.setButtonType(.momentaryChange)
        button.focusRingType = .none
        button.translatesAutoresizingMaskIntoConstraints = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 0
        button.layer?.masksToBounds = true
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 11, weight: .medium))
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 20),
            button.heightAnchor.constraint(equalToConstant: 18)
        ])
        return button
    }

    private static func spacer() -> NSView {
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 4, height: 18))
        v.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            v.widthAnchor.constraint(equalToConstant: 4)
        ])
        return v
    }

    @objc private func invokeAction(_ sender: NSButton) {
        guard let tag = ActionTag(rawValue: sender.tag) else { return }

        switch tag {
        case .sleep:
            runCommand("/usr/bin/pmset", ["sleepnow"])
        case .lock:
            runCommand(
                "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession",
                ["-suspend"]
            )
            runAppleScript(#"tell application "System Events" to keystroke "q" using {control down, command down}"#)
        case .screensaver:
            runCommand("/usr/bin/open", ["-a", "ScreenSaverEngine"])
            runAppleScript(#"tell application "ScreenSaverEngine" to activate"#)
        case .doNotDisturb:
            runCommand("/usr/bin/open", ["x-apple.systempreferences:com.apple.Focus-Settings.extension"])
        case .volumeDown:
            adjustVolume(by: -0.07)
        case .volumeToggle:
            showVolumeSlider()
        case .volumeUp:
            adjustVolume(by: 0.07)
        }
    }

    private func runCommand(_ path: String, _ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        try? process.run()
    }

    private func runAppleScript(_ source: String) {
        NSAppleScript(source: source)?.executeAndReturnError(nil)
    }

    private func showVolumeSlider() {
        let current = SystemVolume.current
        volumeMeter.set(value: current)
    }

    private func adjustVolume(by delta: Float) {
        let next = clamp01(SystemVolume.current + delta)
        SystemVolume.set(next)
        volumeMeter.set(value: SystemVolume.current)
    }

    private func clamp01(_ value: Float) -> Float { min(max(value, 0), 1) }

    private func applyTheme() {
        let tint = theme.primaryTextColor
        buttons.forEach {
            $0.target = self
            $0.contentTintColor = tint
            $0.layer?.backgroundColor = .clear
            $0.layer?.borderWidth = 0
            $0.layer?.borderColor = nil
        }
        volumeMeter.theme = theme
        refreshState()
    }

    private func refreshState() {
        volumeMeter.set(value: SystemVolume.current)
    }
}

enum SystemVolume {
    static var current: Float {
        var dev = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &dev) == noErr,
              dev != kAudioObjectUnknown else { return 0 }

        var vol: Float32 = 0
        var volSize = UInt32(MemoryLayout<Float32>.size)
        var volAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(dev, &volAddr),
              AudioObjectGetPropertyData(dev, &volAddr, 0, nil, &volSize, &vol) == noErr else { return 0 }
        return min(max(vol, 0), 1)
    }

    static func set(_ value: Float) {
        var dev = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &dev) == noErr,
              dev != kAudioObjectUnknown else { return }

        var volume = min(max(value, 0), 1)
        var volAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(dev, &volAddr) else { return }
        let _ = AudioObjectSetPropertyData(dev, &volAddr, 0, nil, UInt32(MemoryLayout<Float32>.size), &volume)
    }
}

final class MeterControl: NSView, TouchBarThemable {
    var theme: TouchBarTheme = .dark {
        didSet { needsDisplay = true }
    }

    private let track = CALayer()
    private let fill = CALayer()
    private let knob = CALayer()
    private var value: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        layer?.addSublayer(track)
        layer?.addSublayer(fill)
        layer?.addSublayer(knob)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 26),
            heightAnchor.constraint(equalToConstant: 18)
        ])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func layout() {
        super.layout()
        let r = bounds.insetBy(dx: 1.5, dy: 6.5)
        track.frame = r
        track.cornerRadius = 2
        track.backgroundColor = theme.barOutlineColor.withAlphaComponent(0.35).cgColor

        let fillWidth = max(2, r.width * value)
        fill.frame = CGRect(x: r.minX, y: r.minY, width: fillWidth, height: r.height)
        fill.cornerRadius = 2
        fill.backgroundColor = theme.accentBlue.cgColor

        knob.frame = CGRect(x: r.minX + fillWidth - 2.5, y: r.minY - 1.5, width: 5, height: r.height + 3)
        knob.cornerRadius = 2.5
        knob.backgroundColor = theme.primaryTextColor.cgColor
    }

    func set(value: Float) {
        self.value = CGFloat(min(max(value, 0), 1))
        needsLayout = true
    }
}

final class DockTouchBarWidget: NSStackView, TouchBarThemable {
    var theme: TouchBarTheme = .dark {
        didSet { applyTheme() }
    }

    private let appsStack = NSStackView()
    private let persistentStack = NSStackView()
    private let separator = NSView(frame: .zero)
    private var refreshTimer: Timer?
    private var dockItems: [DockTouchBarItem] = []
    private var persistentItems: [DockTouchBarItem] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        orientation = .horizontal
        alignment = .centerY
        spacing = 4
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true

        appsStack.orientation = .horizontal
        appsStack.alignment = .centerY
        appsStack.spacing = 4

        persistentStack.orientation = .horizontal
        persistentStack.alignment = .centerY
        persistentStack.spacing = 4

        separator.wantsLayer = true
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.widthAnchor.constraint(equalToConstant: 1).isActive = true
        separator.heightAnchor.constraint(equalToConstant: 18).isActive = true

        addArrangedSubview(appsStack)
        addArrangedSubview(separator)
        addArrangedSubview(persistentStack)

        reload()
        startRefreshing()
    }

    func reload() {
        dockItems = loadDockItems()
        persistentItems = loadPersistentItems()
        rebuildStack(appsStack, with: dockItems)
        rebuildStack(persistentStack, with: persistentItems)
        separator.isHidden = persistentItems.isEmpty
        applyTheme()
    }

    private func applyTheme() {
        layer?.backgroundColor = NSColor.clear.cgColor
        separator.layer?.backgroundColor = theme.barOutlineColor.withAlphaComponent(0.35).cgColor
    }

    private func startRefreshing() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.reload()
        }
    }

    private func rebuildStack(_ stack: NSStackView, with items: [DockTouchBarItem]) {
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        for item in items.prefix(8) {
            let button = NSButton(title: "", target: self, action: #selector(launchItem(_:)))
            button.tag = item.index
            button.bezelStyle = .shadowlessSquare
            button.isBordered = false
            button.focusRingType = .none
            button.translatesAutoresizingMaskIntoConstraints = false
            button.contentTintColor = theme.primaryTextColor
            button.image = item.icon
            button.image?.size = NSSize(width: 22, height: 22)
            button.imageScaling = .scaleProportionallyUpOrDown
            button.toolTip = item.name
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: 24),
                button.heightAnchor.constraint(equalToConstant: 24)
            ])
            stack.addArrangedSubview(button)
        }
    }

    @objc private func launchItem(_ sender: NSButton) {
        guard let item = (dockItems + persistentItems).first(where: { $0.index == sender.tag }) else { return }
        if let bundleIdentifier = item.bundleIdentifier {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
                let configuration = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, _ in }
            }
        } else if let url = item.url {
            NSWorkspace.shared.open(url)
        }
    }

    private func loadDockItems() -> [DockTouchBarItem] {
        let running = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .filter { $0.bundleIdentifier != "com.apple.dock" }
            .prefix(8)
        return running.enumerated().compactMap { index, app in
            DockTouchBarItem(
                index: index,
                name: app.localizedName ?? "App",
                bundleIdentifier: app.bundleIdentifier,
                url: nil,
                icon: app.icon ?? NSWorkspace.shared.icon(forFile: "/System/Applications/App Store.app")
            )
        }
    }

    private func loadPersistentItems() -> [DockTouchBarItem] {
        guard let dict = UserDefaults.standard.persistentDomain(forName: "com.apple.dock"),
              let apps = dict["persistent-apps"] as? [[String: Any]] else { return [] }

        return apps.enumerated().compactMap { index, entry in
            guard let tileData = entry["tile-data"] as? [String: Any],
                  let label = tileData["file-label"] as? String else { return nil }

            let bundleIdentifier = tileData["bundle-identifier"] as? String
            let fileURLString = (tileData["file-data"] as? [String: Any])?["_CFURLString"] as? String
            let url = fileURLString.flatMap { URL(string: $0) }
            let icon = url.map { NSWorkspace.shared.icon(forFile: $0.path) } ?? NSWorkspace.shared.icon(forFile: "/System/Applications/App Store.app")
            return DockTouchBarItem(index: index + 100, name: label, bundleIdentifier: bundleIdentifier, url: url, icon: icon)
        }
    }
}

private struct DockTouchBarItem {
    let index: Int
    let name: String
    let bundleIdentifier: String?
    let url: URL?
    let icon: NSImage
}
