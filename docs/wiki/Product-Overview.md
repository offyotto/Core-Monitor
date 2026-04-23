# Product Overview

Core-Monitor is a native macOS utility focused on Apple Silicon monitoring, thermal awareness, menu bar visibility, dashboard inspection, optional helper-backed fan control, Touch Bar widgets, and support diagnostics.

The product stance is monitoring-first. Sensor reads should work without elevated privileges. The privileged helper is only for fan writes and helper-backed SMC operations that require root-level access. That split is important for trust: normal users can launch and monitor without installing anything privileged, while users who explicitly want fan control can install the helper and see diagnostics when trust or signing state is wrong.

Current public docs describe signed DMG, signed ZIP, and Homebrew cask installs. The repository also contains a separate Mac App Store website path for a sandboxed edition that intentionally excludes helper, AppleSMC/private-framework paths, and non-App-Store behavior.

The app includes a "Weird Mode" Kernel Panic parody game and optional WeatherKit/Touch Bar features, but those are secondary surfaces. The durable core is system monitoring, thermals, fan state, local privacy, menu bar reachability, and a supportable release process.
