import SwiftUI

extension Color {
    static let cmBackground = Color(red: 0.07, green: 0.07, blue: 0.08)
    static let cmSurface = Color(red: 0.10, green: 0.10, blue: 0.12)
    static let cmSurfaceRaised = Color(red: 0.13, green: 0.13, blue: 0.15)
    static let cmBorder = Color(white: 1, opacity: 0.07)
    static let cmBorderBright = Color(white: 1, opacity: 0.14)
    static let cmAmber = Color(red: 1.0, green: 0.72, blue: 0.18)
    static let cmGreen = Color(red: 0.22, green: 0.92, blue: 0.55)
    static let cmRed = Color(red: 1.0, green: 0.34, blue: 0.34)
    static let cmBlue = Color(red: 0.35, green: 0.72, blue: 1.0)
    static let cmPurple = Color(red: 0.72, green: 0.40, blue: 1.0)
    static let cmTextPrimary = Color(white: 0.92)
    static let cmTextSecondary = Color(white: 0.50)
    static let cmTextDim = Color(white: 0.32)

    static let bBackground = Color(red: 0.05, green: 0.05, blue: 0.05)
    static let bSurface = Color(red: 0.09, green: 0.09, blue: 0.09)
    static let bBorder = Color(white: 1, opacity: 0.10)
    static let bText = Color(white: 0.80)
    static let bDim = Color(white: 0.40)
}

extension Font {
    static func cmMono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

private struct CMPanel: ViewModifier {
    var accent: Color = .clear

    func body(content: Content) -> some View {
        content
            .background(Color.cmSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(accent == .clear ? Color.cmBorder : accent.opacity(0.35), lineWidth: 1)
            )
    }
}

private struct BasicPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.bSurface)
            .overlay(Rectangle().stroke(Color.bBorder, lineWidth: 1))
    }
}

extension View {
    func cmPanel(accent: Color = .clear) -> some View {
        modifier(CMPanel(accent: accent))
    }

    func basicPanel() -> some View {
        modifier(BasicPanel())
    }

    @ViewBuilder
    func cmKerning(_ value: CGFloat) -> some View {
        if #available(macOS 13.0, *) {
            kerning(value)
        } else {
            self
        }
    }

    @ViewBuilder
    func cmNumericTextTransition() -> some View {
        if #available(macOS 13.0, *) {
            contentTransition(.numericText())
        } else {
            self
        }
    }

    @ViewBuilder
    func cmPulseSymbolEffect() -> some View {
        if #available(macOS 14.0, *) {
            symbolEffect(.pulse)
        } else {
            self
        }
    }

    @ViewBuilder
    func cmBounceSymbolEffect() -> some View {
        if #available(macOS 14.0, *) {
            symbolEffect(.bounce, value: true)
        } else {
            self
        }
    }

    @ViewBuilder
    func cmHandleSpaceKeyPress(_ action: @escaping () -> Void) -> some View {
        if #available(macOS 14.0, *) {
            onKeyPress(.space) {
                action()
                return .handled
            }
        } else {
            self
        }
    }
}
