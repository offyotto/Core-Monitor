# File: Core-Monitor/DashboardWindowLayout.swift

## Current Role

- Area: Dashboard.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/DashboardWindowLayout.swift`](../../../Core-Monitor/DashboardWindowLayout.swift) |
| Wiki area | Dashboard |
| Exists in current checkout | True |
| Size | 1589 bytes |
| Binary | False |
| Line count | 39 |
| Extension | `.swift` |

## Imports

`AppKit`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| enum | `DashboardWindowLayout` | 2 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `7baad89` | 2026-04-16 | Refine dashboard window sizing |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import AppKit

enum DashboardWindowLayout {
    static let defaultContentSize = NSSize(width: 1_080, height: 720)
    static let minimumContentSize = NSSize(width: 900, height: 640)

    static func targetContentSize(for visibleFrame: CGRect?) -> NSSize {
        guard let visibleFrame,
              visibleFrame.width > 0,
              visibleFrame.height > 0 else {
            return defaultContentSize
        }

        let safeWidth = max(visibleFrame.width - 80, minimumContentSize.width)
        let safeHeight = max(visibleFrame.height - 90, minimumContentSize.height)

        return NSSize(
            width: min(defaultContentSize.width, max(minimumContentSize.width, min(safeWidth, visibleFrame.width * 0.78))),
            height: min(defaultContentSize.height, max(minimumContentSize.height, min(safeHeight, visibleFrame.height * 0.87)))
        )
    }

    static func shouldResetFrame(windowFrame: CGRect, visibleFrame: CGRect?) -> Bool {
        guard let visibleFrame,
              visibleFrame.width > 0,
              visibleFrame.height > 0 else {
            return windowFrame.width < minimumContentSize.width || windowFrame.height < minimumContentSize.height
        }

        let widthLimit = max(visibleFrame.width - 30, minimumContentSize.width)
        let heightLimit = max(visibleFrame.height - 30, minimumContentSize.height)

        return windowFrame.width < minimumContentSize.width ||
            windowFrame.height < minimumContentSize.height ||
            windowFrame.width > widthLimit ||
            windowFrame.height > heightLimit
    }
}
```
