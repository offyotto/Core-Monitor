import XCTest
@testable import Core_Monitor

final class DiskProcessSamplerTests: XCTestCase {
    func testActivitiesAggregateDeltasByProcessName() {
        let previousCounters: [Int32: DiskProcessCounter] = [
            11: DiskProcessCounter(pid: 11, name: "Safari", readBytes: 100, writtenBytes: 50),
            12: DiskProcessCounter(pid: 12, name: "Safari", readBytes: 400, writtenBytes: 100),
            77: DiskProcessCounter(pid: 77, name: "backupd", readBytes: 1_000, writtenBytes: 250)
        ]

        let counters = [
            DiskProcessCounter(pid: 11, name: "Safari", readBytes: 450, writtenBytes: 150),
            DiskProcessCounter(pid: 12, name: "Safari", readBytes: 900, writtenBytes: 300),
            DiskProcessCounter(pid: 77, name: "backupd", readBytes: 1_600, writtenBytes: 250),
            DiskProcessCounter(pid: 99, name: "WindowServer", readBytes: 50, writtenBytes: 50)
        ]

        let activities = DiskProcessSampling.activities(
            from: counters,
            previousCounters: previousCounters,
            limit: 4
        )

        XCTAssertEqual(
            activities,
            [
                DiskProcessActivity(name: "Safari", readBytes: 850, writtenBytes: 300),
                DiskProcessActivity(name: "backupd", readBytes: 600, writtenBytes: 0)
            ]
        )
    }

    func testActivitiesClampCounterResetsAndRespectLimit() {
        let previousCounters: [Int32: DiskProcessCounter] = [
            1: DiskProcessCounter(pid: 1, name: "A", readBytes: 900, writtenBytes: 700),
            2: DiskProcessCounter(pid: 2, name: "B", readBytes: 100, writtenBytes: 100),
            3: DiskProcessCounter(pid: 3, name: "C", readBytes: 100, writtenBytes: 100)
        ]

        let counters = [
            DiskProcessCounter(pid: 1, name: "A", readBytes: 200, writtenBytes: 200),
            DiskProcessCounter(pid: 2, name: "B", readBytes: 700, writtenBytes: 600),
            DiskProcessCounter(pid: 3, name: "C", readBytes: 400, writtenBytes: 200)
        ]

        let activities = DiskProcessSampling.activities(
            from: counters,
            previousCounters: previousCounters,
            limit: 1
        )

        XCTAssertEqual(
            activities,
            [DiskProcessActivity(name: "B", readBytes: 600, writtenBytes: 500)]
        )
    }

    func testFormatBytesUsesCompactLabels() {
        XCTAssertEqual(DiskProcessActivity.formatBytes(999), "999B")
        XCTAssertEqual(DiskProcessActivity.formatBytes(12_288), "12K")
        XCTAssertEqual(DiskProcessActivity.formatBytes(5_242_880), "5.0M")
        XCTAssertEqual(DiskProcessActivity.formatBytes(2_147_483_648), "2.0G")
    }
}
