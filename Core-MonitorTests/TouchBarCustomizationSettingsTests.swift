import XCTest
@testable import Core_Monitor

@MainActor
final class TouchBarCustomizationSettingsTests: XCTestCase {
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

@MainActor
final class CoreMonTouchBarControllerTests: XCTestCase {
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
            [.builtIn(.weather).touchBarIdentifier, .builtIn(.cpu).touchBarIdentifier]
        )

        settings.items = [.builtIn(.cpu), .builtIn(.network)]
        controller.reloadCustomization()

        XCTAssertFalse(controller.touchBar === initialTouchBar)
        XCTAssertEqual(
            controller.touchBar.defaultItemIdentifiers,
            [.builtIn(.cpu).touchBarIdentifier, .builtIn(.network).touchBarIdentifier]
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
