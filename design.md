# Core Monitor Full Redesign Spec for Google Stitch

## Product Reality

Core Monitor is a native macOS utility app for Apple Silicon that combines:

- live dashboard monitoring for CPU, GPU, memory, battery, power, network, disk, and fan metrics
- optional privileged fan control through a helper
- menu bar monitoring and popovers
- Touch Bar customization
- onboarding, help, diagnostics, privacy controls, and launch-at-login setup
- a lightweight Basic Mode

The current app is implemented in SwiftUI with a custom dark shell, a manual sidebar, many rounded cards, heavy custom gradients, persistent dark-mode styling, and repeated use of ring gauges and accent pills. The redesign must keep the product breadth, but replace the current visual language with a cleaner Apple-like macOS utility experience.

## Redesign Goal

Create a complete visual and UX redesign for Core Monitor that feels like a premium first-party Apple pro utility:

- calm, precise, confident, and local-first
- much cleaner information hierarchy
- less neon, less fake glass, less decorative chrome
- more native macOS structure, materials, spacing, and motion
- stronger readability for technical users who keep the app open for hours
- full redesign of every major surface, not just the overview screen

## What Must Change From The Current UI

1. Remove the BetterDisplay-inspired custom shell look. No oversized bespoke gradients, no heavy bluish overlay, no forced custom chrome around the whole window.
2. Stop making every metric the same visual weight. The current dashboard reads like a wall of equally loud cards.
3. Reduce ring-gauge overuse. Reserve circular visuals for a few places where they genuinely help.
4. Replace the current always-dark, almost game-like aesthetic with adaptive macOS materials that work in light and dark mode.
5. Make system status, helper state, onboarding, and setup flows feel intentional and trustworthy, not like miscellaneous cards mixed into the dashboard.
6. Redesign the menu bar popover to feel tighter, faster, and more premium.
7. Redesign fan control so it feels safer and more legible, especially custom curves and helper-backed actions.
8. Redesign Touch Bar customization so it behaves like a proper builder workflow instead of another generic settings page.

## Experience Principles

1. Native first. Use standard macOS split views, toolbars, sheets, search fields, segmented controls, toggles, inspectors, and materials before inventing custom surfaces.
2. Hierarchy over decoration. The most important thing on every screen should be obvious in under two seconds.
3. Calm density. This is a pro utility, so it can be information-rich, but the density should feel deliberate and breathable.
4. Semantic color only. Color should indicate thermal pressure, warning, activity, or selection. Do not tint things for decoration.
5. Motion with purpose. Animations should explain state changes, focus shifts, and live updates, never act like flashy flourish.
6. Trust and safety. Fan control, helper install state, SMC availability, and system-owned cooling should feel explicit and safe at all times.

## Platform Direction

- Treat this as a macOS 15+ utility window, not a mobile dashboard and not a web admin panel.
- Prefer a `NavigationSplitView` mental model with a native translucent sidebar, a toolbar, and a main content region.
- Respect system light mode and dark mode automatically.
- Use system materials and subtle depth. Avoid custom opaque overlays that fight toolbar/sidebar materials.
- Keep the window feeling like one coherent Apple desktop app, not a collection of isolated cards inside a novelty shell.

## Information Architecture

Keep the product structure, but reorganize it into clearer groups.

### Primary Navigation

1. Overview
2. Thermals
3. Memory
4. Fans
5. Battery

### Secondary Navigation

1. Menu Bar
2. Touch Bar
3. System
4. Help
5. About

### Persistent Top Toolbar

- left: current section title
- center or trailing-center: optional search when relevant
- trailing: monitoring freshness pill, helper state icon, quick action for menu bar popover preview, global settings button

### Optional Inspector Pattern

Use a right-side inspector for contextual detail on complex screens:

- Thermals: sensor detail and hottest component summary
- Memory: top processes, swap context, compression context
- Fans: active profile explanation, safety notes, helper state
- Touch Bar: selected widget settings

## Visual System

### Overall Tone

- Apple-like, minimal, technical, refined
- less saturated
- more neutral backgrounds
- small, intentional accent moments

### Backgrounds

- use layered macOS materials and subtle tonal gradients only where needed
- sidebar uses native translucent material
- main content uses a soft base surface with gentle depth, not a dramatic custom gradient
- cards should often be secondary grouped surfaces, not always separate floating islands

### Color

Base palette:

- background: warm neutral graphite in dark mode, soft stone in light mode
- primary accent: restrained blue-cyan for selection and active monitoring
- success: system green
- caution: amber
- critical: system red
- thermal hot scale: yellow to orange to red

Rules:

- no purple-heavy UI
- no random blue glow on every selected item
- no bright green everywhere just because metrics are live
- green is reserved for healthy/live states, not default chrome

### Typography

- use SF Pro and SF Mono only
- section titles: large and clean, not oversized
- metric numerals: SF Mono or monospaced tabular numerals where precision matters
- supporting copy should be shorter, quieter, and more disciplined than the current copy

### Spacing

- 8pt spacing system
- compact cards use 16-20pt padding
- major section gaps 24-32pt
- sidebar item height around 36-40pt
- toolbar clean and restrained, not crowded

### Corners And Strokes

- prefer 12-20pt rounded rectangles depending on component size
- use thin separators and subtle borders only where structure needs them
- avoid constant bright outlines around every panel

## Motion System

Animation style should feel precise and macOS-native.

1. Sidebar selection: soft spring, short travel, subtle background morph.
2. Number updates: animated numeric transitions for values that change live.
3. Chart updates: line and area paths should morph smoothly over 180-240ms.
4. View switching: content crossfade plus slight vertical settle, around 180ms.
5. Hover states: low-amplitude lift or fill change, never dramatic.
6. Press states: quick compression to about 0.98 scale.
7. Sheet presentation: gentle zoom from toolbar or source control when appropriate.
8. Fan curve editing: active control point should magnetize and feel tactile during drag.
9. Popover appearance: soft fade and scale from menu bar anchor.

## Window-Level Redesign

### Main Window

- eliminate the oversized custom shell frame
- use standard macOS titlebar behavior with transparent titlebar and tasteful toolbar integration
- keep the app movable by background, but visually let the window feel native
- content width should feel balanced around 1160-1320px
- do not force dark mode

### Sidebar

- translucent native sidebar
- grouped navigation sections with more obvious hierarchy between monitoring and configuration surfaces
- monochrome icons by default, accented only on selection
- remove the oversized red quit button from the permanent footer
- move quit to app menu; footer should instead contain:
  - mode switch for Basic Mode
  - app version
  - small status summary

## Screen-By-Screen Redesign

## 1. Overview

This becomes the hero screen and should feel editorial, not crowded.

### Layout

- top hero band with system identity:
  - Mac model
  - monitoring freshness
  - thermal state
  - helper state
  - optional quick action buttons
- first row: 3 large hero modules
  - CPU activity
  - thermal health
  - memory pressure
- second row: 4 medium live modules
  - GPU or power
  - fan state
  - network throughput
  - battery summary when present
- lower area: trend studio with segmented time range

### Hero Module Design

- use cleaner linear microcharts instead of huge circular gauges
- each hero card includes:
  - label
  - current value
  - one-line interpretation
  - tiny history visualization
  - delta or context badge

### Overview Behavior

- if a metric is unavailable, show a quiet unavailable state with reason
- do not let empty space collapse awkwardly if battery is missing on desktop Macs
- support quick compare at a glance without overwhelming the user

## 2. Thermals

This should feel like a serious thermal console, not just another set of cards.

### Layout

- top summary row:
  - current thermal pressure
  - hottest readable sensor
  - CPU package temp
  - GPU temp
- main panel:
  - thermal timeline chart with selectable series
- secondary area:
  - grouped sensor list by component
  - hottest components pinboard
- inspector:
  - selected sensor details
  - sampling freshness
  - explanation of missing sensors

### Design Notes

- prioritize trend charts and grouped sensor tables over repeated ring gauges
- use semantic heat coloring only inside data visuals and badges
- sensor explorer should look like a clean source list or table, not a card dump

## 3. Memory

Make this feel analytical and diagnostic.

### Layout

- top row:
  - memory pressure state
  - used vs available
  - compressed memory
  - swap used
- main visualization:
  - stacked memory composition chart
- bottom split:
  - top processes list with app icons
  - swap and pressure explanation panel

### Design Notes

- process list should feel like Activity Monitor meets Apple Settings
- privacy mode must be obvious and trustworthy
- if process insights are disabled, show a respectful empty state with an enable action

## 4. Fans

This must be redesigned as the most safety-critical screen in the app.

### Layout

- top safety banner:
  - current cooling owner: system or Core Monitor
  - helper status
  - active fan profile
- main control area:
  - profile picker as a segmented control or chip row
  - current RPM and target RPM panels
  - per-fan cards only if multiple fans are present
- advanced section:
  - custom curve editor in a dedicated sheet or split panel
  - safety rules
  - supported range
  - restore system auto action

### Fan Curve Editor

- dedicated editor surface
- large chart with temperature on x-axis and fan percentage on y-axis
- draggable points with magnetized feedback
- templates on the left or top
- live preview summary on the right
- bottom actions:
  - save preset
  - duplicate preset
  - revert changes
  - restore default

### Safety UX

- system-owned cooling state should feel reassuring and explicit
- dangerous or helper-required actions must feel deliberate
- show helper trust and connection state inline, not buried

## 5. Battery

Make this feel like a clean Apple battery health dashboard.

### Layout

- hero battery card with:
  - charge percent
  - charging/discharging state
  - time remaining or time to full
  - health percent
- secondary data grid:
  - cycles
  - voltage
  - amperage/current
  - watt draw
  - temperature
  - power source
- optional lower chart:
  - recent charge or power draw history

### Design Notes

- use familiar battery health language
- visually distinguish charge level from health
- avoid making the battery screen look identical to CPU or thermals

## 6. Menu Bar

Split this into two redesigned experiences.

### Menu Bar Configuration Screen

- move it into its own dedicated screen instead of burying it inside generic System content
- show a live preview strip of enabled menu bar items
- presets displayed as elegant cards with density guidance
- toggles displayed in a cleaner list with sample values

### Menu Bar Popover

The popover should feel premium, compact, and fast.

Structure:

1. header with app icon, Mac name, monitoring state
2. primary summary row with 4 most relevant metrics
3. secondary metrics list
4. quick actions
5. footer with dashboard and settings access

Behavior:

- no cluttered wall of equally styled rows
- emphasize CPU temp, CPU load, memory, fan state, and battery when available
- quick actions should include:
  - Open Dashboard
  - Restore System Auto
  - Open Fan Controls
  - Open Help

## 7. Touch Bar

This needs a true builder workflow.

### Layout

- top preview strip showing current Touch Bar composition
- left library of available widgets
- center active layout lane
- right inspector for selected widget settings

### Widget Categories

- system status
- hardware
- weather
- launchers
- custom command widgets

### Key Interactions

- drag to add
- drag to reorder
- tap to edit
- live width usage meter
- preset save/apply flow

### Visual Tone

- feel like Apple customization UI, not a generic settings form
- preview strip should have strong clarity and delightful motion

## 8. System

This becomes the operational health and trust center.

### Layout

- status grid:
  - monitoring freshness
  - helper reachability
  - SMC access
  - thermal state
  - launch at login
  - dashboard shortcut
- control groups:
  - privacy
  - launch at login
  - helper diagnostics
  - audio/brightness quick controls only if worth keeping

### Design Notes

- helper diagnostics should feel like a proper support panel
- export report should look like an action inside a trusted diagnostic surface
- reduce the sense that unrelated controls were dumped into one page

## 9. Help

Redesign Help as a searchable knowledge center.

### Layout

- native search at top
- left topic index
- main article content
- optional quick links or callouts for common tasks

### Design Notes

- keep the content approachable and calm
- show common actions inline:
  - install helper
  - open login items
  - fix menu bar visibility
  - open weather permissions
- use a documentation aesthetic closer to Apple Support and Xcode help

## 10. About

Make About feel brand-clean and credible.

Include:

- app identity
- version and build
- local-first/privacy statement
- open-source credibility
- links to release notes, documentation, and support
- experimental features separated from core app details

Do not make About feel like a second dashboard.

## 11. Onboarding / Welcome Guide

The current onboarding already covers menu bar access, fan helper, Touch Bar, and shortcuts. Keep that scope but redesign it to feel much more premium.

### Flow

1. Welcome and product value
2. Monitoring and menu bar access
3. Fan control safety and helper explanation
4. Touch Bar and customization
5. Final readiness checklist

### Visual Style

- horizontally paged cards or a clean stepped flow
- rich but restrained illustration-style system visuals
- strong setup checklist at the end
- obvious actions for:
  - keep at least one menu bar item visible
  - enable dashboard shortcut
  - install helper only if needed
  - enable launch at login

## 12. Basic Mode

Basic Mode should not feel like a different app. It should feel like a focused compact presentation of the same design system.

### Basic Mode Contents

- single-page overview
- 4 to 6 key metrics max
- menu bar and dashboard access preserved
- one-click return to Full Mode

## Component System

Create a reusable component language.

Core components:

- hero metric card
- compact metric row
- trend card
- section header with status metadata
- source-list style navigation row
- status pill
- semantic banner
- diagnostic panel
- editable chart panel
- preset chip
- popover metric row
- empty state
- permission state
- helper-required state

## Data Visualization Rules

1. Use line and area charts for trends.
2. Use stacked bars or composition charts for memory.
3. Use circular visuals sparingly.
4. Show units clearly and consistently.
5. Use monospaced digits for live values.
6. Make unavailable data graceful, not broken-looking.
7. Avoid charts that feel decorative but provide no extra information.

## Accessibility And Readability

- support dynamic type ranges appropriate for macOS utilities
- maintain strong contrast in both light and dark mode
- do not encode important state with color alone
- all actions should remain clear with keyboard navigation
- the fan-control surface must be understandable without relying only on color

## Hard Constraints

1. Keep this unmistakably a Mac app.
2. Do not redesign it as an iPad app or browser dashboard.
3. Do not remove menu bar workflows.
4. Do not remove Basic Mode.
5. Do not remove helper diagnostics, privacy controls, onboarding, or Touch Bar customization.
6. Keep fan control safety and system-auto restore prominent.
7. Use modern Apple-like materials and motion, but avoid exaggerated fake glass.

## Output Expectation For Stitch

Produce a full redesign that includes:

- main app window in light and dark mode
- Overview
- Thermals
- Memory
- Fans
- Battery
- System
- Menu Bar settings
- Menu Bar popover
- Touch Bar builder
- Help center
- About
- onboarding flow
- Basic Mode

The result should look like a coherent Apple-quality redesign system, not a one-off concept screen.
