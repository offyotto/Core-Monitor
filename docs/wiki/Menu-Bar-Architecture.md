# Menu Bar Architecture

Menu bar behavior is centered on `MenubarController.swift`, `MenuBarSettings.swift`, `MenuBarExtraView.swift`, `MenuBarStatusSummary.swift`, and `MenuBarConfigurationSection.swift`.

`MenuBarSettings` defines presets and persistence, including safety rules that keep at least one visible item so the app remains reachable. `MenuBarController` owns NSStatusItem creation and update. `MenuBarExtraView` builds rich popovers for CPU, memory, disk, network, temperature, and the combined menu surface.

The menu bar is not a separate monitoring system. It should read the shared snapshot and history buffers. This keeps dashboard, menu bar, trends, alert status, and support diagnostics consistent.

The default product direction is readable thermal-first status, not maximum density. Presets exist to let users choose compact, balanced, or dense layouts without turning first launch into a noisy wall of numbers.
