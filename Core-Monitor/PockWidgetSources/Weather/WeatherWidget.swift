//
//  WeatherWidget.swift
//  Weather
//
//  Weather widget source for Core Monitor.
//

import AppKit
import Foundation

final class WeatherWidget: NSView, TouchBarThemable {
    private enum DisplayMode {
        case compact
        case expanded
    }

    var theme: TouchBarTheme = .dark {
        didSet { applyTheme() }
    }

    private let compactIconView = NSImageView(frame: .zero)
    private let expandedIconView = NSImageView(frame: .zero)
    private let compactTitleLabel = NSTextField(labelWithString: "Weather")
    private let compactSubtitleLabel = NSTextField(labelWithString: "Fetching data")
    private let expandedTitleLabel = NSTextField(labelWithString: "Weather")
    private let expandedSubtitleLabel = NSTextField(labelWithString: "Fetching data")
    private let detailLabel = NSTextField(labelWithString: "")
    private let compactLabelsStack = NSStackView(frame: .zero)
    private let expandedLabelsStack = NSStackView(frame: .zero)
    private let compactStack = NSStackView(frame: .zero)
    private let expandedTextStack = NSStackView(frame: .zero)
    private let expandedStack = NSStackView(frame: .zero)
    private let tapButton = NSButton(frame: .zero)
    private var displayMode: DisplayMode = .compact
    private var currentState: WeatherState = .idle

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func apply(state: WeatherState) {
        currentState = state
        switch state {
        case .idle:
            compactTitleLabel.stringValue = "Weather"
            compactSubtitleLabel.stringValue = "Waiting"
            expandedTitleLabel.stringValue = "Weather"
            expandedSubtitleLabel.stringValue = "Waiting"
            detailLabel.stringValue = ""
            compactIconView.image = defaultImage()
            expandedIconView.image = defaultImage()
        case .loading:
            compactTitleLabel.stringValue = "Weather"
            compactSubtitleLabel.stringValue = "Fetching data"
            expandedTitleLabel.stringValue = "Weather"
            expandedSubtitleLabel.stringValue = "Fetching data"
            detailLabel.stringValue = ""
            compactIconView.image = defaultImage()
            expandedIconView.image = defaultImage()
        case .loaded(let snapshot):
            compactTitleLabel.stringValue = snapshot.locationName
            compactSubtitleLabel.stringValue = "\(Int(snapshot.temperature.rounded()))°, \(snapshot.condition)"
            expandedTitleLabel.stringValue = snapshot.locationName
            expandedSubtitleLabel.stringValue = "\(Int(snapshot.temperature.rounded()))°, \(snapshot.condition)"
            detailLabel.stringValue = snapshot.nextRainSummary
            let icon = icon(for: snapshot)
            compactIconView.image = icon
            expandedIconView.image = icon
        case .error:
            compactTitleLabel.stringValue = "Weather"
            compactSubtitleLabel.stringValue = "Unavailable"
            expandedTitleLabel.stringValue = "Weather"
            expandedSubtitleLabel.stringValue = "Unavailable"
            detailLabel.stringValue = ""
            compactIconView.image = defaultImage()
            expandedIconView.image = defaultImage()
        }
        refreshLayout(animated: false)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        compactIconView.translatesAutoresizingMaskIntoConstraints = false
        compactIconView.imageScaling = .scaleProportionallyUpOrDown
        compactIconView.image = defaultImage()
        expandedIconView.translatesAutoresizingMaskIntoConstraints = false
        expandedIconView.imageScaling = .scaleProportionallyUpOrDown
        expandedIconView.image = defaultImage()

        compactTitleLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        compactSubtitleLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        expandedTitleLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        expandedSubtitleLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        detailLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        compactTitleLabel.lineBreakMode = .byTruncatingTail
        compactSubtitleLabel.lineBreakMode = .byTruncatingTail
        expandedTitleLabel.lineBreakMode = .byTruncatingTail
        expandedSubtitleLabel.lineBreakMode = .byTruncatingTail
        detailLabel.lineBreakMode = .byTruncatingTail

        compactLabelsStack.orientation = .vertical
        compactLabelsStack.alignment = .leading
        compactLabelsStack.spacing = 0
        compactLabelsStack.translatesAutoresizingMaskIntoConstraints = false
        compactLabelsStack.addArrangedSubview(compactTitleLabel)
        compactLabelsStack.addArrangedSubview(compactSubtitleLabel)

        expandedLabelsStack.orientation = .vertical
        expandedLabelsStack.alignment = .leading
        expandedLabelsStack.spacing = 0
        expandedLabelsStack.translatesAutoresizingMaskIntoConstraints = false
        expandedLabelsStack.addArrangedSubview(expandedTitleLabel)
        expandedLabelsStack.addArrangedSubview(expandedSubtitleLabel)

        compactStack.orientation = .horizontal
        compactStack.alignment = .centerY
        compactStack.spacing = 8
        compactStack.translatesAutoresizingMaskIntoConstraints = false
        compactIconView.translatesAutoresizingMaskIntoConstraints = false
        compactIconView.imageScaling = .scaleProportionallyUpOrDown
        compactStack.addArrangedSubview(compactIconView)
        compactStack.addArrangedSubview(compactLabelsStack)

        expandedTextStack.orientation = .vertical
        expandedTextStack.alignment = .leading
        expandedTextStack.spacing = 1
        expandedTextStack.translatesAutoresizingMaskIntoConstraints = false
        expandedTextStack.addArrangedSubview(expandedLabelsStack)
        expandedTextStack.addArrangedSubview(detailLabel)

        expandedStack.orientation = .horizontal
        expandedStack.alignment = .centerY
        expandedStack.spacing = 8
        expandedStack.translatesAutoresizingMaskIntoConstraints = false
        expandedIconView.translatesAutoresizingMaskIntoConstraints = false
        expandedIconView.imageScaling = .scaleProportionallyUpOrDown
        expandedStack.addArrangedSubview(expandedIconView)
        expandedStack.addArrangedSubview(expandedTextStack)

        addSubview(compactStack)
        addSubview(expandedStack)

        tapButton.translatesAutoresizingMaskIntoConstraints = false
        tapButton.title = ""
        tapButton.bezelStyle = .regularSquare
        tapButton.isBordered = false
        tapButton.isTransparent = true
        tapButton.focusRingType = .none
        tapButton.target = self
        tapButton.action = #selector(handleTap(_:))
        addSubview(tapButton)

        NSLayoutConstraint.activate([
            compactIconView.widthAnchor.constraint(equalToConstant: 18),
            compactIconView.heightAnchor.constraint(equalToConstant: 18),
            expandedIconView.widthAnchor.constraint(equalToConstant: 18),
            expandedIconView.heightAnchor.constraint(equalToConstant: 18),
            compactStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            compactStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            compactStack.topAnchor.constraint(equalTo: topAnchor),
            compactStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            expandedStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            expandedStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            expandedStack.topAnchor.constraint(equalTo: topAnchor),
            expandedStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            tapButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            tapButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            tapButton.topAnchor.constraint(equalTo: topAnchor),
            tapButton.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        applyTheme()
        refreshLayout(animated: false)
    }

    private func applyTheme() {
        compactTitleLabel.textColor = theme.primaryTextColor
        compactSubtitleLabel.textColor = theme.secondaryTextColor
        expandedTitleLabel.textColor = theme.primaryTextColor
        expandedSubtitleLabel.textColor = theme.secondaryTextColor
        detailLabel.textColor = theme.secondaryTextColor
    }

    @objc private func handleTap(_ sender: NSGestureRecognizer) {
        toggleMode()
    }

    private func toggleMode() {
        displayMode = displayMode == .compact ? .expanded : .compact
        refreshLayout(animated: true)
    }

    private func refreshLayout(animated: Bool) {
        let showingExpanded = displayMode == .expanded
        let expandedVisible = showingExpanded

        expandedStack.isHidden = !expandedVisible
        compactStack.isHidden = expandedVisible

        if animated {
            let transition = CATransition()
            transition.type = .push
            transition.subtype = expandedVisible ? .fromTop : .fromBottom
            transition.duration = 0.22
            wantsLayer = true
            layer?.add(transition, forKey: "weatherModeTransition")
        }

        invalidateIntrinsicContentSize()
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: estimatedWidth(), height: 30)
    }

    private func estimatedWidth() -> CGFloat {
        switch currentState {
        case .idle:
            return 56
        case .loading:
            return 80
        case .loaded(let snapshot):
            let tempStr = "\(Int(snapshot.temperature.rounded()))°"
            let detailStr = snapshot.nextRainSummary
            let timeStr = timeString()
            let tempW = tempStr.size(withAttributes: [.font: NSFont.systemFont(ofSize: 13, weight: .medium)]).width
            let timeW = timeStr.size(withAttributes: [.font: NSFont.systemFont(ofSize: 11, weight: .regular)]).width
            let detailW = detailStr.size(withAttributes: [.font: NSFont.systemFont(ofSize: 10, weight: .medium)]).width
            let compactW = 8 * 2 + 16 + 5 + tempW + 5 + timeW + 4
            let expandedW = 8 * 2 + 16 + 5 + max(tempW, timeW, detailW) + 10
            return displayMode == .expanded ? expandedW : compactW
        case .error:
            return 80
        }
    }

    private func timeString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE H:mm"
        return fmt.string(from: Date())
    }

    private func defaultImage() -> NSImage {
        if let image = NSImage(systemSymbolName: "cloud.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)) {
            image.isTemplate = true
            return image
        }
        return NSImage()
    }

    private func icon(for snapshot: WeatherSnapshot) -> NSImage {
        if let localIcon = NSImage(named: weatherAssetName(for: snapshot)) {
            return localIcon
        }

        if let systemIcon = NSImage(systemSymbolName: snapshot.symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)) {
            systemIcon.isTemplate = true
            return systemIcon
        }

        return defaultImage()
    }

    private func weatherAssetName(for snapshot: WeatherSnapshot) -> String {
        let symbol = snapshot.symbolName.lowercased()
        let night = symbol.contains("moon") || symbol.contains("night")
        let suffix = night ? "n" : "d"

        if symbol.contains("bolt") || symbol.contains("thunder") {
            return "11\(suffix)"
        }
        if symbol.contains("snow") || symbol.contains("sleet") || symbol.contains("hail") {
            return "13\(suffix)"
        }
        if symbol.contains("fog") || symbol.contains("haze") || symbol.contains("smoke") {
            return "50\(suffix)"
        }
        if symbol.contains("drizzle") {
            return "09\(suffix)"
        }
        if symbol.contains("rain") {
            return symbol.contains("sun") || symbol.contains("moon") ? "10\(suffix)" : "09\(suffix)"
        }
        if symbol.contains("cloud.sun") || symbol.contains("sun.max") {
            return "02\(suffix)"
        }
        if symbol.contains("cloud.moon") {
            return "02n"
        }
        if symbol.contains("cloud") {
            return "04\(suffix)"
        }
        if symbol.contains("sun") || symbol.contains("moon") || symbol.contains("clear") {
            return "01\(suffix)"
        }

        return "03\(suffix)"
    }
}
