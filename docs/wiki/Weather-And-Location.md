# Weather And Location

Weather is optional and WeatherKit-dependent. `WeatherService.swift` abstracts providers and location access. `WeatherLocationAccessSection.swift`, `WeatherTouchBarItem.swift`, `WeatherTouchBarView.swift`, and the Pock Weather widget consume the model.

The critical behavior is permission gating. Weather should not trigger a location prompt at launch. The user must explicitly opt in. Builds without WeatherKit entitlement should show clear capability messaging instead of a vague failure.

Weather attribution is loaded separately and should respect appearance. Fallback coordinates and dormant states are tested because launch-time prompts were a real regression.
