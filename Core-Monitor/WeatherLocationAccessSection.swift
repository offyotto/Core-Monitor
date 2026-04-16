import SwiftUI
import CoreLocation

struct WeatherLocationAccessSection: View {
    @ObservedObject var controller: WeatherLocationAccessController
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: symbolName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .frame(width: 18, height: 18)

                Text("Location Access")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(badgeTitle.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(accentColor.opacity(0.14))
                    .clipShape(Capsule())
            }

            Text(detailText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineSpacing(3)

            HStack(spacing: 8) {
                if let requestTitle {
                    Button(requestTitle) {
                        controller.requestAccess()
                    }
                    .buttonStyle(WeatherLocationActionButtonStyle())
                }

                if showsSettingsButton {
                    Button("Open Location Settings") {
                        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") else {
                            return
                        }
                        openURL(url)
                    }
                    .buttonStyle(WeatherLocationActionButtonStyle())
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var symbolName: String {
        switch controller.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return "location.fill"
        case .denied, .restricted:
            return "location.slash.fill"
        case .notDetermined:
            return "location.circle.fill"
        @unknown default:
            return "location"
        }
    }

    private var accentColor: Color {
        switch controller.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return .green
        case .denied, .restricted:
            return .orange
        case .notDetermined:
            return .blue
        @unknown default:
            return .secondary
        }
    }

    private var badgeTitle: String {
        switch controller.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return "Ready"
        case .denied, .restricted:
            return "Disabled"
        case .notDetermined:
            return "Optional"
        @unknown default:
            return "Unknown"
        }
    }

    private var detailText: String {
        switch controller.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return "Live weather widgets can use your current location for local conditions without interrupting launch."
        case .denied, .restricted:
            return "Core Monitor can keep a fallback forecast running, but re-enable location in System Settings if you want weather for your current place in the Touch Bar."
        case .notDetermined:
            return "Core Monitor can still show fallback weather. Request access only when you want live local conditions and rain timing in the Touch Bar."
        @unknown default:
            return "Location access is unavailable right now."
        }
    }

    private var requestTitle: String? {
        switch controller.authorizationStatus {
        case .notDetermined:
            return "Request Access"
        default:
            return nil
        }
    }

    private var showsSettingsButton: Bool {
        switch controller.authorizationStatus {
        case .denied, .restricted:
            return true
        default:
            return false
        }
    }
}

private struct WeatherLocationActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(configuration.isPressed ? 0.10 : 0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
