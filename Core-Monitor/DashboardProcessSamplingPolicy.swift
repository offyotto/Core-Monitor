import Foundation

enum DashboardProcessSamplingPolicy {
    static func requiresDetailedSampling(
        isBasicMode: Bool,
        selection: MonitorSection
    ) -> Bool {
        guard isBasicMode == false else { return false }

        switch selection {
        case .cpu, .memory:
            return true
        case .overview, .thermal, .cooling, .power, .network, .storage, .rescue:
            return false
        }
    }
}
