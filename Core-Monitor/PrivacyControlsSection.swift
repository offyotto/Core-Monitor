import SwiftUI

struct PrivacyControlsSectionContent: View {
    @ObservedObject private var privacySettings = PrivacySettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Privacy Controls")
                .font(.system(size: 16, weight: .bold))

            Toggle(
                "Include top app context in memory views",
                isOn: $privacySettings.processInsightsEnabled
            )
            .toggleStyle(.switch)

            Text(description)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if privacySettings.processInsightsEnabled == false {
                Text("Private mode is on.")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.bdAccent)
            }
        }
    }

    private var description: String {
        if privacySettings.processInsightsEnabled {
            return "Top app context stays on-device and helps explain CPU and memory spikes in the dashboard and menu bar."
        }

        return "Core Monitor still tracks memory pressure and top-process usage locally, but app names stay hidden from memory views while private mode is on."
    }
}
