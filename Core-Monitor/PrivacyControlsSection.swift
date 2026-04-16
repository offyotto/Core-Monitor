import SwiftUI

struct PrivacyControlsSectionContent: View {
    @ObservedObject var alertManager: AlertManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Privacy Controls")
                .font(.system(size: 16, weight: .bold))

            Toggle(
                "Include top app context in alerts and memory views",
                isOn: Binding(
                    get: { alertManager.processInsightsEnabled },
                    set: { alertManager.setProcessInsightsEnabled($0) }
                )
            )
            .toggleStyle(.switch)

            Text(description)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button("Clear Alert History") {
                    alertManager.clearHistory()
                }
                .buttonStyle(.bordered)

                if alertManager.processInsightsEnabled == false {
                    Text("Private mode is on.")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.bdAccent)
                }
            }
        }
    }

    private var description: String {
        if alertManager.processInsightsEnabled {
            return "Top app context stays on-device and helps explain CPU and memory spikes. Turn it off to keep alert history free of process names."
        }

        return "Core Monitor still evaluates thresholds, but active alerts and recent history no longer retain process names. You can find the same control from both the Alerts and System tabs."
    }
}
