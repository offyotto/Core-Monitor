# Core-Monitor Competitor Matrix

Date: 2026-04-15

This document captures the current public positioning of the main macOS monitoring and fan-control competitors that Core-Monitor is most likely to be compared against. It is meant to support product decisions, repo messaging, and roadmap prioritization.

## Snapshot

| Product | Current strength | Publicly documented fan-control model | Important tradeoff | What Core-Monitor should beat |
| --- | --- | --- | --- | --- |
| Stats | Broad open-source menu bar monitoring with a large public user base and easy Homebrew/manual install | Fan control is still present, but the project README says it is in legacy mode and does not receive updates or fixes | Broad feature surface, but weaker trust story around actively maintained fan control | Thermal focus, helper trust, and clearer “monitoring only vs helper required” messaging |
| iStat Menus 7 | Mature menu bar monitoring and polished fan-control UI | Official help documents Automatic, Custom fan curve, and Manual modes; Automatic acts as if iStat Menus is not installed | Broad and polished, but intentionally wider in scope than a thermal-first product | Simpler thermal workflows and less menu bar sprawl by default |
| TG Pro | Strongest “serious fan control” posture and explicit helper/onboarding language | Official docs show per-fan override, Manual mode, and Auto Boost rules; official FAQ separates monitoring-only from helper-backed control | Powerful, but more admin-heavy and rule-oriented than many users need | Open-source transparency and a cleaner daily-use dashboard/menu bar experience |
| Macs Fan Control | Simple mental model, strong reputation, broad Mac model support, and clear fan presets story | Official site documents Auto vs Custom, sensor-based control, saved presets, configurable menu bar display, and restoring fans to Auto on quit | UI is intentionally simple and narrow; custom presets are a Pro feature | Modern UI polish, better local alerts, and a more informative Apple Silicon dashboard |

## Current source-backed notes

### Stats

- The public GitHub README still describes Stats as a macOS system monitor in the menu bar.
- The same README says fan control is in legacy mode and does not receive updates or fixes.
- The README also documents external API usage for update checks and public IP retrieval.
- GitHub’s security advisory page documents a past local privilege-escalation issue in the privileged helper path.

Implication for Core-Monitor:

- Core-Monitor can be more convincing on fan-control trust if the helper remains actively maintained, clearly scoped, and explained in plain language.
- Core-Monitor should stay local-first and keep the “no telemetry / no external dependency for core monitoring” story crisp.

### iStat Menus 7

- Bjango’s official fan help page documents three modes: Automatic, Custom fan curve, and Manual.
- The same page explicitly says Automatic means fans behave as if iStat Menus is not installed.
- Manual mode is documented as not being saved across reboots.

Implication for Core-Monitor:

- Core-Monitor should preserve the same clarity around when the app is actually controlling fans and when macOS is fully in charge.
- Manual and custom modes should keep safety copy close to the control surface instead of burying it in docs.

### TG Pro

- The official user guide documents per-fan override, Manual mode, and Auto Boost rule-based control.
- The official FAQ says the fan helper is essential for fan control, that monitoring remains available without it, and that quitting or uninstalling TG Pro returns all fans to macOS defaults.
- The FAQ also says the helper is developed with hardened runtime and notarized by Apple.

Implication for Core-Monitor:

- Core-Monitor should keep doubling down on helper transparency, installation clarity, and “fully reversible” fan control behavior.
- The app should expose helper health in a way that feels first-class, not like an edge-case diagnostics detail.

### Macs Fan Control

- CrystalIDEA’s official site documents real-time monitoring, custom RPM control, sensor-based control, configurable menu bar display, and saved fan presets.
- The official download page shows version 1.5.21 updated on April 13, 2026, and includes an explicit advanced-user risk warning.
- The official Pro page says saved custom fan presets are a Pro feature.
- The official site says the app restores fans to Auto when it quits.

Implication for Core-Monitor:

- Core-Monitor should keep the “return to system auto” guarantee prominent in both the UI and docs.
- Menu bar controls should offer fast density choices instead of requiring manual toggle-by-toggle setup every time.

## Where Core-Monitor should focus next

### Product

- Keep the product thermal-first. Do not let weather, novelty widgets, or broad status sprawl dilute the main reason users install it.
- Make helper-backed fan control feel obviously optional: monitoring first, elevated control only when requested.
- Continue improving compact menu bar ergonomics, because both Macs Fan Control and Stats set a strong expectation that menu bar data must stay readable.

### UX

- Put helper status, SMC status, and “returns control to macOS” language where users make fan-control decisions.
- Keep fan mode names and explanations short enough to understand without opening Help.
- Add more time-based history for temperature, fan RPM, and watts; iStat Menus still sets the bar there.

### Trust

- Prefer explicit, source-controlled release and helper documentation over broad claims.
- Treat helper validation, install state, and recovery steps as product features, not just engineering details.
- Preserve the privacy advantage over broader monitoring apps by keeping core monitoring local and dependency-light.

## Sources

- Stats GitHub README and repository page: https://github.com/exelban/stats
- Stats security advisory: https://github.com/exelban/stats/security/advisories/GHSA-qwhf-px96-7f6v
- iStat Menus 7 fan control help: https://bjango.com/help/istatmenus7/fans/
- TG Pro user guide: https://www.tunabellysoftware.com/support/tgpro_tutorial/
- TG Pro FAQ: https://www.tunabellysoftware.com/support/faq/
- Macs Fan Control official overview: https://crystalidea.com/macs-fan-control
- Macs Fan Control download page: https://crystalidea.com/macs-fan-control/download
- Macs Fan Control release notes: https://crystalidea.com/macs-fan-control/release-notes
- Macs Fan Control Pro overview: https://crystalidea.com/macs-fan-control/buy
