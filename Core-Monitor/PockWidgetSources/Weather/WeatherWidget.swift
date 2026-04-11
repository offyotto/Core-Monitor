//
//  WeatherWidget.swift
//  Weather
//
//  Adapted from Pock's weather-widget sources for Core Monitor.
//

import AppKit
import Foundation

final class WeatherWidget: NSView, TouchBarThemable {
    var theme: TouchBarTheme = .dark {
        didSet { applyTheme() }
    }

    private let iconView = NSImageView(frame: .zero)
    private let titleLabel = NSTextField(labelWithString: "Weather")
    private let subtitleLabel = NSTextField(labelWithString: "Fetching data")
    private let labelsStack = NSStackView(frame: .zero)
    private let contentStack = NSStackView(frame: .zero)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func apply(state: WeatherState) {
        switch state {
        case .idle:
            titleLabel.stringValue = "Weather"
            subtitleLabel.stringValue = "Waiting"
            iconView.image = defaultImage()
        case .loading:
            titleLabel.stringValue = "Weather"
            subtitleLabel.stringValue = "Fetching data"
            iconView.image = defaultImage()
        case .loaded(let snapshot):
            titleLabel.stringValue = snapshot.locationName
            subtitleLabel.stringValue = "\(Int(snapshot.temperature.rounded()))°, \(snapshot.condition)"
            iconView.image = icon(for: snapshot)
        case .error:
            titleLabel.stringValue = "Weather"
            subtitleLabel.stringValue = "Unavailable"
            iconView.image = defaultImage()
        }
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.image = defaultImage()

        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        subtitleLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        titleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.lineBreakMode = .byTruncatingTail

        labelsStack.orientation = .vertical
        labelsStack.alignment = .leading
        labelsStack.spacing = 0
        labelsStack.translatesAutoresizingMaskIntoConstraints = false
        labelsStack.addArrangedSubview(titleLabel)
        labelsStack.addArrangedSubview(subtitleLabel)

        contentStack.orientation = .horizontal
        contentStack.alignment = .centerY
        contentStack.spacing = 8
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(iconView)
        contentStack.addArrangedSubview(labelsStack)
        addSubview(contentStack)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        applyTheme()
    }

    private func applyTheme() {
        titleLabel.textColor = theme.primaryTextColor
        subtitleLabel.textColor = theme.secondaryTextColor
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
        if let localIcon = NSImage(named: pockIconName(for: snapshot)) {
            return localIcon
        }

        if let systemIcon = NSImage(systemSymbolName: snapshot.symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)) {
            systemIcon.isTemplate = true
            return systemIcon
        }

        return defaultImage()
    }

    private func pockIconName(for snapshot: WeatherSnapshot) -> String {
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
