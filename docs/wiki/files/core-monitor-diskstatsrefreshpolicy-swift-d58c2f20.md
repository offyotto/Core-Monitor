# File: Core-Monitor/DiskStatsRefreshPolicy.swift

## Current Role

- Area: Core app.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/DiskStatsRefreshPolicy.swift`](../../../Core-Monitor/DiskStatsRefreshPolicy.swift) |
| Wiki area | Core app |
| Exists in current checkout | True |
| Size | 398 bytes |
| Binary | False |
| Line count | 15 |
| Extension | `.swift` |

## Imports

`Foundation`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| enum | `DiskStatsRefreshPolicy` | 2 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `767668c` | 2026-04-16 | Throttle disk stats refresh cadence |
| `108166d` | 2026-04-16 | Throttle disk stats refresh cadence |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import Foundation

enum DiskStatsRefreshPolicy {
    static let minimumRefreshInterval: TimeInterval = 30

    static func shouldRefresh(
        lastUpdatedAt: Date?,
        now: Date,
        minimumInterval: TimeInterval = minimumRefreshInterval
    ) -> Bool {
        guard let lastUpdatedAt else { return true }
        return now.timeIntervalSince(lastUpdatedAt) >= minimumInterval
    }
}
```
