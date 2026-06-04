# Core-Monitor Mac App Store Search Playbook

Goal: make the Apple App Store listing appear for searches like `core-monitor`, `Core Monitor`, `Mac system monitor`, `Apple Silicon monitor`, and related utility queries.

Apple App Store listing:

https://apps.apple.com/us/app/core-monitor/id6762558526?mt=12

## Current Search Notes

- The Apple App Store listing exists and is titled `Core-Monitor`.
- Public search currently finds the Core-Monitor website and Mac App Store landing page more reliably than the Apple-hosted listing.
- The Apple listing description is readable, but it starts generically. The first visible sentence should repeat the exact app name and strongest App Store search phrases.

## App Store Connect Metadata

Use this exact direction in App Store Connect when preparing the next metadata update.

### Name

```text
Core-Monitor
```

Keep the hyphen. It is the exact brand query people type.

### Subtitle

```text
Mac System Monitor
```

Short, plain, and search-aligned. It pairs the exact app name with the highest-intent category phrase.

### Keywords

```text
core-monitor,core monitor,system monitor,mac monitor,cpu,memory,battery,network,thermal,m1,m2,m3,m4
```

This is 99 characters including commas. Keep commas, avoid spaces unless the phrase needs one, and do not repeat words already covered by the app name unless the exact phrase matters.

### Promotional Text

```text
Core-Monitor is a clean Mac system monitor for CPU, memory, storage, battery, network, thermal state, menu bar status, and local weather.
```

### Description Opening

Use the strongest search terms in the first paragraph because App Store result pages and crawlers often expose only the beginning.

```text
Core-Monitor is a clean Mac system monitor for macOS. It helps you check CPU activity, per-core load, memory pressure, storage, battery, network throughput, thermal state, uptime, and menu bar status in a focused read-only dashboard.

The Mac App Store edition is sandboxed and designed for local, read-only monitoring. It does not include helper tools, fan control, private APIs, shell-backed actions, or updater flows.
```

### Full Description

```text
Core-Monitor is a clean Mac system monitor for macOS. It helps you check CPU activity, per-core load, memory pressure, storage, battery, network throughput, thermal state, uptime, and menu bar status in a focused read-only dashboard.

The Mac App Store edition is sandboxed and designed for local, read-only monitoring. It does not include helper tools, fan control, private APIs, shell-backed actions, or updater flows.

Core-Monitor shows:

• CPU activity and per-core load
• Memory usage and memory pressure
• Startup disk usage
• Battery and power-source status
• Network upload and download throughput
• Thermal state and warning level
• Uptime and load averages
• A clean menu bar extra
• Local weather when you enable location access

Core-Monitor is built for people who want a simple Mac monitoring app without account setup, analytics SDKs, advertising SDKs, or a cloud dashboard.

If you need helper-backed fan control, AppleSMC access, Touch Bar overlays, or the broader open-source build, use the separate direct-download edition from the Core-Monitor website. The Mac App Store edition intentionally keeps a narrower, sandboxed feature set.
```

## Ratings And Reviews Motion

Apple search ranking is strongly affected by installs, ratings, and reviews. Add these habits to releases:

- Ask happy users to search `Core-Monitor` in the Mac App Store and leave a rating.
- Ask testers to use the exact phrase `Core-Monitor Mac system monitor` in public recommendations when it sounds natural.
- Link directly to the Apple listing from README, the website hero, the Mac App Store landing page, support, privacy, release notes, and launch posts.
- Keep screenshots readable at small sizes. The first screenshot should visually say `Core-Monitor` and `Mac system monitor` if the screenshot text can support it without clutter.

## Public Link Targets

Use the Apple listing URL for App Store install CTAs:

```text
https://apps.apple.com/us/app/core-monitor/id6762558526?mt=12
```

Use the landing page when explaining edition scope:

```text
https://offyotto.github.io/Core-Monitor/Mac-App-Store/
```

Use the support URL in App Store Connect:

```text
https://offyotto.github.io/Core-Monitor/Mac-App-Store/support/
```

Use the privacy URL in App Store Connect:

```text
https://offyotto.github.io/Core-Monitor/Mac-App-Store/privacy/
```
