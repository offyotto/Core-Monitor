import AppKit

@available(macOS 13.0, *)
@MainActor
final class TouchBarPrivatePresenter: NSResponder {
    private var activeTouchBar: NSTouchBar?
    private var previousMode: String?
    private var isVisible = false

    func attach(to window: NSWindow) {
        window.touchBar = nil
    }

    func present(touchBar: NSTouchBar) {
        if let activeTouchBar, isVisible {
            CMDismissTouchBarFromTop(activeTouchBar)
            isVisible = false
        }

        previousMode = previousMode ?? CMCurrentTouchBarPresentationMode()
        activeTouchBar = touchBar
        isVisible = true

        CMPresentTouchBarOnTop(touchBar, 1)
        CMSetTouchBarPresentationMode("app")
    }

    func dismiss() {
        guard isVisible, let activeTouchBar else { return }
        CMDismissTouchBarFromTop(activeTouchBar)
        self.activeTouchBar = nil
        isVisible = false
    }

    func dismissToSystemTouchBar() {
        dismiss()
        CMSetTouchBarPresentationMode(previousMode ?? "appWithControlStrip")
    }
}
