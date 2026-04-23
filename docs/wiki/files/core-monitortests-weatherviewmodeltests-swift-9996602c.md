# File: Core-MonitorTests/WeatherViewModelTests.swift

## Current Role

- Area: Tests.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-MonitorTests/WeatherViewModelTests.swift`](../../../Core-MonitorTests/WeatherViewModelTests.swift) |
| Wiki area | Tests |
| Exists in current checkout | True |
| Size | 10024 bytes |
| Binary | False |
| Line count | 265 |
| Extension | `.swift` |

## Imports

`Combine`, `CoreLocation`, `XCTest`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `WeatherViewModelTests` | 4 |
| func | `testRefreshNowUsesFallbackLocationWhenAccessIsNotDetermined` | 8 |
| func | `testRefreshNowUsesFallbackProviderWhenWeatherKitCapabilityIsMissing` | 32 |
| func | `testRefreshNowRequestsLiveLocationBeforeUsingFallback` | 65 |
| func | `testRefreshNowUsesFallbackLocationWhenAuthorizedWithoutAvailableCurrentLocation` | 86 |
| func | `testStartDoesNotRequestLocationAuthorizationOnLaunch` | 108 |
| func | `testStartRefreshesImmediatelyWhenLocationAccessChanges` | 121 |
| func | `testRefreshNowUsesFallbackProviderWhenLiveProviderFails` | 153 |
| class | `RecordingWeatherProvider` | 181 |
| func | `currentWeather` | 185 |
| class | `FailingWeatherProvider` | 203 |
| struct | `TestError` | 205 |
| func | `currentWeather` | 208 |
| class | `MockWeatherLocationAccess` | 213 |
| func | `requestAccess` | 236 |
| func | `refreshStatus` | 240 |
| func | `requestCurrentLocation` | 244 |
| func | `emitChange` | 249 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `bd80f00` | 2026-04-17 | Fix fan helper recovery and weather fallback |
| `44eb999` | 2026-04-16 | Harden touch bar customization and weather fallback |
| `8bfc685` | 2026-04-16 | Stabilize signing and WeatherKit release packaging |
| `6e7215b` | 2026-04-16 | Refresh weather after location access changes |
| `e235eca` | 2026-04-16 | Add regression coverage for weather permission gating |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import XCTest
import CoreLocation
import Combine
@testable import Core_Monitor

@MainActor
final class WeatherViewModelTests: XCTestCase {
    func testRefreshNowUsesFallbackLocationWhenAccessIsNotDetermined() async {
        let provider = RecordingWeatherProvider()
        let locationAccess = MockWeatherLocationAccess(status: .notDetermined, currentLocation: nil)
        let viewModel = WeatherViewModel(provider: provider, locationAccess: locationAccess)

        await viewModel.refreshNow()

        guard let requestedLocation = provider.requestedLocation else {
            return XCTFail("Expected the weather provider to receive a fallback location.")
        }

        XCTAssertEqual(requestedLocation.coordinate.latitude, 37.3346, accuracy: 0.0001)
        XCTAssertEqual(requestedLocation.coordinate.longitude, -122.0090, accuracy: 0.0001)

        switch viewModel.state {
        case .loaded(let snapshot):
            XCTAssertEqual(snapshot.locationName, "Recorded")
        default:
            XCTFail("Expected a loaded fallback weather snapshot.")
        }

        XCTAssertEqual(locationAccess.requestAccessCallCount, 0)
        XCTAssertEqual(locationAccess.requestCurrentLocationCallCount, 0)
    }

    func testRefreshNowUsesFallbackProviderWhenWeatherKitCapabilityIsMissing() async {
        let provider = RecordingWeatherProvider()
        let fallbackProvider = RecordingWeatherProvider()
        let locationAccess = MockWeatherLocationAccess(status: .authorizedWhenInUse, currentLocation: nil)
        let viewModel = WeatherViewModel(
            provider: provider,
            locationAccess: locationAccess,
            fallbackProvider: fallbackProvider,
```
