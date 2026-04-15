<p align="center">
  <img src="./Core-Monitor/Assets.xcassets/AppIcon.appiconset/icon-512.png" alt="Core-Monitor icon" width="180">
</p>

<h1 align="center">Core-Monitor</h1>

<p align="center">
  Native Apple Silicon monitoring with readable menu bar telemetry, local alerts, and SMC-backed fan control.
</p>

<p align="center">
  <a href="https://github.com/offyotto-sl3/Core-Monitor/releases/latest/download/Core-Monitor.zip">
    <img src="https://img.shields.io/badge/Download-Latest%20Zip-2ea44f?style=for-the-badge" alt="Download latest release zip">
  </a>
</p>

<p align="center">
  <strong>Public releases are intended to ship signed, notarized, and ready for direct download outside the App Store.</strong>
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
  <a href="https://github.com/offyotto-sl3/Core-Monitor/releases/latest/download/Core-Monitor.zip">
    <img src="https://img.shields.io/badge/Download-latest-brightgreen?style=flat" alt="Download latest">
  </a>
  <a href="./LICENSE">
    <img src="https://img.shields.io/badge/License-GPL--3.0-blue?style=flat" alt="GPL-3.0 license">
  </a>
  <img src="https://img.shields.io/badge/macOS-12%2B-black?style=flat&logo=apple" alt="macOS 12+">
</p>

---

Core Monitor reads sensor data directly from the Apple SMC and surfaces it in your menu bar and dashboard. CPU, GPU, memory, battery, temperatures, power draw, and fan speeds update every second via IOKit.

It is written in Swift, built around `host_statistics`, `IOKit`, and `IOPSCopyPowerSourcesInfo`. No updater, no telemetry, and no cloud alerting. Disk, network, and process activity sampling stay local on your Mac. The only extra process is the fan control helper, which is optional and described below.

The product direction is now explicit: Core-Monitor is being rebuilt around one job, not ten. It should be the most trustworthy Apple Silicon thermal command center for people who care about heat, sustained performance, and keeping their menu bar readable under load.

## Product identity

- **Hook:** Monitor heat, catch trouble early, and control your fans without turning your menu bar into noise.
- **Primary users:** developers, creators, gamers, emulator users, and power users pushing Apple Silicon laptops or desktops for long sessions.
- **Unfair advantages:** open-source transparency, native SwiftUI UI, local alerts, and a clearer fan-control trust story than most free alternatives.

The concrete roadmap and brutal audit live here:

- [2026 audit and reinvention plan](./docs/CORE_MONITOR_AUDIT_2026.md)
- [Release and notarization playbook](./RELEASING.md)

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

## Alerts

Core Monitor now includes a local alerts engine that runs off the same monitor snapshot used by the dashboard and menu bar. Alerts cover CPU and GPU temperature, macOS thermal pressure, CPU usage, memory pressure, swap growth, fan safety, battery temperature, battery health, low battery while discharging, SMC availability, and helper availability.

- Desktop notifications are optional. In-app alert history and active alert state continue to work even if you disable banners.
- Presets (`Default`, `Quiet`, `Performance`, and `Aggressive Thermal Safety`) change thresholds, debounce, and repeat timing in one step.
- CPU and memory alerts include top-process context so you can see likely culprits without building per-process rules.
- `Overall Thermal` uses `ProcessInfo.processInfo.thermalState`, which reflects macOS thermal pressure instead of a guessed package sensor.

## Fan control

Fan control is optional and requires a privileged helper called `smc-helper`. If you don't need it, you don't need the helper — everything else works without it.

The helper is bundled at `Core-Monitor.app/Contents/Library/LaunchServices/ventaphobia.smc-helper`, installed to `/Library/PrivilegedHelperTools/ventaphobia.smc-helper` via `SMJobBless`, and registered as a launchd XPC service. The app owns the helper through `SMPrivilegedExecutables`; the helper authorizes the app through its embedded `SMAuthorizedClients` requirement.

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

## Touch Bar customization

Core Monitor includes a full Touch Bar layout editor in the app's **Touch Bar** section. The editor is no longer limited to toggling a fixed set of built-in widgets. A layout can now mix:

- built-in widgets such as Status, Weather, CPU, Dock, Stats, and Network
- pinned applications
- pinned folders
- custom command widgets

Every item in the active layout is stored in order and rendered live in the Touch Bar preview before you apply or rearrange anything else.

### Built-in widgets

Built-in widgets are the existing Core Monitor Touch Bar modules. You can enable or disable them from the built-in widget list and then reorder them from the **Active Items** section.

These built-ins keep their normal live behavior:

- Weather continues to use WeatherKit
- Status continues to show Wi-Fi, battery, and clock data
- CPU/Stats widgets continue to use the current system snapshot
- Dock continues to reflect the compact launcher strip

### Pinning applications

Use **Pin Applications** in the Touch Bar customization panel to add one or more `.app` bundles directly to the Touch Bar.

How it works:

- the picker accepts macOS application bundles
- each selected app is stored by path, display name, and bundle identifier when available
- pinned apps render as compact icon launchers in the Touch Bar
- tapping a pinned app opens that application through `NSWorkspace`

Practical notes:

- pinned apps are meant to be fast launch targets, not full live widgets
- app icons are pulled from the app bundle on disk each time the item is rebuilt
- if you move or rename a pinned app after saving it, the stored path may go stale and that launcher may stop working until you re-pin it
- if you pin many apps, the estimated width meter in the customization panel will warn when your layout is wider than a full Touch Bar

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

- the widget renders as a compact labeled button in the Touch Bar
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
osascript -e 'display notification "Build complete" with title "Core Monitor"'
```

Important caveats:

- commands run with the app's user permissions
- command output is not embedded back into the Touch Bar
- if a command depends on shell setup files, test it directly in `zsh -lc` form first
- keep commands short and deterministic; the current implementation is an action launcher, not a terminal emulator

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

Presets still exist, but they now apply as structured item layouts instead of the older widget-only stack.

Your Touch Bar layout is persisted in user defaults and now migrates older widget-only configurations forward into the richer item model automatically. Existing users should keep their built-in widget layouts, and then add pinned apps, folders, or custom widgets on top.

### Current limits

The new customization system is intentionally practical rather than unlimited. Right now:

- reordering is button-driven, not drag-and-drop
- pinned apps and folders are launcher buttons, not live mini-views
- custom widgets launch commands but do not yet show dynamic script output
- very wide layouts can still exceed the physical Touch Bar width, so use the width meter as the guardrail

## Installation

**Direct download:** Get the latest notarized zip from [Direct Download](https://github.com/offyotto-sl3/Core-Monitor/releases/latest/download/Core-Monitor.zip) and move `Core-Monitor.app` to `/Applications`.

**GitHub release page:** [Latest Release Notes](https://github.com/offyotto-sl3/Core-Monitor/releases/latest)

**Homebrew:**

```bash
brew install --cask https://raw.githubusercontent.com/offyotto-sl3/Core-Monitor/main/Casks/core-monitor.rb
```

**Build from source:**

```bash
git clone https://github.com/offyotto-sl3/Core-Monitor.git
```

Open the project in Xcode, select the `Core-Monitor` scheme, and build. The `smc-helper` is a separate target. You can build and run Core Monitor without it — fan control simply won't be available.

For release automation, signing, notarization, and distribution channels, use [RELEASING.md](./RELEASING.md).

## Compatibility

- macOS 12 or later
- Apple Silicon is the primary target; Intel Macs are not tested
- Fan control requires macOS 13+ (XPC with code-signing requirements)
- Core Monitor is not available on the Mac App Store

## Privacy

Core Monitor does not ship with updater frameworks, telemetry, analytics, or accounts. Sensor reads are local IOKit calls, and the optional fan helper only talks to the local privileged XPC service. 

## WeatherKit 
Core-Monitor communicates with Apple's weatherkit to show you the weather. For best results, we recommend turning on location for the app.

## License

GPL-3.0 — see [LICENSE](./LICENSE).
