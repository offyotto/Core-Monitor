import Foundation

enum MenuBarStatusPillTone: Equatable {
    case neutral
    case accent
    case good
    case warning
    case critical
}

struct MenuBarStatusPillSummary: Equatable {
    let label: String
    let tone: MenuBarStatusPillTone
}

enum MenuBarStatusSummary {
    static func fanModeSummary(for mode: FanControlMode) -> MenuBarStatusPillSummary {
        let resolvedMode = mode.canonicalMode

        if resolvedMode == .automatic {
            return MenuBarStatusPillSummary(label: "System Cooling", tone: .good)
        }

        let tone: MenuBarStatusPillTone = resolvedMode.guidance.ownership == .system ? .good : .accent
        return MenuBarStatusPillSummary(label: "Mode \(resolvedMode.title)", tone: tone)
    }

    static func helperSummary(
        for mode: FanControlMode,
        connectionState: SMCHelperManager.ConnectionState,
        isInstalled: Bool
    ) -> MenuBarStatusPillSummary {
        guard mode.requiresPrivilegedHelper else {
            if connectionState == .unreachable {
                return MenuBarStatusPillSummary(label: "Helper Attention", tone: .critical)
            }
            return MenuBarStatusPillSummary(label: "Helper Optional", tone: .neutral)
        }

        switch connectionState {
        case .reachable:
            return MenuBarStatusPillSummary(label: "Helper Ready", tone: .good)
        case .checking:
            return MenuBarStatusPillSummary(label: "Helper Checking", tone: .neutral)
        case .unreachable:
            return MenuBarStatusPillSummary(label: "Helper Attention", tone: .critical)
        case .unknown where isInstalled:
            return MenuBarStatusPillSummary(label: "Helper Pending", tone: .warning)
        case .unknown, .missing:
            return MenuBarStatusPillSummary(label: "Helper Missing", tone: .warning)
        }
    }
}
