# Removed Companion Launchpad And Glass UI Experiments

## Summary

Early companion launchpad and glass/motion files were deleted before the current dashboard/menu bar architecture stabilized.

## Paths

| Removed path | Removal date(s) | Commit(s) |
| --- | --- | --- |
| `Core-Monitor/CompanionLaunchpadManager.swift` | 2026-03-15 | [61a73aa](../commits/61a73aa-commit-ig.md) |
| `Core-Monitor/LaunchpadGlassView.swift` | 2026-03-15 | [61a73aa](../commits/61a73aa-commit-ig.md) |
| `Core-Monitor/MotionEffects.swift` | 2026-03-15 | [61a73aa](../commits/61a73aa-commit-ig.md) |

## What To Remember

- Removal does not always mean the concept disappeared completely; some behavior moved into a narrower owner.
- If resurrecting any of this code, first verify the current product scope, helper trust model, release process, and App Store constraints.
- The complete deleted-path index lists generated-cache removals separately from product-feature removals.
