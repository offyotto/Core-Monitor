// PillView.swift
// CoreMonitor — reusable dark rounded-rect group container.
//
// Every iStat group sits in one of these pills:
//   ┌────────────────────┐  ← TB.pillH tall (24pt), TB.pillRadius corner
//   │  [content views]   │
//   └────────────────────┘
//  Strip bg (#000) shows between pills.

import AppKit

final class PillView: NSView {

    // Content is placed inside `contentView`; auto-sized to fit.
    let contentView = NSView()

    // Explicit fixed width override (pass 0 to auto-size)
    var fixedWidth: CGFloat = 0 {
        didSet { invalidateIntrinsicContentSize() }
    }

    var theme: TouchBarTheme = .dark {
        didSet { applyTheme() }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = TB.pillRadius
        layer?.borderWidth = 1
        applyTheme()

        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor,  constant: TB.hPad),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -TB.hPad),
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func applyTheme() {
        layer?.backgroundColor = theme.pillBackgroundColor.cgColor
        layer?.borderColor = theme.pillBorderColor.cgColor
    }

    override var intrinsicContentSize: NSSize {
        let cw = fixedWidth > 0 ? fixedWidth : contentView.fittingSize.width + TB.hPad * 2
        return NSSize(width: cw, height: TB.pillH)
    }
}
