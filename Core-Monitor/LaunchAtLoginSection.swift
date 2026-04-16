import SwiftUI

struct LaunchAtLoginSection: View {
    @ObservedObject var startupManager: StartupManager

    var body: some View {
        let summary = startupManager.statusSummary

        VStack(alignment: .leading, spacing: 10) {
            CoreMonGlassPanel(
                cornerRadius: 18,
                tintOpacity: 0.12,
                strokeOpacity: 0.14,
                shadowRadius: 10,
                contentPadding: 16
            ) {
                HStack(spacing: 14) {
                    Image(systemName: "power")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(iconColor(for: summary.tone))
                        .frame(width: 32, height: 32)
                        .background(iconColor(for: summary.tone).opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Launch at Login")
                            .font(.system(size: 13, weight: .semibold))
                        Text(primaryDetail(for: summary))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle(
                        "",
                        isOn: Binding(
                            get: { startupManager.isEnabled },
                            set: { startupManager.setEnabled($0) }
                        )
                    )
                    .toggleStyle(.switch)
                    .tint(.green)
                }
            }

            if let message = startupManager.errorMessage, message.isEmpty == false {
                CoreMonGlassPanel(
                    cornerRadius: 16,
                    tintOpacity: 0.10,
                    strokeOpacity: 0.12,
                    shadowRadius: 8,
                    contentPadding: 14
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(message)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.orange)

                                Text("Core Monitor keeps monitoring normally, but login-item control needs attention.")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if summary.action == .openSystemSettings {
                            Button(summary.actionTitle ?? "Open Login Items") {
                                startupManager.openLoginItemsSettings()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
        .onAppear {
            startupManager.refreshState()
        }
    }

    private func iconColor(for tone: LaunchAtLoginStatusTone) -> Color {
        switch tone {
        case .positive:
            return .green
        case .neutral:
            return .secondary
        case .caution:
            return .orange
        }
    }

    private func primaryDetail(for summary: LaunchAtLoginStatusSummary) -> String {
        switch summary.tone {
        case .positive:
            return "Starts automatically with macOS"
        case .neutral:
            return "Start manually from Applications"
        case .caution:
            return "Review Login Items in System Settings"
        }
    }
}
