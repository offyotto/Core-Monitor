import Foundation

/// Canonical outbound links for the app. Kept in one place so the About tab
/// and the Help menu cannot drift apart.
enum CoreMonitorShareKit {
    static let websiteURL = URL(string: "https://offyotto.github.io/Core-Monitor/")!
    static let repositoryURL = URL(string: "https://github.com/offyotto/Core-Monitor")!
    static let latestReleaseURL = URL(string: "https://github.com/offyotto/Core-Monitor/releases/latest")!
}
