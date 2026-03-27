import SwiftUI

extension View {
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
