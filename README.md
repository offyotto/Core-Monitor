<p align="center">
  <img src="./Core-Monitor/Assets.xcassets/AppIcon.appiconset/icon-512.png" alt="Core-Monitor icon" width="180">
</p>

<h1 align="center">Core-Monitor</h1>

<p align="center">
  A system monitor for Apple Silicon Macs. It sits in your menu bar, reads SMC data, and stays out of your way.
</p>

<p align="center">
  <a href="https://github.com/offyotto-sl3/Core-Monitor/releases/latest">
    <img src="https://img.shields.io/badge/Download-Latest%20Release-2ea44f?style=for-the-badge" alt="Download latest release">
  </a>
</p>

<p align="center">
  <strong>Core-Monitor v12 is officially notarized by Apple.</strong>
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
  <img src="https://img.shields.io/badge/macOS-12%2B-black?style=flat&logo=apple" alt="macOS 12+">
</p>

---

Core Monitor reads sensor data directly from the Apple SMC and surfaces it in your menu bar and dashboard. CPU, GPU, memory, battery, temperatures, power draw, fan speeds, network throughput, and disk I/O — all updated every second via IOKit.

It is written in Swift, built around `host_statistics`, `IOKit`, and `IOPSCopyPowerSourcesInfo`. No daemons, no background services, no network connections. The only exception is the fan control helper, which is optional and described below.

Version 12 is the officially notarized release. The distributed app is signed and notarized for macOS Gatekeeper, so the standard download-and-run experience is as smooth as possible on supported systems.

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

**CPU** — total load, and on Apple Silicon, P-core and E-core utilization independently, read via `host_processor_info` per logical core.

**GPU** — temperature from SMC keys `Tg0e`, `Tg0f`, `Tg0m`, and others depending on your chip.

**Memory** — used/wired/compressed pages via `vm_statistics64`, with a pressure level derived from the ratio of available to total physical memory.

**Battery** — charge, cycle count, health percentage, voltage, amperage, and power draw from `AppleSmartBattery` in the IO registry. Time remaining comes from `IOPSCopyPowerSourcesInfo`.

**Thermals** — CPU die temperature from `TC0P`, `Tp09`, `TCXC`, and fallbacks, GPU from `Tg0e`/`Tg0f`. You can also browse all readable SMC keys from the sensor explorer.

**Network** — inbound and outbound throughput per second via `getifaddrs`, excluding loopback.

**Disk** — read and write throughput from IOKit's `kIOMediaClass` statistics.

## Fan control

Fan control is optional and requires a privileged helper called `smc-helper`. If you don't need it, you don't need the helper — everything else works without it.

The helper is installed to `/Library/PrivilegedHelperTools/ventaphobia.smc-helper` via `SMJobBless` and runs as a persistent XPC service. The main app connects over a Mach service with a code-signing requirement; it validates the helper's path, ownership, permissions, and `SecStaticCode` signature before connecting.

**Fan modes:**

| Mode | Behavior |
|------|----------|
| Smart | Temperature + power-aware curve. Blends CPU/GPU temps with system watt draw, scales against a configurable aggressiveness from 0.0 (always minimum) to 3.0 (always maximum). |
| Silent | Delegates entirely to the firmware's automatic curve. |
| Balanced | Fixed at 60% of the fan's reported maximum. |
| Performance | Fixed at 85%. |
| Max | Fixed at 100%. |
| Manual | You pick the RPM. |
| System | Restores automatic SMC control with `F{n}Md = 0`. |

The Smart curve accounts for system power draw as a temperature boost — at 40 W it adds up to 8°C to the effective temperature before mapping to a fan speed. Fan settings persist across sleep/wake via `NSWorkspace.didWakeNotification`.

**Helper commands** (also usable directly from the terminal):
smc-helper set <fanID> <rpm>   # override fan speed
smc-helper auto <fanID>        # return fan to firmware
smc-helper read <key>          # read any 4-character SMC key
Supported SMC value types: `sp78`, `fpe2`, `flt`, `ui8`, `ui16`.

## Installation

**Download:** Get the latest build from [Releases](https://github.com/offyotto-sl3/Core-Monitor/releases/latest) and move it to `/Applications`.

The v12 release is officially notarized, so it should open normally on supported macOS versions without extra Gatekeeper friction.

**Build from source:**

```bash
git clone https://github.com/offyotto-sl3/Core-Monitor.git
```

Open the project in Xcode, select the `Core-Monitor` scheme, and build. The `smc-helper` is a separate target. You can build and run Core Monitor without it — fan control simply won't be available.

## Compatibility

- macOS 12 or later
- Apple Silicon is the primary target; Intel Macs are not tested
- Fan control requires macOS 13+ (XPC with code-signing requirements)
- v12 is officially notarized by Apple
- Core Monitor is not available on the Mac App Store

## Privacy

Core Monitor makes no network connections except to check for updates via Sparkle, which you can trigger manually. No telemetry, no analytics, no account. All sensor reads are local IOKit calls. The source is here if you want to read it.

## License

GPL-3.0 — see [LICENSE](./LICENSE).
