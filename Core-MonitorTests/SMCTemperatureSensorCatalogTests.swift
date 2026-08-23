import XCTest
@testable import Core_Monitor

final class SMCTemperatureSensorCatalogTests: XCTestCase {
    func testAppleSiliconClusterRangesPutEfficiencyCoresFirst() {
        let ranges = CPUClusterProcessorRanges.resolve(
            cpuCount: 8,
            performanceCoreCount: 6,
            efficiencyCoreCount: 2
        )

        XCTAssertEqual(ranges?.efficiency, 0..<2)
        XCTAssertEqual(ranges?.performance, 2..<8)
    }

    func testSingleClusterUsesTheFullProcessorRange() {
        let ranges = CPUClusterProcessorRanges.resolve(
            cpuCount: 12,
            performanceCoreCount: 12,
            efficiencyCoreCount: 0
        )

        XCTAssertNil(ranges?.efficiency)
        XCTAssertEqual(ranges?.performance, 0..<12)
    }

    func testCatalogUsesGenerationSpecificKeys() {
        let cases = [
            ("Apple M1 Max", "Tp0H", "Tg0D"),
            ("Apple M2 Pro", "Tp1h", "Tg0f"),
            ("Apple M3 Max", "Tf44", "Tf24"),
            ("Apple M4", "Tp0V", "Tg0G"),
            ("Apple M5 Pro", "Tp00", "Tg0U")
        ]

        for (chip, cpuKey, gpuKey) in cases {
            let sensors = SMCTemperatureSensorCatalog.sensors(chipName: chip, isAppleSilicon: true)
            XCTAssertTrue(sensors.cpuKeys.contains(cpuKey), chip)
            XCTAssertTrue(sensors.gpuKeys.contains(gpuKey), chip)
        }
    }

    func testUnknownAppleSiliconUsesKnownFallbackKeys() {
        let sensors = SMCTemperatureSensorCatalog.sensors(
            chipName: "Apple Silicon",
            isAppleSilicon: true
        )

        XCTAssertTrue(sensors.cpuKeys.contains("Tp09"))
        XCTAssertTrue(sensors.cpuKeys.contains("Tp00"))
        XCTAssertTrue(sensors.gpuKeys.contains("Tg05"))
        XCTAssertTrue(sensors.gpuKeys.contains("Tg0U"))
        XCTAssertEqual(Set(sensors.cpuKeys).count, sensors.cpuKeys.count)
        XCTAssertEqual(Set(sensors.gpuKeys).count, sensors.gpuKeys.count)
    }

    func testTemperatureSummaryUsesEveryValidReading() {
        let values: [String: Double] = [
            "A": 40,
            "B": 50,
            "C": 60,
            "D": -1,
            "E": 200
        ]

        var reads: [String] = []
        let summary = SMCTemperatureSensorCatalog.temperatureSummary(
            for: ["A", "B", "C", "D", "E", "missing"],
            readValue: {
                reads.append($0)
                return values[$0]
            }
        )

        XCTAssertEqual(summary?.average ?? 0, 50, accuracy: 0.001)
        XCTAssertEqual(summary?.peak ?? 0, 60, accuracy: 0.001)
        XCTAssertEqual(reads, ["A", "B", "C", "D", "E", "missing"])
    }

    func testAppleStorageUsesTheNANDSensor() {
        let sensors = SMCTemperatureSensorCatalog.sensors(
            chipName: "Apple M4",
            isAppleSilicon: true
        )

        XCTAssertEqual(
            sensors.storageSensors,
            [SMCStorageTemperatureSensor(key: "TH0x", label: "NAND (SMC)")]
        )
    }

    func testIOFloatDecoderReadsLittleEndianFixedPoint() {
        let value = SMCIOFloatDecoder.decode(
            [0xcc, 0xcc, 0x21, 0, 0, 0, 0, 0],
            dataSize: 8
        )

        XCTAssertEqual(value ?? 0, 33.8, accuracy: 0.01)
        XCTAssertNil(SMCIOFloatDecoder.decode([0xcc, 0xcc, 0x21], dataSize: 8))
    }
}
