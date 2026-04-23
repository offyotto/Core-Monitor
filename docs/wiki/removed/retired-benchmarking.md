# Removed Benchmark, Leaderboard, And Quality Rating

## Summary

Benchmark and leaderboard surfaces were removed with the old updater payload, reducing scope outside the core monitoring product.

## Paths

| Removed path | Removal date(s) | Commit(s) |
| --- | --- | --- |
| `Core-Monitor/BenchmarkEngine.swift` | 2026-04-11 | [011232b](../commits/011232b-update-website-install-video.md) |
| `Core-Monitor/BenchmarkResult.swift` | 2026-04-11 | [011232b](../commits/011232b-update-website-install-video.md) |
| `Core-Monitor/BenchmarkView.swift` | 2026-04-11 | [011232b](../commits/011232b-update-website-install-video.md) |
| `Core-Monitor/LeaderboardView.swift` | 2026-04-11 | [011232b](../commits/011232b-update-website-install-video.md) |
| `Core-Monitor/QualityRatingEngine.swift` | 2026-04-11 | [011232b](../commits/011232b-update-website-install-video.md) |

## What To Remember

- Removal does not always mean the concept disappeared completely; some behavior moved into a narrower owner.
- If resurrecting any of this code, first verify the current product scope, helper trust model, release process, and App Store constraints.
- The complete deleted-path index lists generated-cache removals separately from product-feature removals.
