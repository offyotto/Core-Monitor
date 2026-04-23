# File: Core-Monitor/WeatherService.swift

## Current Role

- Owns WeatherKit capability detection, optional location access, fallback coordinates, attribution, and view-model state.
- Startup behavior is intentionally permission-safe: location prompting should only happen after explicit user intent.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/WeatherService.swift`](../../../Core-Monitor/WeatherService.swift) |
| Wiki area | Weather and location |
| Exists in current checkout | True |
| Size | 18392 bytes |
| Binary | False |
| Line count | 545 |
| Extension | `.swift` |

## Imports

`Combine`, `CoreLocation`, `Foundation`, `Security`, `WeatherKit`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| struct | `WeatherSnapshot` | 12 |
| struct | `WeatherAttributionSnapshot` | 25 |
| enum | `WeatherKitCapability` | 32 |
| protocol | `WeatherProviding` | 51 |
| func | `currentWeather` | 53 |
| protocol | `WeatherLocationAccessControlling` | 55 |
| func | `requestAccess` | 61 |
| func | `refreshStatus` | 62 |
| func | `requestCurrentLocation` | 63 |
| class | `WeatherLocationAccessController` | 65 |
| func | `requestAccess` | 91 |
| func | `refreshStatus` | 96 |
| func | `requestCurrentLocation` | 100 |
| func | `applyLocationManagerState` | 140 |
| func | `applyResolvedLocation` | 166 |
| func | `requestLocationIfNeeded` | 175 |
| func | `finishLocationRequests` | 196 |
| class | `LiveWeatherService` | 237 |
| class | `MockWeatherService` | 318 |
| func | `currentWeather` | 320 |
| func | `loadWeatherAttribution` | 340 |
| enum | `WeatherState` | 360 |
| class | `WeatherViewModel` | 367 |
| func | `start` | 407 |
| func | `stop` | 414 |
| func | `bindLocationAccess` | 424 |
| func | `scheduleRefresh` | 436 |
| func | `refreshNow` | 447 |
| func | `errorMessage` | 494 |
| func | `refreshFallbackWeather` | 508 |
| func | `loadWeatherSnapshot` | 527 |
| func | `fetchWeatherSnapshot` | 532 |
| func | `applyLoadedSnapshot` | 539 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `29afd92` | 2026-04-18 | Ship 14.0.7 localization update |
| `bd80f00` | 2026-04-17 | Fix fan helper recovery and weather fallback |
| `44eb999` | 2026-04-16 | Harden touch bar customization and weather fallback |
| `e486572` | 2026-04-16 | Scope detailed sampling to active monitoring views |
| `8bfc685` | 2026-04-16 | Stabilize signing and WeatherKit release packaging |
| `6e7215b` | 2026-04-16 | Refresh weather after location access changes |
| `adede3f` | 2026-04-16 | Clean up warning baseline for menu bar and weather |
| `f259317` | 2026-04-16 | Finish Xcode 16.2 CI repair |
| `3fff2ff` | 2026-04-16 | Fix Xcode 16.2 CI compatibility |
| `e235eca` | 2026-04-16 | Add regression coverage for weather permission gating |
| `311dc52` | 2026-04-15 | Refine first-run onboarding and weather permissions |
| `4d78a8f` | 2026-04-15 | e |
| `2664fd1` | 2026-04-11 | Update Core Monitor |
| `011232b` | 2026-04-11 | Update website install video |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
// WeatherService.swift
// Core-Monitor — WeatherKit data layer
// Requires: WeatherKit entitlement + Privacy Usage string in Info.plist

import Foundation
import Combine
import WeatherKit
import CoreLocation
import Security

// MARK: - Domain model

struct WeatherSnapshot: Sendable {
    let locationName: String
    let symbolName: String      // SF Symbol name
    let temperature: Double     // Celsius
    let condition: String       // Short label e.g. "Partly Cloudy"
    let nextRainSummary: String
    let high: Double
    let low: Double
    let feelsLike: Double
    let humidity: Int           // 0-100
    let updatedAt: Date
}

struct WeatherAttributionSnapshot: Sendable {
    let legalPageURL: URL
    let markURL: URL
    let serviceName: String
    let legalText: String?
}

enum WeatherKitCapability {
    private static let entitlementKey = "com.apple.developer.weatherkit"

    static func isEnabled() -> Bool {
        guard let task = SecTaskCreateFromSelf(nil),
              let entitlement = SecTaskCopyValueForEntitlement(task, entitlementKey as CFString, nil) else {
            return false
        }
```
