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
        case .controlCenter: return "Brightness & Volume"
        case .dock: return "Dock"
        case .cpu: return "CPU"
        case .stats: return "Stats"
        case .detailedStats: return "Stats + Clock"
        case .combined: return "Combined"
        case .hardware: return "Hardware"
        case .network: return "Network"
        case .ramPressure: return "RAM Pressure"
        }
    }

    var subtitle: String {
        switch self {
        case .worldClocks: return "Wi-Fi, battery, and clock"
        case .weather: return "Live conditions and rain timing"
        case .controlCenter: return "Brightness and volume controls"
        case .dock: return "Running apps and pinned favorites"
        case .cpu: return "Load, temperature, and usage bar"
        case .stats: return "Time with MEM, SSD, and CPU meters"
        case .detailedStats: return "Stats plus a longer clock readout"
        case .combined: return "Dense status strip with power and network"
        case .hardware: return "System glyphs and mini graphs"
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
