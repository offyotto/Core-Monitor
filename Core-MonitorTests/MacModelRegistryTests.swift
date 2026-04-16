import XCTest
@testable import Core_Monitor

final class MacModelRegistryTests: XCTestCase {
    func testDisplayNameFallsBackToIdentifierWhenModelIsUnknown() {
        XCTAssertEqual(MacModelRegistry.displayName(for: "MysteryMac1,1"), "MysteryMac1,1")
    }

    func testRegistryMapsModernMacBookProIdentifiersAccurately() {
        XCTAssertEqual(
            MacModelRegistry.entry(for: "Mac15,10")?.friendlyName,
            "MacBook Pro (14-inch, Nov 2023, M3 Pro/Max)"
        )
        XCTAssertEqual(
            MacModelRegistry.entry(for: "Mac16,7")?.friendlyName,
            "MacBook Pro (16-inch, 2024, M4 Pro/Max)"
        )
        XCTAssertEqual(
            MacModelRegistry.entry(for: "Mac17,2")?.friendlyName,
            "MacBook Pro (14-inch, 2025, M5)"
        )
        XCTAssertEqual(MacModelRegistry.entry(for: "Mac16,7")?.family, .macBookProMSeries)
    }

    func testRegistryIncludesRecentAppleSiliconMacsAcrossFamilies() {
        XCTAssertEqual(
            MacModelRegistry.entry(for: "Mac16,12")?.friendlyName,
            "MacBook Air (13-inch, 2025, M4)"
        )
        XCTAssertEqual(
            MacModelRegistry.entry(for: "Mac16,11")?.friendlyName,
            "Mac mini (2024)"
        )
        XCTAssertEqual(
            MacModelRegistry.entry(for: "Mac16,3")?.friendlyName,
            "iMac (24-inch, 2024, Four ports)"
        )
        XCTAssertEqual(
            MacModelRegistry.entry(for: "Mac15,14")?.friendlyName,
            "Mac Studio (2025, M3 Ultra)"
        )
    }

    func testEntriesUseUniqueHardwareModelIdentifiers() {
        XCTAssertEqual(Set(MacModelRegistry.entries.map(\.hwModel)).count, MacModelRegistry.entries.count)
    }

    func testAppleSiliconDelayedResponseCaveatOnlyAppearsForManagedMacBookProsWithFans() {
        let notebookNote = FanModeGuidanceCopy.appleSiliconDelayedResponseNote(
            for: .manual,
            hasFans: true,
            hostModelIdentifier: "Mac16,7",
            isAppleSilicon: true
        )

        XCTAssertEqual(
            notebookNote,
            "On MacBook Pro (16-inch, 2024, M4 Pro/Max), macOS may hold fan RPM near its baseline until extra airflow is needed, so a manual target can take a moment to react on a cool machine."
        )

        XCTAssertNil(
            FanModeGuidanceCopy.appleSiliconDelayedResponseNote(
                for: .automatic,
                hasFans: true,
                hostModelIdentifier: "Mac16,7",
                isAppleSilicon: true
            )
        )
        XCTAssertNil(
            FanModeGuidanceCopy.appleSiliconDelayedResponseNote(
                for: .manual,
                hasFans: false,
                hostModelIdentifier: "Mac16,7",
                isAppleSilicon: true
            )
        )
        XCTAssertNil(
            FanModeGuidanceCopy.appleSiliconDelayedResponseNote(
                for: .manual,
                hasFans: true,
                hostModelIdentifier: "Mac16,9",
                isAppleSilicon: true
            )
        )
        XCTAssertNil(
            FanModeGuidanceCopy.appleSiliconDelayedResponseNote(
                for: .manual,
                hasFans: true,
                hostModelIdentifier: "Mac16,7",
                isAppleSilicon: false
            )
        )
    }
}
