# Troubleshooting

If the app runs but menu bar items are missing, check macOS System Settings -> Menu Bar before assuming launch failed. If first launch is invisible, inspect welcome-guide state and activation policy.

If fan writes fail, export Helper Diagnostics from the System tab, check whether the helper is missing/reachable/unreachable, verify signing requirements, and confirm the installed helper/LaunchDaemon paths match the current app build.

If Weather fails, check WeatherKit entitlement capability and whether the user has explicitly granted location access. If sensors are missing, distinguish unsupported SMC keys from sampling failures.
