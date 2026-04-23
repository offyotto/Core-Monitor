# Custom Fan Curves

Custom presets are modeled by `CustomFanPreset` and edited through `FanCurveEditorView.swift`. A preset includes a sensor source, curve points, optional update interval, smoothing step, RPM bounds, per-fan offsets, and optional power boost.

The editor constrains point movement, temperature range, speed range, nearest-handle selection, template application, and validation. Tests under `CustomFanPresetTests` and related curve editor geometry coverage protect these rules.

Custom curves are high-risk because they turn user configuration into hardware behavior. Validate bad JSON, invalid curve order, impossible RPM ranges, and fallback defaults defensively.
