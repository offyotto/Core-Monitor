# Privileged Helper

The helper is `smc-helper`, installed as `ventaphobia.smc-helper` under `/Library/PrivilegedHelperTools` with a LaunchDaemon plist. The app bundles it under `Contents/Library/LaunchServices` and blesses it through ServiceManagement.

`SMCHelperManager` is app-side. It detects missing/stale installs, blesses or repairs, probes XPC reachability, executes fan commands, reads SMC values, and exposes status messages.

`smc-helper/main.swift` is helper-side. It can run command-line commands such as `set`, `auto`, and `read`, or run as an NSXPC service. It opens AppleSMC, validates inputs, writes fan mode/target keys, and exposes control metadata.

The helper is optional. Documentation and UI should keep the monitoring-without-helper path clear.
