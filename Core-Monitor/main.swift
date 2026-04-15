import AppKit

if #available(macOS 13.0, *) {
    let coreMonitorAppDelegate = MainActor.assumeIsolated { CoreMonitorApplicationDelegate() }
    let application = NSApplication.shared
    MainActor.assumeIsolated {
        application.delegate = coreMonitorAppDelegate
    }
    _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
} else {
    fatalError("Core Monitor requires macOS 13.0 or newer.")
}
