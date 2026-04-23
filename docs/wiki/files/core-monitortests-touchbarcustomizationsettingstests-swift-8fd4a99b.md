# File: Core-MonitorTests/TouchBarCustomizationSettingsTests.swift

## Current Role

- Area: Tests.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-MonitorTests/TouchBarCustomizationSettingsTests.swift`](../../../Core-MonitorTests/TouchBarCustomizationSettingsTests.swift) |
| Wiki area | Tests |
| Exists in current checkout | True |
| Size | 4581 bytes |
| Binary | False |
| Line count | 128 |
| Extension | `.swift` |

## Imports

`XCTest`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `TouchBarCustomizationSettingsTests` | 2 |
| func | `testNormalizedItemsDeduplicatesBuiltInsAndPinnedPaths` | 6 |
| func | `testAddPinnedAppsSkipsDuplicatePaths` | 68 |
| func | `makeSettings` | 83 |
| class | `CoreMonTouchBarControllerTests` | 92 |
| func | `testReloadCustomizationRebuildsTouchBarWithUpdatedIdentifiers` | 95 |
| func | `makeSettings` | 119 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `44eb999` | 2026-04-16 | Harden touch bar customization and weather fallback |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import XCTest
@testable import Core_Monitor

@MainActor
final class TouchBarCustomizationSettingsTests: XCTestCase {
    func testNormalizedItemsDeduplicatesBuiltInsAndPinnedPaths() {
        let appPath = "/Applications/Utilities/Terminal.app"
        let folderPath = "/Applications"
        let items: [TouchBarItemConfiguration] = [
            .builtIn(.weather),
            .builtIn(.weather),
            .pinnedApp(
                TouchBarPinnedApp(
                    id: "app-1",
                    displayName: "Terminal",
                    filePath: appPath,
                    bundleIdentifier: "com.apple.Terminal"
                )
            ),
            .pinnedApp(
                TouchBarPinnedApp(
                    id: "app-2",
                    displayName: "Terminal Again",
                    filePath: appPath,
                    bundleIdentifier: "com.apple.Terminal"
                )
            ),
            .pinnedFolder(
                TouchBarPinnedFolder(
                    id: "folder-1",
                    displayName: "Applications",
                    folderPath: folderPath
                )
            ),
            .pinnedFolder(
                TouchBarPinnedFolder(
                    id: "folder-2",
                    displayName: "Applications Again",
                    folderPath: folderPath
                )
```
