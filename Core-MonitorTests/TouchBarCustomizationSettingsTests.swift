import XCTest
@testable import Core_Monitor

@MainActor
final class TouchBarCustomizationSettingsTests: XCTestCase {
    func testFreshConfigurationKeepsLiveWeatherOff() {
        let settings = makeSettings(suiteName: "TouchBarCustomizationSettingsTests.freshWeather")

        XCTAssertFalse(settings.weatherEnabled)
        XCTAssertFalse(settings.contains(.weather))
    }

    func testEnablingLiveWeatherAddsWidgetAndPersistsConsent() {
        let suiteName = "TouchBarCustomizationSettingsTests.enableWeather"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Expected a dedicated defaults suite for Touch Bar tests.")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let settings = TouchBarCustomizationSettings(defaults: defaults)
        settings.setWeatherEnabled(true)

        XCTAssertTrue(settings.weatherEnabled)
        XCTAssertTrue(settings.contains(.weather))

        let restored = TouchBarCustomizationSettings(defaults: defaults)
        XCTAssertTrue(restored.weatherEnabled)
        XCTAssertTrue(restored.contains(.weather))
    }

    func testLegacyConfigurationDoesNotImplicitlyConsentToLiveWeather() throws {
        let suiteName = "TouchBarCustomizationSettingsTests.legacyWeather"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Expected a dedicated defaults suite for Touch Bar tests.")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let legacyConfiguration = LegacyTouchBarConfigurationV6(
            theme: "dark",
            items: [.builtIn(.weather), .builtIn(.cpu)],
            presentationMode: .app
        )
        defaults.set(
            try JSONEncoder().encode(legacyConfiguration),
            forKey: "coremonitor.touchBarConfiguration.v6"
        )

        let settings = TouchBarCustomizationSettings(defaults: defaults)

        XCTAssertFalse(settings.weatherEnabled)
        XCTAssertTrue(settings.contains(.weather))
    }

    func testNormalizedItemsDeduplicatesBuiltInsAndPinnedPaths() {
        let appPath = "/Applications/Utilities/Terminal.app"
        let folderPath = "/Applications"
        let items: [TouchBarItemConfiguration] = [
            .builtIn(.weather),
            .builtIn(.weather),
            .pinnedApp(
                TouchBarPinnedApp(
                    id: "app-1",
                    displayName: "Terminal",
                    filePath: appPath,
                    bundleIdentifier: "com.apple.Terminal"
                )
            ),
            .pinnedApp(
                TouchBarPinnedApp(
                    id: "app-2",
                    displayName: "Terminal Again",
                    filePath: appPath,
                    bundleIdentifier: "com.apple.Terminal"
                )
            ),
            .pinnedFolder(
                TouchBarPinnedFolder(
                    id: "folder-1",
                    displayName: "Applications",
                    folderPath: folderPath
                )
            ),
            .pinnedFolder(
                TouchBarPinnedFolder(
                    id: "folder-2",
                    displayName: "Applications Again",
                    folderPath: folderPath
                )
            )
        ]

        let normalized = TouchBarCustomizationSettings.normalizedItems(items)

        XCTAssertEqual(
            normalized,
            [
                .builtIn(.weather),
                .pinnedApp(
                    TouchBarPinnedApp(
                        id: "app-1",
                        displayName: "Terminal",
                        filePath: appPath,
                        bundleIdentifier: "com.apple.Terminal"
                    )
                ),
                .pinnedFolder(
                    TouchBarPinnedFolder(
                        id: "folder-1",
                        displayName: "Applications",
                        folderPath: folderPath
                    )
                )
            ]
        )
    }

    func testAddPinnedAppsSkipsDuplicatePaths() {
        let settings = makeSettings(suiteName: "TouchBarCustomizationSettingsTests.addPinnedApps")
        let appURL = URL(fileURLWithPath: "/Applications/Utilities/Terminal.app")

        settings.addPinnedApps(urls: [appURL, appURL])

        let pinnedApps = settings.items.compactMap { item -> TouchBarPinnedApp? in
            guard case .pinnedApp(let app) = item else { return nil }
            return app
        }

        XCTAssertEqual(pinnedApps.count, 1)
        XCTAssertEqual(pinnedApps.first?.filePath, appURL.path)
    }

    private func makeSettings(suiteName: String) -> TouchBarCustomizationSettings {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Expected a dedicated defaults suite for Touch Bar tests.")
        }
        defaults.removePersistentDomain(forName: suiteName)
        return TouchBarCustomizationSettings(defaults: defaults)
    }
}

private struct LegacyTouchBarConfigurationV6: Encodable {
    let theme: String
    let items: [TouchBarItemConfiguration]
    let presentationMode: TouchBarPresentationMode
}

@MainActor
final class CoreMonTouchBarControllerTests: XCTestCase {
    func testWeatherMonitoringStaysIdleWithoutExplicitOptIn() async {
        let settings = makeSettings(suiteName: "CoreMonTouchBarControllerTests.weatherOptIn")
        settings.items = [.builtIn(.weather), .builtIn(.cpu)]
        let monitor = SystemMonitor()
        let controller = CoreMonTouchBarController(
            weatherProvider: MockWeatherService(),
            monitor: monitor,
            customizationSettings: settings
        )

        controller.start()
        try? await Task.sleep(nanoseconds: 50_000_000)
        controller.stop()

        guard case .idle = controller.weatherViewModel.state else {
            return XCTFail("Weather monitoring must not start without persisted opt-in.")
        }
    }

    func testReloadCustomizationRebuildsTouchBarWithUpdatedIdentifiers() {
        let settings = makeSettings(suiteName: "CoreMonTouchBarControllerTests.reloadCustomization")
        settings.items = [.builtIn(.weather), .builtIn(.cpu)]

        let controller = CoreMonTouchBarController(
            weatherProvider: MockWeatherService(),
            customizationSettings: settings
        )

        let initialTouchBar = controller.touchBar
        XCTAssertEqual(
            controller.touchBar.defaultItemIdentifiers,
            [
                TouchBarItemConfiguration.builtIn(.weather).touchBarIdentifier,
                TouchBarItemConfiguration.builtIn(.cpu).touchBarIdentifier
            ]
        )

        settings.items = [.builtIn(.cpu), .builtIn(.network)]
        controller.reloadCustomization()

        XCTAssertFalse(controller.touchBar === initialTouchBar)
        XCTAssertEqual(
            controller.touchBar.defaultItemIdentifiers,
            [
                TouchBarItemConfiguration.builtIn(.cpu).touchBarIdentifier,
                TouchBarItemConfiguration.builtIn(.network).touchBarIdentifier
            ]
        )
    }

    private func makeSettings(suiteName: String) -> TouchBarCustomizationSettings {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Expected a dedicated defaults suite for Touch Bar controller tests.")
        }
        defaults.removePersistentDomain(forName: suiteName)
        return TouchBarCustomizationSettings(defaults: defaults)
    }
}
