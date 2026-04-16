import Foundation

enum AppRuntimeContext {
    static func isRunningUnitTests(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        environment["XCTestConfigurationFilePath"] != nil ||
        environment["XCTestBundlePath"] != nil ||
        environment["XCInjectBundleInto"] != nil
    }

    static func shouldBootstrapInteractiveApp(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        !isRunningUnitTests(environment: environment)
    }
}
