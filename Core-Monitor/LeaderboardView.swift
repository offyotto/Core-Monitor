import SwiftUI
#if canImport(Charts)
import Charts
#endif

struct LeaderboardView: View {
    @ObservedObject var store: BenchmarkStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFamilies = Set<MacFamily>()
    @State private var selectedCoreCounts = Set<Int>()
    @State private var selectedRatings = Set<QualityRating>()
    @State private var showCustomFanOnly = false
    @State private var topScoreOnly = false
    @State private var selectedResult: BenchmarkResult?

    private var filteredResults: [BenchmarkResult] {
        var results = store.results.sorted { $0.rawScore > $1.rawScore }
        if !selectedFamilies.isEmpty {
            results = results.filter {
                let family = MacModelRegistry.entry(for: $0.macModel)?.family
                return family.map(selectedFamilies.contains) ?? false
            }
        }
        if !selectedCoreCounts.isEmpty {
            results = results.filter { selectedCoreCounts.contains($0.totalCores) }
        }
        if !selectedRatings.isEmpty {
            results = results.filter { selectedRatings.contains($0.qualityRating) }
        }
        if showCustomFanOnly {
            results = results.filter(\.customFanControl)
        }
        if topScoreOnly {
            var seen = Set<String>()
            results = results.filter {
                let key = "\($0.chipName)-\($0.macModel)"
                if seen.contains(key) { return false }
                seen.insert(key)
                return true
            }
        }
        return results
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("LOCAL LEADERBOARD").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(Color.cmBlue)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
            }
            filterBar
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(filteredResults.enumerated()), id: \.element.id) { index, result in
                        Button {
                            selectedResult = result
                        } label: {
                            leaderboardRow(result: result, rank: index + 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(18)
        .preferredColorScheme(.dark)
        .frame(minWidth: 860, minHeight: 640)
        .background(Color.cmBackground)
        .sheet(item: $selectedResult) { result in
            BenchmarkResultDetailView(result: result)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu("Family") {
                    ForEach(MacFamily.allCases) { family in
                        Button {
                            toggle(&selectedFamilies, family)
                        } label: {
                            Label(family.rawValue, systemImage: selectedFamilies.contains(family) ? "checkmark.circle.fill" : "circle")
                        }
                    }
                }
                Menu("Cores") {
                    ForEach([8, 10, 12, 14, 16, 20, 24], id: \.self) { coreCount in
                        Button {
                            toggle(&selectedCoreCounts, coreCount)
                        } label: {
                            Label("\(coreCount) cores", systemImage: selectedCoreCounts.contains(coreCount) ? "checkmark.circle.fill" : "circle")
                        }
                    }
                }
                Menu("Quality") {
                    ForEach(QualityRating.allCases) { rating in
                        Button {
                            toggle(&selectedRatings, rating)
                        } label: {
                            Label(rating.title, systemImage: selectedRatings.contains(rating) ? "checkmark.circle.fill" : "circle")
                        }
                    }
                }
                Toggle("Custom Fan", isOn: $showCustomFanOnly)
                Toggle("Top Score Only", isOn: $topScoreOnly)
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced))
        }
    }

    private func leaderboardRow(result: BenchmarkResult, rank: Int) -> some View {
        HStack(spacing: 12) {
            Text("#\(rank)").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(Color.cmAmber).frame(width: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.chipName).font(.system(size: 12, weight: .bold))
                Text(MacModelRegistry.entry(for: result.macModel)?.friendlyName ?? result.macModel)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            qualityBadge(result)
            metric("\(result.rawScore)", label: "Score")
            metric("\(Int(result.peakTemp.rounded()))°", label: "Peak")
            metric("\(Int(result.avgLoad.rounded()))%", label: "Load")
            Text(result.date.formatted(date: .abbreviated, time: .omitted))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
            if result.customFanControl {
                Text("Custom Fan Control")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.cmAmber)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.cmAmber.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(10)
        .background(Color.cmSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cmBorder, lineWidth: 1))
    }

    private func qualityBadge(_ result: BenchmarkResult) -> some View {
        HStack(spacing: 4) {
            Image(systemName: result.qualityRating.symbolName)
            Text(result.qualityRating.title.uppercased())
        }
        .font(.system(size: 9, weight: .bold, design: .monospaced))
        .foregroundStyle(result.customFanControl ? Color.cmAmber : result.qualityRating.color)
    }

    private func metric(_ value: String, label: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(value).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(.white)
            Text(label).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
        }
        .frame(width: 62, alignment: .trailing)
    }

    private func toggle<T: Hashable>(_ set: inout Set<T>, _ value: T) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }
}

private struct BenchmarkResultDetailView: View {
    let result: BenchmarkResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("BENCHMARK DETAILS").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(Color.cmBlue)
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
            }
            BenchmarkTimelineView(samples: result.samples)
                .frame(height: 220)
            VStack(alignment: .leading, spacing: 8) {
                detailLine("Chip", result.chipName)
                detailLine("Model", MacModelRegistry.entry(for: result.macModel)?.friendlyName ?? result.macModel)
                detailLine("Score", "\(result.rawScore)")
                detailLine("Rating", result.qualityRating.displayTitle(customFanControl: result.customFanControl))
                detailLine("Peak Temp", "\(Int(result.peakTemp.rounded()))°C")
                detailLine("Average Load", "\(Int(result.avgLoad.rounded()))%")
                detailLine("Duration", "\(result.durationSeconds)s")
            }
            Spacer()
        }
        .padding(18)
        .preferredColorScheme(.dark)
        .frame(minWidth: 700, minHeight: 520)
        .background(Color.cmBackground)
    }

    private func detailLine(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label.uppercased()).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(.white)
        }
    }
}
