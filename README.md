# Core Monitor: Monitor thermals, power, memory, alerts, and fan state on Apple silicon

## Overview

Core Monitor is a native macOS app for monitoring CPU, GPU, memory, battery, power, disk, network, thermals, and fan state on Apple silicon.
It presents live readings in a dashboard and menu bar, keeps short trend histories, and can raise local alerts when thresholds are crossed.

Monitoring works without elevated access.
If you choose a fan-control mode that writes SMC values, the app can install and communicate with a privileged helper.

The app is written in Swift and built on macOS APIs including `host_statistics`, `host_processor_info`, `IOKit`, `IOPSCopyPowerSourcesInfo`, `SMAppService`, and `SMJobBless`.

## Requirements

- macOS 12 or later
- Apple silicon is the primary target
- A signed build is required to validate the full helper-backed fan-control path end to end

## Monitoring Capabilities

Core Monitor includes the following monitoring surfaces:

- CPU usage, including performance-core and efficiency-core split when available
- GPU temperature and power readings when available on the current Mac
- Memory usage, memory pressure, compressed memory, page activity, and swap usage
- Battery charge, health, cycle count, runtime, voltage, current, temperature, and power draw
- Total system power, CPU power, GPU power, SSD temperature, disk usage, network throughput, and fan RPM
- macOS thermal state, data freshness state, and rolling 1-minute, 5-minute, and 15-minute trend windows

## Alerts

Core Monitor evaluates alerts locally from the same snapshot used by the dashboard and menu bar.

Alert rules can cover:

- CPU and GPU temperature
- macOS thermal pressure
- CPU usage
- memory pressure
- swap growth
- battery temperature
- battery health
- low battery while discharging
- SMC availability
- helper reachability
- fan safety conditions

Desktop notifications are optional.
Alert history and active state remain available inside the app even when notifications are disabled.

## Fan Control

Core Monitor starts in `System` mode, which leaves cooling under the firmware's automatic curve.

The following modes are available:

| Mode | Behavior |
| --- | --- |
| `System` | Restores firmware-controlled fan behavior. |
| `Silent` | Keeps monitoring active while leaving the firmware curve in charge. |
| `Smart` | Blends thermal readings with system power draw and adjusts fan targets while the app runs. |
| `Balanced` | Writes a moderate fixed fan target. |
| `Performance` | Writes a higher fixed fan target for sustained load. |
| `Max` | Writes the maximum available fan target. |
| `Manual` | Writes a fixed RPM target. |
| `Custom` | Applies a saved temperature curve with optional power-based boost and smoothing. |

`Smart`, `Balanced`, `Performance`, `Max`, `Manual`, and `Custom` require the privileged helper.
`System` and `Silent` do not require ongoing fan writes.

For support and helper-state exports, see [docs/HELPER_DIAGNOSTICS.md](./docs/HELPER_DIAGNOSTICS.md).

## Optional Features

Core Monitor also includes:

- menu bar configuration with visibility presets
- Touch Bar customization on supported Macs
- an optional WeatherKit-powered weather widget
- privacy controls that can disable process insights and redact app names from local alert history
- helper diagnostics export for support and bug reports

The weather widget only needs location access after you choose to enable live weather.

## Install

### Direct Download

Download the latest release from GitHub Releases:

- [Latest release](https://github.com/offyotto-sl3/Core-Monitor/releases/latest)
- [Core-Monitor.zip](https://github.com/offyotto-sl3/Core-Monitor/releases/latest/download/Core-Monitor.zip)

Move `Core-Monitor.app` to `/Applications`.

### Homebrew

```bash
brew install --cask https://raw.githubusercontent.com/offyotto-sl3/Core-Monitor/main/Casks/core-monitor.rb
```

## Build and Test

Build:

```bash
xcodebuild -project Core-Monitor.xcodeproj -scheme Core-Monitor -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

Test:

```bash
xcodebuild -project Core-Monitor.xcodeproj -scheme Core-Monitor -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
```

You can build and run the app without installing the helper.
In that configuration, monitoring, alerts, and the dashboard remain available, but helper-backed fan control will not.

## Repository Guide

- [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md): app shell, monitoring pipeline, alerts stack, helper boundary, and UI ownership
- [CONTRIBUTING.md](./CONTRIBUTING.md): contributor workflow, verification expectations, and helper-safety rules
- [docs/HELPER_DIAGNOSTICS.md](./docs/HELPER_DIAGNOSTICS.md): helper diagnostics export format and privacy notes
- [RELEASING.md](./RELEASING.md): signing, notarization, and release workflow
- [docs/CORE_MONITOR_AUDIT_2026.md](./docs/CORE_MONITOR_AUDIT_2026.md): current product audit and direction
- [docs/COMPETITOR_MATRIX_2026.md](./docs/COMPETITOR_MATRIX_2026.md): positioning and competitor analysis

## Contributing

Before contributing, read [CONTRIBUTING.md](./CONTRIBUTING.md).

If a change touches helper install, signing, or fan control, also read [docs/HELPER_DIAGNOSTICS.md](./docs/HELPER_DIAGNOSTICS.md).

## License

GPL-3.0.
See [LICENSE](./LICENSE).
