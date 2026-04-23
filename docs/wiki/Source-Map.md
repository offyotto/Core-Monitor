# Source Map

The active app target lives under `Core-Monitor/`. The privileged helper target lives under `smc-helper/`. Tests live under `Core-MonitorTests/`. Public docs, website assets, and support pages live under `docs/`, root HTML/CSS files, and `Mac-App-Store/`. Release scripts live under `scripts/release/`, localization tooling under `scripts/localization/`, and the custom Homebrew cask under `Casks/`.

High-risk source files are `SystemMonitor.swift`, `FanController.swift`, `SMCHelperManager.swift`, `smc-helper/main.swift`, `Core_MonitorApp.swift`, `ContentView.swift`, and `MenuBarExtraView.swift`. They coordinate sampling, fan writes, helper trust, startup, dashboard UI, and menu bar UI.

The Pock/Touch Bar compatibility layer is split across `CoreMonTouchBarController.swift`, `TouchBarCustomizationCompatibility.swift`, `TouchBarUtilityWidgets.swift`, `GroupViews.swift`, `PKCoreMonWidgets.swift`, `PKWidget*`, and `PockWidgetSources/`.

Generated file pages in this wiki give per-file imports, declarations, recent history, and maintenance notes. Start at File Index when tracing ownership.
