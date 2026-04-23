# File: Core-Monitor/AppRuntimeContext.swift

## Current Role

- Area: Core app.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/AppRuntimeContext.swift`](../../../Core-Monitor/AppRuntimeContext.swift) |
| Wiki area | Core app |
| Exists in current checkout | True |
| Size | 540 bytes |
| Binary | False |
| Line count | 18 |
| Extension | `.swift` |

## Imports

`Foundation`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| enum | `AppRuntimeContext` | 2 |

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
```
