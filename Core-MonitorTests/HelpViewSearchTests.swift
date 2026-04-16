import SwiftUI
import XCTest
@testable import Core_Monitor

final class HelpViewSearchTests: XCTestCase {
    func testHelpSectionMatchesKeywordsAndTitleCaseInsensitively() {
        let section = HelpView.HelpSection(
            id: "system",
            title: "System Controls",
            icon: "gearshape",
            keywords: ["launch at login", "login items", "helper diagnostics"],
            content: AnyView(EmptyView())
        )

        XCTAssertTrue(section.matches(query: "system"))
        XCTAssertTrue(section.matches(query: "LOGIN"))
        XCTAssertTrue(section.matches(query: "helper"))
    }

    func testHelpSectionRequiresAllQueryTokensToMatch() {
        let section = HelpView.HelpSection(
            id: "weather",
            title: "Weather Permission Tips",
            icon: "cloud.sun.rain.fill",
            keywords: ["weatherkit", "location services", "permission"],
            content: AnyView(EmptyView())
        )

        XCTAssertTrue(section.matches(query: "weather location"))
        XCTAssertFalse(section.matches(query: "weather helper"))
    }

    func testHelpSectionMatchesMenuBarRecoveryLanguage() {
        let section = HelpView.HelpSection(
            id: "menubar",
            title: "Menu Bar Items and Popovers",
            icon: "menubar.rectangle",
            keywords: ["fan", "rpm", "allow in menu bar", "hidden icon", "missing icon", "macos 26"],
            content: AnyView(EmptyView())
        )

        XCTAssertTrue(section.matches(query: "fan rpm"))
        XCTAssertTrue(section.matches(query: "allow menu"))
        XCTAssertTrue(section.matches(query: "hidden icon"))
        XCTAssertTrue(section.matches(query: "macos 26"))
    }

    func testHelpSectionMatchesBatteryRuntimeAndElectricalKeywords() {
        let section = HelpView.HelpSection(
            id: "battery",
            title: "Battery",
            icon: "battery.100",
            keywords: ["time remaining", "time to full", "voltage", "current", "power adapter"],
            content: AnyView(EmptyView())
        )

        XCTAssertTrue(section.matches(query: "time remaining"))
        XCTAssertTrue(section.matches(query: "voltage current"))
        XCTAssertFalse(section.matches(query: "voltage helper"))
    }

    func testHelpSectionMatchesNetworkThroughputKeywords() {
        let section = HelpView.HelpSection(
            id: "overview",
            title: "Overview Dashboard",
            icon: "gauge.medium",
            keywords: ["network", "upload", "download", "throughput"],
            content: AnyView(EmptyView())
        )

        XCTAssertTrue(section.matches(query: "network"))
        XCTAssertTrue(section.matches(query: "upload throughput"))
        XCTAssertFalse(section.matches(query: "upload helper"))
    }

    func testHelpSectionMatchesDashboardShortcutKeywords() {
        let section = HelpView.HelpSection(
            id: "system",
            title: "System Controls",
            icon: "gearshape",
            keywords: ["dashboard shortcut", "dashboard hotkey", "option command m"],
            content: AnyView(EmptyView())
        )

        XCTAssertTrue(section.matches(query: "dashboard shortcut"))
        XCTAssertTrue(section.matches(query: "option command"))
        XCTAssertFalse(section.matches(query: "dashboard fan"))
    }
}
