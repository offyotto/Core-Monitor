<p align="center">
  <img src="./Core-Monitor/Assets.xcassets/AppIcon.appiconset/icon-512.png" alt="Core-Monitor icon" width="128">
</p>

<h1 align="center">Core-Monitor</h1>

<p align="center">
  Open-source macOS control center for live monitoring, fan control, benchmarking, menu bar stats, and Touch Bar tools.
</p>

<p align="center">
  <img src="./docs/images/ui/dashboard-v2.png" alt="Core-Monitor dashboard" width="95%">
</p>

<p align="center">
  <img src="./docs/images/ui/menu-bar-v2.png" alt="Core-Monitor menu bar panel" width="48%">
</p>


# Core-Monitor
[![Website](https://img.shields.io/badge/Website-Core--Monitor-8A2BE2)](https://offyotto-sl3.github.io/Core-Monitor/)
[![Download](https://img.shields.io/badge/Download-Latest%20Release-brightgreen)](https://github.com/offyotto-sl3/Core-Monitor/releases/latest)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](https://github.com/offyotto-sl3/Core-Monitor/blob/main/LICENSE)
![macOS](https://img.shields.io/badge/macOS-12%2B-black?logo=apple)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-M1--M5-orange)
![Swift](https://img.shields.io/badge/Swift-Native-F05138?logo=swift&logoColor=white)
![Open Source](https://img.shields.io/badge/Open%20Source-Yes-green)

Core-Monitor is a native swift application made to combine features like touch-bar integration, menu-bar implentation, and fan control. 
The app is designed to have a easy way to have proper touch-bar implementation, menu-bar impletation, fan control, all in one app, Now usually, if you want to have touch-bar support in a fan control app, thats free, you'll have to manually implement one with another touchbar app, or, you'll have to pay for a paid alternative, (eg, iStats)
Which is why I made this app. It is intended to be used for someone who wanted a all rounded fan control app, with loads of useful extras, that was free and open-source.

# Install
Install the latest release from releases or build from source. Clone via the web url with https://github.com/offyotto-sl3/Core-Monitor.git.

# System Requirements
Requires macOS 12 or later. Certain features may not work on intel models.

# Features
CPU utilization
GPU utilization
Memory usage
Battery level
Fan control
Sensors information (Temperature/Voltage/Power)
Touch-bar widgets

# Documentation
Core-Monitor will be notarized by v11 hopefully. 
Explanation of smc-helper below. 

# smc-helper

Opens the Apple​SMC service with IOService​Get​Matching​Service(..., ​IOService​Matching("​Apple​SMC")).
Uses IOConnect​Call​Struct​Method to talk to SMC keyspace.
Supports exactly three commands:
set <fan​ID> <rpm>
auto <fan​ID>
read <key>

set <fan​ID> <rpm>
Detects the fan mode key form: F​%dmd or F​%d​Md
Optionally enables Ftst​=1 if that key exists
Writes manual mode: F0​Md​=1 or F0md​=1
Writes target RPM: F0​Tg=<rpm>
auto <fan​ID>
Writes automatic mode: F0​Md​=0 or F0md​=0
Clears target if possible: F0​Tg​=0
Clears force-test if present: Ftst​=0
read <key>
Reads any 4-character SMC key, for example temperature, RPM, limits, etc.
Parses a few known SMC data types: sp78, fpe2, ui8 , ui16, flt 

## License

Core-Monitor is open source. See [LICENSE](LICENSE) for the full license text.
