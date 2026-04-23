# File: Core-Monitor/WelcomeGuide.swift

## Current Role

- Area: Startup and onboarding.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/WelcomeGuide.swift`](../../../Core-Monitor/WelcomeGuide.swift) |
| Wiki area | Startup and onboarding |
| Exists in current checkout | True |
| Size | 63409 bytes |
| Binary | False |
| Line count | 1605 |
| Extension | `.swift` |

## Imports

`SwiftUI`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| extension | `View` | 10 |
| func | `welcomeGuide` | 13 |
| struct | `WelcomeGuideModifier` | 17 |
| func | `body` | 19 |
| enum | `WelcomeGuideDismissAction` | 44 |
| struct | `WelcomeGuidePresentationController` | 49 |
| extension | `Color` | 85 |
| struct | `GuideStep` | 103 |
| struct | `WelcomeGuideSheet` | 194 |
| func | `iconBadge` | 277 |
| func | `transition` | 364 |
| func | `prepareSheet` | 374 |
| func | `tearDownSheet` | 402 |
| func | `goBack` | 409 |
| func | `goForwardStep` | 414 |
| func | `advanceOrDismiss` | 419 |
| func | `dismissSheet` | 427 |
| func | `installScrollMonitor` | 436 |
| func | `handleNavigationGesture` | 452 |
| func | `handleSwipeGesture` | 468 |
| func | `handleHorizontalScroll` | 489 |
| func | `enableLaunchAtLogin` | 541 |
| func | `performLaunchAtLoginAction` | 546 |
| func | `enableDashboardShortcut` | 555 |
| func | `installHelperIfNeeded` | 559 |
| func | `applyBalancedPreset` | 563 |
| func | `refreshHelperDiagnostics` | 567 |
| func | `exportHelperDiagnostics` | 572 |
| func | `checklistTone` | 619 |
| struct | `WelcomeGuideTouchBarShowcase` | 706 |
| struct | `WelcomeGuideTouchBarDemoPanel` | 770 |
| struct | `WelcomeGuideWeatherTouchBarDemo` | 817 |
| struct | `WelcomeGuideCardSwipeDemo` | 895 |
| func | `cardProgressIndex` | 962 |
| struct | `WelcomeGuideTouchBarEditDemo` | 980 |
| struct | `WelcomeGuideTouchBarPill` | 1062 |
| struct | `WelcomeGuideCardPreview` | 1103 |
| struct | `WelcomeGuideActiveWidgetChip` | 1147 |
| struct | `WelcomeGuideLibraryWidgetChip` | 1167 |
| func | `wgMix` | 1186 |
| func | `wgSmoothProgress` | 1190 |
| func | `wgLoopEnvelope` | 1196 |
| func | `wgPulse` | 1216 |
| struct | `WelcomeGuideStepContent` | 1226 |
| func | `contentLayout` | 1258 |
| struct | `WelcomeGuideBulletRow` | 1321 |
| struct | `WelcomeGuideChecklistStatus` | 1344 |
| enum | `WelcomeGuideChecklistTone` | 1353 |
| struct | `WelcomeGuideReadinessPanel` | 1370 |
| struct | `WelcomeGuideDiagnosticsExportRow` | 1425 |
| struct | `WelcomeGuideChecklistRow` | 1469 |
| struct | `WelcomeGuideBottomBar` | 1525 |
| struct | `WGRandom` | 1593 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `32f6f43` | 2026-04-18 | Ship 14.0.6 Cupertino Touch Bar fix |
| `712cda3` | 2026-04-17 | Improve welcome guide Touch Bar onboarding |
| `4e417f6` | 2026-04-17 | Remove Alerts screen surface |
| `83e001c` | 2026-04-17 | Reinstall stale privileged helper |
| `7c1b882` | 2026-04-17 | Keep Touch Bar HUD always on |
| `e24d811` | 2026-04-16 | :)) |
| `ebf3e12` | 2026-04-16 | Retire redundant silent fan mode |
| `6cabf2c` | 2026-04-16 | Make onboarding copy platform-aware |
| `133d9ad` | 2026-04-16 | Replace alert surfaces with monitoring status |
| `cfea009` | 2026-04-16 | Polish launch-at-login recovery flow |
| `3672312` | 2026-04-16 | Promote dashboard shortcut in onboarding |
| `5fe6a4c` | 2026-04-16 | Harden first-launch startup and onboarding state |
| `616b507` | 2026-04-16 | Fix first-launch welcome guide persistence |
| `c408c06` | 2026-04-16 | Default fresh installs to system Touch Bar |
| `5dc29ed` | 2026-04-16 | Add privacy controls and refine Core Monitor presentation |
| `719a663` | 2026-04-16 | Refine welcome guide overflow handling |
| `844ce69` | 2026-04-16 | Fix first-launch dashboard discoverability |
| `311dc52` | 2026-04-15 | Refine first-run onboarding and weather permissions |
| `7185d36` | 2026-04-15 | Improve fan control and alert surfaces |
| `b09dbec` | 2026-04-14 | Tighten app copy and weather privacy behavior |
| `81ce4d9` | 2026-04-14 | Save current Core-Monitor rescue changes |
| `2664fd1` | 2026-04-11 | Update Core Monitor |
| `011232b` | 2026-04-11 | Update website install video |
| `3651f98` | 2026-03-29 | Remove CoreVisor and virtualization support |
| `4537bc5` | 2026-03-28 | Detect fan SMC keys and add wake-reapplied fan profiles |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
// WelcomeGuide.swift
// Core Monitor — first-launch onboarding guide
// Shown exactly once (keyed by AppStorage). No motion blur.

import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - View modifier entry-point
// ─────────────────────────────────────────────────────────────────────────────

extension View {
    /// Attaches the first-launch guide sheet. Call once on the root view.
    func welcomeGuide() -> some View {
        modifier(WelcomeGuideModifier())
    }
}

private struct WelcomeGuideModifier: ViewModifier {
    @AppStorage(WelcomeGuideProgress.hasSeenDefaultsKey) private var hasSeen = false
    @State private var presentation = WelcomeGuidePresentationController()

    func body(content: Content) -> some View {
        content
            .onAppear {
                presentation.syncStoredPreference(hasSeen: hasSeen)
            }
            .onChange(of: hasSeen) {
                presentation.syncStoredPreference(hasSeen: $0)
            }
            .sheet(isPresented: Binding(
                get: { presentation.isSheetPresented },
                set: { isPresented in
                    let dismissAction = presentation.handlePresentationChange(isPresented)
                    if dismissAction == .persistCompletion, hasSeen == false {
                        hasSeen = true
                    }
                }
            )) {
                WelcomeGuideSheet { hasSeen = true }
                    .interactiveDismissDisabled(true)
```
