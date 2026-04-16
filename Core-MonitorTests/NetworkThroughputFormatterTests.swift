import XCTest
@testable import Core_Monitor

final class NetworkThroughputFormatterTests: XCTestCase {
    func testFormatterHandlesByteKilobyteAndMegabyteRanges() {
        XCTAssertEqual(NetworkThroughputFormatter.compactRate(bytesPerSecond: 0), "0 B/s")
        XCTAssertEqual(NetworkThroughputFormatter.compactRate(bytesPerSecond: 845), "845 B/s")
        XCTAssertEqual(NetworkThroughputFormatter.compactRate(bytesPerSecond: 12_400), "12 KB/s")
        XCTAssertEqual(NetworkThroughputFormatter.compactRate(bytesPerSecond: 1_550_000), "1.6 MB/s")
    }

    func testFormatterUsesAbsoluteValueForTrendDeltas() {
        XCTAssertEqual(NetworkThroughputFormatter.compactRate(bytesPerSecond: -8_400), "8.4 KB/s")
    }
}
