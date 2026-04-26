//
//  HelpView.swift
//  CoreMonitor
//
//  Created by Core Monitor Team on 2026-04-13.
//

import SwiftUI
import AppKit

struct HelpView: View {
    @AppStorage(WelcomeGuideProgress.hasSeenDefaultsKey) private var hasSeenWelcomeGuide: Bool = false
    @State private var searchText: String = ""

    // MARK: - Help Section Model
    struct HelpSection: Identifiable {
        let id: String
        let title: String
        let icon: String
        let keywords: [String]
        let content: AnyView

        func matches(query rawQuery: String) -> Bool {
            let query = rawQuery
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: AppLocaleStore.currentLocale)

            guard query.isEmpty == false else { return true }

            let searchableText = ([title] + keywords)
                .joined(separator: " ")
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: AppLocaleStore.currentLocale)

            return query
                .split(whereSeparator: \.isWhitespace)
                .allSatisfy { token in searchableText.contains(token) }
        }
    }

    // MARK: - Help Data
    private var allSections: [HelpSection] {
        [
            HelpSection(id: "overview", title: "Overview Dashboard", icon: "gauge.medium", keywords: [
                "dashboard", "cpu", "gpu", "memory", "thermal", "power", "network", "upload", "download", "throughput", "history", "trends"
            ], content: AnyView(
                HelpCard {
                    Text("The Overview Dashboard provides a comprehensive summary of your Mac’s current state including CPU, GPU, memory, thermal, power, and live network information.")
                    HelpBullet(text: "`CPU`, `GPU`, and `Memory` usage are shown with real-time graphs and numeric values.")
                    HelpBullet(text: "Thermal zones and sensor temperatures update continuously.")
                    HelpBullet(text: "Download and upload tiles surface current throughput, and the trend section keeps short rolling history for sustained transfer spikes.")
                    HelpBullet(text: "Load and thermal trend cards keep rolling 1-minute, 5-minute, and 15-minute windows so you can spot sustained pressure instead of only point-in-time spikes.")
                    HelpBullet(text: "Use the dashboard to quickly assess system performance and health.")
                }
            )),
            HelpSection(id: "thermals", title: "Thermals", icon: "thermometer.medium", keywords: [
                "temperature", "sensors", "thermal pressure", "cpu temp", "gpu temp", "ssd"
            ], content: AnyView(
                HelpCard {
                    Text("The Thermals section displays detailed temperature readings from multiple sensors across your Mac.")
                    HelpBullet(text: "Current builds surface CPU, GPU, SSD, and battery temperatures when those readings are available.")
                    HelpBullet(text: "If a temperature is missing, the app could not resolve a readable sensor key for this Mac.")
                    HelpBullet(text: "Overall thermal uses `ProcessInfo.processInfo.thermalState`, which is macOS thermal pressure rather than a guessed package sensor.")
                    HelpBullet(text: "Use the `Overview` and `System` sections to track monitoring freshness, thermal pressure, helper health, and SMC availability.")
                }
            )),
            HelpSection(id: "memory", title: "Memory", icon: "memorychip", keywords: [
                "swap", "ram", "page outs", "pressure", "compressed", "top processes"
            ], content: AnyView(
                HelpCard {
                    Text("Memory monitoring includes RAM usage, swap usage, and memory pressure visualization.")
                    HelpBullet(text: "Track real-time page ins, page outs, and compressed memory in the `Memory` tab.")
                    HelpBullet(text: "Use the memory pressure graph and top-process panel to see system memory stress and the apps most likely to be driving it.")
                }
            )),
            HelpSection(id: "fans", title: "Fans & Fan Control", icon: "fanblades.fill", keywords: [
                "helper", "manual", "curve", "rpm", "scan fan keys", "automatic"
            ], content: AnyView(
                HelpCard {
                    Text("Manage your Mac’s fans with advanced controls and profiles.")
                    HelpBullet(text: "Fresh installs start in System mode so monitoring, notifications, and menu bar readings work normally before you opt into helper-backed fan control.")
                    HelpBullet(text: "System immediately restores the firmware curve without keeping an active profile selected. Silent uses the helper once to hand fan ownership back to the firmware curve, then stays passive while monitoring continues.")
                    HelpBullet(text: "Smart, Balanced, Performance, Max, Manual, and Custom actively write fan targets through the helper while those modes stay selected.")
                    HelpBullet(text: "The helper tool must be installed and trusted before managed fan control is reliable.")
                    HelpBullet(text: "Use `Reset to System Auto` or quit Core Monitor to hand control back to macOS.")
                    HelpBullet(text: "The `Scan Fan Keys` action checks which fan-related SMC keys respond on the current Mac. It does not calibrate RPM accuracy.")
                    HelpBullet(text: "On some Apple Silicon notebooks, manual targets only take effect after macOS has already activated the fan.")
                    HelpBullet(text: "Safety features prevent unsafe fan speeds and protect hardware integrity.")
                    Text("Use the `Fans` tab to switch profiles or adjust settings.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            )),
            HelpSection(id: "battery", title: "Battery", icon: "battery.100", keywords: [
                "cycles", "health", "charge", "capacity", "temperature", "time remaining",
                "time to full", "voltage", "current", "amperage", "power adapter"
            ], content: AnyView(
                HelpCard {
                    Text("Battery monitoring now combines battery health with live runtime and electrical details.")
                    HelpBullet(text: "The `Battery` tab shows charge, health, cycle count, temperature, voltage, current, and live power draw when those readings are available.")
                    HelpBullet(text: "Runtime copy changes with the source: `Time Remaining` while discharging and `Time to Full` while charging on adapter power.")
                    HelpBullet(text: "Source and electrical values come from macOS power-source APIs and `AppleSmartBattery`, so some fields still vary by Mac model.")
                }
            )),
            HelpSection(id: "system", title: "System Controls", icon: "gearshape", keywords: [
                "volume", "brightness", "launch at login", "login items", "helper diagnostics", "notifications", "privacy", "process names", "status history", "dashboard shortcut", "dashboard hotkey", "option command m", "status", "monitoring"
            ], content: AnyView(
                HelpCard {
                    Text("System controls enable adjusting volume, screen brightness, and launch-at-login behavior.")
                    HelpBullet(text: "Use the `System` tab or menu bar popovers to view current volume and brightness.")
                    HelpBullet(text: "Toggle `Launch at Login` to start Core Monitor automatically.")
                    HelpBullet(text: "The `System` tab now surfaces helper state, SMC access, overall thermal pressure, notification permission status, privacy mode, and monitoring freshness in dedicated status cards.")
                    HelpBullet(text: "Privacy Controls also live in the `System` tab so you can disable process-name capture without hunting through notification settings first.")
                    HelpBullet(text: "An optional global dashboard shortcut can register `Option-Command-M` so you can reopen Core Monitor even if menu bar items are hidden or hard to reach.")
                }
            )),
            HelpSection(id: "touchbar", title: "Touch Bar Customization", icon: "rectangle.3.group", keywords: [
                "widgets", "pinned apps", "folders", "custom command", "presets", "layout"
            ], content: AnyView(
                HelpCard {
                    Text("Customize your MacBook's Touch Bar with Core Monitor widgets and controls.")
                    HelpBullet(text: "Presentation modes control how the app presents widgets on the Touch Bar.")
                    HelpBullet(text: "Fresh installs stay in `System` mode until you explicitly switch Core Monitor’s Touch Bar on.")
                    HelpBullet(text: "Presets let you quickly switch between themed layouts.")
                    HelpBullet(text: "Built-in widgets include CPU usage, fan speed, battery, network, stats, and weather.")
                    HelpBullet(text: "Pin apps and folders for quick access directly from the Touch Bar.")
                    HelpBullet(text: "Add custom widgets via shell commands with a title, SF Symbol, and width.")
                    HelpBullet(text: "Theme options allow switching between available appearances.")
                    HelpBullet(text: "Width guidance warns when the active stack may clip on a full Touch Bar.")
                    Text("Weather data uses WeatherKit — attribution is required by Apple.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            )),
            HelpSection(id: "menubar", title: "Menu Bar Items and Popovers", icon: "menubar.rectangle", keywords: [
                "menu bar", "popover", "visible items", "cpu", "fan", "rpm", "memory", "network", "disk", "temperature",
                "allow in menu bar", "hidden icon", "missing icon", "macos 26", "menu bar access"
            ], content: AnyView(
                HelpCard {
                    Text("Core Monitor menu bar items provide quick overview and access to system metrics.")
                    HelpBullet(text: "Click menu bar icons to open popovers with detailed info and controls.")
                    HelpBullet(text: "Use `System` → `Menu Bar` to choose which of the CPU, Fan, Memory, Network, Disk, and Temperature items stay visible.")
                    HelpBullet(text: "The default Balanced preset keeps CPU load, live fan RPM, and temperature visible so thermal changes are easy to catch without filling the menu bar.")
                    HelpBullet(text: "At least one menu bar item must stay enabled so the app remains reachable after launch.")
                    HelpBullet(text: "If Core Monitor is running but its icons are still missing, open System Settings → Menu Bar and re-enable the app there on newer macOS releases before assuming monitoring failed.")
                }
            )),
            HelpSection(id: "basic", title: "Basic Mode", icon: "square.grid.2x2.fill", keywords: [
                "lightweight", "simplified", "full ui", "essential metrics"
            ], content: AnyView(
                HelpCard {
                    Text("Basic Mode simplifies Core Monitor’s interface and monitoring options.")
                    HelpBullet(text: "Recommended for a lightweight experience with essential metrics.")
                    HelpBullet(text: "Switch back to Full UI any time from the header button.")
                }
            )),
            HelpSection(id: "weather", title: "Weather Permission Tips", icon: "cloud.sun.rain.fill", keywords: [
                "location", "weatherkit", "permission", "location services", "forecast"
            ], content: AnyView(
                HelpCard {
                    Text("Core Monitor uses WeatherKit data in WeatherKit-enabled builds, and location access upgrades the weather widget from a fallback forecast to your local conditions.")
                    HelpBullet(text: "Core Monitor only requests location after the live weather widget is shown.")
                    HelpBullet(text: "Without location access, the Touch Bar weather item can still fall back to a non-local forecast.")
                    HelpBullet(text: "Grant Core Monitor access to your location in System Settings → Privacy & Security → Location Services for local conditions and rain timing.")
                    HelpBullet(text: "If weather data fails to load, ensure the current build is signed with the WeatherKit entitlement.")
                }
            )),
            HelpSection(id: "smc", title: "SMC Access and Helper Install", icon: "cpu.fill", keywords: [
                "apple smc", "helper", "privileged", "fan control", "reset to system auto"
            ], content: AnyView(
                HelpCard {
                    Text("Core Monitor reads sensors via AppleSMC. Fan writes require the bundled helper.")
                    HelpBullet(text: "The helper is signed and uses the macOS authorization sheet on first use.")
                    HelpBullet(text: "Core Monitor starts in system-owned cooling. Helper state matters after you switch into Smart, Balanced, Performance, Max, Manual, or Custom.")
                    HelpBullet(text: "Use the `System` tab’s `Helper Diagnostics` card to recheck helper trust or export a support report without reopening onboarding.")
                    HelpBullet(text: "Use `Reset to System Auto` in the Fans section to restore default behavior immediately; Core Monitor also best-effort restores system auto when the app quits.")
                }
            )),
            HelpSection(id: "troubleshooting", title: "Troubleshooting", icon: "wrench.and.screwdriver", keywords: [
                "missing sensors", "helper diagnostics", "weather unavailable", "login items", "touch bar clipping"
            ], content: AnyView(
                HelpCard {
                    Text("Common issues and solutions:")
                        .fontWeight(.semibold)
                    HelpBullet(text: "If sensors are missing, restart Core Monitor and verify SMC access.")
                    HelpBullet(text: "Fan control not working? Use `System` → `Helper Diagnostics` to recheck or export a support report, then reset to system auto and run `Scan Fan Keys`.")
                    HelpBullet(text: "Weather unavailable? Check location permissions and WeatherKit configuration.")
                    HelpBullet(text: "Login item requires approval — open System Settings → General → Login Items.")
                    HelpBullet(text: "Menu bar items missing even though the app is running? Open System Settings → Menu Bar and re-enable Core Monitor there, then confirm at least one item stays enabled in `System` → `Menu Bar`.")
                    HelpBullet(text: "Touch Bar clipping — reduce active items or apply a narrower preset.")
                }
            ))
        ]
    }

    // MARK: - Filtered Sections
    private var filteredSections: [HelpSection] {
        let query = trimmedSearchText
        guard !query.isEmpty else { return allSections }
        return allSections.filter { $0.matches(query: query) }
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        if filteredSections.isEmpty == false {
                            sidebarIndex(proxy: proxy)
                        }

                        if trimmedSearchText.isEmpty == false {
                            Text("\(filteredSections.count) topic\(filteredSections.count == 1 ? "" : "s") for \"\(trimmedSearchText)\"")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }

                        if filteredSections.isEmpty {
                            HelpSearchEmptyState(query: trimmedSearchText)
                        } else {
                            ForEach(filteredSections) { section in
                                SectionView(section: section)
                                    .id(section.id)
                            }
                        }

                        footer
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
                    .frame(maxWidth: 900)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .preferredColorScheme(.dark)
        .background(
            .regularMaterial
        )
    }

    // MARK: - Header
    @ViewBuilder
    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "questionmark.circle.fill")
                .font(.title2.weight(.semibold))
                .foregroundColor(.accentColor)
            Text("Core Monitor Help")
                .font(.title3.weight(.semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .layoutPriority(1)
            
            Spacer(minLength: 8)
            
            searchField
            
            Spacer(minLength: 8)
            
            HStack(spacing: 8) {
                Button(action: { hasSeenWelcomeGuide = false }) {
                    Text("Reopen Welcome Guide")
                }
                .buttonStyle(PrimaryButtonStyle())
                
                Button(action: { hasSeenWelcomeGuide = true }) {
                    Text("Mark Guide Seen")
                }
                .buttonStyle(BorderedAccentButtonStyle())
            }
            .layoutPriority(1)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 13, weight: .medium))
            TextField("Search Sections", text: $searchText)
                .textFieldStyle(.plain)
                .frame(minWidth: 100, maxWidth: 180)
                .disableAutocorrection(true)
            if trimmedSearchText.isEmpty == false {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("Clear help search")
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Sidebar-like Index
    @ViewBuilder
    private func sidebarIndex(proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(filteredSections) { section in
                    Button(action: {
                        withAnimation(.easeInOut) { proxy.scrollTo(section.id, anchor: .top) }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: section.icon)
                            Text(section.title)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                        }
                        .padding(.vertical, 7)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    .help("Jump to \(section.title)")
                }
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 8)
        }
        .padding(.bottom, -10)
    }

    // MARK: - Footer
    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 12) {
            Divider()
            VStack(spacing: 4) {
                Text("Contact & Links")
                    .font(.footnote.weight(.bold))
                    .foregroundColor(.primary.opacity(0.8))
                HStack(spacing: 24) {
                    Link("GitHub Issues", destination: URL(string: "https://github.com/offyotto/Core-Monitor/issues")!)
                    Link("Official Website", destination: URL(string: "https://offyotto.github.io/Core-Monitor/")!)
                    Link("Security Policy", destination: URL(string: "https://github.com/offyotto/Core-Monitor/blob/main/SECURITY.md")!)
                }
                .font(.footnote)
                .foregroundColor(.accentColor)
            }
        }
        .padding(.top, 20)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - SectionView
private struct SectionView: View {
    let section: HelpView.HelpSection

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: section.icon)
                    .foregroundColor(.accentColor)
                    .font(.title3.weight(.semibold))
                Text(section.title)
                    .font(.title3.weight(.bold))
                    .foregroundColor(.primary)
            }
            section.content
        }
    }
}

// MARK: - HelpCard
private struct HelpCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct HelpSearchEmptyState: View {
    let query: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
                Label("No matching help topics", systemImage: "magnifyingglass.circle")
                    .font(.system(size: 15, weight: .semibold))
                Text("No help sections matched \"\(query)\". Try terms like helper, weather, login items, menu bar, or Touch Bar.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - HelpBullet
private struct HelpBullet: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("•")
                .font(.body.weight(.black))
                .foregroundColor(.accentColor)
                .frame(width: 12, alignment: .leading)
                .padding(.top, 1)
            Text(text)
                .font(.body)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 4)
    }
}

// MARK: - Local Button Styles
private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold))
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

private struct BorderedAccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold))
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: 1.5)
            )
            .foregroundColor(Color.accentColor)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
