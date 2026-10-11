import Foundation
import Security
import XCTest

final class PrivilegedHelperRequirementStringsTests: XCTestCase {
    private let teamIdentifier = "6VDP675K4L"
    private let helperLabel = "ventaphobia.smc-helper"

    func testAppHelperRequirementUsesTeamIdentifierRule() throws {
        let plist = try loadPlist(at: "App-Info.plist")
        let privilegedExecutables = try XCTUnwrap(plist["SMPrivilegedExecutables"] as? [String: String])
        let requirement = try XCTUnwrap(privilegedExecutables["ventaphobia.smc-helper"])

        XCTAssertEqual(
            requirement,
            #"anchor apple generic and identifier "ventaphobia.smc-helper" and certificate leaf[subject.OU] = "6VDP675K4L" and certificate leaf[field.1.2.840.113635.100.6.1.13] exists and certificate 1[field.1.2.840.113635.100.6.2.6] exists"#
        )
        XCTAssertTrue(requirement.contains("1.2.840.113635.100.6.1.13"))
        XCTAssertTrue(requirement.contains("1.2.840.113635.100.6.2.6"))
        assertRequirementCompiles(requirement)
    }

    func testHelperAuthorizedClientsUsesSameTeamIdentifierRule() throws {
        let plist = try loadPlist(at: "smc-helper/Info.plist")
        let authorizedClients = try XCTUnwrap(plist["SMAuthorizedClients"] as? [String])
        let requirement = try XCTUnwrap(authorizedClients.first)

        XCTAssertEqual(
            requirement,
            #"anchor apple generic and identifier "CoreTools.Core-Monitor" and certificate leaf[subject.OU] = "6VDP675K4L" and certificate leaf[field.1.2.840.113635.100.6.1.13] exists and certificate 1[field.1.2.840.113635.100.6.2.6] exists"#
        )
        XCTAssertEqual(authorizedClients.count, 1)
        XCTAssertTrue(requirement.contains("1.2.840.113635.100.6.1.13"))
        XCTAssertTrue(requirement.contains("1.2.840.113635.100.6.2.6"))
        assertRequirementCompiles(requirement)
    }

    func testHelperInfoPlistUsesConcreteExecutableMetadata() throws {
        let plist = try loadPlist(at: "smc-helper/Info.plist")

        XCTAssertEqual(plist["CFBundleExecutable"] as? String, helperLabel)
        XCTAssertEqual(plist["CFBundleIdentifier"] as? String, helperLabel)
        XCTAssertEqual(plist["CFBundleName"] as? String, helperLabel)
    }

    func testBundledHelperBinaryDoesNotContainUnexpandedInfoPlistPlaceholders() throws {
        let helperURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/LaunchServices/\(helperLabel)")
        XCTAssertTrue(FileManager.default.fileExists(atPath: helperURL.path))

        let helperData = try Data(contentsOf: helperURL)
        let start = try XCTUnwrap(helperData.range(of: Data("<?xml".utf8)))
        let end = try XCTUnwrap(helperData.range(of: Data("</plist>".utf8), in: start.lowerBound..<helperData.endIndex))
        let xml = helperData.subdata(in: start.lowerBound..<end.upperBound)
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: xml, options: [], format: nil) as? [String: Any])
        for key in ["CFBundleExecutable", "CFBundleIdentifier", "CFBundleName"] {
            XCTAssertEqual(plist[key] as? String, helperLabel)
        }
        let version = try XCTUnwrap(plist["CFBundleVersion"] as? String)
        XCTAssertFalse(version.isEmpty)
        XCTAssertFalse(version.contains("$("), "Embedded version must be expanded")
    }

    private func loadPlist(at relativePath: String) throws -> [String: Any] {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let plistURL = repoRoot.appendingPathComponent(relativePath)
        let data = try Data(contentsOf: plistURL)
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        return try XCTUnwrap(plist as? [String: Any])
    }

    private func assertRequirementCompiles(
        _ requirement: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var compiledRequirement: SecRequirement?
        let status = SecRequirementCreateWithString(requirement as CFString, SecCSFlags(), &compiledRequirement)

        XCTAssertEqual(status, errSecSuccess, file: file, line: line)
        XCTAssertNotNil(compiledRequirement, file: file, line: line)
    }
}
