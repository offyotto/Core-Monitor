<p align="center">
  <img src="./Core-Monitor/Assets.xcassets/AppIcon.appiconset/icon-512.png" alt="Core-Monitor icon" width="180">
</p>

<h1 align="center">Core-Monitor</h1>

<p align="center">
  A native system monitor for macOS, built for Apple Silicon Macs.
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
  <img src="https://img.shields.io/badge/macOS-12%2B-black?style=flat&logo=apple" alt="macOS 12+">
</p>

---

Core-Monitor reads sensor data from the Apple SMC and standard macOS system APIs, then presents it in the menu bar, dashboard, and, on supported hardware, the Touch Bar. CPU, GPU, memory, battery, temperatures, power draw, and fan speeds update continuously in the native app.

It is written in Swift and built around `host_statistics`, `IOKit`, and `IOPSCopyPowerSourcesInfo`. Sensor reads stay local to your Mac. The optional fan control helper is the only additional process, and it is only needed if you want write access for fan control.

Public builds are available through GitHub Releases.

## Why Core-Monitor

- **Thermal-first by default.** Core-Monitor is built for people who care about heat, fan behavior, throttling risk, and sustained load more than decorative desktop stats.
- **Monitoring first, helper optional.** Fresh installs start in system-owned cooling. You only need the privileged helper if you explicitly choose a fan mode that writes RPM targets.
- **Readable menu bar defaults.** New installs start with the balanced three-item layout instead of trying to occupy the entire menu bar at once.
- **Local diagnostics, no accounts.** Sensor reads, alert history, and helper diagnostics stay on-device. There are no cloud dashboards, required logins, or telemetry dependencies for core monitoring.
- **Open-source trust surface.** The repo includes helper diagnostics docs, architecture notes, contributor guidance, and a current public-source competitor matrix instead of hiding the hard parts behind marketing copy.

If you want the broader market context, see [`docs/COMPETITOR_MATRIX_2026.md`](./docs/COMPETITOR_MATRIX_2026.md) and [`docs/CORE_MONITOR_AUDIT_2026.md`](./docs/CORE_MONITOR_AUDIT_2026.md).

## Install

Direct download:

- Download [Core-Monitor.zip](https://github.com/offyotto-sl3/Core-Monitor/releases/latest/download/Core-Monitor.zip) from the latest GitHub release.
- Move `Core-Monitor.app` into `/Applications`.

Homebrew:

```bash
brew tap --custom-remote offyotto-sl3/core-monitor https://github.com/offyotto-sl3/Core-Monitor
brew install --cask offyotto-sl3/core-monitor/core-monitor
```

## UI Preview

<p align="center">
  <img src="./docs/images/ui/overview-2026.png" alt="Core-Monitor overview screen showing alert state, monitoring freshness, and CPU and memory load cards." width="900">
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

## Fan control

Fan control is optional and requires a privileged helper called `smc-helper`. If you don't need it, you don't need the helper — everything else works without it.

The helper is bundled at `Core-Monitor.app/Contents/Library/LaunchServices/ventaphobia.smc-helper`, installed to `/Library/PrivilegedHelperTools/ventaphobia.smc-helper` via `SMJobBless`, and registered as a launchd XPC service. The app owns the helper through `SMPrivilegedExecutables`; the helper authorizes the app through its embedded `SMAuthorizedClients` requirement.

**Fan modes:**

| Mode | Behavior |
|------|----------|
| Smart | Temperature + power-aware curve. Blends CPU/GPU temps with system watt draw, scales against a configurable aggressiveness from 0.0 (always minimum) to 3.0 (always maximum). |
| Balanced | Fixed at 60% of the fan's reported maximum. |
| Performance | Fixed at 85%. |
| Max | Fixed at 100%. |
| Manual | You pick the RPM. |
| System | Restores automatic SMC control with `F{n}Md = 0`. |

The Smart curve accounts for system power draw as a temperature boost — at 40 W it adds up to 8°C to the effective temperature before mapping to a fan speed. Fan settings persist across sleep/wake via `NSWorkspace.didWakeNotification`.

**Helper commands** (also usable directly from the terminal):

```text
smc-helper set <fanID> <rpm>   # override fan speed
smc-helper auto <fanID>        # return fan to firmware
smc-helper read <key>          # read any 4-character SMC key
```

Supported SMC value types: `sp78`, `fpe2`, `flt`, `ui8`, `ui16`.

## Touch Bar customization

Core-Monitor includes a Touch Bar layout editor in the app's **Touch Bar** section. Layouts can mix:

- built-in items such as Status, Weather, CPU, Dock, Stats, and Network
- pinned applications
- pinned folders
- custom command widgets

Every item in the active layout is stored in order and rendered in the live preview before you apply changes.

### Built-in widgets

Built-in items are the existing Core-Monitor Touch Bar modules. You can enable or disable them from the built-in list, then reorder them in **Active Items**.

These built-ins keep their normal live behavior:

- Weather continues to use WeatherKit
- Status continues to show Wi-Fi, battery, and clock data
- CPU and Stats items continue to use the current system snapshot
- Dock continues to reflect the compact launcher strip

### Pinning applications

Use **Pin Applications** in the Touch Bar customization panel to add one or more `.app` bundles directly to the Touch Bar.

How it works:

- the picker accepts macOS application bundles
- each selected app is stored by path, display name, and bundle identifier when available
- pinned apps render as compact icon launchers in the Touch Bar
- tapping a pinned app opens that application through `NSWorkspace`

Practical notes:

- pinned apps are meant to be quick launch targets, not live widgets
- app icons are pulled from the app bundle on disk each time the item is rebuilt
- if you move or rename a pinned app after saving it, the stored path may go stale and that launcher may stop working until you re-pin it
- if you pin many apps, the width meter warns when the layout is wider than a full Touch Bar

### Pinning folders

Use **Pin Folders** to add Finder locations to the Touch Bar.

How it works:

- the picker accepts directories only
- each selected folder is stored by path and display name
- pinned folders render as compact launcher buttons just like pinned apps
- tapping a pinned folder opens it in Finder through `NSWorkspace`

Good use cases:

- a project root you open repeatedly
- Downloads, Screenshots, or a working assets folder
- a scripts/tools directory used during development

Folder pinning follows the same persistence rules as app pinning: if the path changes, re-pin it.

### Custom command widgets

The **Custom Widget** form lets you create a simple Touch Bar action backed by your own shell command.

Each custom widget stores:

- a visible title
- an SF Symbol name
- a shell command
- a target width

Current behavior:

- the widget appears as a compact labeled button in the Touch Bar
- tapping it launches `/bin/zsh -lc "<your command>"`
- this is designed for quick actions, scripts, and automations rather than long-running UI

Examples:

```bash
open -a Terminal
```

```bash
open ~/Downloads
```

```bash
shortcuts run "Build Project"
```

```bash
osascript -e 'display notification "Build complete" with title "Core-Monitor"'
```

Important caveats:

- commands run with the app's user permissions
- command output is not embedded back into the Touch Bar
- if a command depends on shell setup files, test it directly in `zsh -lc` form first
- keep commands short and predictable; the current implementation is an action launcher, not a terminal emulator

### Rearranging the layout

The **Active Items** list is the source of truth for Touch Bar order.

From that list you can:

- move any item up
- move any item down
- remove any item

This applies equally to:

- built-in widgets
- pinned apps
- pinned folders
- custom command widgets

The live preview strip above the editor reflects the current order and item widths immediately.

### Presets and persistence

Presets still exist, but they now apply structured item layouts instead of the older widget-only stack.

Touch Bar layouts are stored in user defaults and older widget-only configurations are migrated forward into the richer item model automatically. Existing users should keep their built-in layouts, then add pinned apps, folders, or custom widgets on top.

### Current limits

The new customization system is intentionally practical rather than unlimited. Right now:

- reordering is button-driven, not drag-and-drop
- pinned apps and folders are launcher buttons, not live mini-views
- custom widgets launch commands but do not yet show dynamic script output
- very wide layouts can still exceed the physical Touch Bar width, so use the width meter as the guardrail

## Installation

**Download:** Get the latest public build from [Releases](https://github.com/offyotto-sl3/Core-Monitor/releases/latest) and move it to `/Applications`.

**Build from source:**

```bash
git clone https://github.com/offyotto-sl3/Core-Monitor.git
```

Open the project in Xcode, select the `Core-Monitor` scheme, and build. The `smc-helper` is a separate target. You can build and run Core-Monitor without it, but fan control will not be available.

## Compatibility

- macOS 12 or later
- Apple Silicon is the primary target; Intel Macs are not part of the current test path
- Fan control requires macOS 13+ (XPC with code-signing requirements)
- Core-Monitor is not available on the Mac App Store

## Privacy

Core-Monitor does not include analytics, ad SDKs, or account features. Sensor reads stay local to your Mac, and the optional fan helper only communicates with the local privileged XPC service.

## WeatherKit

The optional Touch Bar weather item uses Apple WeatherKit and location access to show local conditions. Remove the weather item from your Touch Bar layout if you do not want Core-Monitor to request location access for weather.

## License

GPL-3.0 — see [LICENSE](./LICENSE).
