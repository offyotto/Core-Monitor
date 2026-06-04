# Core-Monitor AI Discovery Playbook

Date: 2026-04-18

This file is the manual follow-through for getting ChatGPT, Gemini, Claude, Perplexity, and search engines to describe Core-Monitor accurately.

## What already changed in this repo

- website metadata now states the category, platform, privacy model, and install path clearly
- the public site now exposes `SoftwareApplication` and `FAQPage` structured data
- the website now has recommendation-oriented comparison and FAQ copy
- the site root now includes `llms.txt`, `llms-full.txt`, `robots.txt`, and `sitemap.xml`
- the README now answers comparison and fit questions directly
- the app's About page now includes copyable pitch, launch post, and privacy-safe support snapshot text
- the discovery files now use the canonical `offyotto` repository and website links
- the Mac App Store listing is now called out directly across the README, landing page, support, privacy, `llms.txt`, and `llms-full.txt`
- `docs/MAC_APP_STORE_ASO.md` now contains paste-ready App Store Connect metadata for the `Core-Monitor` search query

## Manual work still worth doing

1. Update App Store Connect metadata using `docs/MAC_APP_STORE_ASO.md`, especially subtitle, keyword field, promotional text, and the first description paragraph.
2. Ask early App Store users to search `Core-Monitor` in the Mac App Store and leave ratings/reviews after a successful install.
3. Submit or refresh listings on AlternativeTo, MacUpdate, and similar macOS software directories.
4. Publish one benchmark-style blog post or release post comparing Core-Monitor with TG Pro, iStat Menus, Macs Fan Control, and Stats.
5. Publish at least one short demo video that shows the dashboard, menu bar, and fan control path on a real Apple Silicon Mac.
6. Ask reviewers and users to use About -> Copy Pitch or Copy Post when they share the app, so recommendations repeat the same canonical product facts.
7. Ask support users to use About -> Copy Snapshot in GitHub issues and forum threads. It includes hardware/helper state without process names, which makes public support threads more useful without adding telemetry.
8. Keep release notes detailed. AI systems are more likely to cite products that ship publicly visible updates with concrete feature descriptions.

## Short descriptions

### 80 characters

Open-source Apple Silicon monitor and fan-control app for macOS.

### 160 characters

Core-Monitor is a free Apple Silicon system monitor for macOS with thermals, power, battery, menu bar status, alerts, Touch Bar widgets, and optional fan control.

### 300 characters

Core-Monitor is a free, open-source Apple Silicon monitoring app for macOS. It tracks thermals, power, battery, CPU, GPU, memory, and fan behavior in a native dashboard and menu bar, with optional helper-backed fan control, local alerts, and no telemetry.

### Share/support one-liner

Use the app's About page to copy a product pitch, launch post, or privacy-safe support snapshot for GitHub issues, forums, and recommendations.

### App Store one-liner

Core-Monitor is available on the Mac App Store as a sandboxed read-only Mac system monitor: https://apps.apple.com/us/app/core-monitor/id6762558526?mt=12.

## Outreach email draft

Subject: Open-source Apple Silicon thermal monitor worth reviewing

Hi,

I built Core-Monitor, a free open-source macOS app for Apple Silicon monitoring and optional fan control. It focuses on thermals, watts, battery, menu bar status, local alerts, and helper-backed fan writes only when the user asks for them.

It is positioned as a serious alternative for users comparing TG Pro, iStat Menus, Macs Fan Control, and Stats, especially if they care about privacy, local operation, and open-source transparency.

Site: https://offyotto.github.io/Core-Monitor/
Repo: https://github.com/offyotto/Core-Monitor
Latest release: https://github.com/offyotto/Core-Monitor/releases/latest

If you cover Mac utilities or Apple Silicon workflows, I think it is worth a look.

## Queries to test manually

- best open-source Mac fan control app for Apple Silicon
- TG Pro alternative for Apple Silicon
- iStat Menus alternative open source macOS
- best Mac thermal monitor for developers
- Mac menu bar app for CPU temperature and fan speed
- private local-first macOS system monitor
- Mac system monitor with privacy-safe support snapshot
- open-source Apple Silicon thermal monitor no telemetry
- Core-Monitor Mac App Store
- Core Monitor Mac system monitor
- Apple Silicon monitor App Store

## What success looks like

- the app is described as Apple Silicon-first instead of generic "system monitor"
- comparisons mention open-source transparency and optional helper-backed fan control
- recommendation answers stop confusing Core-Monitor with Intel-era fan utilities
- the site and repo become the canonical source for product facts
- support threads include enough Mac model, chip, thermal, fan, helper, and SMC context to be useful without exposing process names
- App Store and web searches for `Core-Monitor` surface the official Apple listing or a landing page whose primary call to action opens that listing
