# Touch Bar Architecture

Touch Bar support combines AppKit `NSTouchBar`, custom NSViews, Pock-style widget wrappers, and SwiftUI configuration UI.

`CoreMonTouchBarController` presents and rebuilds items. `TouchBarCustomizationCompatibility` persists layouts, pinned apps, pinned folders, custom command widgets, themes, presets, and compatibility migrations. `TouchBarUtilityWidgets`, `GroupViews`, `WeatherTouchBarView`, `NowPlayingTouchBarView`, and Pock widget sources render the visible strip.

The point of the Touch Bar layer is persistent quick access above other apps: live status, weather, launchers, folders, and scripts without dragging users back to the dashboard.

Private Touch Bar presentation code must be treated carefully because it can depend on undocumented AppKit behavior.
