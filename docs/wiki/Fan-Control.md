# Fan Control

`FanController.swift` owns fan modes: Smart, System/Silent, Balanced, Performance, Max, Manual, Custom, and Automatic/System restoration.

Managed modes require the helper because they write fan targets. Monitoring itself does not. Smart mode blends the hottest CPU/GPU reading with system power draw. Balanced and Performance pin fans near fixed percentages of maximum. Manual writes a fixed RPM. Custom follows a persisted curve.

The UI should always explain who owns the fan curve: macOS firmware or Core-Monitor. If Core-Monitor owns it, quitting or switching to automatic should hand control back to the system best-effort.

Fan behavior can lag visibly on Apple Silicon. The guide copy intentionally warns users that a write can succeed before RPM changes are immediately obvious.
