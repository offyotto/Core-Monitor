# File: Core-Monitor/PrivacySettings.swift

## Current Role

- Area: Privacy controls.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/PrivacySettings.swift`](../../../Core-Monitor/PrivacySettings.swift) |
| Wiki area | Privacy controls |
| Exists in current checkout | True |
| Size | 857 bytes |
| Binary | False |
| Line count | 30 |
| Extension | `.swift` |

## Imports

`Combine`, `Foundation`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `PrivacySettings` | 3 |
| enum | `Key` | 6 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `5dc29ed` | 2026-04-16 | Add privacy controls and refine Core Monitor presentation |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import Foundation
import Combine

final class PrivacySettings: ObservableObject {
    static let shared = PrivacySettings()

    private enum Key {
        static let processInsightsEnabled = "coremonitor.privacy.processInsightsEnabled"
    }

    @Published var processInsightsEnabled: Bool {
        didSet {
            defaults.set(processInsightsEnabled, forKey: Key.processInsightsEnabled)
        }
    }

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if defaults.object(forKey: Key.processInsightsEnabled) == nil {
            self.processInsightsEnabled = false
            defaults.set(false, forKey: Key.processInsightsEnabled)
        } else {
            self.processInsightsEnabled = defaults.bool(forKey: Key.processInsightsEnabled)
        }
    }
}
```
