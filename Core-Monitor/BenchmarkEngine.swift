import Foundation
import Combine
import Darwin

private let kM2BaselineOps: Double = 8_000_000

@MainActor
final class BenchmarkSession: ObservableObject {
    @Published var samples: [BenchmarkSample] = []
    @Published var peakTemp: Double = 0
    @Published var peakLoad: Double = 0
    @Published var avgTemp: Double = 0
    @Published var avgLoad: Double = 0
    @Published var currentTemp: Double = 0
    @Published var currentLoad: Double = 0
    @Published var rawScore: Int = 0
    @Published var elapsedSeconds: Int = 0
    @Published var isRunning = false
    @Published var customFanControl = false

    var latestResult: BenchmarkResult?
    fileprivate var opsTimeline: [Double] = []
    fileprivate var cumulativeTemp: Double = 0
    fileprivate var cumulativeLoad: Double = 0

    func reset(customFanControl: Bool) {
        samples = []
        peakTemp = 0
        peakLoad = 0
        avgTemp = 0
        avgLoad = 0
        currentTemp = 0
        currentLoad = 0
        rawScore = 0
        elapsedSeconds = 0
        isRunning = false
        latestResult = nil
        opsTimeline = []
        cumulativeTemp = 0
        cumulativeLoad = 0
        self.customFanControl = customFanControl
    }
}

final class BenchmarkEngine {
    private var sampleTimer: DispatchSourceTimer?
    private var workers: [DispatchWorkItem] = []
    private let opsQueue = DispatchQueue(label: "CoreMonitor.BenchmarkOps")
    private var opsCompleted: Double = 0
    private var lastSecondOps: Double = 0
    private var stopRequested = false

    func run(
        session: BenchmarkSession,
        systemMonitor: SystemMonitor,
        detector: SMCTamperDetector,
        durationSeconds: Int = 60,
        completion: @escaping (BenchmarkResult) -> Void
    ) {
        detector.inspect()
        session.reset(customFanControl: detector.isTampered)
        session.isRunning = true
        opsQueue.sync {
            stopRequested = false
            opsCompleted = 0
            lastSecondOps = 0
        }

        let perfCores = max(1, SystemMonitor.performanceCoreCount())
        let cpuSampler = CPUUsageSampler()
        let startDate = Date()

        for workerID in 0..<perfCores {
            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                var seed = UInt64(workerID + 1) &* 0x9E3779B97F4A7C15
                while !self.shouldStop {
                    let chunk = BenchmarkEngine.runWorkload(seed: &seed)
                    self.addOps(chunk)
                }
            }
            workers.append(workItem)
            DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
        }

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInitiated))
        timer.schedule(deadline: .now() + 1.0, repeating: 1.0)
        timer.setEventHandler { [weak self, weak systemMonitor] in
            guard let self else { return }
            let elapsed = Int(Date().timeIntervalSince(startDate))
            let load = cpuSampler.sample()
            let (currentOps, delta) = self.consumeOps()

            Task { @MainActor [weak systemMonitor] in
                guard let systemMonitor else { return }
                let temps = systemMonitor.benchmarkTemperatureReadings()
                let packageTemp = temps["package"] ?? systemMonitor.cpuTemperature ?? 0
                let fanRPM = systemMonitor.fanSpeeds.first ?? 0
                let sample = BenchmarkSample(
                    timestamp: Date().timeIntervalSince(startDate),
                    cpuLoad: load,
                    packageTemp: packageTemp,
                    allTemps: temps,
                    fanRPM: fanRPM
                )
                session.samples.append(sample)
                session.opsTimeline.append(delta)
                session.cumulativeTemp += packageTemp
                session.cumulativeLoad += load
                session.elapsedSeconds = elapsed
                session.currentLoad = load
                session.currentTemp = packageTemp
                session.peakLoad = max(session.peakLoad, load)
                session.peakTemp = max(session.peakTemp, packageTemp)
                let sampleCount = Double(max(1, session.samples.count))
                session.avgTemp = session.cumulativeTemp / sampleCount
                session.avgLoad = session.cumulativeLoad / sampleCount
                session.rawScore = Int((currentOps / kM2BaselineOps) * 1000.0)

                if elapsed >= durationSeconds || self.shouldStop {
                    self.finish(session: session, startDate: startDate, completion: completion)
                }
            }
        }
        sampleTimer = timer
        timer.resume()
    }

    func stop(session: BenchmarkSession, systemMonitor: SystemMonitor, completion: @escaping (BenchmarkResult) -> Void) {
        setStopRequested(true)
        Task { @MainActor in
            self.finish(session: session, startDate: Date().addingTimeInterval(-Double(session.elapsedSeconds)), completion: completion)
        }
    }

    @MainActor
    private func finish(
        session: BenchmarkSession,
        startDate: Date,
        completion: @escaping (BenchmarkResult) -> Void
    ) {
        guard session.isRunning else { return }
        session.isRunning = false
        setStopRequested(true)
        sampleTimer?.cancel()
        sampleTimer = nil
        workers.forEach { $0.cancel() }
        workers.removeAll()

        let result = BenchmarkResult(
            id: UUID(),
            date: Date(),
            macModel: SystemMonitor.hostModelIdentifier(),
            chipName: SystemMonitor.chipName(),
            performanceCores: SystemMonitor.performanceCoreCount(),
            efficiencyCores: SystemMonitor.efficiencyCoreCount(),
            totalCores: SystemMonitor.totalLogicalCoreCount(),
            rawScore: session.rawScore,
            qualityRating: QualityRatingEngine.evaluate(
                avgLoad: session.avgLoad,
                peakTemp: session.peakTemp,
                opsTimeline: session.opsTimeline
            ),
            peakTemp: session.peakTemp,
            avgTemp: session.avgTemp,
            avgLoad: session.avgLoad,
            customFanControl: session.customFanControl,
            durationSeconds: max(session.elapsedSeconds, Int(Date().timeIntervalSince(startDate))),
            samples: session.samples
        )
        session.latestResult = result
        completion(result)
    }

    private static func runWorkload(seed: inout UInt64) -> Double {
        var ops: Double = 0
        var matrixA = [Double](repeating: 0, count: 64)
        var matrixB = [Double](repeating: 0, count: 64)
        var matrixC = [Double](repeating: 0, count: 64)
        for i in 0..<64 {
            seed = seed &* 6364136223846793005 &+ 1
            matrixA[i] = Double(seed & 0xFF) / 255.0
            seed = seed &* 6364136223846793005 &+ 1
            matrixB[i] = Double(seed & 0xFF) / 255.0
        }
        for row in 0..<8 {
            for col in 0..<8 {
                var sum = 0.0
                for k in 0..<8 {
                    sum += matrixA[row * 8 + k] * matrixB[k * 8 + col]
                    ops += 2
                }
                matrixC[row * 8 + col] = sum
            }
        }

        var hash: UInt64 = 1469598103934665603
        for value in matrixC {
            hash ^= UInt64(bitPattern: Int64(value.bitPattern))
            hash &*= 1099511628211
            ops += 1
        }

        let limit = 1200
        var sieve = [Bool](repeating: true, count: limit)
        sieve[0] = false
        sieve[1] = false
        var primeCount = 0
        for p in 2..<limit where sieve[p] {
            primeCount += 1
            var multiple = p * p
            while multiple < limit {
                sieve[multiple] = false
                multiple += p
                ops += 1
            }
        }

        return ops + Double(hash & 0xFF) + Double(primeCount)
    }

    private var shouldStop: Bool {
        opsQueue.sync { stopRequested }
    }

    private func setStopRequested(_ value: Bool) {
        opsQueue.sync {
            stopRequested = value
        }
    }

    private func addOps(_ chunk: Double) {
        opsQueue.sync {
            opsCompleted += chunk
        }
    }

    private func consumeOps() -> (Double, Double) {
        opsQueue.sync {
            let currentOps = opsCompleted
            let delta = currentOps - lastSecondOps
            lastSecondOps = currentOps
            return (currentOps, delta)
        }
    }
}

private final class CPUUsageSampler {
    private var previousCPULoadInfo = host_cpu_load_info_data_t()
    private var hasPrevious = false

    func sample() -> Double {
        var loadInfo = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &loadInfo) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        defer { previousCPULoadInfo = loadInfo; hasPrevious = true }
        guard hasPrevious else { return 0 }
        let user = Double(loadInfo.cpu_ticks.0 - previousCPULoadInfo.cpu_ticks.0)
        let system = Double(loadInfo.cpu_ticks.1 - previousCPULoadInfo.cpu_ticks.1)
        let idle = Double(loadInfo.cpu_ticks.2 - previousCPULoadInfo.cpu_ticks.2)
        let nice = Double(loadInfo.cpu_ticks.3 - previousCPULoadInfo.cpu_ticks.3)
        let total = user + system + idle + nice
        guard total > 0 else { return 0 }
        return ((user + system + nice) / total) * 100.0
    }
}
