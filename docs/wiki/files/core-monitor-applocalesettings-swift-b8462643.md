# File: Core-Monitor/AppLocaleSettings.swift

## Current Role

- Area: Core app.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/AppLocaleSettings.swift`](../../../Core-Monitor/AppLocaleSettings.swift) |
| Wiki area | Core app |
| Exists in current checkout | True |
| Size | 8570 bytes |
| Binary | False |
| Line count | 202 |
| Extension | `.swift` |

## Imports

`Foundation`, `SwiftUI`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| enum | `AppLocaleStore` | 3 |
| struct | `DashboardRootView` | 70 |
| struct | `LocalizationSettingsCard` | 87 |
| func | `quickPickLabel` | 177 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `29afd92` | 2026-04-18 | Ship 14.0.7 localization update |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import Foundation
import SwiftUI

enum AppLocaleStore {
    nonisolated static let localeOverrideKey = "coremonitor.localeOverride"
    nonisolated static let systemLocaleValue = "__system__"

    private nonisolated static let englishReferenceLocale = Locale(identifier: "en")

    nonisolated static var currentLocale: Locale {
        locale(forStoredIdentifier: UserDefaults.standard.string(forKey: localeOverrideKey) ?? systemLocaleValue)
    }

    nonisolated static func locale(forStoredIdentifier storedIdentifier: String) -> Locale {
        guard storedIdentifier.isEmpty == false, storedIdentifier != systemLocaleValue else {
            return .autoupdatingCurrent
        }
        return Locale(identifier: storedIdentifier)
    }

    nonisolated static var supportedLocaleIdentifiers: [String] {
        Bundle.main.localizations
            .filter { $0 != "Base" }
            .sorted { lhs, rhs in
                if lhs == "en" { return true }
                if rhs == "en" { return false }

                let lhsName = englishDisplayName(for: lhs)
                let rhsName = englishDisplayName(for: rhs)
                let comparison = lhsName.localizedCaseInsensitiveCompare(rhsName)
                if comparison == .orderedSame {
                    return lhs < rhs
                }
                return comparison == .orderedAscending
            }
    }

    nonisolated static func optionLabel(for identifier: String) -> String {
        let english = englishDisplayName(for: identifier)
        let native = nativeDisplayName(for: identifier)
```
