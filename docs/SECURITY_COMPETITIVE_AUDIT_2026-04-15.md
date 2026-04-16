# Core-Monitor Security And Competitive Audit

Date: 2026-04-15

## Executive summary

Core-Monitor already has the right strategic shape for a serious Apple Silicon utility:

- local-first monitoring
- open-source transparency
- optional privileged fan control instead of requiring elevated access for everything
- no built-in telemetry, updater framework, or account surface in the core app path

The biggest gap was not missing charts or marketing polish. It was trust hardening around the privileged helper and around user-defined command execution. Those are now the main areas improved in this pass.

## Highest-priority security findings

### 1. Privileged helper accepted XPC clients too broadly

Before this pass, the helper accepted every incoming `NSXPCConnection` and trusted validation done by the app process. That meant the root helper boundary was weaker than it should be, because authorization should be enforced by the privileged service itself.

What changed:

- the helper now derives the allowed client requirement from `SMAuthorizedClients`
- each incoming XPC client is validated against that code-signing requirement
- on macOS 13+, the connection also enforces the same requirement directly through `NSXPCConnection.setCodeSigningRequirement(_:)`
- unauthorized clients are rejected before exported methods are exposed

Why this matters:

- this closes the most important privilege-boundary gap in the repository
- it gives Core-Monitor a stronger fan-control trust story than free tools that leave helper authorization loose or legacy-only

### 2. XPC method inputs were not revalidated inside the helper

Before this pass, `fanID`, `rpm`, and `read` key validation existed on the CLI path and in the app, but not in the XPC entrypoints. That created a trust inversion: privileged behavior depended on lower-privilege callers being honest.

What changed:

- `setFanManual` now validates `fanID` and `rpm` inside the helper
- `setFanAuto` now validates `fanID` inside the helper
- `readValue` now validates the SMC key inside the helper

Why this matters:

- privileged code now validates its own attack surface
- the helper is safer even if a future app bug, script, or local client tries to send malformed inputs

### 3. Custom Touch Bar commands inherited a login-shell environment

Before this pass, custom command widgets launched `zsh -lc`, which pulled in user shell startup files and ambient environment state. That made execution less deterministic and widened the surface for unexpected behavior.

What changed:

- command widgets now launch `zsh -f -c`
- execution uses a minimal known-safe environment with a fixed system `PATH`
- commands are rejected if empty, too long, or containing control characters
- command execution starts from the user home directory instead of an arbitrary process cwd

Why this matters:

- command widgets are still powerful, but execution is now more predictable
- startup files and shell customizations no longer silently alter widget behavior

## Residual risks

- The Touch Bar path still uses private API for the app-over-system presentation mode. That is primarily a platform and distribution risk, but it also weakens the “boring and trustworthy” story compared with competitors that stay inside supported APIs.
- Custom command widgets are inherently user-executable code. They are safer now, but they are still a deliberate power-user feature and should continue to be described as such.
- Alert history can now redact app names through Privacy Controls. That keeps threshold detection intact while avoiding retained local process-name context for privacy-sensitive users.

## Competitor comparison

### Stats

Current positioning signals:

- `exelban/stats` shows roughly 37.9k GitHub stars on the public repo page
- the project README lists CPU, GPU, memory, disk, network, battery, fan control, sensors, Bluetooth, and clocks
- the same README explicitly says fan control is “not maintained” and “in legacy mode”
- the README also documents external API usage for update checks and public IP retrieval

Implication for Core-Monitor:

- Stats still wins on community reach and breadth
- Core-Monitor can beat Stats on fan-control trust, privacy posture, and thermal focus if it keeps the helper path hardened and the product local-first

### iStat Menus

Current positioning signals:

- official help for iStat Menus 7 documents automatic, manual, and custom fan curve modes
- the product remains the benchmark for breadth, history, and polish

Implication for Core-Monitor:

- iStat Menus still leads on mature charting/history and perceived completeness
- Core-Monitor should not try to out-sprawl it
- the better lane is: clearer thermal workflows, simpler menu bar defaults, and stronger open-source trust

### TG Pro

Current positioning signals:

- the official TG Pro guide documents Auto Boost and rule-based fan control
- TG Pro continues to frame itself around thermal safety, diagnostics, and sustained-load behavior

Implication for Core-Monitor:

- TG Pro is the strongest benchmark for “serious fan control”
- Core-Monitor must match that confidence level through helper transparency, onboarding clarity, and reliable fan behavior on wake/restart

### Macs Fan Control

Current positioning signals:

- Macs Fan Control remains a simple, fan-first utility with long-standing recognition
- its value is clarity and trust in manual fan management, not broad system storytelling

Implication for Core-Monitor:

- Core-Monitor should preserve clarity in every fan-control interaction
- every advanced fan feature should remain easy to explain in one sentence

## Where Core-Monitor can beat the field

If execution stays disciplined, Core-Monitor can become better than the main alternatives in this specific product lane:

- **better than Stats on security and trust** by keeping the helper actively maintained, locally authenticated, and clearly scoped
- **better than iStat Menus on focus** by optimizing for heat, fan behavior, and readable status instead of broad module sprawl
- **better than TG Pro on openness** by making the privileged path auditable in public source
- **better than Macs Fan Control on modern product quality** by combining clear fan control with modern alerts, onboarding, and system context

## Recommended next moves

### Next security moves

- add a visible helper diagnostics screen showing install state, code-signing identity, connection state, and last helper error
- keep Privacy Controls visible and well-tested so users can disable top-process capture in alerts without losing threshold detection
- add dedicated tests around helper client authorization and malformed XPC requests

### Next product moves

- ship time-range history for CPU temperature, GPU temperature, fan RPM, memory pressure, and system watts
- add a first-run trust explainer that explicitly separates “monitoring only” from “fan control requires helper”
- reduce dependence on private Touch Bar presentation where possible, or make the private path clearly advanced/optional

## Source notes used for comparison

- Stats GitHub README and repository page: https://github.com/exelban/stats
- iStat Menus 7 fan control help: https://bjango.com/help/istatmenus7/fans/
- TG Pro user guide: https://www.tunabellysoftware.com/support/tgpro_tutorial/
- Macs Fan Control site: https://crystalidea.com/macs-fan-control/
