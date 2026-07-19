import Charts
import SwiftUI

// MARK: - Thermal page

struct ThermalPage: View {
    @ObservedObject var systemMonitor: SystemMonitor
    @State private var range: MonitoringTrendRange = .fiveMinutes

    var body: some View {
        let snapshot = systemMonitor.snapshot

        MonitorPage("Thermal", subtitle: "Temperatures and macOS thermal pressure.") {
            Panel {
                HeroReading(
                    value: ReadingFormat.celsius(snapshot.cpuTemperature),
                    label: "CPU temperature",
                    tint: MetricTint.thermal,
                    severity: snapshot.cpuTemperature.map(ReadingThresholds.temperature) ?? .nominal
                )
                TrendRangePicker(range: $range)
                TrendChart(
                    points: systemMonitor.cpuTemperatureTrend.points,
                    range: range,
                    tint: MetricTint.thermal
                )
                TrendSummaryStrip(
                    series: systemMonitor.cpuTemperatureTrend,
                    range: range,
                    format: { ReadingFormat.celsiusLong($0) }
                )
            }

            Panel("Sensors") {
                temperatureRow("CPU", snapshot.cpuTemperature)
                temperatureRow("GPU", snapshot.gpuTemperature)
                temperatureRow("SSD", snapshot.ssdTemperature)
                if let battery = snapshot.batteryInfo.temperatureC {
                    temperatureRow("Battery", battery)
                }
            }

            Panel("Thermal Pressure", caption: "Reported by macOS. When pressure rises, the system may reduce performance to manage heat.") {
                ReadingRow(
                    "State",
                    value: pressureTitle(snapshot.thermalState),
                    valueColor: ReadingThresholds.thermalState(snapshot.thermalState) > .nominal
                        ? ReadingThresholds.thermalState(snapshot.thermalState).color
                        : .primary
                )
            }

            if snapshot.hasSMCAccess == false {
                Panel("Sensor Access") {
                    ReadingRow(
                        "SMC",
                        value: "Unavailable",
                        note: snapshot.lastError ?? "Temperature sensors could not be read on this Mac."
                    )
                }
            }
        }
    }

    private func temperatureRow(_ label: String, _ value: Double?) -> some View {
        let severity = value.map(ReadingThresholds.temperature) ?? .nominal
        return ReadingRow(
            label,
            value: ReadingFormat.celsiusLong(value),
            valueColor: severity > .elevated ? severity.color : .primary
        )
    }

    private func pressureTitle(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}

// MARK: - Cooling page

struct CoolingPage: View {
    @ObservedObject var systemMonitor: SystemMonitor
    @ObservedObject var fanController: FanController
    @ObservedObject private var helperManager = SMCHelperManager.shared
    @State private var isEditingCurve = false

    var body: some View {
        let snapshot = systemMonitor.snapshot

        MonitorPage("Cooling", subtitle: "Fan readings, cooling mode, and the privileged helper.") {
            fansPanel(snapshot)
            modePanel
            if fanController.mode == .custom {
                customCurvePanel
            }
            helperPanel
        }
        .sheet(isPresented: $isEditingCurve) {
            FanCurveEditorSheet(fanController: fanController)
        }
    }

    // MARK: Fans

    private func fansPanel(_ snapshot: SystemMonitorSnapshot) -> some View {
        Panel("Fans") {
            if snapshot.fanSpeeds.isEmpty {
                Text("No fan readings are available on this Mac.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                HStack(spacing: 24) {
                    ForEach(Array(snapshot.fanSpeeds.enumerated()), id: \.offset) { index, rpm in
                        fanGauge(index: index, rpm: rpm, snapshot: snapshot)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func fanGauge(index: Int, rpm: Int, snapshot: SystemMonitorSnapshot) -> some View {
        let maxSpeed = snapshot.fanMaxSpeeds.indices.contains(index)
            ? max(snapshot.fanMaxSpeeds[index], 1)
            : max(fanController.maxSpeed, 1)

        // A negative reading is the sentinel for a failed SMC read, distinct
        // from a genuine 0 RPM (fan at rest).
        let isUnavailable = rpm < 0
        let detailText = isUnavailable ? "Unavailable" : (rpm > 0 ? ReadingFormat.rpm(rpm) : "At rest")

        return VStack(spacing: 6) {
            Gauge(value: Double(max(rpm, 0)), in: 0...Double(maxSpeed)) {
                Text("Fan \(index + 1)")
            } currentValueLabel: {
                Text(isUnavailable ? "—" : ReadingFormat.rpmShort(rpm))
                    .font(.readingSmall.monospacedDigit())
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(MetricTint.cooling)
            .scaleEffect(1.1)
            .frame(width: 64, height: 64)

            Text("Fan \(index + 1)")
                .font(.caption.weight(.medium))
            Text(detailText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Fan \(index + 1), \(detailText)")
    }

    // MARK: Mode

    private var modePanel: some View {
        Panel("Cooling Mode") {
            Picker("Mode", selection: modeBinding) {
                ForEach(FanControlMode.quickModes, id: \.rawValue) { mode in
                    Text(displayTitle(for: mode)).tag(mode.rawValue)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 320, alignment: .leading)

            let guidance = fanController.mode.guidance
            Text(guidance.summary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if fanController.mode == .manual {
                Divider()
                LabeledContent("Target speed") {
                    Text(ReadingFormat.rpm(fanController.manualSpeed))
                        .font(.body.monospacedDigit())
                }
                Slider(
                    value: manualSpeedBinding,
                    in: Double(fanController.minSpeed)...Double(fanController.maxSpeed),
                    step: 50
                ) {
                    Text("Target speed")
                }
                .labelsHidden()
            }

            if fanController.mode == .smart {
                Divider()
                LabeledContent("Aggressiveness") {
                    Text(String(format: "%.1f", fanController.autoAggressiveness))
                        .font(.body.monospacedDigit())
                }
                Slider(value: aggressivenessBinding, in: 0...3, step: 0.1) {
                    Text("Aggressiveness")
                }
                .labelsHidden()

                LabeledContent("Speed ceiling") {
                    Text(ReadingFormat.rpm(fanController.autoMaxSpeed))
                        .font(.body.monospacedDigit())
                }
                Slider(
                    value: smartCeilingBinding,
                    in: Double(fanController.minSpeed)...Double(fanController.maxSpeed),
                    step: 50
                ) {
                    Text("Speed ceiling")
                }
                .labelsHidden()
            }

            Divider()

            HStack(spacing: 10) {
                Button("Hand Cooling Back to macOS") {
                    fanController.resetToSystemAutomatic()
                    fanController.setMode(.automatic)
                }
                Button(fanController.isCalibrating ? "Calibrating…" : "Calibrate Fans") {
                    fanController.calibrateFanControl()
                }
                .disabled(fanController.isCalibrating)
            }

            if fanController.statusMessage.isEmpty == false, fanController.statusMessage != "Idle" {
                Text(fanController.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Custom curve

    private var customCurvePanel: some View {
        Panel("Custom Curve", caption: "Fan speed follows your saved temperature curve.") {
            if let preset = decodeCurrentPreset() {
                FanCurveChart(preset: preset)
                ReadingRow("Sensor", value: preset.sensor.title)
                ReadingRow("Points", value: "\(preset.points.count)")
            } else {
                Text("The saved curve could not be read. Edit it to create a fresh one.")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }

            if let error = fanController.customPresetLastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("Edit Curve…") {
                isEditingCurve = true
            }
        }
    }

    private func decodeCurrentPreset() -> CustomFanPreset? {
        guard let data = fanController.customPresetSource.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(CustomFanPreset.self, from: data)
    }

    // MARK: Helper

    private var helperPanel: some View {
        Panel("Privileged Helper", caption: "Fan writes need a small helper installed with administrator approval. Reading sensors never does.") {
            ReadingRow(
                "Status",
                value: helperStatusTitle,
                note: helperManager.statusMessage
            )
            HStack(spacing: 10) {
                Button(helperManager.isInstalled ? "Repair Helper" : "Install Helper") {
                    helperManager.installFromApp(forceReinstall: helperManager.isInstalled)
                }
                Button("Check Connection") {
                    helperManager.refreshDiagnostics()
                }
            }
        }
    }

    private var helperStatusTitle: String {
        guard helperManager.isInstalled else { return "Not installed" }
        switch helperManager.connectionState {
        case .missing: return "Missing"
        case .unknown: return "Installed"
        case .checking: return "Checking…"
        case .reachable: return "Installed and reachable"
        case .unreachable: return "Installed, not responding"
        }
    }

    // MARK: Bindings

    private var modeBinding: Binding<String> {
        Binding {
            fanController.mode.rawValue
        } set: { rawValue in
            if let mode = FanControlMode(rawValue: rawValue) {
                fanController.setMode(mode)
            }
        }
    }

    private var manualSpeedBinding: Binding<Double> {
        Binding {
            Double(fanController.manualSpeed)
        } set: { value in
            fanController.setManualSpeed(Int(value.rounded()))
        }
    }

    private var aggressivenessBinding: Binding<Double> {
        Binding {
            fanController.autoAggressiveness
        } set: { value in
            fanController.setAutoAggressiveness(value)
        }
    }

    private var smartCeilingBinding: Binding<Double> {
        Binding {
            Double(fanController.autoMaxSpeed)
        } set: { value in
            fanController.setAutoMaxSpeed(Int(value.rounded()))
        }
    }

    private func displayTitle(for mode: FanControlMode) -> String {
        switch mode {
        case .smart: return "Smart"
        case .silent: return "System Handoff"
        case .balanced: return "Balanced"
        case .performance: return "Performance"
        case .max: return "Maximum"
        case .manual: return "Manual"
        case .custom: return "Custom Curve"
        case .automatic: return "System Automatic"
        }
    }
}

// MARK: - Curve chart

/// Read-only rendering of a custom fan curve.
struct FanCurveChart: View {
    let preset: CustomFanPreset

    private var sortedPoints: [CustomFanPreset.CurvePoint] {
        preset.points.sorted { $0.temperatureC < $1.temperatureC }
    }

    var body: some View {
        Chart(sortedPoints) { point in
            LineMark(
                x: .value("Temperature", point.temperatureC),
                y: .value("Speed", point.speedPercent)
            )
            .foregroundStyle(MetricTint.cooling)
            .lineStyle(StrokeStyle(lineWidth: 1.5))

            PointMark(
                x: .value("Temperature", point.temperatureC),
                y: .value("Speed", point.speedPercent)
            )
            .foregroundStyle(MetricTint.cooling)
            .symbolSize(36)

            AreaMark(
                x: .value("Temperature", point.temperatureC),
                y: .value("Speed", point.speedPercent)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [MetricTint.cooling.opacity(0.18), MetricTint.cooling.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .chartXScale(domain: 20...110)
        .chartYScale(domain: 0...100)
        .chartXAxisLabel("°C", alignment: .trailing)
        .chartYAxisLabel("% speed")
        .frame(height: 150)
    }
}

// MARK: - Curve editor sheet

struct FanCurveEditorSheet: View {
    @ObservedObject var fanController: FanController
    @Environment(\.dismiss) private var dismiss

    @State private var sensor: CustomFanPreset.Sensor = .max
    @State private var points: [CustomFanPreset.CurvePoint] = []
    @State private var name: String = "Custom"
    @State private var loadedVersion: Int = 1
    @State private var saveError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Edit Custom Curve")
                .font(.title3.weight(.semibold))

            FanCurveChart(preset: draftPreset)

            Picker("React to", selection: $sensor) {
                ForEach(CustomFanPreset.Sensor.allCases) { candidate in
                    Text(candidate.title).tag(candidate)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)

            VStack(spacing: 6) {
                ForEach($points) { $point in
                    HStack(spacing: 12) {
                        Text(String(format: "%.0f °C", point.temperatureC))
                            .font(.body.monospacedDigit())
                            .frame(width: 52, alignment: .trailing)
                        Slider(value: $point.temperatureC, in: 20...110, step: 1) {
                            Text("Temperature")
                        }
                        .labelsHidden()

                        Text(String(format: "%.0f%%", point.speedPercent))
                            .font(.body.monospacedDigit())
                            .frame(width: 44, alignment: .trailing)
                        Slider(value: $point.speedPercent, in: 0...100, step: 1) {
                            Text("Speed")
                        }
                        .labelsHidden()

                        Button {
                            points.removeAll { $0.id == point.id }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .disabled(points.count <= 2)
                        .help("Remove point")
                    }
                }
            }

            Button {
                addPoint()
            } label: {
                Label("Add Point", systemImage: "plus")
            }
            .disabled(points.count >= 8)

            if let saveError {
                Text(saveError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save Curve") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(points.count < 2)
            }
        }
        .padding(22)
        .frame(width: 520)
        .onAppear(perform: loadCurrentPreset)
    }

    private var draftPreset: CustomFanPreset {
        var preset = basePreset
        preset.sensor = sensor
        preset.points = points.sorted { $0.temperatureC < $1.temperatureC }
        return preset
    }

    private var basePreset: CustomFanPreset {
        if let data = fanController.customPresetSource.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(CustomFanPreset.self, from: data) {
            return decoded
        }
        var starter = CustomFanPreset.starter
        starter.name = name
        starter.version = loadedVersion
        return starter
    }

    private func loadCurrentPreset() {
        guard let data = fanController.customPresetSource.data(using: .utf8),
              let preset = try? JSONDecoder().decode(CustomFanPreset.self, from: data),
              preset.points.count >= 2 else {
            points = [
                CustomFanPreset.CurvePoint(temperatureC: 45, speedPercent: 20),
                CustomFanPreset.CurvePoint(temperatureC: 70, speedPercent: 55),
                CustomFanPreset.CurvePoint(temperatureC: 90, speedPercent: 100)
            ]
            return
        }
        sensor = preset.sensor
        name = preset.name
        loadedVersion = preset.version
        points = preset.points.sorted { $0.temperatureC < $1.temperatureC }
    }

    private func addPoint() {
        let sorted = points.sorted { $0.temperatureC < $1.temperatureC }
        let newTemperature: Double
        if let last = sorted.last, last.temperatureC < 105 {
            newTemperature = min(last.temperatureC + 5, 110)
        } else {
            newTemperature = 60
        }
        let newSpeed = sorted.last?.speedPercent ?? 50
        points.append(CustomFanPreset.CurvePoint(temperatureC: newTemperature, speedPercent: newSpeed))
    }

    private func save() {
        switch fanController.saveCustomPreset(draftPreset) {
        case .success:
            saveError = nil
            dismiss()
        case .failure(let reasons):
            saveError = reasons.joined(separator: " ")
        }
    }
}
