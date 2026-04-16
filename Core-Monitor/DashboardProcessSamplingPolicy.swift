import Foundation

enum DashboardProcessSamplingPolicy {
    static func requiresDetailedSampling(
        isBasicMode: Bool,
        selection: SidebarItem
    ) -> Bool {
        guard isBasicMode == false else { return false }

        switch selection {
        case .memory:
            return true
        case .overview, .thermals, .fans, .battery, .system, .touchBar, .help, .about:
            return false
        }
    }
}
