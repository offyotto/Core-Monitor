# File: Core-MonitorTests/PrivilegedHelperRequirementStringsTests.swift

## Current Role

- Area: Tests.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-MonitorTests/PrivilegedHelperRequirementStringsTests.swift`](../../../Core-MonitorTests/PrivilegedHelperRequirementStringsTests.swift) |
| Wiki area | Tests |
| Exists in current checkout | True |
| Size | 3718 bytes |
| Binary | False |
| Line count | 87 |
| Extension | `.swift` |

## Imports

`Foundation`, `Security`, `XCTest`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `PrivilegedHelperRequirementStringsTests` | 4 |
| func | `testAppHelperRequirementUsesTeamIdentifierRule` | 8 |
| func | `testHelperAuthorizedClientsUsesSameTeamIdentifierRule` | 22 |
| func | `testHelperInfoPlistUsesConcreteExecutableMetadata` | 37 |
| func | `testBundledHelperBinaryDoesNotContainUnexpandedInfoPlistPlaceholders` | 45 |
| func | `loadPlist` | 64 |
| func | `assertRequirementCompiles` | 74 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `675fabf` | 2026-04-17 | Ship 14.0.5 helper recovery release |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
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
            #"anchor apple generic and identifier "ventaphobia.smc-helper" and certificate leaf[subject.OU] = "6VDP675K4L""#
        )
        XCTAssertFalse(requirement.contains("1.2.840.113635.100.6.1.9"))
        XCTAssertFalse(requirement.contains("1.2.840.113635.100.6.2.6"))
        assertRequirementCompiles(requirement)
    }

    func testHelperAuthorizedClientsUsesSameTeamIdentifierRule() throws {
        let plist = try loadPlist(at: "smc-helper/Info.plist")
        let authorizedClients = try XCTUnwrap(plist["SMAuthorizedClients"] as? [String])
        let requirement = try XCTUnwrap(authorizedClients.first)

        XCTAssertEqual(
            requirement,
            #"anchor apple generic and identifier "CoreTools.Core-Monitor" and certificate leaf[subject.OU] = "6VDP675K4L""#
        )
        XCTAssertEqual(authorizedClients.count, 1)
        XCTAssertFalse(requirement.contains("1.2.840.113635.100.6.1.9"))
        XCTAssertFalse(requirement.contains("1.2.840.113635.100.6.2.6"))
        assertRequirementCompiles(requirement)
    }

    func testHelperInfoPlistUsesConcreteExecutableMetadata() throws {
        let plist = try loadPlist(at: "smc-helper/Info.plist")

```
