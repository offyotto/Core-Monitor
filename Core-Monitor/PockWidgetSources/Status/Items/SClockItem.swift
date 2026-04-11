//
//  SClockItem.swift
//  Status widget item for Core Monitor.
//

import AppKit
import Foundation

final class SClockItem: StatusItem {
    private var refreshTimer: Timer?
    private let clockLabel = NSTextField(labelWithString: "…")

    init() {
        didLoad()
    }

    deinit {
        didUnload()
    }

    var view: NSView { clockLabel }

    func didLoad() {
        clockLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        clockLabel.maximumNumberOfLines = 1
        reload()
        refreshTimer = Timer.scheduledTimer(timeInterval: 1, target: self, repeats: true) { [weak self] in
            self?.reload()
        }
    }

    func didUnload() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func apply(theme: TouchBarTheme) {
        clockLabel.textColor = theme.primaryTextColor
    }

    @objc func reload() {
        let formatter = DateFormatter()
        formatter.dateFormat = "H:mm"
        formatter.locale = Locale(identifier: Locale.preferredLanguages.first ?? "en_US_POSIX")
        clockLabel.stringValue = formatter.string(from: Date())
        clockLabel.sizeToFit()
    }
}
