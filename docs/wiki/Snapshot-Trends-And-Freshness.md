# Snapshot Trends And Freshness

`MonitoringSnapshot.swift` defines the shared data model, trend ranges, freshness states, trend points, process activity snapshots, and top-process snapshot containers.

The app uses freshness classification to distinguish waiting, live, delayed, and stale samples. That matters because a system monitor is worse than useless when stale numbers look live. Dashboard and menu bar surfaces should surface last-update and cadence context when telemetry lags.

Trend series cover short and longer windows so users can interpret sustained load instead of only a point-in-time reading. CPU temperature, GPU temperature, total power, primary fan speed, memory usage, swap usage, and network throughput all fit the same history model.

When adding a metric, prefer adding it to `SystemMonitorSnapshot` and the trend model rather than threading individual properties through each UI.
