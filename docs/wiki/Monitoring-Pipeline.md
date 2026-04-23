# Monitoring Pipeline

`SystemMonitor.swift` samples CPU, performance/efficiency cores, memory, disk, battery, power, network, fan speed, temperatures, SMC values, volume, brightness, thermal state, and top processes. The output is folded into `SystemMonitorSnapshot` and trend series in `MonitoringSnapshot.swift`.

Fast interactive monitoring uses a roughly one-second cadence. Basic/background mode backs off. Supplemental data such as disk stats and controls uses refresh gates so slower or heavier reads do not run every sample.

Important APIs include `host_statistics`, `host_processor_info`, `vm_statistics64`, `IOPSCopyPowerSourcesInfo`, IORegistry queries for AppleSmartBattery, sysctl, IOKit AppleSMC calls, CoreAudio volume APIs, and process enumeration helpers.

All monitoring should remain local. Avoid adding telemetry, network reporting, or account dependencies to the core pipeline.
