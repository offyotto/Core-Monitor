//
//  SClockItem.swift
//  Status widget item for Core Monitor.
//

import AppKit
import Foundation

final class SClockItem: StatusItem {
    private let clockLabel = NSTextField(labelWithString: "…")
    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("Hm")
        return formatter
    }()

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
    }

    func didUnload() {}

    func apply(theme: TouchBarTheme) {
        clockLabel.textColor = theme.primaryTextColor
    }

    @objc func reload() {
        formatter.locale = AppLocaleStore.currentLocale
        clockLabel.stringValue = formatter.string(from: Date())
        clockLabel.sizeToFit()
    }
}
