# Developer Workflow

Before editing, read `docs/ARCHITECTURE.md`, relevant feature files, and nearby tests. Prefer the smallest owner of behavior, add focused tests, build, run relevant tests, and inspect user-visible UI directly.

Do not hide broad refactors inside high-risk files. If a change crosses monitoring, helper, fan control, and UI boundaries, document the reason in the commit message and worklog.

Standard test command: `xcodebuild -project Core-Monitor.xcodeproj -scheme Core-Monitor -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test`.
