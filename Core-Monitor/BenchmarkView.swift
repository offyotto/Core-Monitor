import SwiftUI
#if canImport(Charts)
import Charts
#endif

struct BenchmarkView: View {
    enum BenchmarkPhase {
        case idle
        case running
        case complete
    }

    @ObservedObject var systemMonitor: SystemMonitor
    @ObservedObject var store: BenchmarkStore
    @StateObject private var detector = SMCTamperDetector.shared
    @StateObject private var session = BenchmarkSession()

    @State private var state: BenchmarkPhase = .idle
    @State private var durationSeconds = 60
    @State private var completedResult: BenchmarkResult?
    @State private var showLeaderboard = false

    private let engine = BenchmarkEngine()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch state {
            case .idle:
                idleView
            case .running:
                runningView
            case .complete:
                completeView
            }
        }
        .sheet(isPresented: $showLeaderboard) {
            LeaderboardView(store: store)
        }
        .onAppear { detector.inspect() }
    }

    private var idleView: some View {
        VStack(alignment: .leading, spacing: 14) {
            benchmarkInfoCard
            HStack {
                Stepper("Duration: \(durationSeconds)s", value: $durationSeconds, in: 15...180, step: 15)
                    .font(.system(size: 11, design: .monospaced))
                Spacer()
                if detector.isTampered {
                    tamperBadge
                }
                Button("Start Benchmark") { startBenchmark() }
                    .buttonStyle(.borderedProminent)
            }
            if let best = store.results.max(by: { $0.rawScore < $1.rawScore }) {
                Text("Best local score: \(best.rawScore)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .cmPanel(accent: .cmBlue)
    }

    private var runningView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                BenchmarkArcGauge(value: session.currentTemp, maxValue: 110, color: gaugeColor)
                VStack(alignment: .leading, spacing: 6) {
                    statLine("Elapsed", "\(session.elapsedSeconds)s")
                    statLine("Peak Temp", "\(Int(session.peakTemp.rounded()))°C")
                    statLine("Peak Load", "\(Int(session.peakLoad.rounded()))%")
                    statLine("Score", "\(session.rawScore)")
                }
                Spacer()
                Button("Stop") { stopBenchmark() }
                    .buttonStyle(.bordered)
            }
            BenchmarkTimelineView(samples: session.samples)
                .frame(height: 140)
        }
        .padding(14)
        .cmPanel(accent: gaugeColor)
    }

    private var completeView: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let result = completedResult {
                HStack {
                    Image(systemName: result.qualityRating.symbolName)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(result.customFanControl ? Color.cmAmber : result.qualityRating.color)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.qualityRating.displayTitle(customFanControl: result.customFanControl))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(result.customFanControl ? Color.cmAmber : result.qualityRating.color)
                        Text(result.qualityRating.description)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(result.rawScore)")
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }
                HStack(spacing: 12) {
                    statCard("Peak", "\(Int(result.peakTemp.rounded()))°C")
                    statCard("Average", "\(Int(result.avgTemp.rounded()))°C")
                    statCard("Load", "\(Int(result.avgLoad.rounded()))%")
                }
                HStack {
                    Button("Save to Leaderboard") { store.save(result) }
                        .buttonStyle(.borderedProminent)
                    Button("View Leaderboard") { showLeaderboard = true }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("Run Again") {
                        state = .idle
                        completedResult = nil
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .cmPanel(accent: .cmGreen)
    }

    private var benchmarkInfoCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("BENCHMARK").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(Color.cmBlue)
            statLine("Model", MacModelRegistry.entry(for: SystemMonitor.hostModelIdentifier())?.friendlyName ?? SystemMonitor.hostModelIdentifier())
            statLine("Chip", SystemMonitor.chipName())
            statLine("Perf Cores", "\(SystemMonitor.performanceCoreCount())")
            statLine("Eff Cores", "\(SystemMonitor.efficiencyCoreCount())")
        }
    }

    private var tamperBadge: some View {
        Label(detector.tamperLabel ?? "Custom Fan Control", systemImage: "exclamationmark.triangle.fill")
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.cmAmber)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.cmAmber.opacity(0.12))
            .clipShape(Capsule())
    }

    private var gaugeColor: Color {
        if session.currentTemp > 95 { return .cmRed }
        if session.currentTemp > 80 { return .cmAmber }
        return .cmBlue
    }

    private func startBenchmark() {
        detector.inspect()
        state = .running
        engine.run(session: session, systemMonitor: systemMonitor, detector: detector, durationSeconds: durationSeconds) { result in
            Task { @MainActor in
                completedResult = result
                state = .complete
            }
        }
    }

    private func stopBenchmark() {
        engine.stop(session: session, systemMonitor: systemMonitor) { result in
            Task { @MainActor in
                completedResult = result
                state = .complete
            }
        }
    }

    private func statLine(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label.uppercased()).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(.white)
        }
    }

    private func statCard(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased()).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundStyle(.white)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cmSurfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct BenchmarkArcGauge: View {
    let value: Double
    let maxValue: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.15, to: 0.85)
                .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(90))
            Circle()
                .trim(from: 0.15, to: 0.15 + 0.70 * min(max(value / maxValue, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(90))
            VStack(spacing: 4) {
                Text("\(Int(value.rounded()))").font(.system(size: 28, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                Text("°C").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(color)
            }
        }
        .frame(width: 140, height: 140)
    }
}

struct BenchmarkTimelineView: View {
    let samples: [BenchmarkSample]

    var body: some View {
#if canImport(Charts)
        if #available(macOS 13.0, *) {
            Chart {
                ForEach(samples) { sample in
                    LineMark(x: .value("Time", sample.timestamp), y: .value("Temp", sample.packageTemp))
                        .foregroundStyle(Color.cmAmber)
                    LineMark(x: .value("Time", sample.timestamp), y: .value("Load", sample.cpuLoad))
                        .foregroundStyle(Color.cmBlue)
                }
            }
        } else {
            BenchmarkFallbackGraph(samples: samples)
        }
#else
        BenchmarkFallbackGraph(samples: samples)
#endif
    }
}

private struct BenchmarkFallbackGraph: View {
    let samples: [BenchmarkSample]

    var body: some View {
        GeometryReader { geo in
            let tempPoints = normalize(values: samples.map(\.packageTemp), height: geo.size.height)
            let loadPoints = normalize(values: samples.map(\.cpuLoad), height: geo.size.height)
            ZStack {
                linePath(points: tempPoints, width: geo.size.width).stroke(Color.cmAmber, lineWidth: 2)
                linePath(points: loadPoints, width: geo.size.width).stroke(Color.cmBlue, lineWidth: 2)
            }
        }
    }

    private func normalize(values: [Double], height: CGFloat) -> [CGFloat] {
        values.map { height - CGFloat(min(max($0 / 110.0, 0), 1)) * height }
    }

    private func linePath(points: [CGFloat], width: CGFloat) -> Path {
        Path { path in
            guard points.count > 1 else { return }
            let step = width / CGFloat(max(points.count - 1, 1))
            for (idx, value) in points.enumerated() {
                let point = CGPoint(x: CGFloat(idx) * step, y: value)
                if idx == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
        }
    }
}
