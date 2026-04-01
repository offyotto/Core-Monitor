<p align="center">
  <img src="./Core-Monitor/Assets.xcassets/AppIcon.appiconset/icon-512.png" width="128">
</p>

<h1 align="center">Core-Monitor</h1>

<p align="center">
<<<<<<< HEAD
  macOS system monitor with fan control, menu bar stats, and Touch Bar support.
=======
  Native macOS monitoring, fan control, benchmarking, menu bar stats, and Touch Bar utilities in one app.
</p>

<p align="center">
  <a href="https://github.com/offyotto-sl3/Core-Monitor/releases/latest">Download Latest Release</a>
  ·
  <a href="https://github.com/offyotto-sl3/Core-Monitor">GitHub</a>
  ·
  <a href="./LICENSE">License</a>
>>>>>>> aa21a26 (Remove leftover unused CoreVisor files)
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

<<<<<<< HEAD
---

## what is this

i made this because most free mac fan control apps:
- don’t support the touch bar  
- feel outdated  
- or lock basic features behind a paywall  

this keeps everything in one place without extra setup.

---

<p align="center">
  <img src="./docs/images/ui/dashboard-v2.png" width="95%">
</p>

<p align="center">
  <img src="./docs/images/ui/menu-bar-v2.png" width="48%">
</p>

---

## features

- cpu / gpu / memory usage  
- battery stats  
- fan control (manual + auto)  
- temps, voltage, power  
- menu bar stats  
- touch bar widgets  

---

## install

download:  
https://github.com/offyotto-sl3/Core-Monitor/releases/latest  

or build from source:

```bash
git clone https://github.com/offyotto-sl3/Core-Monitor.git
````

open in xcode and build.

---

## requirements

* macOS 12 or later
* apple silicon recommended
* intel supported (some features may be limited)

---

## notarization

the app is signed and notarized through the apple developer program (v12 or higher, v12 is still in testing sadly, will be ready in 1-2d)

---

## permissions

* monitoring works without elevated privileges
* fan control requires `smc-helper` (optional)

nothing runs in the background without you knowing.

---

## smc-helper

used only for fan control writes.

it communicates directly with apple smc:

* opens AppleSMC service
* uses IOConnectCallStructMethod

### commands

```
set <fanID> <rpm>
auto <fanID>
read <key>
```

### behavior
=======
## About Core-Monitor

Core-Monitor is a native Swift app for macOS that combines hardware monitoring, fan control, benchmarking, menu bar telemetry, and Touch Bar utilities into a single desktop tool.

The project is aimed at users who want one app for everyday system visibility and machine tuning without juggling multiple utilities. Monitoring features work without elevated privileges. Fan write operations are separated behind a helper so they can be handled more safely.

## Key Features

- Live CPU, GPU, memory, battery, temperature, power, and voltage monitoring
- Menu bar stats with quick-access system information
- Fan speed monitoring and manual fan control support
- Built-in benchmark tooling
- Touch Bar widgets and utility views
- Native Swift macOS interface with no Electron or web wrapper

## Download and Installation

Core-Monitor can be installed either by downloading a release build or by building the project from source.

### Release Builds

- Download the latest release from [Releases](https://github.com/offyotto-sl3/Core-Monitor/releases/latest)
- Move the app to `/Applications`
- Launch Core-Monitor from Applications, Spotlight, or Launchpad

### Build From Source

- Clone the repository:

```bash
git clone https://github.com/offyotto-sl3/Core-Monitor.git
```

- Open the project in Xcode
- Build and run the `Core-Monitor` target

## Privileged Fan Control

Monitoring, Touch Bar widgets, benchmark tooling, and menu bar features do not require administrator privileges.

Fan write access is handled separately through the privileged `smc-helper`. When fan control needs elevated access, Core-Monitor installs the helper and communicates with it over XPC.

### What `smc-helper` Does

The helper is used only for privileged SMC write operations.

Supported commands:

- `set <fanID> <rpm>` sets a fan target RPM
- `auto <fanID>` returns a fan to automatic control
- `read <key>` reads a 4-character SMC key

Internally, the helper:

- opens the `AppleSMC` service
- communicates with the SMC keyspace through IOKit
- switches fan mode between automatic and manual when required
- reads common sensor and fan-related SMC values

## Compatibility

- macOS 12 or later
- Apple Silicon is the primary target
- Some features may behave differently on Intel Macs
- Fan control availability depends on hardware support and helper installation

## Project Status

Core-Monitor is currently best suited for direct distribution and local builds.

Because some advanced functionality involves elevated system access and macOS-specific behavior, feature availability may vary by build type and signing setup.

## Why This Exists

Core-Monitor was built as an all-in-one alternative for users who want system stats, menu bar access, Touch Bar utilities, and fan control in a single native macOS app.
>>>>>>> aa21a26 (Remove leftover unused CoreVisor files)

* `set` → enables manual mode and writes target rpm
* `auto` → restores system control
* `read` → reads any 4-character smc key

supports:

* sp78
* fpe2
* ui8 / ui16
* flt

---

## license

GPL-3.0
