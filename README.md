<p align="center">
  <img src="./Core-Monitor/Assets.xcassets/AppIcon.appiconset/icon-512.png" alt="Core-Monitor icon" width="180">
</p>

<h1 align="center">Core-Monitor</h1>

<p align="center">
  A native Apple Silicon system monitor for macOS.
</p>

<p align="center">
  <a href="https://apps.apple.com/us/app/core-monitor/id6762558526?mt=12">
    <img src="https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg" alt="Download on the App Store" width="200">
  </a>
</p>

<p align="center">
  <a href="https://github.com/offyotto/Core-Monitor/releases/latest">
    <img src="https://img.shields.io/badge/Download-Latest%20Release-2ea44f?style=for-the-badge" alt="Download latest release">
  </a>
</p>

<p align="center">
  <a href="https://github.com/offyotto/Core-Monitor/releases/latest">Latest release</a>
  ·
  <a href="https://github.com/offyotto/Core-Monitor/releases">All releases</a>
  ·
  <a href="./LICENSE">License</a>
</p>

<p align="center">
  <a href="https://offyotto.github.io/Core-Monitor/">
    <img src="https://img.shields.io/badge/Website-Core--Monitor-8A2BE2?style=flat" alt="Website">
  </a>
  <a href="https://github.com/offyotto/Core-Monitor/releases/latest">
    <img src="https://img.shields.io/badge/Download-latest-brightgreen?style=flat" alt="Download latest">
  </a>
  <a href="./LICENSE">
    <img src="https://img.shields.io/badge/License-GPL--3.0-blue?style=flat" alt="GPL-3.0 license">
  </a>
  <img src="https://img.shields.io/badge/macOS-13%2B-black?style=flat&logo=apple" alt="macOS 13+">
</p>

---

Core-Monitor reads sensor data from the Apple SMC and standard macOS system APIs, then presents it in the menu bar, dashboard, and, on supported hardware, the Touch Bar.

Public builds are available through GitHub Releases and the Mac App Store.

## Install

- Download from the Mac App Store.
- Download the latest release from GitHub.
- Build from source using Xcode.

## UI Preview

<p align="center">
  <img src="./docs/images/ui/overview-2026.png" alt="Core-Monitor overview screen showing CPU, memory, temperature, and power cards." width="900">
</p>

<p align="center">
  <img src="./docs/images/ui/thermals-2026.png" alt="Core-Monitor thermals screen showing CPU and GPU temperature cards with SMC sensor details." width="900">
</p>

<p align="center">
  <img src="./docs/images/ui/menu-bar-2026.png" alt="Core-Monitor menu bar panel showing quick system summary stats and SMC status." width="520">
</p>

## What it monitors

CPU, GPU, memory, battery, thermals, power draw, fan status, and readable sensor data.

## Privacy

Core-Monitor does not require an account. Sensor reads stay local to your Mac.

## Compatibility

- macOS 13 or later
- Apple Silicon is the primary target

## License

GPL-3.0, see [LICENSE](./LICENSE).
