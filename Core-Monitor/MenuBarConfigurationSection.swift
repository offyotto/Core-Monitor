import SwiftUI

struct MenuBarSettingsCard: View {
    struct Snapshot {
        var cpuUsagePercent: Double
        var memoryUsagePercent: Double
        var diskUsagePercent: Double
        var cpuTemperature: Double?
    }

    @ObservedObject private var menuBarSettings = MenuBarSettings.shared

    let snapshot: Snapshot

    var body: some View {
        CoreMonGlassPanel(
            cornerRadius: 18,
            tintOpacity: 0.12,
            strokeOpacity: 0.14,
            shadowRadius: 10,
            contentPadding: 16
        ) {
            VStack(alignment: .leading, spacing: 14) {
                header
                presetSection
                toggleSection

                if let warning = menuBarSettings.lastWarning, !warning.isEmpty {
                    Text(warning)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Menu Bar")
                    .font(.system(size: 13, weight: .semibold))
                Text("Apply a preset or fine-tune each live item. Changes appear immediately.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(summaryLine)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.bdAccent)
            }

            Spacer(minLength: 12)

            Button("Restore Balanced") {
                menuBarSettings.restoreDefaults()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Presets")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 8)], spacing: 8) {
                ForEach(MenuBarVisibilityPreset.allCases) { preset in
                    Button {
                        menuBarSettings.applyPreset(preset)
                    } label: {
                        MenuBarPresetChip(
                            title: preset.title,
                            detail: preset.detail,
                            isRecommended: preset.isRecommended,
                            isSelected: menuBarSettings.activePreset == preset
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if menuBarSettings.activePreset == nil {
                Text("Custom layout active. Toggle individual items below for a mixed setup.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var toggleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Visible Items")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(MenuBarItemKind.allCases.enumerated()), id: \.element.defaultsKey) { index, kind in
                    if index > 0 {
                        Rectangle()
                            .fill(Color.bdDivider)
                            .frame(height: 1)
                            .padding(.vertical, 6)
                    }

                    MenuBarToggleRow(
                        kind: kind,
                        detail: detail(for: kind),
                        preview: preview(for: kind),
                        isOn: binding(for: kind)
                    )
                }
            }
        }
    }

    private var summaryLine: String {
        let count = menuBarSettings.enabledItemCount
        let presetTitle = menuBarSettings.activePreset?.title ?? "Custom"
        let noun = count == 1 ? "item" : "items"
        return "\(count) live \(noun) visible · \(presetTitle)"
    }

    private func detail(for kind: MenuBarItemKind) -> String {
        switch kind {
        case .cpu:
            return "Core load at a glance."
        case .memory:
            return "Unified memory pressure and usage."
        case .network:
            return "Live download and upload throughput."
        case .disk:
            return "Startup disk capacity, not I/O throughput."
        case .temperature:
            return "CPU thermal signal when SMC is reachable."
        }
    }

    private func preview(for kind: MenuBarItemKind) -> String {
        switch kind {
        case .cpu:
            return "CPU \(Int(snapshot.cpuUsagePercent.rounded()))%"
        case .memory:
            return "MEM \(Int(snapshot.memoryUsagePercent.rounded()))%"
        case .network:
            return "NET Live"
        case .disk:
            return "SSD \(Int(snapshot.diskUsagePercent.rounded()))%"
        case .temperature:
            if let cpuTemperature = snapshot.cpuTemperature {
                return "\(Int(cpuTemperature.rounded()))°"
            }
            return "—°"
        }
    }

    private func binding(for kind: MenuBarItemKind) -> Binding<Bool> {
        Binding(
            get: { menuBarSettings.isEnabled(kind) },
            set: { menuBarSettings.setEnabled($0, for: kind) }
        )
    }
}

private struct MenuBarPresetChip: View {
    let title: String
    let detail: String
    let isRecommended: Bool
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.bdAccent : .primary)
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.bdAccent : .secondary)
            }

            if isRecommended {
                Text("Recommended")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.bdAccent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.bdAccent.opacity(0.14))
                    .clipShape(Capsule())
            }

            Text(detail)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.bdAccent.opacity(0.16) : Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? Color.bdAccent.opacity(0.45) : Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct MenuBarToggleRow: View {
    let kind: MenuBarItemKind
    let detail: String
    let preview: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Label(kind.title, systemImage: kind.systemImageName)
                    .font(.system(size: 12, weight: .medium))
                Text(detail)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Text(preview)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(isOn ? Color.bdAccent : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.05))
                .clipShape(Capsule())

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Color.bdAccent)
        }
    }
}
