# Battery Power And Thermals

Battery data is modeled in `BatteryInfo` and formatted through `BatteryDetailFormatter`. Data includes charge, source, status, cycle count, health, voltage, amperage, power watts, temperature, capacities, and time remaining where macOS provides it.

Power data is used both for user-facing visibility and fan-control heuristics. Smart and custom fan modes can treat high watt draw as an effective temperature boost, which lets Core-Monitor respond to sustained load before raw temperature alone catches up.

Thermal readings come from SMC keys and ProcessInfo thermal state. The app must be honest about missing sensors: unsupported keys should show unavailable/fallback messaging rather than pretending exact measurements exist.
