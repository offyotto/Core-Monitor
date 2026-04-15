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
}
