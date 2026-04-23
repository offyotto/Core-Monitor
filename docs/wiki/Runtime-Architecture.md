# Runtime Architecture

The runtime is a menu bar utility with a dashboard window. `Core_MonitorApp.swift` installs the application delegate, creates long-lived coordinator state, handles duplicate launches, sets activation policy, installs menu bar items, and opens the dashboard when onboarding or explicit user actions require it.

`AppCoordinator` owns shared app objects such as `SystemMonitor`, `FanController`, menu bar coordination, Touch Bar attachment, and dashboard navigation. SwiftUI surfaces should read from these shared objects rather than creating parallel samplers or independent fan state.

`SystemMonitor` is the telemetry source of truth. It publishes `SystemMonitorSnapshot`, trend series, and lightweight convenience accessors. Dashboard and menu bar surfaces read from the snapshot and history buffers. Detailed process sampling is adaptive and reason-driven to avoid constant expensive enumeration.

Fan control is split: `FanController` decides product behavior and target RPMs, `SMCHelperManager` manages helper install/reachability/XPC, and `smc-helper/main.swift` performs privileged AppleSMC writes after validating clients and input.
