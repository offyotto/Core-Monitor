import AppKit
import SwiftUI

private struct FanCurveCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

enum FanCurveChartGeometry {
    static let temperatureRange: ClosedRange<Double> = 30...110
    static let speedRange: ClosedRange<Double> = 0...100
    static let pointInset: CGFloat = 12
    static let handleSelectionRadius: CGFloat = 28

    static func plotPoint(
        for point: CustomFanPreset.CurvePoint,
        size: CGSize
    ) -> CGPoint {
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        let innerWidth = max(width - (pointInset * 2), 1)
        let innerHeight = max(height - (pointInset * 2), 1)
        let xRatio = (point.temperatureC - temperatureRange.lowerBound) / (temperatureRange.upperBound - temperatureRange.lowerBound)
        let yRatio = point.speedPercent / speedRange.upperBound

        return CGPoint(
            x: pointInset + (CGFloat(xRatio) * innerWidth),
            y: height - (pointInset + (CGFloat(yRatio) * innerHeight))
        )
    }

    static func values(
        for location: CGPoint,
        size: CGSize
    ) -> (temperature: Double, speed: Double) {
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        let innerWidth = max(width - (pointInset * 2), 1)
        let innerHeight = max(height - (pointInset * 2), 1)
        let clampedX = min(max(location.x, pointInset), width - pointInset)
        let clampedY = min(max(location.y, pointInset), height - pointInset)
        let xRatio = (clampedX - pointInset) / innerWidth
        let yRatio = 1 - ((clampedY - pointInset) / innerHeight)

        return (
            temperature: temperatureRange.lowerBound + (Double(xRatio) * (temperatureRange.upperBound - temperatureRange.lowerBound)),
            speed: Double(yRatio) * speedRange.upperBound
        )
    }

    static func temperatureRange(
        for index: Int,
        points: [CustomFanPreset.CurvePoint]
    ) -> ClosedRange<Double> {
        let previousTemperature = points[safe: index - 1]?.temperatureC ?? temperatureRange.lowerBound
        let nextTemperature = points[safe: index + 1]?.temperatureC ?? temperatureRange.upperBound
        let minimumTemperature = max(temperatureRange.lowerBound, previousTemperature + (index == 0 ? 0 : 1))
        let maximumTemperature = min(temperatureRange.upperBound, nextTemperature - (index == points.count - 1 ? 0 : 1))
        let clampedMaximumTemperature = max(minimumTemperature, maximumTemperature)
        return minimumTemperature...clampedMaximumTemperature
    }

    static func clampedValues(
        for pointID: UUID,
        rawTemperature: Double,
        rawSpeed: Double,
        points: [CustomFanPreset.CurvePoint]
    ) -> (temperature: Double, speed: Double)? {
        guard let index = points.firstIndex(where: { $0.id == pointID }) else { return nil }
        let allowedTemperatureRange = temperatureRange(for: index, points: points)
        return (
            temperature: min(max(rawTemperature.rounded(), allowedTemperatureRange.lowerBound), allowedTemperatureRange.upperBound),
            speed: min(max(rawSpeed.rounded(), speedRange.lowerBound), speedRange.upperBound)
        )
    }

    static func nearestPointID(
        to location: CGPoint,
        size: CGSize,
        points: [CustomFanPreset.CurvePoint],
        selectionRadius: CGFloat = handleSelectionRadius
    ) -> UUID? {
        let nearest = points.min { lhs, rhs in
            distanceSquared(from: location, to: plotPoint(for: lhs, size: size)) <
                distanceSquared(from: location, to: plotPoint(for: rhs, size: size))
        }

        guard let nearest else { return nil }
        let nearestDistance = sqrt(distanceSquared(from: location, to: plotPoint(for: nearest, size: size)))
        return nearestDistance <= selectionRadius ? nearest.id : nil
    }

    private static func distanceSquared(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return (dx * dx) + (dy * dy)
    }
}

struct FanCurvePreview: View {
    let preset: CustomFanPreset
    var activePointID: UUID? = nil
    var onPointDragChanged: ((UUID, Double, Double) -> Void)? = nil
    var onPointDragEnded: (() -> Void)? = nil
    var showsAxisLabels = true
    var minimumHeight: CGFloat? = 220
    @State private var dragPointID: UUID?

    var body: some View {
        GeometryReader { geometry in
            let points = preset.sortedPoints
            let width = max(geometry.size.width, 1)
            let height = max(geometry.size.height, 1)

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.12))

                grid(width: width, height: height)

                if points.count > 1 {
                    fillPath(points: points, width: width, height: height)
                        .fill(
                            LinearGradient(
                                colors: [Color.bdAccent.opacity(0.30), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    linePath(points: points, width: width, height: height)
                        .stroke(Color.bdAccent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                    ForEach(points) { point in
                        pointHandle(point, size: geometry.size)
                    }
                }

                if showsAxisLabels {
                    axisLabels
                }

                if onPointDragChanged != nil {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.clear)
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .gesture(chartGesture(size: geometry.size, points: points))
                }
            }
            .coordinateSpace(name: "FanCurvePreviewChart")
        }
        .frame(minHeight: minimumHeight)
    }

    private var axisLabels: some View {
        VStack {
            HStack {
                Text("100%")
                Spacer()
                Text("Hotter")
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)

            Spacer()

            HStack {
                Text("30°C")
                Spacer()
                Text("110°C")
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
        }
        .padding(12)
    }

    private func grid(width: CGFloat, height: CGFloat) -> some View {
        Path { path in
            for step in 1..<5 {
                let y = (height / 5) * CGFloat(step)
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: width, y: y))
            }
            for step in 1..<5 {
                let x = (width / 5) * CGFloat(step)
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: height))
            }
        }
        .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
    }

    private func fillPath(points: [CustomFanPreset.CurvePoint], width: CGFloat, height: CGFloat) -> Path {
        var path = linePath(points: points, width: width, height: height)
        guard let last = points.last else { return path }
        path.addLine(to: CGPoint(x: chartPoint(for: last, width: width, height: height).x, y: height))
        path.addLine(to: CGPoint(x: chartPoint(for: points[0], width: width, height: height).x, y: height))
        path.closeSubpath()
        return path
    }

    private func linePath(points: [CustomFanPreset.CurvePoint], width: CGFloat, height: CGFloat) -> Path {
        Path { path in
            for (index, point) in points.enumerated() {
                let chartPoint = chartPoint(for: point, width: width, height: height)
                if index == 0 {
                    path.move(to: chartPoint)
                } else {
                    path.addLine(to: chartPoint)
                }
            }
        }
    }

    private func chartPoint(for point: CustomFanPreset.CurvePoint, width: CGFloat, height: CGFloat) -> CGPoint {
        FanCurveChartGeometry.plotPoint(for: point, size: CGSize(width: width, height: height))
    }

    private func pointHandle(
        _ point: CustomFanPreset.CurvePoint,
        size: CGSize
    ) -> some View {
        let plotPoint = FanCurveChartGeometry.plotPoint(for: point, size: size)

        return Circle()
            .fill(Color.bdAccent)
            .frame(width: 10, height: 10)
            .position(plotPoint)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.22), lineWidth: 2)
                    .frame(width: 10, height: 10)
                    .position(plotPoint)
            )
    }

    private func chartGesture(
        size: CGSize,
        points: [CustomFanPreset.CurvePoint]
    ) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("FanCurvePreviewChart"))
            .onChanged { value in
                guard onPointDragChanged != nil else { return }

                let lockedPointID = dragPointID
                    ?? FanCurveChartGeometry.nearestPointID(to: value.startLocation, size: size, points: points)
                    ?? FanCurveChartGeometry.nearestPointID(to: value.location, size: size, points: points)

                guard let lockedPointID else { return }
                dragPointID = lockedPointID

                let values = FanCurveChartGeometry.values(for: value.location, size: size)
                onPointDragChanged?(lockedPointID, values.temperature, values.speed)
            }
            .onEnded { _ in
                dragPointID = nil
                onPointDragEnded?()
            }
    }
}

private enum FanCurveTemplate: String, CaseIterable, Identifiable {
    case quiet
    case balanced
    case aggressive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quiet: return "Quiet"
        case .balanced: return "Balanced"
        case .aggressive: return "Cooling First"
        }
    }
}

struct CustomFanPresetEditorSheet: View {
    @ObservedObject var fanController: FanController
    @Environment(\.dismiss) private var dismiss

    @State private var draft: CustomFanPreset
    @State private var messages: [String] = []
    @State private var hasError = false
    @State private var showsAdvancedJSON = false
    @State private var activeDragPointID: UUID?

    init(fanController: FanController) {
        self.fanController = fanController
        _draft = State(initialValue: fanController.currentCustomPresetDraft())
    }

    var body: some View {
        VStack(spacing: 14) {
            header

            ScrollView {
                VStack(spacing: 14) {
                    summaryCard
                    chartCard
                    controlsCard
                    pointsCard
                    advancedCard
                    resultCard
                }
                .padding(.vertical, 2)
            }
        }
        .padding(18)
        .frame(minWidth: 880, minHeight: 720)
        .background(CoreMonBackdrop())
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Custom Fan Curve")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text("Tune a real curve instead of editing raw JSON. Core Monitor still keeps the underlying preset portable and transparent.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
    }

    private var summaryCard: some View {
        FanCurveCard {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(draft.name)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("Sensor: \(draft.sensor.title) • \(draft.sortedPoints.count) points • Interval \(formattedInterval)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(fanController.customPresetFilePath)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Spacer(minLength: 24)

                HStack(spacing: 8) {
                    templateButton(.quiet)
                    templateButton(.balanced)
                    templateButton(.aggressive)
                }
            }
        }
    }

    private var chartCard: some View {
        FanCurveCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Curve Preview")
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                    Text("RPM window \(draft.minimumRPM ?? fanController.minSpeed)–\(draft.maximumRPM ?? fanController.maxSpeed)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                FanCurvePreview(
                    preset: normalizedDraft,
                    activePointID: activeDragPointID,
                    onPointDragChanged: { id, temperature, speed in
                        activeDragPointID = id
                        updatePoint(id, temperature: temperature, speed: speed)
                    },
                    onPointDragEnded: {
                        activeDragPointID = nil
                    }
                )
                    .frame(height: 230)

                Text("The preview shows fan speed percentage against effective temperature. Power Boost raises the effective temperature under sustained watt draw before the curve is evaluated.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var controlsCard: some View {
        FanCurveCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Controls")
                    .font(.system(size: 16, weight: .bold))

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        labeledTextField("Preset Name", text: $draft.name)
                        Picker("Sensor", selection: $draft.sensor) {
                            ForEach(CustomFanPreset.Sensor.allCases) { sensor in
                                Text(sensor.title).tag(sensor)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 280)
                    }

                    HStack(spacing: 12) {
                        integerStepper(
                            title: "Minimum RPM",
                            value: Binding(
                                get: { draft.minimumRPM ?? fanController.minSpeed },
                                set: { draft.minimumRPM = max(fanController.minSpeed, min($0, draft.maximumRPM ?? fanController.maxSpeed)) }
                            ),
                            range: fanController.minSpeed...fanController.maxSpeed,
                            step: 50
                        )

                        integerStepper(
                            title: "Maximum RPM",
                            value: Binding(
                                get: { draft.maximumRPM ?? fanController.maxSpeed },
                                set: { draft.maximumRPM = min(fanController.maxSpeed, max($0, draft.minimumRPM ?? fanController.minSpeed)) }
                            ),
                            range: fanController.minSpeed...fanController.maxSpeed,
                            step: 50
                        )
                    }

                    HStack(spacing: 12) {
                        numericSlider(
                            title: "Update Interval",
                            value: Binding(
                                get: { draft.updateIntervalSeconds ?? 2.0 },
                                set: { draft.updateIntervalSeconds = $0 }
                            ),
                            range: 0.5...10,
                            step: 0.5,
                            format: { String(format: "%.1fs", $0) }
                        )

                        numericSlider(
                            title: "Smoothing",
                            value: Binding(
                                get: { Double(draft.smoothingStepRPM ?? 75) },
                                set: { draft.smoothingStepRPM = Int($0.rounded()) }
                            ),
                            range: 0...600,
                            step: 25,
                            format: { "\(Int($0.rounded())) RPM" }
                        )
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(
                            "Enable Power Boost",
                            isOn: Binding(
                                get: { draft.powerBoost?.enabled ?? true },
                                set: { enabled in
                                    if draft.powerBoost == nil {
                                        draft.powerBoost = .init()
                                    }
                                    draft.powerBoost?.enabled = enabled
                                }
                            )
                        )
                        .toggleStyle(.switch)

                        HStack(spacing: 12) {
                            numericSlider(
                                title: "Watts at Max Boost",
                                value: Binding(
                                    get: { draft.powerBoost?.wattsAtMaxBoost ?? 40 },
                                    set: {
                                        if draft.powerBoost == nil { draft.powerBoost = .init() }
                                        draft.powerBoost?.wattsAtMaxBoost = $0
                                    }
                                ),
                                range: 10...120,
                                step: 1,
                                format: { String(format: "%.0f W", $0) }
                            )

                            numericSlider(
                                title: "Max Added Temp",
                                value: Binding(
                                    get: { draft.powerBoost?.maxAddedTemperatureC ?? 8 },
                                    set: {
                                        if draft.powerBoost == nil { draft.powerBoost = .init() }
                                        draft.powerBoost?.maxAddedTemperatureC = $0
                                    }
                                ),
                                range: 0...20,
                                step: 1,
                                format: { String(format: "%.0f°C", $0) }
                            )
                        }
                        .disabled((draft.powerBoost?.enabled ?? true) == false)
                    }
                }
            }
        }
    }

    private var pointsCard: some View {
        FanCurveCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Curve Points")
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                    Button {
                        addPoint()
                    } label: {
                        Label("Add Point", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                }

                ForEach(Array(normalizedDraft.sortedPoints.enumerated()), id: \.element.id) { index, point in
                    pointRow(index: index, point: point)
                }
            }
        }
    }

    private var advancedCard: some View {
        FanCurveCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Advanced JSON")
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                    Button(showsAdvancedJSON ? "Hide" : "Show") {
                        showsAdvancedJSON.toggle()
                    }
                    .buttonStyle(.bordered)
                    Button("Copy JSON") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(fanController.prettyPrintedPresetSource(for: normalizedDraft), forType: .string)
                        messages = ["Copied the generated JSON preset to the clipboard."]
                        hasError = false
                    }
                    .buttonStyle(.bordered)
                }

                if showsAdvancedJSON {
                    ScrollView {
                        Text(fanController.prettyPrintedPresetSource(for: normalizedDraft))
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(minHeight: 160, maxHeight: 220)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.black.opacity(0.18))
                    )
                } else {
                    Text("Power users can still inspect or copy the generated preset JSON. Editing happens through the safer form above.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var resultCard: some View {
        FanCurveCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Validate & Save")
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                    Button("Load Starter") {
                        draft = .starter
                        messages = ["Loaded the starter template."]
                        hasError = false
                    }
                    .buttonStyle(.bordered)

                    Button("Validate") {
                        let validation = fanController.validateCustomPreset(normalizedDraft)
                        hasError = !validation.isEmpty
                        messages = validation.isEmpty
                            ? ["Preset looks valid. Save it to apply the new curve."]
                            : validation
                    }
                    .buttonStyle(.bordered)

                    Button("Save") {
                        save(closeAfterSave: false)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Save & Use") {
                        save(closeAfterSave: true)
                    }
                    .buttonStyle(.borderedProminent)
                }

                if messages.isEmpty {
                    Text("Validation checks curve ordering, threshold ranges, RPM bounds, smoothing, and power boost limits before Core Monitor attempts to apply anything.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(messages.enumerated()), id: \.offset) { entry in
                        Text("• \(entry.element)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(hasError ? .orange : .secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func templateButton(_ template: FanCurveTemplate) -> some View {
        Button(template.title) {
            applyTemplate(template)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func labeledTextField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func integerStepper(
        title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(value.wrappedValue) RPM")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.bdAccent)
            }
            Stepper("", value: value, in: range, step: step)
                .labelsHidden()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func numericSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        format: @escaping (Double) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(format(value.wrappedValue))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.bdAccent)
            }
            Slider(value: value, in: range, step: step)
                .tint(Color.bdAccent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pointRow(index: Int, point: CustomFanPreset.CurvePoint) -> some View {
        let allowedTemperatureRange = FanCurveChartGeometry.temperatureRange(for: index, points: normalizedDraft.sortedPoints)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Point \(index + 1)")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Button(role: .destructive) {
                    removePoint(point.id)
                } label: {
                    Label("Remove", systemImage: "trash")
                }
                .buttonStyle(.borderless)
                .disabled(normalizedDraft.sortedPoints.count <= 2)
            }

            HStack(spacing: 12) {
                numericSlider(
                    title: "Temperature",
                    value: temperatureBinding(for: point.id),
                    range: allowedTemperatureRange,
                    step: 1,
                    format: { String(format: "%.0f°C", $0) }
                )

                numericSlider(
                    title: "Speed",
                    value: speedBinding(for: point.id),
                    range: 0...100,
                    step: 1,
                    format: { String(format: "%.0f%%", $0) }
                )
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func temperatureBinding(for id: UUID) -> Binding<Double> {
        Binding(
            get: {
                normalizedDraft.sortedPoints.first(where: { $0.id == id })?.temperatureC ?? 0
            },
            set: { newValue in
                updatePoint(id, temperature: newValue)
            }
        )
    }

    private func speedBinding(for id: UUID) -> Binding<Double> {
        Binding(
            get: {
                normalizedDraft.sortedPoints.first(where: { $0.id == id })?.speedPercent ?? 0
            },
            set: { newValue in
                updatePoint(id, speed: newValue)
            }
        )
    }

    private func updatePoint(
        _ id: UUID,
        temperature: Double? = nil,
        speed: Double? = nil
    ) {
        let points = draft.sortedPoints
        guard let draftIndex = draft.points.firstIndex(where: { $0.id == id }) else { return }
        let currentPoint = draft.points[draftIndex]
        let rawTemperature = temperature ?? currentPoint.temperatureC
        let rawSpeed = speed ?? currentPoint.speedPercent
        guard let values = FanCurveChartGeometry.clampedValues(
            for: id,
            rawTemperature: rawTemperature,
            rawSpeed: rawSpeed,
            points: points
        ) else {
            return
        }

        draft.points[draftIndex].temperatureC = values.temperature
        draft.points[draftIndex].speedPercent = values.speed
        draft.points = draft.sortedPoints
        hasError = false
        if !messages.isEmpty {
            messages.removeAll()
        }
    }

    private func removePoint(_ id: UUID) {
        guard draft.points.count > 2 else {
            messages = ["A custom fan curve needs at least two points."]
            hasError = true
            return
        }
        draft.points.removeAll { $0.id == id }
        if activeDragPointID == id {
            activeDragPointID = nil
        }
    }

    private func addPoint() {
        let points = normalizedDraft.sortedPoints
        guard let last = points.last else {
            draft.points = [.init(temperatureC: 40, speedPercent: 25), .init(temperatureC: 85, speedPercent: 100)]
            return
        }

        let nextTemp = min(last.temperatureC + 8, 110)
        guard nextTemp > last.temperatureC else {
            messages = ["No more temperature headroom is available. Increase an earlier point or remove one before adding another."]
            hasError = true
            return
        }

        let nextSpeed = min(last.speedPercent + 8, 100)
        draft.points.append(.init(temperatureC: nextTemp, speedPercent: nextSpeed))
        draft.points = draft.sortedPoints
    }

    private func applyTemplate(_ template: FanCurveTemplate) {
        switch template {
        case .quiet:
            draft = CustomFanPreset.starter
        case .balanced:
            draft = CustomFanPreset(
                name: "Balanced curve",
                version: 1,
                sensor: .max,
                updateIntervalSeconds: 2,
                smoothingStepRPM: 90,
                minimumRPM: 1600,
                maximumRPM: 6300,
                perFanRPMOffset: draft.perFanRPMOffset,
                powerBoost: .init(enabled: true, wattsAtMaxBoost: 45, maxAddedTemperatureC: 6),
                points: [
                    .init(temperatureC: 38, speedPercent: 26),
                    .init(temperatureC: 52, speedPercent: 36),
                    .init(temperatureC: 68, speedPercent: 56),
                    .init(temperatureC: 80, speedPercent: 78),
                    .init(temperatureC: 90, speedPercent: 100),
                ]
            )
        case .aggressive:
            draft = CustomFanPreset(
                name: "Cooling-first curve",
                version: 1,
                sensor: .max,
                updateIntervalSeconds: 1.5,
                smoothingStepRPM: 140,
                minimumRPM: 1800,
                maximumRPM: 6500,
                perFanRPMOffset: draft.perFanRPMOffset,
                powerBoost: .init(enabled: true, wattsAtMaxBoost: 38, maxAddedTemperatureC: 10),
                points: [
                    .init(temperatureC: 35, speedPercent: 32),
                    .init(temperatureC: 48, speedPercent: 48),
                    .init(temperatureC: 62, speedPercent: 66),
                    .init(temperatureC: 74, speedPercent: 84),
                    .init(temperatureC: 84, speedPercent: 100),
                ]
            )
        }
        messages = ["Loaded the \(template.title.lowercased()) template."]
        hasError = false
    }

    private func save(closeAfterSave: Bool) {
        switch fanController.saveCustomPreset(normalizedDraft) {
        case .success(let message):
            draft = fanController.currentCustomPresetDraft()
            messages = [message]
            hasError = false
            if closeAfterSave {
                dismiss()
            }
        case .failure(let errors):
            messages = errors
            hasError = true
        }
    }

    private var normalizedDraft: CustomFanPreset {
        var preset = draft
        preset.name = preset.name.trimmingCharacters(in: .whitespacesAndNewlines)
        preset.points = preset.sortedPoints
        if preset.minimumRPM == nil {
            preset.minimumRPM = fanController.minSpeed
        }
        if preset.maximumRPM == nil {
            preset.maximumRPM = fanController.maxSpeed
        }
        return preset
    }

    private var formattedInterval: String {
        String(format: "%.1fs", normalizedDraft.updateIntervalSeconds ?? 2.0)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
