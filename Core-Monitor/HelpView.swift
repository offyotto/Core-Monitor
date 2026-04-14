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
        let id: String
        let title: String
        let icon: String
        let content: AnyView
    }

    // MARK: - Help Data
    private var allSections: [HelpSection] {
        [
            HelpSection(id: "overview", title: "Overview Dashboard", icon: "gauge.medium", content: AnyView(
                HelpCard {
                    Text("The Overview screen shows CPU, GPU, memory, battery, and thermals in one place.")
                    HelpBullet(text: "`CPU`, `GPU`, and `Memory` cards update with live graphs and current values.")
                    HelpBullet(text: "Temperature cards show the readings Core-Monitor can resolve on your Mac.")
                    HelpBullet(text: "Use the dashboard for a fast read on system activity.")
                }
            )),
            HelpSection(id: "thermals", title: "Thermals", icon: "thermometer.medium", content: AnyView(
                HelpCard {
                    Text("The Thermals section shows detailed temperature readings from the sensors Core-Monitor can resolve.")
                    HelpBullet(text: "Current builds surface CPU, GPU, SSD, and battery temperatures when those readings are available.")
                    HelpBullet(text: "If a temperature is missing, the app could not resolve a readable sensor key for this Mac.")
                    HelpBullet(text: "Core-Monitor does not include automatic thermal alerts.")
                }
            )),
            HelpSection(id: "memory", title: "Memory", icon: "memorychip", content: AnyView(
                HelpCard {
                    Text("Memory shows RAM use, swap use, and memory pressure.")
                    HelpBullet(text: "Track real-time page ins, page outs, and compressed memory in the `Memory` tab.")
                    HelpBullet(text: "Use the pressure graph to see when the system is under memory pressure.")
                }
            )),
            HelpSection(id: "fans", title: "Fans & Fan Control", icon: "fanblades.fill", content: AnyView(
                HelpCard {
                    Text("Manage the fans with fixed modes, smart curves, or a custom preset.")
                    HelpBullet(text: "Fan modes let you use system control, fixed targets, or automatic fan management.")
                    HelpBullet(text: "The helper must be installed before Core-Monitor can write fan speeds.")
                    HelpBullet(text: "The `Probe Fan Keys` action checks which fan-related SMC keys respond on the current Mac. It does not calibrate RPM accuracy.")
                    HelpBullet(text: "Safety limits prevent targets outside the supported range.")
                    Text("Use the `Fans` tab to switch modes or adjust settings.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            )),
            HelpSection(id: "battery", title: "Battery", icon: "battery.100", content: AnyView(
                HelpCard {
                    Text("Battery monitoring shows charge cycles, current charge, health status, and battery temperature.")
                    HelpBullet(text: "Track battery capacity relative to design capacity and current health.")
                    HelpBullet(text: "Some details vary by Mac model.")
                }
            )),
            HelpSection(id: "system", title: "System Controls", icon: "gearshape", content: AnyView(
                HelpCard {
                    Text("System controls include volume, brightness, and Launch at Login.")
                    HelpBullet(text: "Use the `System` tab or menu bar popovers to view current volume and brightness.")
                    HelpBullet(text: "Toggle `Launch at Login` if you want Core-Monitor to open when you sign in.")
                }
            )),
            HelpSection(id: "touchbar", title: "Touch Bar Customization", icon: "rectangle.3.group", content: AnyView(
                HelpCard {
                    Text("On supported Macs, customize the Touch Bar with Core-Monitor items and shortcuts.")
                    HelpBullet(text: "Presentation modes control whether Core-Monitor uses its own Touch Bar layout or the standard macOS one.")
                    HelpBullet(text: "Presets let you quickly switch between themed layouts.")
                    HelpBullet(text: "Built-in items include status, CPU, network, memory, hardware, and weather.")
                    HelpBullet(text: "Pin apps and folders for quick access directly from the Touch Bar.")
                    HelpBullet(text: "Add custom widgets via shell commands with a title, SF Symbol, and width.")
                    HelpBullet(text: "Theme options allow switching between available appearances.")
                    HelpBullet(text: "Width guidance warns when the active stack may clip on a full Touch Bar.")
                    Text("Weather uses Apple WeatherKit, and Apple requires attribution when that feature is enabled.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            )),
            HelpSection(id: "menubar", title: "Menu Bar Items and Popovers", icon: "menubar.rectangle", content: AnyView(
                HelpCard {
                    Text("Core-Monitor menu bar items give you quick readings and controls.")
                    HelpBullet(text: "Click menu bar icons to open popovers with detailed info and controls.")
                    HelpBullet(text: "Use `System` → `Menu Bar` to choose which of the CPU, Memory, Disk, and Temperature items stay visible.")
                    HelpBullet(text: "At least one menu bar item must stay enabled so the app remains reachable after launch.")
                }
            )),
            HelpSection(id: "basic", title: "Basic Mode", icon: "square.grid.2x2.fill", content: AnyView(
                HelpCard {
                    Text("Basic Mode keeps the interface lighter and more focused.")
                    HelpBullet(text: "Use it if you want a smaller view with essential metrics.")
                    HelpBullet(text: "Switch back to Full UI any time from the header button.")
                }
            )),
            HelpSection(id: "weather", title: "Weather Permission Tips", icon: "cloud.sun.rain.fill", content: AnyView(
                HelpCard {
                    Text("The weather item uses Apple WeatherKit. Location access is only needed if you keep that item in your Touch Bar layout.")
                    HelpBullet(text: "Grant Core-Monitor access to your location in System Settings > Privacy & Security > Location Services if you want local weather.")
                    HelpBullet(text: "If weather data fails to load, ensure WeatherKit is enabled for your signed build.")
                }
            )),
            HelpSection(id: "smc", title: "SMC Access and Helper Install", icon: "cpu.fill", content: AnyView(
                HelpCard {
                    Text("Core-Monitor reads sensors through AppleSMC. Fan writes require the bundled helper.")
                    HelpBullet(text: "The helper is signed and uses the macOS authorization sheet on first use.")
                    HelpBullet(text: "Use `Reset to System Auto` in the Fans section to restore default behavior.")
                }
            )),
            HelpSection(id: "troubleshooting", title: "Troubleshooting", icon: "wrench.and.screwdriver", content: AnyView(
                HelpCard {
                    Text("Common issues and solutions:")
                        .fontWeight(.semibold)
                    HelpBullet(text: "If sensors are missing, restart Core-Monitor and verify SMC access.")
                    HelpBullet(text: "Fan control not working? Ensure the helper is installed, reset to system auto, then run `Probe Fan Keys` to confirm readable fan SMC keys.")
                    HelpBullet(text: "Weather unavailable? Check location permissions and WeatherKit configuration.")
                    HelpBullet(text: "Launch at Login requires approval. Open System Settings > General > Login Items.")
                    HelpBullet(text: "Touch Bar clipping — reduce active items or apply a narrower preset.")
                }
            ))
        ]
    }

    // MARK: - Filtered Sections
    private var filteredSections: [HelpSection] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return allSections }
        return allSections.filter { $0.title.localizedCaseInsensitiveContains(q) }
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        sidebarIndex(proxy: proxy)
                        
                        ForEach(filteredSections) { section in
                            SectionView(section: section)
                                .id(section.id)
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
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()
        )
    }

    // MARK: - Header
    @ViewBuilder
    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "questionmark.circle.fill")
                .font(.title2.weight(.semibold))
                .foregroundColor(.accentColor)
            Text("Core-Monitor Help")
                .font(.title3.weight(.semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .layoutPriority(1)
            
            Spacer(minLength: 8)
            
            searchField
            
            Spacer(minLength: 8)
            
            HStack(spacing: 8) {
                Button(action: { hasSeenWelcomeGuide = false }) {
                    Text("Show Welcome Guide")
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
                    Link("GitHub Issues", destination: URL(string: "https://github.com/offyotto-sl3/Core-Monitor/issues")!)
                    Link("Official Website", destination: URL(string: "https://offyotto-sl3.github.io/Core-Monitor/")!)
                    Link("Privacy Details", destination: URL(string: "https://github.com/offyotto-sl3/Core-Monitor#privacy")!)
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
        CoreMonGlassPanel(cornerRadius: 18, tintOpacity: 0.12, strokeOpacity: 0.16, shadowRadius: 10, contentPadding: 0) {
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
