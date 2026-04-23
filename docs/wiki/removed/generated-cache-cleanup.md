# Removed Generated Build Cache

## Summary

Tracked Xcode DerivedData, module cache, SDK stat cache, and build-output files were removed because they are generated artifacts and should not live in source control.

## Paths

| Removed path | Removal date(s) | Commit(s) |
| --- | --- | --- |
| `.deriveddata/CompilationCache.noindex/generic/lock` | 2026-04-07 | [1705aa1](../commits/1705aa1-add-debug-mode-and-remove-build-cache.md) |
| `.deriveddata/ModuleCache.noindex/modules.timestamp` | 2026-04-07 | [1705aa1](../commits/1705aa1-add-debug-mode-and-remove-build-cache.md) |

## What To Remember

- Removal does not always mean the concept disappeared completely; some behavior moved into a narrower owner.
- If resurrecting any of this code, first verify the current product scope, helper trust model, release process, and App Store constraints.
- The complete deleted-path index lists generated-cache removals separately from product-feature removals.
