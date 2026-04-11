//
//  SWifiItem.swift
//  Status widget item for Core Monitor.
//

import AppKit
import CoreWLAN
import Foundation

final class SWifiItem: StatusItem {
    private let wifiClient = CWWiFiClient.shared()
    private let iconView = NSImageView(frame: NSRect(x: 0, y: 0, width: 22, height: 22))

    init() {
        didLoad()
    }

    deinit {
        didUnload()
    }

    var view: NSView { iconView }

    func didLoad() {
        wifiClient.delegate = self
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.frame.size = NSSize(width: 20, height: 20)
        reload()
        try? wifiClient.startMonitoringEvent(with: .linkDidChange)
        try? wifiClient.startMonitoringEvent(with: .ssidDidChange)
        try? wifiClient.startMonitoringEvent(with: .powerDidChange)
        try? wifiClient.startMonitoringEvent(with: .linkQualityDidChange)
    }

    func didUnload() {
        wifiClient.delegate = nil
        try? wifiClient.stopMonitoringAllEvents()
    }

    func apply(theme: TouchBarTheme) {
        iconView.contentTintColor = theme.primaryTextColor
    }

    func reload() {
        let interface = wifiClient.interface()
        let rssi = interface?.rssiValue() ?? 0
        let iconName = imageName(for: rssi, poweredOn: interface?.powerOn() ?? false)

        if let image = NSImage(named: iconName)?.copy() as? NSImage {
            image.isTemplate = true
            iconView.image = image
        } else {
            let fallbackName = interface?.powerOn() == true ? "wifi" : "wifi.slash"
            let symbol = NSImage(systemSymbolName: fallbackName, accessibilityDescription: nil)?
                .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 15, weight: .regular))
            symbol?.isTemplate = true
            iconView.image = symbol
        }
    }

    private func imageName(for rssi: Int, poweredOn: Bool) -> String {
        guard poweredOn else { return "wifiOff" }
        let percentage = rssi == 0 ? 0 : min(max(2 * (rssi + 100), 0), 100)
        let code = Int(percentage / 10)

        switch code {
        case 0:
            return "wifiOff"
        default:
            let index = min(max(code - 1, 0), 4)
            return "wifi\(index)"
        }
    }
}

extension SWifiItem: CWEventDelegate {
    func linkDidChangeForWiFiInterface(withName interfaceName: String) {
        reload()
    }

    func ssidDidChangeForWiFiInterface(withName interfaceName: String) {
        reload()
    }

    func powerStateDidChangeForWiFiInterface(withName interfaceName: String) {
        reload()
    }

    func linkQualityDidChangeForWiFiInterface(withName interfaceName: String, rssi: Int, transmitRate: Double) {
        reload()
    }
}
