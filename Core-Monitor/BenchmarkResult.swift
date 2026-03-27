import Foundation
import Combine

struct BenchmarkSample: Identifiable, Codable, Hashable {
    let id: UUID
    let timestamp: TimeInterval
    let cpuLoad: Double
    let packageTemp: Double
    let allTemps: [String: Double]
    let fanRPM: Int

    init(
        id: UUID = UUID(),
        timestamp: TimeInterval,
        cpuLoad: Double,
        packageTemp: Double,
        allTemps: [String: Double],
        fanRPM: Int
    ) {
        self.id = id
        self.timestamp = timestamp
        self.cpuLoad = cpuLoad
        self.packageTemp = packageTemp
        self.allTemps = allTemps
        self.fanRPM = fanRPM
    }
}

enum QualityRating: String, Codable, CaseIterable, Identifiable {
    case platinum
    case gold
    case silver
    case bronze
    case thermalThrottle = "thermal_throttle"

    var id: String { rawValue }
}

struct BenchmarkResult: Codable, Identifiable, Hashable {
    let id: UUID
    let date: Date
    let macModel: String
    let chipName: String
    let performanceCores: Int
    let efficiencyCores: Int
    let totalCores: Int
    let rawScore: Int
    let qualityRating: QualityRating
    let peakTemp: Double
    let avgTemp: Double
    let avgLoad: Double
    let customFanControl: Bool
    let durationSeconds: Int
    let samples: [BenchmarkSample]
}

@MainActor
final class BenchmarkStore: ObservableObject {
    @Published private(set) var results: [BenchmarkResult] = []

    private let fileManager = FileManager.default

    init() {
        load()
    }

    func save(_ result: BenchmarkResult) {
        results.removeAll { $0.id == result.id }
        results.append(result)
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: resultsURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([BenchmarkResult].self, from: data) {
            results = decoded.sorted { $0.rawScore > $1.rawScore }
        }
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            try fileManager.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
            let data = try encoder.encode(results.sorted { $0.rawScore > $1.rawScore })
            try data.write(to: resultsURL, options: [.atomic])
        } catch {
            NSLog("BenchmarkStore persist failed: \(error.localizedDescription)")
        }
    }

    private var supportDirectory: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CoreMonitor", isDirectory: true)
    }

    private var resultsURL: URL {
        supportDirectory.appendingPathComponent("benchmark_results.json")
    }
}
