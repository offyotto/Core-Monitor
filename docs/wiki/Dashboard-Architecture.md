# Dashboard Architecture

The dashboard is mainly in `ContentView.swift`, `MonitoringDashboardViews.swift`, `FanCurveEditorView.swift`, `FanModeGuidanceCard.swift`, `MenuBarConfigurationSection.swift`, `LaunchAtLoginSection.swift`, `PrivacyControlsSection.swift`, `WeatherLocationAccessSection.swift`, `HelpView.swift`, and support cards such as helper diagnostics.

`ContentView.swift` remains oversized and mixes shell, sidebar, overview cards, system pages, fan controls, Touch Bar customization, helper support, and about surfaces. The architecture docs already call it a pressure point. New UI work should prefer extracting small dedicated views rather than growing it.

Dashboard data should come from `SystemMonitorSnapshot`, `FanController`, `SMCHelperManager`, and settings objects. Avoid ad hoc timers or local telemetry state in SwiftUI views. Detailed process panels should request detailed sampling while visible and release that reason when hidden.

`DashboardWindowLayout.swift` owns safe window sizing and frame reset rules; use it instead of hardcoding dashboard geometry.
