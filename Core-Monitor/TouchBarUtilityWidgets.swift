import AppKit
import Foundation
import CoreAudio
import IOKit
import IOKit.graphics

protocol TouchBarThemable: AnyObject {
    var theme: TouchBarTheme { get set }
}

struct TouchBarTheme: Equatable, Hashable {
    let primaryTextColor: NSColor
    let secondaryTextColor: NSColor
    let pillBackgroundColor: NSColor
    let pillBorderColor: NSColor
    let barOutlineColor: NSColor

    static let dark = TouchBarTheme(
        primaryTextColor: .white,
        secondaryTextColor: NSColor.white.withAlphaComponent(0.72),
        pillBackgroundColor: NSColor.white.withAlphaComponent(0.08),
        pillBorderColor: NSColor.white.withAlphaComponent(0.15),
        barOutlineColor: NSColor.white.withAlphaComponent(0.35)
    )

    static let light = TouchBarTheme(
        primaryTextColor: .labelColor,
        secondaryTextColor: NSColor.secondaryLabelColor,
        pillBackgroundColor: NSColor.black.withAlphaComponent(0.06),
        pillBorderColor: NSColor.black.withAlphaComponent(0.12),
        barOutlineColor: NSColor.black.withAlphaComponent(0.25)
    )

    static func == (lhs: TouchBarTheme, rhs: TouchBarTheme) -> Bool {
        lhs.primaryTextColor == rhs.primaryTextColor &&
        lhs.secondaryTextColor == rhs.secondaryTextColor &&
        lhs.pillBackgroundColor == rhs.pillBackgroundColor &&
        lhs.pillBorderColor == rhs.pillBorderColor &&
        lhs.barOutlineColor == rhs.barOutlineColor
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(primaryTextColor)
        hasher.combine(secondaryTextColor)
        hasher.combine(pillBackgroundColor)
        hasher.combine(pillBorderColor)
        hasher.combine(barOutlineColor)
    }
}

final class ControlCenterTouchBarWidget: NSStackView, TouchBarThemable {
    var theme: TouchBarTheme = .dark {
        didSet { applyTheme() }
    }

    private enum ActionTag: Int {
        case brightnessDown = 1
        case brightnessUp = 2
        case volumeDown = 3
        case volumeUp = 4
    }

    private let buttons: [NSButton]

    override init(frame frameRect: NSRect) {
        buttons = [
            Self.makeButton(symbol: "sun.min.fill", tag: .brightnessDown),
            Self.makeButton(symbol: "sun.max.fill", tag: .brightnessUp),
            Self.makeButton(symbol: "speaker.fill", tag: .volumeDown),
            Self.makeButton(symbol: "speaker.wave.3.fill", tag: .volumeUp),
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
        distribution = .fill
        spacing = 14
        translatesAutoresizingMaskIntoConstraints = false

        buttons.forEach { button in
            addArrangedSubview(button)
        }

        applyTheme()
    }

    private static func makeButton(symbol: String, tag: ActionTag) -> NSButton {
        let button = NSButton(title: "", target: nil, action: #selector(ControlCenterTouchBarWidget.invokeAction(_:)))
        button.tag = tag.rawValue
        button.target = nil
        button.isBordered = false
        button.bezelStyle = .shadowlessSquare
        button.setButtonType(.momentaryChange)
        button.isContinuous = true
        (button.cell as? NSButtonCell)?.setPeriodicDelay(0.35, interval: 0.08)
        button.focusRingType = .none
        button.translatesAutoresizingMaskIntoConstraints = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 0
        button.layer?.masksToBounds = true
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .medium))
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 24),
            button.heightAnchor.constraint(equalToConstant: 22)
        ])
        return button
    }

    @objc private func invokeAction(_ sender: NSButton) {
        guard let tag = ActionTag(rawValue: sender.tag) else { return }

        switch tag {
        case .brightnessDown:
            SystemBrightness.adjust(by: -0.0625)
        case .brightnessUp:
            SystemBrightness.adjust(by: 0.0625)
        case .volumeDown:
            adjustVolume(by: -0.07)
        case .volumeUp:
            adjustVolume(by: 0.07)
        }
    }

    private func adjustVolume(by delta: Float) {
        let next = min(max(SystemVolume.current + delta, 0), 1)
        SystemVolume.set(next)
    }

    private func applyTheme() {
        let tint = theme.primaryTextColor
        buttons.forEach {
            $0.target = self
            $0.contentTintColor = tint
            $0.layer?.backgroundColor = .clear
            $0.layer?.borderWidth = 0
            $0.layer?.borderColor = nil
        }
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

    static var symbolName: String {
        switch current {
        case ..<0.01:
            return "speaker.slash.fill"
        case ..<0.34:
            return "speaker.wave.1.fill"
        case ..<0.68:
            return "speaker.wave.2.fill"
        default:
            return "speaker.wave.3.fill"
        }
    }
}

enum SystemBrightness {
    static var current: Float {
        min(max(CMCurrentBrightness(), 0), 1)
    }

    static func set(_ value: Float) {
        CMSetBrightness(min(max(value, 0), 1))
    }

    static func adjust(by delta: Float) {
        if delta > 0 {
            CMIncreaseBrightness()
        } else if delta < 0 {
            CMDecreaseBrightness()
        }
    }
}

@available(macOS 13.0, *)
@MainActor
final class ControlCenterSliderPresenter: NSObject, NSTouchBarDelegate {
    enum SliderKind {
        case brightness
        case volume

        var title: String {
            switch self {
            case .brightness: return "Brightness"
            case .volume: return "Volume"
            }
        }

        var leftSymbol: String {
            switch self {
            case .brightness: return "sun.min.fill"
            case .volume: return "speaker.wave.1.fill"
            }
        }

        var rightSymbol: String {
            switch self {
            case .brightness: return "sun.max.fill"
            case .volume: return "speaker.wave.3.fill"
            }
        }
    }

    static let shared = ControlCenterSliderPresenter()

    private let itemIdentifier = NSTouchBarItem.Identifier("com.coremonitor.touchbar.controlCenter.slider")
    private var presenter = TouchBarPrivatePresenter()
    private var activeKind: SliderKind?
    private var activeButton: NSButton?
    private var theme: TouchBarTheme = .dark
    private weak var sliderView: ControlCenterSliderView?

    func present(kind: SliderKind, theme: TouchBarTheme, sourceButton: NSButton) {
        if activeKind == kind {
            dismiss()
            return
        }

        self.theme = theme
        activeKind = kind
        activeButton = sourceButton
        sourceButton.layer?.backgroundColor = theme.pillBorderColor.cgColor

        let touchBar = NSTouchBar()
        touchBar.delegate = self
        touchBar.defaultItemIdentifiers = [itemIdentifier]
        presenter.present(touchBar: touchBar)
    }

    func dismiss() {
        activeButton?.layer?.backgroundColor = NSColor.clear.cgColor
        activeButton = nil
        activeKind = nil
        sliderView = nil
        presenter.dismiss()
    }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        guard identifier == itemIdentifier, let activeKind else { return nil }
        let item = NSCustomTouchBarItem(identifier: identifier)
        let sliderView = ControlCenterSliderView(kind: activeKind, theme: theme) { [weak self] in
            self?.dismiss()
        }
        self.sliderView = sliderView
        item.view = sliderView
        return item
    }
}

@available(macOS 13.0, *)
final class ControlCenterSliderView: NSStackView, TouchBarThemable {
    var theme: TouchBarTheme {
        didSet { applyTheme() }
    }

    private let kind: ControlCenterSliderPresenter.SliderKind
    private let leftButton = NSButton(title: "", target: nil, action: nil)
    private let rightButton = NSButton(title: "", target: nil, action: nil)
    private let closeButton = NSButton(title: "", target: nil, action: nil)
    private let slider = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let onClose: () -> Void

    init(kind: ControlCenterSliderPresenter.SliderKind, theme: TouchBarTheme, onClose: @escaping () -> Void) {
        self.kind = kind
        self.theme = theme
        self.onClose = onClose
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private func setup() {
        orientation = .horizontal
        alignment = .centerY
        spacing = 8
        translatesAutoresizingMaskIntoConstraints = false

        configureButton(leftButton, symbol: kind.leftSymbol, action: #selector(stepDown))
        configureButton(rightButton, symbol: kind.rightSymbol, action: #selector(stepUp))
        configureButton(closeButton, symbol: "xmark", action: #selector(closePressed))

        slider.target = self
        slider.action = #selector(sliderChanged(_:))
        slider.isContinuous = true
        slider.controlSize = .small
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.doubleValue = Double(currentValue())
        slider.widthAnchor.constraint(equalToConstant: 180).isActive = true

        addArrangedSubview(leftButton)
        addArrangedSubview(slider)
        addArrangedSubview(rightButton)
        addArrangedSubview(closeButton)

        applyTheme()
    }

    private func configureButton(_ button: NSButton, symbol: String, action: Selector) {
        button.target = self
        button.action = action
        button.isBordered = false
        button.bezelStyle = .shadowlessSquare
        button.focusRingType = .none
        button.translatesAutoresizingMaskIntoConstraints = false
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 12, weight: .medium))
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 20),
            button.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    private func currentValue() -> Float {
        switch kind {
        case .brightness:
            return SystemBrightness.current
        case .volume:
            return SystemVolume.current
        }
    }

    private func setValue(_ value: Float) {
        switch kind {
        case .brightness:
            SystemBrightness.set(value)
        case .volume:
            SystemVolume.set(value)
        }
        slider.doubleValue = Double(value)
    }

    private func applyTheme() {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = theme.pillBackgroundColor.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = theme.pillBorderColor.cgColor
        [leftButton, rightButton, closeButton].forEach { $0.contentTintColor = theme.primaryTextColor }
    }

    @objc private func stepDown() {
        let delta: Float = kind == .brightness ? -0.0625 : -0.07
        setValue(min(max(currentValue() + delta, 0), 1))
    }

    @objc private func stepUp() {
        let delta: Float = kind == .brightness ? 0.0625 : 0.07
        setValue(min(max(currentValue() + delta, 0), 1))
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        setValue(Float(sender.doubleValue))
    }

    @objc private func closePressed() {
        onClose()
    }
}

final class MeterControl: NSView, TouchBarThemable {
    var theme: TouchBarTheme = .dark {
        didSet { needsDisplay = true }
    }

    var fillColor: NSColor = .systemBlue {
        didSet { needsLayout = true }
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
            widthAnchor.constraint(equalToConstant: 40),
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
        fill.backgroundColor = fillColor.cgColor

        knob.frame = CGRect(x: r.minX + fillWidth - 2.5, y: r.minY - 1.5, width: 5, height: r.height + 3)
        knob.cornerRadius = 2.5
        knob.backgroundColor = theme.primaryTextColor.cgColor
    }

    func set(value: Float) {
        self.value = CGFloat(min(max(value, 0), 1))
        needsLayout = true
    }
}

final class RAMPressureTouchBarWidget: NSStackView, TouchBarThemable {
    var theme: TouchBarTheme = .dark {
        didSet { applyTheme() }
    }

    private let iconView = NSImageView()
    let meter = MeterControl()

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
        spacing = 6
        translatesAutoresizingMaskIntoConstraints = false

        iconView.image = NSImage(systemSymbolName: "memorychip", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 12, weight: .medium))
        iconView.translatesAutoresizingMaskIntoConstraints = false

        addArrangedSubview(iconView)
        addArrangedSubview(meter)
        
        applyTheme()
    }
    func update(usage: Float, pressure: MemoryPressureLevel) {
        meter.set(value: usage)
        
        switch pressure {
        case .green:
            meter.fillColor = NSColor(red: 0.25, green: 0.90, blue: 0.58, alpha: 1.0)
        case .yellow:
            meter.fillColor = NSColor(red: 1.00, green: 0.62, blue: 0.20, alpha: 1.0)
        case .red:
            meter.fillColor = .systemRed
        }
    }

    private func applyTheme() {
        iconView.contentTintColor = theme.primaryTextColor
        meter.theme = theme
    }
}

final class DockTouchBarWidget: NSStackView, TouchBarThemable {
    var theme: TouchBarTheme = .dark {
        didSet { applyTheme() }
    }

    private let scrollView = NSScrollView()
    private let contentStack = NSStackView()
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
        spacing = 0
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true

        contentStack.orientation = .horizontal
        contentStack.alignment = .centerY
        contentStack.spacing = 4
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.horizontalScrollElasticity = .allowed
        scrollView.verticalScrollElasticity = .none
        scrollView.documentView = contentStack
        addArrangedSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.widthAnchor.constraint(equalToConstant: 92),
            scrollView.heightAnchor.constraint(equalToConstant: 24),
            contentStack.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])

        reload()
    }

    func reload() {
        dockItems = loadDockItems()
        persistentItems = loadPersistentItems()
        rebuildStack(contentStack, with: mergedItems())
        applyTheme()
    }

    private func applyTheme() {
        layer?.backgroundColor = NSColor.clear.cgColor
        scrollView.contentView.backgroundColor = .clear
    }

    private func rebuildStack(_ stack: NSStackView, with items: [DockTouchBarItem]) {
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        for item in items {
            let itemContainer = NSStackView()
            itemContainer.orientation = .vertical
            itemContainer.alignment = .centerX
            itemContainer.spacing = 0
            itemContainer.translatesAutoresizingMaskIntoConstraints = false

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
                button.heightAnchor.constraint(equalToConstant: 22)
            ])
            itemContainer.addArrangedSubview(button)

            if item.isRunning {
                let dot = NSView()
                dot.translatesAutoresizingMaskIntoConstraints = false
                dot.wantsLayer = true
                dot.layer?.backgroundColor = NSColor.white.cgColor
                dot.layer?.cornerRadius = 1
                NSLayoutConstraint.activate([
                    dot.widthAnchor.constraint(equalToConstant: 2),
                    dot.heightAnchor.constraint(equalToConstant: 2)
                ])
                itemContainer.addArrangedSubview(dot)
            } else {
                // Spacer for layout consistency
                let spacer = NSView()
                spacer.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    spacer.widthAnchor.constraint(equalToConstant: 2),
                    spacer.heightAnchor.constraint(equalToConstant: 2)
                ])
                itemContainer.addArrangedSubview(spacer)
            }

            stack.addArrangedSubview(itemContainer)
        }
    }

    private func mergedItems() -> [DockTouchBarItem] {
        var seen = Set<String>()
        var merged: [DockTouchBarItem] = []

        let runningIDs = Set(dockItems.compactMap { $0.bundleIdentifier })

        for item in persistentItems {
            let key = item.bundleIdentifier ?? item.url?.absoluteString ?? item.name
            guard seen.insert(key).inserted else { continue }
            var updated = item
            if let bid = item.bundleIdentifier, runningIDs.contains(bid) {
                updated.isRunning = true
            }
            merged.append(updated)
        }

        for item in dockItems {
            let key = item.bundleIdentifier ?? item.url?.absoluteString ?? item.name
            guard seen.insert(key).inserted else { continue }
            merged.append(item)
        }

        return merged
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
        return running.enumerated().compactMap { index, app in
            DockTouchBarItem(
                index: index,
                name: app.localizedName ?? "App",
                bundleIdentifier: app.bundleIdentifier,
                url: nil,
                icon: app.icon ?? NSWorkspace.shared.icon(forFile: "/System/Applications/App Store.app"),
                isRunning: true
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
            return DockTouchBarItem(index: index + 100, name: label, bundleIdentifier: bundleIdentifier, url: url, icon: icon, isRunning: false)
        }
    }
}

private struct DockTouchBarItem {
    let index: Int
    let name: String
    let bundleIdentifier: String?
    let url: URL?
    let icon: NSImage
    var isRunning: Bool = false
}
