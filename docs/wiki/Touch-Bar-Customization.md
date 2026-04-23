# Touch Bar Customization

The customization surface lets users combine built-in widgets, pinned apps, pinned folders, and custom shell command widgets. The active ordered layout is stored and previewed before application.

Pinned apps store path, display name, and bundle identifier when available. Pinned folders store path and display name. Custom command widgets store title, SF Symbol, command, and width. Tapping a command launches `/bin/zsh -lc`.

Persistence uses versioned configuration structs so older layouts can migrate forward. Any change to layout storage should include compatibility tests.
