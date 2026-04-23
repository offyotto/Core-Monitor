# Removed Appcast And Delta Update Feed

## Summary

Sparkle-style appcast and delta downloads were deleted when release distribution shifted toward signed DMG/ZIP artifacts and Homebrew cask metadata.

## Paths

| Removed path | Removal date(s) | Commit(s) |
| --- | --- | --- |
| `Core-Monitor/AppUpdater.swift` | 2026-04-11 | [011232b](../commits/011232b-update-website-install-video.md) |
| `appcast.xml` | 2026-04-11 | [011232b](../commits/011232b-update-website-install-video.md) |
| `downloads/Core-Monitor112100-11250.delta` | 2026-04-11 | [011232b](../commits/011232b-update-website-install-video.md) |

## What To Remember

- Removal does not always mean the concept disappeared completely; some behavior moved into a narrower owner.
- If resurrecting any of this code, first verify the current product scope, helper trust model, release process, and App Store constraints.
- The complete deleted-path index lists generated-cache removals separately from product-feature removals.
