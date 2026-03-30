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



Core-Monitor
Website
Download
License: GPL-3.0
macOS
Apple Silicon
Swift
Open Source

Core-Monitor is a native Swift application made to combine features like Touch Bar integration, menu bar implementation, and fan control.
The app is designed to provide Touch Bar support, menu bar implementation, and fan control in one app. Usually, if you want Touch Bar support in a free fan control app, you have to manually set it up with another Touch Bar app, or pay for a paid alternative (for example, iStat Menus).
Which is why I made this app. It is intended for someone who wants an all-around fan control app with useful extras that is free and open source.

Install
Install the latest release from Releases or build from source. Clone via the web URL: https://github.com/offyotto-sl3/Core-Monitor.git.

System Requirements
Requires macOS 12 or later. Certain features may not work on Intel models.

Features
CPU utilization

GPU utilization

Memory usage

Battery level

Fan control

Sensor information (Temperature/Voltage/Power)

Touch Bar widgets

Documentation

Core-Monitor is unsigned at the moment. Monitoring, Touch Bar widgets, menu bar stats, and benchmark features run without elevated privileges. 


Explanation of smc​-helper below.

smc-helper

smc​-helper is only needed for fan writes. Core-Monitor no longer installs it or elevates privileges from inside the app.

Opens the Apple​SMC service with IOService​Get​Matching​Service(..., ​IOService​Matching("​Apple​SMC")).
Uses IOConnect​Call​Struct​Method to talk to the SMC keyspace.
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
Parses a few known SMC data types: sp78, fpe2, ui8, ui16, flt

License

Core-Monitor is open source. See LICENSE for the full license text.
