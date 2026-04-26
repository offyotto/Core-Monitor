import SwiftUI

struct FanModeGuidanceCard: View {
    let mode: FanControlMode
    let hasFans: Bool

    @ObservedObject private var helperManager = SMCHelperManager.shared

    var body: some View {
        let guidance = mode.guidance

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Selected Mode")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(mode.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(primaryColor)
                    Text(guidance.summary)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Text(ownershipLabel)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(primaryColor.opacity(0.14))
                    .clipShape(Capsule())
            }

            HStack(spacing: 8) {
                guidancePill(helperRequirementLabel, color: helperRequirementColor)
                if guidance.restoresSystemAutomaticOnExit {
                    guidancePill("Auto On Quit", color: .green)
                }
                if guidance.ownership == .system {
                    guidancePill("macOS Curve", color: .green)
                }
            }

            Text(guidance.detail)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let runtimeNote {
                Label(runtimeNote, systemImage: runtimeIcon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(runtimeColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let delayedResponseNote = FanModeGuidanceCopy.appleSiliconDelayedResponseNote(
                for: mode,
                hasFans: hasFans,
                hostModelIdentifier: SystemMonitor.hostModelIdentifier()
            ) {
                Label(delayedResponseNote, systemImage: "exclamationmark.triangle")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var ownershipLabel: String {
        switch mode.guidance.ownership {
        case .system:
            return "System Controlled"
        case .coreMonitor:
            return "Core Monitor"
        }
    }

    private var primaryColor: Color {
        switch mode.guidance.ownership {
        case .system:
            return .green
        case .coreMonitor:
            return Color.bdAccent
        }
    }

    private var runtimeNote: String? {
        guard hasFans else {
            return "This Mac is not exposing controllable fans, so monitoring stays available but fan overrides cannot take effect."
        }

        guard mode.guidance.requiresHelper else {
            return "macOS owns the fan curve in this mode. Core Monitor keeps monitoring, alerts, and trend history active."
        }

        switch mode.guidance.helperRequirement {
        case .none:
            return "macOS owns the fan curve in this mode. Core Monitor keeps monitoring, alerts, and trend history active."
        case .handoff:
            switch helperManager.connectionState {
            case .reachable:
                return "Silent mode uses the helper once to return fan ownership to the firmware curve, then Core Monitor stays passive and keeps monitoring."
            case .checking:
                return "The helper trust check is still running. Wait for Ready before relying on Silent mode to confirm the handoff back to the firmware curve."
            case .unreachable:
                return helperManager.statusMessage ?? "Silent mode could not confirm the handoff back to the firmware curve because the installed helper is rejecting this app build."
            case .missing, .unknown:
                return "Silent mode still needs one successful helper handoff to guarantee the firmware curve is restored before Core Monitor becomes passive."
            }
        case .managedControl:
            switch helperManager.connectionState {
            case .reachable:
                return "Core Monitor will return fans to system automatic when you press Reset to System Auto and again when the app quits."
            case .checking:
                return "The helper trust check is still running. Wait for Ready before relying on managed fan control."
            case .unreachable:
                return helperManager.statusMessage ?? "The installed helper is rejecting this app build, so managed fan writes are not trustworthy yet."
            case .missing, .unknown:
                return "Install and verify the helper before trusting this mode for sustained workloads."
            }
        }
    }

    private var runtimeIcon: String {
        switch (mode.guidance.helperRequirement, helperManager.connectionState) {
        case (.handoff, .reachable):
            return "arrow.trianglehead.clockwise"
        case (_, .reachable) where mode.guidance.ownership == .coreMonitor:
            return "checkmark.shield"
        case (_, .reachable):
            return "leaf"
        case (_, .checking):
            return "arrow.triangle.2.circlepath"
        case (_, .unreachable):
            return "xmark.shield"
        case (_, .missing), (_, .unknown):
            return "lock.shield"
        }
    }

    private var runtimeColor: Color {
        switch (mode.guidance.helperRequirement, helperManager.connectionState) {
        case (.handoff, .reachable):
            return .orange
        case (_, .reachable):
            return mode.guidance.ownership == .coreMonitor ? .green : .secondary
        case (_, .checking):
            return Color.bdAccent
        case (_, .unreachable):
            return .orange
        case (_, .missing), (_, .unknown):
            return .secondary
        }
    }

    private var helperRequirementLabel: String {
        switch mode.guidance.helperRequirement {
        case .none:
            return "Monitoring Only"
        case .handoff:
            return "Helper Handoff"
        case .managedControl:
            return "Managed Fans"
        }
    }

    private var helperRequirementColor: Color {
        switch mode.guidance.helperRequirement {
        case .none:
            return .green
        case .handoff, .managedControl:
            return .orange
        }
    }

    private func guidancePill(_ text: String, color: Color) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
    }
}

enum FanModeGuidanceCopy {
    static func appleSiliconDelayedResponseNote(
        for mode: FanControlMode,
        hasFans: Bool,
        hostModelIdentifier: String,
        isAppleSilicon: Bool = SystemMonitor.isAppleSilicon
    ) -> String? {
        guard mode.guidance.showsAppleSiliconDelayedResponseNote, hasFans, isAppleSilicon else {
            return nil
        }

        guard let model = MacModelRegistry.entry(for: hostModelIdentifier), model.family.isAppleSiliconPortable else {
            return nil
        }

        return "On \(model.friendlyName), macOS may hold fan RPM near its baseline until extra airflow is needed, so a manual target can take a moment to react on a cool machine."
    }
}
