import SwiftUI

/// Read-only hardware diagnostics: USB-C controller state and drive SMART
/// health. Everything here diagnoses; nothing here writes to hardware.
struct RescuePage: View {
    @StateObject private var viewModel = HardwareRescueViewModel()

    var body: some View {
        MonitorPage("Rescue", subtitle: "Read-only hardware diagnostics for technicians.") {
            scanPanel
            controllersPanel
            storagePanel
        }
        .onAppear {
            if viewModel.snapshot == nil {
                viewModel.refresh()
            }
        }
    }

    // MARK: Scan / toolkit

    private var scanPanel: some View {
        Panel {
            HStack(spacing: 10) {
                Button {
                    viewModel.refresh()
                } label: {
                    Label(viewModel.isRefreshing ? "Scanning…" : "Scan Hardware", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isRefreshing)

                Button {
                    viewModel.copyReport()
                } label: {
                    Label("Copy Report", systemImage: "doc.on.doc")
                }
                .disabled(viewModel.snapshot == nil)

                Button {
                    viewModel.copyDiagnosisCommands()
                } label: {
                    Label("Copy Checks", systemImage: "terminal")
                }

                Button {
                    viewModel.copyRecoveryTemplate()
                } label: {
                    Label("Copy Recovery Template", systemImage: "exclamationmark.triangle")
                }
            }

            Text("Recovery templates are copy-only on purpose. Run them only after a controller reports BOOT or firmware 0, and only with the exact matching Apple firmware image.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let message = viewModel.pasteboardMessage {
                Label(message, systemImage: "checkmark.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: USB-C controllers

    private var controllersPanel: some View {
        Panel("USB-C Controllers") {
            if let snapshot = viewModel.snapshot {
                ReadingRow("Status", value: snapshot.usbStatusTitle, note: snapshot.usbStatusDetail)
                ReadingRow(
                    "Apple flasher",
                    value: snapshot.usbcfwflasherAvailable ? "Available" : "Unavailable",
                    note: "usbcfwflasher is only ever surfaced as a copyable technician command."
                )

                if snapshot.usbControllers.isEmpty == false {
                    Divider()
                    ForEach(snapshot.usbControllers) { controller in
                        ControllerRow(controller: controller)
                        if controller.id != snapshot.usbControllers.last?.id {
                            Divider()
                        }
                    }
                }
            } else {
                Text("Run a scan to read USB-C controller firmware and error counters.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        }
    }

    // MARK: Storage health

    private var storagePanel: some View {
        Panel("Drive Health") {
            if let storage = viewModel.snapshot?.storageHealth {
                ReadingRow("SMART", value: storage.statusTitle, note: storage.statusDetail)
                if let model = storage.model {
                    ReadingRow("Model", value: model)
                }
                if let firmware = storage.firmware {
                    ReadingRow("Firmware", value: firmware)
                }
                if let percentageUsed = storage.percentageUsed {
                    CapacityRow(
                        label: "Rated wear used",
                        value: "\(percentageUsed)%",
                        fraction: Double(percentageUsed) / 100,
                        tint: percentageUsed > 80 ? .orange : MetricTint.rescue
                    )
                }
                if let dataWritten = storage.dataUnitsWritten {
                    ReadingRow("Data written", value: dataWritten)
                }
                if let unsafeShutdowns = storage.unsafeShutdowns {
                    ReadingRow("Unsafe shutdowns", value: "\(unsafeShutdowns)")
                }
                if let mediaErrors = storage.mediaErrors {
                    ReadingRow(
                        "Media errors",
                        value: "\(mediaErrors)",
                        valueColor: mediaErrors > 0 ? .orange : .primary
                    )
                }
            } else {
                Text("Install smartmontools to read exact NVMe SMART health.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        }
    }
}

// MARK: - Controller row

private struct ControllerRow: View {
    let controller: USBPortControllerReport

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Label {
                    Text(controller.displayName)
                        .fontWeight(.semibold)
                } icon: {
                    Image(systemName: severitySymbol)
                        .foregroundStyle(severityColor)
                }
                Spacer()
                Text(controller.stateTitle)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(severityColor)
            }

            Text(controller.stateDetail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 4) {
                GridRow {
                    Text("Firmware").foregroundStyle(.secondary)
                    Text(controller.firmwareVersionDescription).monospacedDigit()
                    Text("I2C errors").foregroundStyle(.secondary)
                    Text(controller.i2cErrorCountDescription).monospacedDigit()
                }
                GridRow {
                    Text("Boot flags").foregroundStyle(.secondary)
                    Text(controller.bootFlagsDescription).monospacedDigit()
                    Text("Max power").foregroundStyle(.secondary)
                    Text(controller.maxPowerDescription).monospacedDigit()
                }
            }
            .font(.caption)
        }
    }

    private var severitySymbol: String {
        switch controller.severity {
        case .ok: return "checkmark.circle"
        case .watch: return "exclamationmark.circle"
        case .attention: return "exclamationmark.triangle"
        }
    }

    private var severityColor: Color {
        switch controller.severity {
        case .ok: return .green
        case .watch: return .orange
        case .attention: return .red
        }
    }
}
