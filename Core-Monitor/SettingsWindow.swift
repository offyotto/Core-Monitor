import AppKit
import SwiftUI

// MARK: - Window manager

/// Owns the single Settings window, HIG-style (⌘, and the toolbar gear).
@MainActor
final class SettingsWindowManager: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowManager()

    private var window: NSWindow?
    private var systemMonitor: SystemMonitor?
    private var fanController: FanController?
    private var startupManager: StartupManager?

    /// Called once at launch so any surface (toolbar, popovers, app menu)
    /// can open Settings without threading dependencies around.
    func configure(
        systemMonitor: SystemMonitor,
        fanController: FanController,
        startupManager: StartupManager
    ) {
        self.systemMonitor = systemMonitor
        self.fanController = fanController
        self.startupManager = startupManager
    }

    func show(tab: SettingsTab = .general) {
        guard let startupManager else { return }

        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let rootView = SettingsView(
            startupManager: startupManager,
            initialTab: tab
        )
        let hostingController = NSHostingController(rootView: rootView)
        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.title = "Core Monitor Settings"
        newWindow.styleMask = [.titled, .closable]
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = self
        newWindow.center()

        window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case menuBar
    case touchBar
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .menuBar: return "Menu Bar"
        case .touchBar: return "Touch Bar"
        case .about: return "About"
        }
    }

    var symbolName: String {
        switch self {
        case .general: return "gearshape"
        case .menuBar: return "menubar.rectangle"
        case .touchBar: return "rectangle.and.hand.point.up.left"
        case .about: return "info.circle"
        }
    }
}

// MARK: - Root

struct SettingsView: View {
    @ObservedObject var startupManager: StartupManager
    @State private var tab: SettingsTab

    init(
        startupManager: StartupManager,
        initialTab: SettingsTab = .general
    ) {
        self.startupManager = startupManager
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        TabView(selection: $tab) {
            GeneralSettingsTab(startupManager: startupManager)
                .tabItem { Label(SettingsTab.general.title, systemImage: SettingsTab.general.symbolName) }
                .tag(SettingsTab.general)

            MenuBarSettingsTab()
                .tabItem { Label(SettingsTab.menuBar.title, systemImage: SettingsTab.menuBar.symbolName) }
                .tag(SettingsTab.menuBar)

            TouchBarSettingsTab()
                .tabItem { Label(SettingsTab.touchBar.title, systemImage: SettingsTab.touchBar.symbolName) }
                .tag(SettingsTab.touchBar)

            AboutSettingsTab()
                .tabItem { Label(SettingsTab.about.title, systemImage: SettingsTab.about.symbolName) }
                .tag(SettingsTab.about)
        }
        .frame(width: 560)
        .frame(minHeight: 430)
    }
}

// MARK: - General

private struct GeneralSettingsTab: View {
    @ObservedObject var startupManager: StartupManager
    @ObservedObject private var privacySettings = PrivacySettings.shared
    @AppStorage(AppLocaleStore.localeOverrideKey) private var localeOverrideIdentifier = AppLocaleStore.systemLocaleValue

    var body: some View {
        let launchSummary = LaunchAtLoginStatusSummary.make(
            status: startupManager.state,
            errorMessage: startupManager.errorMessage
        )

        Form {
            Section {
                Toggle("Open Core Monitor at login", isOn: launchBinding)
                LabeledContent("Status", value: launchSummary.badge)
                if launchSummary.detail.isEmpty == false {
                    Text(launchSummary.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if launchSummary.action == .openSystemSettings {
                    Button(launchSummary.actionTitle ?? "Open Login Items") {
                        startupManager.openLoginItemsSettings()
                    }
                }
            } header: {
                Text("Startup")
            }

            Section {
                Toggle("Show app names in process lists", isOn: $privacySettings.processInsightsEnabled)
            } header: {
                Text("Privacy")
            } footer: {
                Text("Hardware readings never leave this Mac. App names are optional and only used to explain CPU and memory activity.")
            }

            Section {
                Picker("Language", selection: $localeOverrideIdentifier) {
                    Text("System Default").tag(AppLocaleStore.systemLocaleValue)
                    ForEach(AppLocaleStore.supportedLocaleIdentifiers, id: \.self) { identifier in
                        Text(AppLocaleStore.optionLabel(for: identifier)).tag(identifier)
                    }
                }
            } header: {
                Text("Language")
            } footer: {
                Text(AppLocaleStore.selectionSummary(for: localeOverrideIdentifier))
            }
        }
        .formStyle(.grouped)
    }

    private var launchBinding: Binding<Bool> {
        Binding {
            startupManager.isEnabled
        } set: { enabled in
            startupManager.setEnabled(enabled)
        }
    }
}

// MARK: - Menu bar

private struct MenuBarSettingsTab: View {
    @ObservedObject private var menuBarSettings = MenuBarSettings.shared

    var body: some View {
        Form {
            Section {
                Picker("Preset", selection: presetBinding) {
                    ForEach(MenuBarVisibilityPreset.allCases, id: \.title) { preset in
                        Text(preset.title).tag(preset.title)
                    }
                }
            } header: {
                Text("Preset")
            } footer: {
                if let warning = menuBarSettings.lastWarning {
                    Text(warning)
                }
            }

            Section {
                ForEach(MenuBarItemKind.allCases, id: \.defaultsKey) { kind in
                    Toggle(isOn: itemBinding(kind)) {
                        Label(kind.title, systemImage: kind.systemImageName)
                    }
                }
            } header: {
                Text("Items")
            } footer: {
                Text("Each item is its own menu bar readout with a live popover.")
            }
        }
        .formStyle(.grouped)
    }

    private var presetBinding: Binding<String> {
        Binding {
            (menuBarSettings.activePreset ?? MenuBarSettings.defaultPreset).title
        } set: { title in
            guard let preset = MenuBarVisibilityPreset.allCases.first(where: { $0.title == title }) else { return }
            menuBarSettings.applyPreset(preset)
        }
    }

    private func itemBinding(_ kind: MenuBarItemKind) -> Binding<Bool> {
        Binding {
            menuBarSettings.isEnabled(kind)
        } set: { enabled in
            menuBarSettings.setEnabled(enabled, for: kind)
        }
    }
}

// MARK: - Touch Bar

private struct TouchBarSettingsTab: View {
    @ObservedObject private var settings = TouchBarCustomizationSettings.shared

    var body: some View {
        Form {
            Section("Presentation") {
                Picker("Hardware Touch Bar", selection: presentationBinding) {
                    ForEach(TouchBarPresentationMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Theme", selection: themeBinding) {
                    ForEach(TouchBarTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.segmented)

                LabeledContent("Estimated width", value: "\(Int(settings.estimatedWidth.rounded())) pt")
                if settings.widthOverflow > 0 {
                    Text("This layout exceeds the recommended Touch Bar width.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section {
                Toggle("Enable Live Weather", isOn: weatherBinding)
            } header: {
                Text("Live Weather")
            } footer: {
                Text("Off by default. Enabling this adds the Weather widget, requests location access, and contacts Apple WeatherKit and CoreLocation. Core-Monitor does not receive this data.")
            }

            Section("Presets") {
                ForEach(TouchBarPreset.all) { preset in
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(preset.title)
                            Text(preset.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(settings.activePreset == preset ? "Selected" : "Use") {
                            settings.applyPreset(preset)
                        }
                        .disabled(settings.activePreset == preset)
                    }
                }
                Button("Restore Defaults") {
                    settings.restoreDefaults()
                }
            }

            Section("Active Items") {
                ForEach(Array(settings.items.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title)
                            Text(item.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Button {
                            settings.moveUp(item)
                        } label: {
                            Image(systemName: "chevron.up")
                        }
                        .buttonStyle(.borderless)
                        .disabled(index == 0)
                        .help("Move up")

                        Button {
                            settings.moveDown(item)
                        } label: {
                            Image(systemName: "chevron.down")
                        }
                        .buttonStyle(.borderless)
                        .disabled(index == settings.items.count - 1)
                        .help("Move down")

                        Button {
                            settings.remove(item)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .disabled(settings.items.count <= 1)
                        .help("Remove")
                    }
                }
            }

            Section("Built-In Widgets") {
                ForEach(TouchBarWidgetKind.allCases.filter { $0 != .weather }) { kind in
                    Toggle(kind.title, isOn: widgetBinding(kind))
                }
            }
        }
        .formStyle(.grouped)
    }

    private var presentationBinding: Binding<String> {
        Binding {
            settings.presentationMode.rawValue
        } set: { rawValue in
            settings.presentationMode = TouchBarPresentationMode(rawValue: rawValue) ?? .app
        }
    }

    private var themeBinding: Binding<TouchBarTheme> {
        Binding {
            settings.theme
        } set: { theme in
            settings.theme = theme
        }
    }

    private var weatherBinding: Binding<Bool> {
        Binding {
            settings.weatherEnabled
        } set: { enabled in
            settings.setWeatherEnabled(enabled)
        }
    }

    private func widgetBinding(_ kind: TouchBarWidgetKind) -> Binding<Bool> {
        Binding {
            settings.contains(kind)
        } set: { _ in
            settings.toggle(kind)
        }
    }
}

// MARK: - About

private struct AboutSettingsTab: View {
    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSImage(named: "AppIcon") ?? NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Core Monitor")
                            .font(.title3.weight(.semibold))
                        Text("Version \(AppVersion.current)")
                            .foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Mac", value: MacModelRegistry.displayName(for: SystemMonitor.hostModelIdentifier()))
                LabeledContent("Model identifier", value: SystemMonitor.hostModelIdentifier())
            }

            Section("Links") {
                Link("Website", destination: CoreMonitorShareKit.websiteURL)
                Link("Latest release", destination: CoreMonitorShareKit.latestReleaseURL)
                Link("Source on GitHub", destination: CoreMonitorShareKit.repositoryURL)
            }

            Section {
                Button("Quit Core Monitor", role: .destructive) {
                    NSApp.terminate(nil)
                }
            }
        }
        .formStyle(.grouped)
    }
}
