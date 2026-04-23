# Removed Old Topbar Extension

## Summary

The old widget-extension style topbar project was removed during repository cleanup, leaving the active Core-Monitor app and its Pock/Touch Bar integrations.

## Paths

| Removed path | Removal date(s) | Commit(s) |
| --- | --- | --- |
| `topbar/AppIntent.swift` | 2026-03-27 | [3252194](../commits/3252194-clean-repo-and-keep-only-active-core-monitor-project.md) |
| `topbar/topbar.swift` | 2026-03-27 | [3252194](../commits/3252194-clean-repo-and-keep-only-active-core-monitor-project.md) |
| `topbar/topbarBundle.swift` | 2026-03-27 | [3252194](../commits/3252194-clean-repo-and-keep-only-active-core-monitor-project.md) |
| `topbar/topbarControl.swift` | 2026-03-27 | [3252194](../commits/3252194-clean-repo-and-keep-only-active-core-monitor-project.md) |

## What To Remember

- Removal does not always mean the concept disappeared completely; some behavior moved into a narrower owner.
- If resurrecting any of this code, first verify the current product scope, helper trust model, release process, and App Store constraints.
- The complete deleted-path index lists generated-cache removals separately from product-feature removals.
