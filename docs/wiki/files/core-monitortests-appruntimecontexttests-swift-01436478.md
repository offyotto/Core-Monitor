# File: Core-MonitorTests/AppRuntimeContextTests.swift

## Current Role

- Area: Tests.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-MonitorTests/AppRuntimeContextTests.swift`](../../../Core-MonitorTests/AppRuntimeContextTests.swift) |
| Wiki area | Tests |
| Exists in current checkout | True |
| Size | 850 bytes |
| Binary | False |
| Line count | 26 |
| Extension | `.swift` |

## Imports

`XCTest`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `AppRuntimeContextTests` | 2 |
| func | `testDetectsXCTestConfigurationEnvironment` | 5 |
| func | `testDetectsBundleInjectionEnvironment` | 12 |
| func | `testInteractiveBootstrapRemainsEnabledOutsideTests` | 20 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `423587b` | 2026-04-16 | Stabilize unit test app bootstrap |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
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
```
