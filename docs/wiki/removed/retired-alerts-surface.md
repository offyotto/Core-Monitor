# Retired Alerts Screen Surface

## Summary

The old Alerts screen UI was removed while core alert models/evaluation logic remained as legacy or future-facing support code.

## Paths

| Removed path | Removal date(s) | Commit(s) |
| --- | --- | --- |
| `Core-Monitor/AlertsView.swift` | 2026-04-17 | [4e417f6](../commits/4e417f6-remove-alerts-screen-surface.md) |
| `Core-Monitor/AlertsPresentation.swift` | 2026-04-17 | [734d179](../commits/734d179-remove-remaining-alerts-strings.md) |

## What To Remember

- Removal does not always mean the concept disappeared completely; some behavior moved into a narrower owner.
- If resurrecting any of this code, first verify the current product scope, helper trust model, release process, and App Store constraints.
- The complete deleted-path index lists generated-cache removals separately from product-feature removals.
