// TouchBarIdentifiers.swift
// CoreMonitor — central registry for all NSTouchBarItem identifiers.

import AppKit

extension NSTouchBarItem.Identifier {
    // Left section
    static let timezone      = NSTouchBarItem.Identifier("com.coremon.tb.timezone")
    // Centre (`.weather` is already defined by WeatherTouchBarItem.swift)
    static let systemStats   = NSTouchBarItem.Identifier("com.coremon.tb.systemstats")
    static let combined      = NSTouchBarItem.Identifier("com.coremon.tb.combined")
    // Right section
    static let network       = NSTouchBarItem.Identifier("com.coremon.tb.network")
    static let hardware      = NSTouchBarItem.Identifier("com.coremon.tb.hardware")
}
