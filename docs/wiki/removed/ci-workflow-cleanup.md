# Removed CI Workflow Experiments

## Summary

Older CodeQL and Objective-C/Xcode workflows were removed while the repository moved toward focused GitHub Actions CI and release workflows.

## Paths

| Removed path | Removal date(s) | Commit(s) |
| --- | --- | --- |
| `.github/workflows/codeql.yml` | 2026-04-08 | [4b3afec](../commits/4b3afec-remove-codeql-workflow.md) |
| `.github/workflows/objective-c-xcode.yml` | 2026-03-27 | [f1be4db](../commits/f1be4db-remove-broken-xcode-workflow.md) |

## What To Remember

- Removal does not always mean the concept disappeared completely; some behavior moved into a narrower owner.
- If resurrecting any of this code, first verify the current product scope, helper trust model, release process, and App Store constraints.
- The complete deleted-path index lists generated-cache removals separately from product-feature removals.
