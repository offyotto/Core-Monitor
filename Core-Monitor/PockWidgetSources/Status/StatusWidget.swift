//
//  StatusWidget.swift
//  Status
//
//  Status widget source for Core Monitor.
//

import AppKit
import Foundation

final class StatusWidget: NSStackView, TouchBarThemable {
    var theme: TouchBarTheme = .dark {
        didSet { applyTheme() }
    }

    private var loadedItems: [StatusItem] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    deinit {
        clearItems()
    }

    private func setup() {
        orientation = .horizontal
        alignment = .centerY
        distribution = .fill
        spacing = 12
        translatesAutoresizingMaskIntoConstraints = false
        loadStatusElements()
    }

    func reload() {
        for item in loadedItems {
            item.reload()
        }
    }

    private func clearItems() {
        for view in arrangedSubviews {
            removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for item in loadedItems {
            item.didUnload()
        }

        loadedItems.removeAll()
    }

    private func loadStatusElements() {
        clearItems()

        let items: [StatusItem] = [
            SWifiItem(),
            SPowerItem(),
            SClockItem()
        ]

        loadedItems = items
        for item in items {
            item.apply(theme: theme)
            let view = item.view
            view.translatesAutoresizingMaskIntoConstraints = false
            addArrangedSubview(view)
        }
    }

    private func applyTheme() {
        for item in loadedItems {
            item.apply(theme: theme)
        }
    }
}
