import SwiftUI

struct PanelRevealModifier: ViewModifier {
    let index: Int
    let active: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(active ? 1.0 : 0.965)
            .opacity(active ? 1.0 : 0.0)
            .offset(y: active ? 0 : 16)
            .blur(radius: active ? 0 : 7)
            .animation(
                .spring(response: 0.56, dampingFraction: 0.84, blendDuration: 0.25)
                .delay(Double(index) * 0.045),
                value: active
            )
    }
}

extension View {
    func panelReveal(index: Int, active: Bool) -> some View {
        modifier(PanelRevealModifier(index: index, active: active))
    }
}
