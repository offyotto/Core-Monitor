import XCTest
@testable import Core_Monitor

final class HardwareRescueDiagnosticsTests: XCTestCase {
    func testPortControllerParserExtractsRecoveredUg400State() {
        let ioreg = """
        +-o AppleSmartBattery  <class AppleSmartBattery>
            {
              "PortControllerInfo" = ({"PortControllerI2cErrCount"=0,"PortControllerFwVersion"=2191360,"PortControllerBootFlags"=0,"PortControllerStuckCmdCount"=0,"PortControllerSurpriseNackCount"=0,"PortControllerWakeFailCount"=0,"PortControllerAttachCount"=1,"PortControllerDetachCount"=1,"PortControllerMaxPower"=0,"PortControllerPowerState"=255,"PortControllerPDst"=0},{"PortControllerI2cErrCount"=0,"PortControllerFwVersion"=2191360,"PortControllerBootFlags"=0,"PortControllerStuckCmdCount"=0,"PortControllerSurpriseNackCount"=0,"PortControllerWakeFailCount"=0,"PortControllerAttachCount"=0,"PortControllerDetachCount"=0,"PortControllerMaxPower"=0,"PortControllerPowerState"=255,"PortControllerPDst"=0},{"PortControllerI2cErrCount"=0,"PortControllerFwVersion"=2177024,"PortControllerBootFlags"=0,"PortControllerStuckCmdCount"=0,"PortControllerSurpriseNackCount"=0,"PortControllerWakeFailCount"=0,"PortControllerAttachCount"=2,"PortControllerDetachCount"=2,"PortControllerMaxPower"=0,"PortControllerPowerState"=255,"PortControllerPDst"=0},{"PortControllerI2cErrCount"=0,"PortControllerFwVersion"=2191360,"PortControllerBootFlags"=0,"PortControllerStuckCmdCount"=0,"PortControllerSurpriseNackCount"=0,"PortControllerWakeFailCount"=0,"PortControllerAttachCount"=4,"PortControllerDetachCount"=3,"PortControllerMaxPower"=99800,"PortControllerPowerState"=255,"PortControllerPDst"=5})
            }
        """

        let controllers = HardwareRescueTextParser.parsePortControllers(from: ioreg)

        XCTAssertEqual(controllers.count, 4)
        XCTAssertEqual(controllers[2].ridHint, 2)
        XCTAssertEqual(controllers[2].addressHint, "0x3b")
        XCTAssertEqual(controllers[2].firmwareVersionDescription, "2.138.0")
        XCTAssertEqual(controllers[2].severity, .ok)
        XCTAssertEqual(controllers[3].maxPowerDescription, "99.8 W")
    }

    func testPortControllerParserFlagsBootLikeState() {
        let ioreg = """
        "PortControllerInfo" = ({"PortControllerI2cErrCount"=42,"PortControllerFwVersion"=0,"PortControllerBootFlags"=159,"PortControllerStuckCmdCount"=1,"PortControllerSurpriseNackCount"=0,"PortControllerWakeFailCount"=0,"PortControllerAttachCount"=0,"PortControllerDetachCount"=0,"PortControllerMaxPower"=0,"PortControllerPowerState"=255,"PortControllerPDst"=0})
        """

        let controller = HardwareRescueTextParser.parsePortControllers(from: ioreg).first

        XCTAssertEqual(controller?.firmwareVersionDescription, "0 / not loaded")
        XCTAssertEqual(controller?.i2cErrorCount, 42)
        XCTAssertEqual(controller?.bootFlagsDescription, "0x9F")
        XCTAssertEqual(controller?.severity, .attention)
    }

    func testSmartctlParserExtractsNvmeWearAndErrors() {
        let smartctl = """
        SMART overall-health self-assessment test result: PASSED

        SMART/Health Information (NVMe Log 0x02, NSID 0xffffffff)
        Critical Warning:                   0x00
        Temperature:                        34 Celsius
        Available Spare:                    100%
        Percentage Used:                    0%
        Data Units Read:                    24,232,182 [12.4 TB]
        Data Units Written:                 13,342,942 [6.83 TB]
        Power Cycles:                       757
        Power On Hours:                     140
        Unsafe Shutdowns:                   58
        Media and Data Integrity Errors:    0
        Error Information Log Entries:      0
        """

        let storage = HardwareRescueTextParser.parseStorageHealth(from: smartctl)

        XCTAssertEqual(storage.healthPassed, true)
        XCTAssertEqual(storage.percentageUsed, 0)
        XCTAssertEqual(storage.dataUnitsWritten, "13,342,942 [6.83 TB]")
        XCTAssertEqual(storage.unsafeShutdowns, 58)
        XCTAssertEqual(storage.mediaErrors, 0)
        XCTAssertEqual(storage.errorLogEntries, 0)
    }
}
