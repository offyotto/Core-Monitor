# Removed Or Replaced Media Assets

## Summary

Website videos, screenshots, and Kernel Panic soundtrack files were removed or replaced as release media moved from older assets to current DMG/site/audio payloads.

## Paths

| Removed path | Removal date(s) | Commit(s) |
| --- | --- | --- |
| `docs/videos/install-walkthrough.mov` | 2026-04-11 | [011232b](../commits/011232b-update-website-install-video.md) |
| `docs/images/install-walkthrough-shot.png` | 2026-04-11 | [a5fd96a](../commits/a5fd96a-restore-install-walkthrough-video-embed.md) |
| `Core-Monitor/KernelPanicAudio/kernelpanic_phase1.mp3` | 2026-04-19 | [608ea0c](../commits/608ea0c-optimize-14-08-release-packaging.md), [4372e29](../commits/4372e29-optimize-14-08-release-packaging.md) |

## What To Remember

- Removal does not always mean the concept disappeared completely; some behavior moved into a narrower owner.
- If resurrecting any of this code, first verify the current product scope, helper trust model, release process, and App Store constraints.
- The complete deleted-path index lists generated-cache removals separately from product-feature removals.
