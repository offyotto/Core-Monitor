import SwiftUI

/// First-launch sheet. One screen, three promises, no tour.
struct WelcomeView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 8) {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text("Welcome to Core Monitor")
                    .font(.title2.weight(.semibold))

                Text("Live hardware readings for Apple Silicon, kept on this Mac.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 16) {
                welcomePoint(
                    symbol: "waveform.path.ecg",
                    tint: MetricTint.cpu,
                    title: "Everything at a glance",
                    detail: "CPU, memory, temperatures, fans, power, and network — with history charts for each."
                )
                welcomePoint(
                    symbol: "menubar.rectangle",
                    tint: MetricTint.network,
                    title: "Lives in your menu bar",
                    detail: "Pick the readouts you want in Settings › Menu Bar. Each one opens a live popover."
                )
                welcomePoint(
                    symbol: "fan",
                    tint: MetricTint.cooling,
                    title: "Fan control is optional",
                    detail: "Monitoring never needs special access. Taking over the fans asks for an administrator-approved helper first."
                )
            }
            .frame(maxWidth: 380)

            VStack(spacing: 8) {
                Button("Start Monitoring") {
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)

                Text("No account. No telemetry. Open source.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 6)
        }
        .padding(28)
        .frame(width: 460)
    }

    private func welcomePoint(symbol: String, tint: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
