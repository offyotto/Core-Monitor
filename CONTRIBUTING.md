# Contributing to Core-Monitor

Thanks for helping improve Core-Monitor. This repository includes a macOS app, a privileged helper, and a GitHub Pages site, so keep changes focused and verify the exact area you touched.

## Before you start

- Prefer working on a branch instead of committing directly to `main`.
- Keep commits small and scoped.
- Do not mix unrelated app, helper, and website changes unless the change really depends on all three.
- If you edit release assets or website pages, verify the final files in `docs/` and `index.html`.

## Development setup

- Open `Core-Monitor.xcodeproj` in Xcode.
- Build the `Core-Monitor` scheme.
- If you change fan control, also build the `smc-helper` target.
- If you change the website, verify both `index.html` and `docs/index.html`.

## Common checks

Use the smallest check that covers the change:

- App UI or logic: build the `Core-Monitor` scheme.
- Helper changes: build the helper target and confirm the app still launches.
- Website changes: confirm the site files render correctly and assets exist in `docs/`.
- Asset swaps: verify the new file is actually different before committing.

## Code style

- Follow the surrounding Swift style.
- Keep views and controllers easy to read.
- Avoid adding new abstractions unless they remove real duplication.
- Keep user-facing copy direct and accurate.

## Touch Bar work

- Keep Touch Bar widgets compact.
- Test the default widget layout after changes.
- If you add or remove widgets, update the default order and any relevant onboarding text.

## Fan control and helper work

- Do not change the helper contract casually.
- Preserve the signed helper workflow already in the app.
- If you touch privileged helper code, verify the app still builds and the helper bundle is still embedded correctly.

## Pull requests / commits

- Commit the actual behavior change, not formatting-only churn.
- Mention any manual verification you performed.
- If a change affects the website, include the relevant page and asset paths in your summary.

## What to avoid

- Do not commit build products or derived data.
- Do not add recovery or scratch files to the repo.
- Do not rename public bundle identifiers or helper labels unless that is part of the change.

## When in doubt

Prefer the least invasive fix that makes the app correct and keeps the build green.

## Automated edits

- Review generated or automated changes before you commit them.
- Do not submit large copy or code rewrites you did not verify.
- Keep the final diff scoped to the area you actually tested.
