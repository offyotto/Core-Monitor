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
    private let compactSubtitleLabel = NSTextField(labelWithString: "Updating weather")
    private let expandedTitleLabel = NSTextField(labelWithString: "Weather")
    private let expandedSubtitleLabel = NSTextField(labelWithString: "Updating weather")
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
        let tooltip: String
        switch state {
        case .idle:
            compactTitleLabel.stringValue = "Weather"
            compactSubtitleLabel.stringValue = "Waiting for location"
            expandedTitleLabel.stringValue = "Weather"
            expandedSubtitleLabel.stringValue = "Waiting for location"
            detailLabel.stringValue = ""
            compactIconView.image = defaultImage()
            expandedIconView.image = defaultImage()
            tooltip = "Waiting for location"
        case .loading:
            compactTitleLabel.stringValue = "Weather"
            compactSubtitleLabel.stringValue = "Updating weather"
            expandedTitleLabel.stringValue = "Weather"
            expandedSubtitleLabel.stringValue = "Updating weather"
            detailLabel.stringValue = ""
            compactIconView.image = defaultImage()
            expandedIconView.image = defaultImage()
            tooltip = "Updating weather"
        case .loaded(let snapshot):
            compactTitleLabel.stringValue = snapshot.locationName
            compactSubtitleLabel.stringValue = "\(Int(snapshot.temperature.rounded()))°, \(snapshot.condition)"
            expandedTitleLabel.stringValue = snapshot.locationName
            expandedSubtitleLabel.stringValue = expandedSummary(for: snapshot)
            detailLabel.stringValue = snapshot.nextRainSummary
            let icon = icon(for: snapshot)
            compactIconView.image = icon
            expandedIconView.image = icon
            tooltip = weatherTooltip(for: snapshot)
        case .error(let message):
            let errorPresentation = weatherErrorPresentation(for: message)
            compactTitleLabel.stringValue = "Weather"
            compactSubtitleLabel.stringValue = errorPresentation.subtitle
            expandedTitleLabel.stringValue = "Weather"
            expandedSubtitleLabel.stringValue = errorPresentation.subtitle
            detailLabel.stringValue = errorPresentation.detail
            compactIconView.image = defaultImage()
            expandedIconView.image = defaultImage()
            tooltip = message
        }
        toolTip = tooltip
        tapButton.toolTip = tooltip
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

        compactTitleLabel.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        compactSubtitleLabel.font = NSFont.systemFont(ofSize: 8, weight: .regular)
        expandedTitleLabel.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        expandedSubtitleLabel.font = NSFont.systemFont(ofSize: 8, weight: .regular)
        detailLabel.font = NSFont.systemFont(ofSize: 8, weight: .regular)
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
        expandedTextStack.spacing = 0
        expandedTextStack.translatesAutoresizingMaskIntoConstraints = false
        expandedTextStack.addArrangedSubview(expandedLabelsStack)

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
        compactIconView.contentTintColor = theme.primaryTextColor
        expandedIconView.contentTintColor = theme.primaryTextColor
    }

    @objc private func handleTap(_ sender: Any?) {
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
        detailLabel.isHidden = true

        if animated {
            let transition = CATransition()
            transition.type = .push
            transition.subtype = expandedVisible ? .fromTop : .fromBottom
            transition.duration = 0.22
            wantsLayer = true
            layer?.add(transition, forKey: "weatherModeTransition")
        }

        needsLayout = true
        invalidateIntrinsicContentSize()
        superview?.invalidateIntrinsicContentSize()
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: estimatedWidth(), height: TB.pillH)
    }

    private func estimatedWidth() -> CGFloat {
        let visibleStack = displayMode == .expanded ? expandedStack : compactStack
        let measuredWidth = ceil(visibleStack.fittingSize.width)

        switch currentState {
        case .idle:
            return max(56, measuredWidth)
        case .loading, .error:
            return max(80, measuredWidth)
        case .loaded:
            return measuredWidth
        }
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

    private func weatherTooltip(for snapshot: WeatherSnapshot) -> String {
        let high = Int(snapshot.high.rounded())
        let low = Int(snapshot.low.rounded())
        let feelsLike = Int(snapshot.feelsLike.rounded())
        return "\(snapshot.locationName) • \(snapshot.condition)\n\(snapshot.nextRainSummary)\nH \(high)° / L \(low)° • Feels like \(feelsLike)° • Humidity \(snapshot.humidity)%"
    }

    private func expandedSummary(for snapshot: WeatherSnapshot) -> String {
        let headline = "\(Int(snapshot.temperature.rounded()))°, \(snapshot.condition)"
        guard snapshot.nextRainSummary.isEmpty == false else {
            return headline
        }

        return "\(headline) • \(snapshot.nextRainSummary)"
    }

    private func weatherErrorPresentation(for message: String) -> (subtitle: String, detail: String) {
        let lowered = message.lowercased()
        if lowered.contains("optional") || lowered.contains("request location") {
            return ("Location Optional", "Request access from Touch Bar settings")
        }
        if lowered.contains("enable location") || lowered.contains("location") {
            return ("Location Off", "Enable access in System Settings")
        }
        return ("Unavailable", "")
    }
}
