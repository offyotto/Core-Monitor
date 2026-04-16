# Core-Monitor Audit and Reinvention Plan

## Verdict

Core-Monitor has real strengths: native SwiftUI UI, direct Apple SMC access, a privileged helper path for actual fan control, open-source trust, and a menu bar footprint that can become a serious daily utility. It is not yet category-dominating.

The main blocker is not raw feature count. It is trust and focus. Users trust TG Pro and Macs Fan Control when they need fan control. Users trust iStat Menus and Stats when they need at-a-glance monitoring. Core-Monitor currently sits in the middle with good ingredients, but too many rough edges in release rigor, architecture, and product framing.

## Brutally honest audit

### Critical

- Release trust gap: the repository did not previously contain a source-controlled CI or notarized release pipeline, even though the product story depends on signed helper-backed distribution.
- Monolithic UI files: `ContentView.swift`, `MenuBarExtraView.swift`, `SystemMonitor.swift`, and `FanController.swift` are still oversized enough to slow iteration and increase regression risk.
- Fan-control persistence risk: saved custom curve data previously did not restore the in-memory preset correctly after launch, making custom mode unreliable after restart.
- Hardware detection fragility: fan discovery depended too heavily on `FNum`, which is not robust across every Apple Silicon machine and SMC variant.

### High

- Helper identity and signing assumptions were too hard-coded. That creates friction when preparing a clean Developer ID release flow.
- Product positioning was blurred. Weather, Touch Bar, and broad stats collection diluted the sharper story users actually buy into: thermal awareness, fan control, alerts, and readable menu bar status.
- Website and release copy over-promised a smooth install path without repository evidence for how that path is produced.
- There is still not enough narrow test coverage around helper-adjacent behavior, fan curves, and monitoring edge cases.

### Medium

- The website is duplicated across `index.html` and `docs/index.html`, which increases drift risk.
- Xcode Cloud documentation was stale and still described a pre-test-target world.
- There is a lot of product surface area for a utility this size. Touch Bar, weather, launcher widgets, and menu bar customization all add maintenance cost.

### Low

- GitHub topics and discovery copy were too noisy and too close to competitor-keyword stuffing.
- Release channel guidance was scattered instead of codified.

## Competitor intelligence

### iStat Menus

- Strengths: broadest monitoring surface, polished multi-menu experience, mature history/graphing, strong perception of reliability, direct sales plus Setapp.
- Weaknesses: can feel dense and sprawling, pricing is premium, broad scope can make simple thermal workflows slower.
- Why users choose it: trust, breadth, and years of polish.
- What Core-Monitor should learn: history, menu bar polish, and confidence.
- What not to copy: excessive module sprawl and "show everything" defaults.

### TG Pro

- Strengths: strongest fan-control trust, hardware diagnostics framing, clear thermal-safety story, remote/mac admin usefulness.
- Weaknesses: narrower daily monitoring appeal, more utilitarian visual design.
- Why users choose it: when they care more about thermal control and hardware safety than broad desktop ornamentation.
- What Core-Monitor should learn: clear trust model for fan writes and strong thermal-language copy.
- What not to copy: admin-heavy framing for ordinary daily monitoring.

### Macs Fan Control

- Strengths: simple mental model, strong reputation for manual fan control, easy user understanding.
- Weaknesses: older-feeling UX, narrower monitoring layer, less modern product identity.
- Why users choose it: fan control first, everything else second.
- What Core-Monitor should learn: clarity beats cleverness when the feature can alter hardware behavior.
- What not to copy: dated interaction patterns.

### Stats

- Strengths: free, open source, broad GitHub reach, modular menu bar presence, strong community credibility.
- Weaknesses: configuration can sprawl, visual consistency varies, fan-control story is weaker than TG Pro or Macs Fan Control.
- Why users choose it: free native monitoring with solid community adoption.
- What Core-Monitor should learn: open-source distribution discipline and lightweight menu bar ergonomics.
- What not to copy: overly fragmented settings surface.

### Other open-source monitors

- Strengths: transparency, hackability, no pricing friction.
- Weaknesses: weaker release trust, inconsistent signing/notarization, and often a thinner product identity.
- Why users choose them: open-source trust and zero-cost experimentation.
- What Core-Monitor should learn: open source only becomes a strategic advantage when the shipping quality feels commercial-grade.

## Feature gaps Core-Monitor must fill

- Historical graphs with useful time scales instead of raw point-in-time status only
- A first-class custom fan curve editor instead of JSON-first editing
- Actionable alerts with context, snooze, and recovery behavior
- Clear release trust: signed, notarized, reproducible, and easy to install
- Stronger onboarding around helper installation and what requires it

## Overkill to avoid

- Pushing weather or novelty widgets as the main story
- Building enterprise fleet features before fixing consumer trust and onboarding
- Adding remote/cloud alerting that dilutes the local-first privacy advantage
- Turning the menu bar into a miniature dashboard with too many simultaneous numbers

## Unfair advantages Core-Monitor can build

- Open-source transparency with a real notarized shipping story
- Apple Silicon-first thermal product identity instead of general-purpose desktop stats bloat
- Trustworthy, readable menu bar design for people who actually work under sustained load
- Local alerts and diagnostics that never require telemetry or accounts

## Product identity

- Positioning statement: Core-Monitor is the native Apple Silicon thermal command center for people who want trustworthy fan control, readable menu bar status, and local alerts without subscriptions or surveillance.
- One-line hook: Monitor heat, catch trouble early, and control your fans without turning your menu bar into noise.
- Primary users:
- developers compiling and containerizing all day
- creators exporting video or running audio sessions on laptops
- gamers and emulator users pushing Apple Silicon thermals
- power users who want real hardware visibility without iStat-level sprawl

## What this implementation pass changes

- Hardens helper identity handling so the app and helper label are not trapped behind one literal string.
- Fixes fan discovery edge cases that directly affect trust in hardware behavior.
- Fixes custom curve persistence and replaces the raw-JSON-first editing path with a proper graphical fan curve editor.
- Adds source-controlled CI, release, notarization, checksum, and Homebrew distribution scaffolding.
- Tightens README, website, and release docs around the actual product story instead of vague "system monitor" positioning.

## Recommended roadmap after this branch

### Next 30 days

- Split `ContentView`, `MenuBarExtraView`, and `SystemMonitor` into smaller feature files
- Add historical charts for temperature, CPU load, memory pressure, and fan RPM
- Improve helper onboarding with a clearer install-state explainer and recovery steps

### Next 60 days

- Add exportable diagnostics bundles for support and bug reports
- Sharpen menu bar presets so users can choose compact, balanced, or dense layouts quickly
- Tighten the visual hierarchy of the alerts and thermals surfaces

### Next 90 days

- Launch on MacUpdate, AlternativeTo, and relevant Apple Silicon/macOS directories
- Validate whether Setapp is worth the tradeoffs after onboarding, release cadence, and helper trust improve
- Consider a dedicated Homebrew tap only if install volume makes raw-cask distribution too awkward
