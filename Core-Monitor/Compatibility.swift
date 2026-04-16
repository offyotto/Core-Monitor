import SwiftUI

extension Color {
    static let cmBackground = Color(red: 0.93, green: 0.93, blue: 0.93)
    static let cmSurface = Color.white
    static let cmSurfaceRaised = Color(red: 0.96, green: 0.96, blue: 0.96)
    static let cmSurfaceSoft = Color(red: 0.90, green: 0.90, blue: 0.90)
    static let cmBorder = Color.black.opacity(0.28)
    static let cmBorderBright = Color.black.opacity(0.45)
    static let cmAmber = Color(red: 1.00, green: 0.78, blue: 0.31)
    static let cmGreen = Color(red: 0.45, green: 0.93, blue: 0.74)
    static let cmRed = Color(red: 1.00, green: 0.45, blue: 0.47)
    static let cmBlue = Color.black
    static let cmPurple = Color.black
    static let cmMint = Color(red: 0.18, green: 0.18, blue: 0.18)
    static let cmTextPrimary = Color.black
    static let cmTextSecondary = Color(red: 0.20, green: 0.20, blue: 0.20)
    static let cmTextDim = Color(red: 0.38, green: 0.38, blue: 0.38)

    static let bBackground = Color.white
    static let bSurface = Color.white
    static let bBorder = Color.black.opacity(0.92)
    static let bText = Color.black
    static let bDim = Color.black.opacity(0.55)
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
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.cmSurface)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(accent == .clear ? Color.cmBorder : accent.opacity(0.35), lineWidth: 1)
            )
    }
}

private struct BasicPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.bSurface)
            .overlay(Rectangle().stroke(Color.bBorder, lineWidth: 2))
    }
}

extension View {
    func cmPanel(accent: Color = .clear) -> some View {
        modifier(CMPanel(accent: accent))
    }

    func basicPanel() -> some View {
        modifier(BasicPanel())
    }

    func cmGlassBackground() -> some View {
        background(
            Color.cmBackground.ignoresSafeArea()
        )
    }

    @ViewBuilder
    func cmLiquidGlassCard(cornerRadius: CGFloat = 14) -> some View {
#if swift(>=6.3)
        if #available(macOS 26.0, *) {
            glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.8)
                )
        } else {
            background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.006))
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                }
            )
        }
#else
        background(
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.006))
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
            }
        )
#endif
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

    @ViewBuilder
    func cmHideWindowToolbarBackground() -> some View {
        if #available(macOS 15.0, *) {
            toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        } else {
            self
        }
    }

    @ViewBuilder
    func cmRemoveWindowToolbarTitle() -> some View {
        if #available(macOS 15.0, *) {
            toolbar(removing: .title)
        } else {
            self
        }
    }
}
