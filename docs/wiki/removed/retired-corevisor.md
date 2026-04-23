# Removed CoreVisor And Virtualization Support

## Summary

CoreVisor/QEMU assets and views were removed as the product narrowed back to Apple Silicon monitoring, thermals, menu bar, Touch Bar, and fan control.

## Paths

| Removed path | Removal date(s) | Commit(s) |
| --- | --- | --- |
| `Core-Monitor/CoreVisorManager.swift` | 2026-03-29 | [b20fd3e](../commits/b20fd3e-refresh-readme-media-and-system-monitor-branding.md) |
| `Core-Monitor/CoreVisorSetupView.swift` | 2026-03-29 | [b20fd3e](../commits/b20fd3e-refresh-readme-media-and-system-monitor-branding.md) |
| `EmbeddedQEMU/README.md` | 2026-03-29 | [3651f98](../commits/3651f98-remove-corevisor-and-virtualization-support.md) |
| `EmbeddedQEMU/qemu-system-aarch64` | 2026-03-29 | [3651f98](../commits/3651f98-remove-corevisor-and-virtualization-support.md) |

## What To Remember

- Removal does not always mean the concept disappeared completely; some behavior moved into a narrower owner.
- If resurrecting any of this code, first verify the current product scope, helper trust model, release process, and App Store constraints.
- The complete deleted-path index lists generated-cache removals separately from product-feature removals.
