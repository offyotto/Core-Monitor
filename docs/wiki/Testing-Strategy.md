# Testing Strategy

The macOS test target covers helper diagnostics, alert evaluation, fan presets, dashboard layout, weather, menu bar settings, top process sampling, launch environment, single-instance policy, formatters, disk stats refresh, localization/platform copy, and Touch Bar customization.

Run the full suite with `xcodebuild -project Core-Monitor.xcodeproj -scheme Core-Monitor -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test`.

For high-risk edits, add focused tests near the owner: helper trust, fan curve validation, startup/onboarding state, weather permission gating, menu bar reachability, and sampling policy.
