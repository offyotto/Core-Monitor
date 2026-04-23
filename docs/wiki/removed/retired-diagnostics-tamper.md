# Removed Diagnostics And Tamper Experiments

## Summary

Dashboard launch diagnostics and SMC tamper detector files were removed as helper health, diagnostics export, and service alerts became the support path.

## Paths

| Removed path | Removal date(s) | Commit(s) |
| --- | --- | --- |
| `Core-Monitor/DashboardLaunchDiagnostics.swift` | 2026-04-16 | [5dc29ed](../commits/5dc29ed-add-privacy-controls-and-refine-core-monitor-presentation.md) |
| `Core-Monitor/SMCTamperDetector.swift` | 2026-04-16 | [1ff7bdb](../commits/1ff7bdb-refine-helper-health-states-and-service-alerts.md) |

## What To Remember

- Removal does not always mean the concept disappeared completely; some behavior moved into a narrower owner.
- If resurrecting any of this code, first verify the current product scope, helper trust model, release process, and App Store constraints.
- The complete deleted-path index lists generated-cache removals separately from product-feature removals.
