import SwiftUI

enum QualityRatingEngine {
    static func evaluate(
        avgLoad: Double,
        peakTemp: Double,
        opsTimeline: [Double]
    ) -> QualityRating {
        let throttled = peakTemp > 100 || hasThermalThrottle(opsTimeline: opsTimeline)
        if throttled { return .thermalThrottle }
        if avgLoad > 95, peakTemp < 90 { return .platinum }
        if avgLoad > 85, peakTemp < 95 { return .gold }
        if avgLoad > 70 { return .silver }
        return .bronze
    }

    private static func hasThermalThrottle(opsTimeline: [Double]) -> Bool {
        guard opsTimeline.count >= 12 else { return false }
        let earlier = opsTimeline.dropLast(10).suffix(5)
        let later = opsTimeline.suffix(10)
        guard !earlier.isEmpty, !later.isEmpty else { return false }
        let earlierAvg = earlier.reduce(0, +) / Double(earlier.count)
        let laterAvg = later.reduce(0, +) / Double(later.count)
        guard earlierAvg > 0 else { return false }
        return laterAvg < earlierAvg * 0.85
    }
}

extension QualityRating {
    var title: String {
        switch self {
        case .platinum: return "Platinum"
        case .gold: return "Gold"
        case .silver: return "Silver"
        case .bronze: return "Bronze"
        case .thermalThrottle: return "Thermal Throttle"
        }
    }

    func displayTitle(customFanControl: Bool) -> String {
        customFanControl ? "\(title) (Custom Fan Control)" : title
    }

    var symbolName: String {
        switch self {
        case .platinum: return "crown.fill"
        case .gold: return "medal.fill"
        case .silver: return "seal.fill"
        case .bronze: return "circle.hexagongrid.fill"
        case .thermalThrottle: return "thermometer.high"
        }
    }

    var color: Color {
        switch self {
        case .platinum: return Color(red: 0.72, green: 0.93, blue: 1.0)
        case .gold: return Color(red: 1.0, green: 0.79, blue: 0.24)
        case .silver: return Color(red: 0.78, green: 0.82, blue: 0.90)
        case .bronze: return Color(red: 0.73, green: 0.46, blue: 0.24)
        case .thermalThrottle: return Color.red
        }
    }

    var description: String {
        switch self {
        case .platinum: return "High sustained load with clean thermal headroom."
        case .gold: return "Strong sustained load with moderate heat."
        case .silver: return "Stable but below peak sustained throughput."
        case .bronze: return "Low sustained throughput."
        case .thermalThrottle: return "Performance fell off under thermal pressure."
        }
    }
}
