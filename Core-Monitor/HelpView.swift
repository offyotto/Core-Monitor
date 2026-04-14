//
//  HelpView.swift
//  CoreMonitor
//
//  Created by Core Monitor Team on 2026-04-13.
//

import SwiftUI
import AppKit

struct HelpView: View {
    @AppStorage("com.coremonitor.hasSeenWelcomeGuide.v1") private var hasSeenWelcomeGuide: Bool = true
    @State private var searchText: String = ""
    
    // MARK: - Help Section Model
    
    struct HelpSection: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let content: () -> AnyView
    }
    
    // MARK: - Help Data
    
    private var allSections: [HelpSection] {
        [
            HelpSection(title: "Overview Dashboard", icon: "speedometer") {
                AnyView(
                    VStack(alignment: .leading, spacing: 12) {
                        HelpCard {
                            Text("The Overview Dashboard provides a comprehensive summary of your Mac’s current state including CPU, GPU, memory, and thermal information.")
                                .fixedSize(horizontal: false, vertical: true)
                            HelpBullet(text: "`CPU`, `GPU`, and `Memory` usage are shown with real-time graphs and numeric values.")
                            HelpBullet(text: "Thermal zones and sensor temperatures update continuously.")
                            HelpBullet(text: "Use the dashboard to quickly assess system performance and health.")
                        }
                    }
                )
            },
            HelpSection(title: "Thermals", icon: "thermometer") {
                AnyView(
                    VStack(alignment: .leading, spacing: 12) {
                        HelpCard {
                            Text("The Thermals section displays detailed temperature readings from multiple sensors across your Mac.")
                            HelpBullet(text: "Supports a variety of sensor types including die, battery, and ambient temperatures.")
                            HelpBullet(text: "Shows temperature warnings and alerts if thresholds are reached.")
                            HelpBullet(text: "You can reference individual sensor data by names like `CPU Proximity` or `Battery Max`.")
                        }
                    }
                )
            },
            HelpSection(title: "Memory", icon: "memorychip") {
                AnyView(
                    HelpCard {
                        Text("Memory monitoring includes RAM usage, swap usage, and memory pressure visualization.")
                        HelpBullet(text: "Track real-time page ins, page outs, and compressed memory in the `Memory` tab.")
                        HelpBullet(text: "Use the memory pressure graph to see system memory stress and performance impact.")
                    }
                )
            },
            HelpSection(title: "Fans & Fan Control", icon: "fanblades") {
                AnyView(
                    VStack(alignment: .leading, spacing: 12) {
                        HelpCard {
                            Text("Manage your Mac’s fans with advanced controls and profiles.")
                            HelpBullet(text: "Fan profiles allow custom curves, manual speed settings, or automatic fan speed management.")
                            HelpBullet(text: "The helper tool must be installed to enable fan control functionality.")
                            HelpBullet(text: "Calibration assists in aligning fan speeds correctly with actual hardware RPM.")
                            HelpBullet(text: "Safety features prevent unsafe fan speeds and protect hardware integrity.")
                            Text("Use the `Fan Control` tab to create and select profiles.")
                        }
                    }
                )
            },
            HelpSection(title: "Battery", icon: "battery.100") {
                AnyView(
                    HelpCard {
                        Text("Battery monitoring shows charge cycles, current charge, health status, and battery temperature.")
                        HelpBullet(text: "Track battery capacity relative to design capacity and receive health warnings.")
                        HelpBullet(text: "View detailed logs of battery charge and discharge history.")
                    }
                )
            },
            HelpSection(title: "System Controls", icon: "gearshape") {
                AnyView(
                    HelpCard {
                        Text("System controls enable adjusting volume, screen brightness, and launch-at-login behavior.")
                        HelpBullet(text: "Volume and brightness sliders can be accessed from the `System Controls` tab or menu bar popover.")
                        HelpBullet(text: "Toggle the `Launch at Login` option to start Core Monitor automatically when you log in.")
                    }
                )
            },
            HelpSection(title: "Touch Bar Customization", icon: "touchid") {
                AnyView(
                    VStack(alignment: .leading, spacing: 12) {
                        HelpCard {
                            Text("Customize your MacBook's Touch Bar with Core Monitor widgets and controls.")
                            HelpBullet(text: "Presentation modes include expanded, compact, and auto-switch modes.")
                            HelpBullet(text: "Presets let you quickly switch between common layouts.")
                            HelpBullet(text: "Built-in widgets include CPU usage, fan speed, battery, and weather.")
                            HelpBullet(text: "Pin apps and folders for quick access directly from the Touch Bar.")
                            HelpBullet(text: "Add custom widgets via scripts or system commands.")
                            HelpBullet(text: "Theme options allow light, dark, or system appearance matching.")
                            HelpBullet(text: "Width guidance: ideal width is 2172 pt (full Touch Bar width).")
                            Text("Weather data uses WeatherKit — attribution is required by Apple.")
                        }
                    }
                )
            },
            HelpSection(title: "Menu Bar Items and Popovers", icon: "menubar.dock.rectangle") {
                AnyView(
                    HelpCard {
                        Text("Core Monitor menu bar items provide quick overview and access to system metrics.")
                        HelpBullet(text: "Click menu bar icons to open popovers with detailed info and controls.")
                        HelpBullet(text: "Popovers are interactive and support real-time updates.")
                        HelpBullet(text: "Customize which metrics appear in the menu bar from the `Preferences`.")
                    }
                )
            },
            HelpSection(title: "Basic Mode", icon: "switch.2") {
                AnyView(
                    HelpCard {
                        Text("Basic Mode simplifies Core Monitor’s interface and monitoring options.")
                        HelpBullet(text: "Recommended for users who want minimal system info without advanced controls.")
                        HelpBullet(text: "Disable detailed sensors and fan control for a lightweight experience.")
                    }
                )
            },
            HelpSection(title: "Weather Permission Tips", icon: "cloud.sun.rain") {
                AnyView(
                    HelpCard {
                        Text("Core Monitor uses WeatherKit data which requires location permission.")
                        HelpBullet(text: "To enable weather widgets, grant `Core Monitor` access to your location in System Preferences → Privacy & Security → Location Services.")
                        HelpBullet(text: "If weather data fails to load, verify that location permission is enabled and the network is available.")
                    }
                )
            },
            HelpSection(title: "SMC Access and Helper Install", icon: "cpu") {
                AnyView(
                    HelpCard {
                        Text("Core Monitor requires SMC (System Management Controller) access for fan control and sensor readings.")
                        HelpBullet(text: "The helper tool is installed with your consent to enable privileged operations.")
                        HelpBullet(text: "Helper installation requests admin permissions and is signed to maintain macOS security requirements.")
                        HelpBullet(text: "If fan control or sensor data is missing, verify the helper tool is installed and running.")
                    }
                )
            },
            HelpSection(title: "Troubleshooting", icon: "wrench.and.screwdriver") {
                AnyView(
                    VStack(alignment: .leading, spacing: 12) {
                        HelpCard {
                            Text("Here are some common troubleshooting tips:")
                            HelpBullet(text: "If sensors are missing or show invalid values, restart Core Monitor and verify permissions.")
                            HelpBullet(text: "Fan control not working? Ensure the helper tool is installed and the calibration profile is selected.")
                            HelpBullet(text: "Weather data not updating? Check location permissions and network availability.")
                            HelpBullet(text: "App crashes or UI glitches? Try restarting your Mac or reinstalling Core Monitor.")
                            HelpBullet(text: "For further assistance, visit our GitHub issues page linked below.")
                        }
                    }
                )
            }
        ]
    }
    
    // MARK: - Filtered Sections
    
    private var filteredSections: [HelpSection] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return allSections
        }
        return allSections.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    // MARK: - Body
    
    var body: some View {
        VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
            .edgesIgnoringSafeArea(.all)
            .overlay(
                VStack(spacing: 0) {
                    header
                    Divider()
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                sidebarIndex(proxy: proxy)
                                Divider()
                                ForEach(filteredSections) { section in
                                    SectionView(section: section)
                                        .id(section.id)
                                }
                                footer
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 20)
                            .frame(maxWidth: 900)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .foregroundColor(Color(NSColor.textColor))
                .padding()
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
            Spacer()
            searchField
            Spacer(minLength: 30)
            Button(action: {
                hasSeenWelcomeGuide = false
            }) {
                Text("Open Welcome Guide")
            }
            .buttonStyle(.primary)
            Button(action: {
                hasSeenWelcomeGuide = true
            }) {
                Text("Reset Guide")
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 10)
    }
    
    @ViewBuilder
    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search Sections", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)
                .disableAutocorrection(true)
                .textInputAutocapitalization(.never)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            DarkCard()
                .opacity(0.35)
        )
        .cornerRadius(6)
    }
    
    // MARK: - Sidebar-like Index
    
    @ViewBuilder
    private func sidebarIndex(proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(filteredSections) { section in
                    Button(action: {
                        withAnimation(.easeInOut) {
                            proxy.scrollTo(section.id, anchor: .top)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: section.icon)
                            Text(section.title)
                                .font(.footnote.weight(.medium))
                                .lineLimit(1)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            CoreMonGlassPanel()
                                .opacity(0.35)
                        )
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    .help("Jump to \(section.title)")
                }
            }
            .padding(.bottom, 6)
        }
    }
    
    // MARK: - Footer
    
    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 6) {
            Divider()
            Text("Contact & Links")
                .font(.footnote.weight(.semibold))
                .foregroundColor(.secondary)
            HStack(spacing: 20) {
                Link("GitHub Issues", destination: URL(string: "https://github.com/core-monitor/core-monitor/issues")!)
                Link("Official Website", destination: URL(string: "https://coremonitor.app")!)
                Link("Privacy Policy", destination: URL(string: "https://coremonitor.app/privacy")!)
            }
            .font(.footnote)
        }
        .padding(.top, 12)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - SectionView

private struct SectionView: View {
    let section: HelpView.HelpSection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: section.icon)
                    .foregroundColor(.accentColor)
                    .font(.title3)
                Text(section.title)
                    .font(.title3.weight(.bold))
                    .foregroundColor(.primary)
            }
            section.content()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }
}

// MARK: - HelpCard

private struct HelpCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        CoreMonGlassPanel()
            .overlay(
                content
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            )
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.4), radius: 3, x: 0, y: 1)
    }
}

// MARK: - HelpBullet

private struct HelpBullet: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.body.weight(.bold))
                .foregroundColor(.accentColor)
                .frame(width: 12, alignment: .leading)
                .padding(.top, 2)
            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 8)
    }
}

// MARK: - Button Styles

private extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

private extension ButtonStyle where Self == BorderedButtonStyle {
    static var bordered: BorderedButtonStyle { BorderedButtonStyle() }
}

private struct BorderedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: 1.5)
            )
            .foregroundColor(Color.accentColor)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

#if DEBUG
struct HelpView_Previews: PreviewProvider {
    static var previews: some View {
        HelpView()
            .frame(width: 900, height: 700)
            .preferredColorScheme(.dark)
    }
}
#endif
