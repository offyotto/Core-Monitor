# File: Core-Monitor/HelpView.swift

## Current Role

- Area: Core app.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/HelpView.swift`](../../../Core-Monitor/HelpView.swift) |
| Wiki area | Core app |
| Exists in current checkout | True |
| Size | 25645 bytes |
| Binary | False |
| Line count | 480 |
| Extension | `.swift` |

## Imports

`AppKit`, `SwiftUI`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| struct | `HelpView` | 10 |
| struct | `HelpSection` | 16 |
| func | `matches` | 22 |
| func | `sidebarIndex` | 321 |
| struct | `SectionView` | 377 |
| struct | `HelpCard` | 396 |
| struct | `HelpSearchEmptyState` | 409 |
| struct | `HelpBullet` | 429 |
| struct | `PrimaryButtonStyle` | 449 |
| func | `makeBody` | 450 |
| struct | `BorderedAccentButtonStyle` | 463 |
| func | `makeBody` | 465 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `4dc3880` | 2026-04-21 | Update GitHub username references |
| `29afd92` | 2026-04-18 | Ship 14.0.7 localization update |
| `4e417f6` | 2026-04-17 | Remove Alerts screen surface |
| `e24d811` | 2026-04-16 | :)) |
| `ebf3e12` | 2026-04-16 | Retire redundant silent fan mode |
| `133d9ad` | 2026-04-16 | Replace alert surfaces with monitoring status |
| `58feb7a` | 2026-04-16 | Add network menu bar item and popover |
| `7c0c8d6` | 2026-04-16 | Add dashboard shortcut and app menu access |
| `be75b81` | 2026-04-16 | Add dashboard network throughput visibility |
| `b8fd8a6` | 2026-04-16 | Clarify silent mode helper handoff semantics |
| `44eb999` | 2026-04-16 | Harden touch bar customization and weather fallback |
| `e486572` | 2026-04-16 | Scope detailed sampling to active monitoring views |
| `c408c06` | 2026-04-16 | Default fresh installs to system Touch Bar |
| `0574661` | 2026-04-16 | Sync menu bar guidance with the latest thermal UX |
| `8bfc685` | 2026-04-16 | Stabilize signing and WeatherKit release packaging |
| `78d0fd2` | 2026-04-16 | Stabilize onboarding launch and menu bar defaults |
| `0690966` | 2026-04-16 | Surface privacy controls in system settings |
| `5dc29ed` | 2026-04-16 | Add privacy controls and refine Core Monitor presentation |
| `3dbf6ac` | 2026-04-16 | Default fan control to system mode |
| `86747c6` | 2026-04-16 | Refresh in-app help for trends and battery details |
| `f7b2ac8` | 2026-04-16 | Clarify menu bar visibility recovery in support docs |
| `3bc6fbd` | 2026-04-16 | Restore system auto on quit and clarify fan mode behavior |
| `84427d5` | 2026-04-16 | Improve in-app help search discoverability |
| `3ce51de` | 2026-04-16 | Improve helper diagnostics discoverability |
| `1ff7bdb` | 2026-04-16 | Refine helper health states and service alerts |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
//
//  HelpView.swift
//  CoreMonitor
//
//  Created by Core Monitor Team on 2026-04-13.
//

import SwiftUI
import AppKit

struct HelpView: View {
    @AppStorage(WelcomeGuideProgress.hasSeenDefaultsKey) private var hasSeenWelcomeGuide: Bool = false
    @State private var searchText: String = ""

    // MARK: - Help Section Model
    struct HelpSection: Identifiable {
        let id: String
        let title: String
        let icon: String
        let keywords: [String]
        let content: AnyView

        func matches(query rawQuery: String) -> Bool {
            let query = rawQuery
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: AppLocaleStore.currentLocale)

            guard query.isEmpty == false else { return true }

            let searchableText = ([title] + keywords)
                .joined(separator: " ")
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: AppLocaleStore.currentLocale)

            return query
                .split(whereSeparator: \.isWhitespace)
                .allSatisfy { token in searchableText.contains(token) }
        }
    }

    // MARK: - Help Data
```
