<p align="center">
  <img src="./Core-Monitor/Assets.xcassets/AppIcon.appiconset/icon-512.png" alt="Core-Monitor icon" width="180">
</p>

<h1 align="center">Core-Monitor</h1>

<p align="center">
  Hardware monitoring, fan control, menu bar stats, sensor readouts, and Touch Bar utilities for macOS.
</p>

<p align="center">
  Native Swift utility for Apple Silicon Macs with optional privileged fan control.
</p>

<p align="center">
  <a href="https://github.com/offyotto-sl3/Core-Monitor/releases/latest">
    <img src="https://img.shields.io/badge/Download-Latest%20Release-2ea44f?style=for-the-badge" alt="Download latest release">
  </a>
</p>

<p align="center">
  <a href="https://github.com/offyotto-sl3/Core-Monitor/releases/latest">Latest release</a>
  ·
  <a href="https://github.com/offyotto-sl3/Core-Monitor/releases">All releases</a>
  ·
  <a href="./LICENSE">License</a>
</p>

<p align="center">
  <a href="https://offyotto-sl3.github.io/Core-Monitor/">
    <img src="https://img.shields.io/badge/Website-Core--Monitor-8A2BE2?style=flat">
  </a>
  <a href="https://github.com/offyotto-sl3/Core-Monitor/releases/latest">
    <img src="https://img.shields.io/badge/Download-latest-brightgreen?style=flat">
  </a>
  <a href="./LICENSE">
    <img src="https://img.shields.io/badge/License-GPL--3.0-blue?style=flat">
  </a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-12%2B-black?style=flat&logo=apple">
</p>

## Overview

Core-Monitor is a native macOS utility written in Swift. It combines hardware monitoring, menu bar stats, Touch Bar support, benchmarking, and optional fan control in one app.

This repository currently targets direct distribution and local builds. Some features require elevated privileges, and some Touch Bar functionality uses macOS-specific implementation details that are not suitable for every release channel.

## Features

- CPU, GPU, memory, battery, temperature, power, and voltage monitoring
- Menu bar stats and quick system readouts
- Fan RPM monitoring
- Manual fan control through a privileged helper
- Touch Bar widgets and utility views
- Native SwiftUI/AppKit macOS app

## Privacy

Core-Monitor is built with a simple position: privacy is a fundamental human right.

This project is open source so the code can be inspected directly. That matters for a system utility that reads hardware state, surfaces sensor data, and can optionally talk to a privileged helper for fan control.

Privacy expectations for the project:

- No telemetry
- No analytics
- No ad tech
- No account requirement
- No subscription gate for the core utility

Core-Monitor is designed to run locally on your Mac and focus on monitoring, menu bar stats, Touch Bar tools, benchmarking, and fan control without collecting usage data about you.

## Installation

### Download

- Download the latest build from [Releases](https://github.com/offyotto-sl3/Core-Monitor/releases/latest)
- Move the app to `/Applications`
- Launch `Core-Monitor`

### Build from Source

```bash
git clone https://github.com/offyotto-sl3/Core-Monitor.git
```

- Open the project in Xcode
- Select the `Core-Monitor` scheme
- Build and run

## Privileged Helper

Monitoring, menu bar stats, and most UI features do not require administrator privileges.

Fan write access is handled by `smc-helper`, a privileged helper that talks to the Apple SMC over IOKit. The app installs and communicates with the helper over XPC when fan control needs elevated access.

Supported helper commands:

- `set <fanID> <rpm>` sets a fan target RPM
- `auto <fanID>` returns a fan to automatic control
- `read <key>` reads a 4-character SMC key

Internally, the helper:

- opens the `AppleSMC` service
- communicates with the SMC keyspace through IOKit
- switches fan mode between automatic and manual when required
- reads common sensor and fan-related SMC values

Supported value formats include:

- `sp78`
- `fpe2`
- `ui8`
- `ui16`
- `flt`

## Compatibility

- macOS 12 or later
- Apple Silicon is the primary target
- Intel support is partial and may differ by feature
- Fan control depends on helper installation and hardware behavior

## Notes

- This project is not currently positioned for the Mac App Store.
- Signed and unsigned builds may expose different feature sets depending on distribution strategy.
- Fan control and Touch Bar features should be treated separately when preparing public release builds.
- Feature availability may vary by build type and signing setup.

## Why This Exists

Core-Monitor was built as an all-in-one alternative for users who want system stats, menu bar access, Touch Bar utilities, benchmarking, and fan control in a single native macOS app.

## License

GPL-3.0
