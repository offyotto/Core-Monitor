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
                guidancePill(guidance.requiresHelper ? "Helper Path" : "Monitoring Only", color: guidance.requiresHelper ? .orange : .green)
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

            if guidance.showsAppleSiliconDelayedResponseNote && SystemMonitor.isAppleSilicon {
                Label(
                    "Some Apple Silicon notebooks only change RPM after macOS has already asked for airflow, so a manual target may not move immediately on a cool machine.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(
            CoreMonGlassBackground(
                cornerRadius: 18,
                tintOpacity: 0.12,
                strokeOpacity: 0.14,
                shadowRadius: 10
            )
        )
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

        switch helperManager.connectionState {
        case .reachable:
            if mode.guidance.ownership == .system {
                return "The helper is ready if you need to switch back into a managed profile later."
            }
            return "Core Monitor will return fans to system automatic when you press Reset to System Auto and again when the app quits."
        case .checking:
            return "The helper trust check is still running. Wait for Ready before relying on managed fan control."
        case .unreachable:
            return helperManager.statusMessage ?? "The installed helper is rejecting this app build, so managed fan writes are not trustworthy yet."
        case .missing, .unknown:
            return "Install and verify the helper before trusting this mode for sustained workloads."
        }
    }

    private var runtimeIcon: String {
        switch helperManager.connectionState {
        case .reachable where mode.guidance.ownership == .coreMonitor:
            return "checkmark.shield"
        case .reachable:
            return "leaf"
        case .checking:
            return "arrow.triangle.2.circlepath"
        case .unreachable:
            return "xmark.shield"
        case .missing, .unknown:
            return "lock.shield"
        }
    }

    private var runtimeColor: Color {
        switch helperManager.connectionState {
        case .reachable:
            return mode.guidance.ownership == .coreMonitor ? .green : .secondary
        case .checking:
            return Color.bdAccent
        case .unreachable:
            return .orange
        case .missing, .unknown:
            return .secondary
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
