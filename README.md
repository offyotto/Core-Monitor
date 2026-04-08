<p align="center">
  <img src="./Core-Monitor/Assets.xcassets/AppIcon.appiconset/icon-512.png" alt="Core-Monitor icon" width="180">
</p>

<h1 align="center">Core-Monitor</h1>

<p align="center">
  Core-Monitor helps you keep an eye on your Mac’s hardware. It can show live system stats in the menu bar and, if you want, it can also control your fans.
</p>

<p align="center">
  Core-Monitor is built for Apple Silicon Macs and written in Swift.
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
    <img src="https://img.shields.io/badge/Website-Core--Monitor-8A2BE2?style=flat" alt="Website">
  </a>
  <a href="https://github.com/offyotto-sl3/Core-Monitor/releases/latest">
    <img src="https://img.shields.io/badge/Download-latest-brightgreen?style=flat" alt="Download latest">
  </a>
  <a href="./LICENSE">
    <img src="https://img.shields.io/badge/License-GPL--3.0-blue?style=flat" alt="GPL-3.0 license">
  </a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-12%2B-black?style=flat&logo=apple" alt="macOS 12+">
</p>

## Overview

Core-Monitor is a macOS utility for hardware monitoring, menu bar stats, and optional fan control. It is built in Swift and designed primarily for Apple Silicon Macs.

## Features

- Live CPU monitoring
- GPU monitoring
- Memory usage monitoring
- Battery status monitoring
- Temperature monitoring
- Power usage monitoring
- Voltage monitoring
- Fan speed monitoring
- Optional fan control
- Menu bar stats
- Touch Bar support

## Privacy

Your privacy matters.

Core-Monitor is open source, which means you can inspect the code yourself and see how it works.

Core-Monitor does not:

- collect your data
- send usage data anywhere
- show ads
- require an account
- require a subscription for the core utility

## Installation

### Download

- Download Core-Monitor from [Releases](https://github.com/offyotto-sl3/Core-Monitor/releases/latest)
- Move the app to your `/Applications` folder
- Open Core-Monitor

### Build from Source

```bash
git clone https://github.com/offyotto-sl3/Core-Monitor.git
```

- Open the project in Xcode
- Select the `Core-Monitor` scheme
- Build and run the app

## Privileged Helper

Core-Monitor can optionally control your fans, but that requires a privileged helper.

The helper is called `smc-helper`. It communicates with the Apple SMC through IOKit.

Supported helper commands:

- `set <fanID> <rpm>` sets a fan speed
- `auto <fanID>` returns a fan to automatic control
- `read <key>` reads a 4-character SMC key

The helper can read common fan and sensor values in these formats:

- `sp78`
- `fpe2`
- `ui8`
- `ui16`
- `flt`

## Compatibility

- macOS 12 or later
- Apple Silicon is the primary target
- Intel Macs may work, but support is not guaranteed
- Fan control depends on the helper and your Mac’s hardware

## Notes

- Core-Monitor is not currently available on the Mac App Store
- Signed and unsigned builds may expose different features
- Fan control and Touch Bar support may vary between builds
- Feature availability may depend on signing and distribution setup

## License

Core-Monitor is licensed under the GPL-3.0 license.
