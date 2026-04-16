import XCTest
@testable import Core_Monitor

final class AppRuntimeContextTests: XCTestCase {
    func testDetectsXCTestConfigurationEnvironment() {
        XCTAssertTrue(
            AppRuntimeContext.isRunningUnitTests(
                environment: ["XCTestConfigurationFilePath": "/tmp/session.xctestconfiguration"]
            )
        )
    }

    func testDetectsBundleInjectionEnvironment() {
        XCTAssertTrue(
            AppRuntimeContext.isRunningUnitTests(
                environment: ["XCInjectBundleInto": "/tmp/Core-Monitor.app/Contents/MacOS/Core-Monitor"]
            )
        )
    }

    func testInteractiveBootstrapRemainsEnabledOutsideTests() {
        XCTAssertFalse(AppRuntimeContext.isRunningUnitTests(environment: [:]))
        XCTAssertTrue(AppRuntimeContext.shouldBootstrapInteractiveApp(environment: [:]))
    }
}
