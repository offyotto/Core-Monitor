import AppKit
import CoreGraphics

enum TouchBarWidgetKind: String, CaseIterable, Codable, Identifiable {
    case worldClocks
    case weather
    case controlCenter
    case dock
    case cpu
    case stats
    case detailedStats
    case combined
    case hardware
    case network
    case ramPressure

    var id: String { rawValue }

    var title: String {
        switch self {
        case .worldClocks: return "Status"
        case .weather: return "Weather"
        case .controlCenter: return "Brightness and Volume"
        case .dock: return "Dock"
        case .cpu: return "CPU"
        case .stats: return "Stats"
        case .detailedStats: return "Stats and Clock"
        case .combined: return "Combined"
        case .hardware: return "Hardware"
        case .network: return "Network"
        case .ramPressure: return "Memory Pressure"
        }
    }

    var subtitle: String {
        switch self {
        case .worldClocks: return "Wi-Fi, battery, and clock"
        case .weather: return "Local weather. Requires a WeatherKit-enabled build; location access enables local conditions."
        case .controlCenter: return "Brightness and volume controls"
        case .dock: return "Running apps and pinned items"
        case .cpu: return "CPU load, temperature, and activity"
        case .stats: return "Time, memory, storage, and CPU"
        case .detailedStats: return "Expanded meters with time and date"
        case .combined: return "Dense status view with power and network"
        case .hardware: return "System icons and mini graphs"
        case .network: return "Live upload and download rates"
        case .ramPressure: return "Memory pressure meter"
        }
    }

    var identifier: NSTouchBarItem.Identifier {
        NSTouchBarItem.Identifier("com.coremonitor.touchbar.\(rawValue)")
    }

    var estimatedWidth: CGFloat {
        switch self {
        case .worldClocks: return 182
        case .weather: return 208
        case .controlCenter: return 144
        case .dock: return 96
        case .cpu: return 128
        case .stats: return 314
        case .detailedStats: return 348
        case .combined: return 628
        case .hardware: return 380
        case .network: return 180
        case .ramPressure: return 74
        }
    }
}
