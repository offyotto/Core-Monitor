<p align="center">
  <img src="./Core-Monitor/Assets.xcassets/AppIcon.appiconset/icon-512.png" width="128">
</p>

<h1 align="center">Core-Monitor</h1>

<p align="center">
  macOS system monitor with fan control, menu bar stats, and Touch Bar support.
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
  <img src="https://img.shields.io/badge/Apple%20Silicon-Yes-black?style=flat&logo=apple">
  <img src="https://img.shields.io/badge/Swift-Native-orange?style=flat&logo=swift">
</p>

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

the app is signed and notarized through the apple developer program.

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

* `set` → enables manual mode and writes target rpm
* `auto` → restores system control
* `read` → reads any 4-character smc key

supports:

* sp78
* fpe2
* ui8 / ui16
* flt

no auto install. no hidden services.

---

## license

GPL-3.0
