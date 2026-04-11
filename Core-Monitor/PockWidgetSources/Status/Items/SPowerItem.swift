//
//  SPowerItem.swift
//  Status widget item for Core Monitor.
//

import AppKit
import Foundation
import IOKit.ps

private struct SPowerStatus {
    var isCharging: Bool
    var isCharged: Bool
    var currentValue: Int
}

final class SPowerItem: StatusItem {
    private var refreshTimer: Timer?
    private var powerStatus = SPowerStatus(isCharging: false, isCharged: false, currentValue: 0)
    private var currentTheme: TouchBarTheme = .dark

    private let stackView = NSStackView(frame: .zero)
    private let iconView = NSImageView(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
    private let bodyView = NSView(frame: NSRect(x: 2, y: 2, width: 21, height: 8))
    private let valueLabel = NSTextField(labelWithString: "-%")

    init() {
        didLoad()
    }

    deinit {
        didUnload()
    }

    var view: NSView { stackView }

    func didLoad() {
        bodyView.wantsLayer = true
        bodyView.layer?.cornerRadius = 1
        configureValueLabel()
        configureStackView()
        stackView.wantsLayer = false
        reload()
        refreshTimer = Timer.scheduledTimer(timeInterval: 30, target: self, repeats: true) { [weak self] in
            self?.reload()
        }
    }

    func didUnload() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func apply(theme: TouchBarTheme) {
        currentTheme = theme
        valueLabel.textColor = theme.primaryTextColor
        iconView.contentTintColor = theme.primaryTextColor
        updateIcon(value: powerStatus.currentValue)
    }

    private func configureValueLabel() {
        valueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        valueLabel.sizeToFit()
    }

    private func configureStackView() {
        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.distribution = .fillProportionally
        stackView.spacing = 4
        if stackView.arrangedSubviews.isEmpty {
            stackView.addArrangedSubview(valueLabel)
            stackView.addArrangedSubview(iconView)
        }
    }

    @objc func reload() {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        for ps in sources {
            guard let info = IOPSGetPowerSourceDescription(snapshot, ps).takeUnretainedValue() as? [String: AnyObject] else {
                continue
            }

            if let capacity = info[kIOPSCurrentCapacityKey] as? Int {
                powerStatus.currentValue = capacity
            }
            if let isCharging = info[kIOPSIsChargingKey] as? Bool {
                powerStatus.isCharging = isCharging
            }
            if let isCharged = info[kIOPSIsChargedKey] as? Bool {
                powerStatus.isCharged = isCharged
            }
        }

        updateIcon(value: powerStatus.currentValue)
    }

    private func updateIcon(value: Int) {
        var iconName: String
        if powerStatus.isCharged {
            iconView.subviews.forEach { $0.removeFromSuperview() }
            iconName = "powerIsCharged"
        } else if powerStatus.isCharging {
            iconView.subviews.forEach { $0.removeFromSuperview() }
            iconName = "powerIsCharging"
        } else {
            iconName = "powerEmpty"
            buildBatteryIcon(withValue: value)
        }

        if let image = NSImage(named: iconName)?.copy() as? NSImage {
            image.isTemplate = true
            iconView.image = image
        } else {
            let fallback = powerStatus.isCharging ? "battery.100.bolt" : "battery.100"
            let symbol = NSImage(systemSymbolName: fallback, accessibilityDescription: nil)?
                .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 13, weight: .regular))
            symbol?.isTemplate = true
            iconView.image = symbol
        }

        valueLabel.stringValue = "\(value)%"
        valueLabel.isHidden = false
    }

    private func buildBatteryIcon(withValue value: Int) {
        let width = (CGFloat(value) / 100) * (iconView.frame.width - 7)
        if !iconView.subviews.contains(bodyView) {
            iconView.addSubview(bodyView)
        }

        switch value {
        case 0...20:
            bodyView.layer?.backgroundColor = NSColor.systemRed.cgColor
        default:
            bodyView.layer?.backgroundColor = currentTheme.primaryTextColor.cgColor
        }

        bodyView.frame.size.width = max(width, 1.25)
    }
}
