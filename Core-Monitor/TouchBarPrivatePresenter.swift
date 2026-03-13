import AppKit
import ObjectiveC.runtime

final class TouchBarPrivatePresenter: NSObject {
    private enum Identifier {
        static let monitor = NSTouchBar.CustomizationIdentifier("com.coremonitor.private.touchbar")
        static let metrics = NSTouchBarItem.Identifier("com.coremonitor.private.touchbar.metrics")
    }

    private var touchBar: NSTouchBar?
    private weak var topLabel: NSTextField?
    private weak var bottomLabel: NSTextField?

    func present() {
        guard touchBar == nil else { return }

        let bar = NSTouchBar()
        bar.customizationIdentifier = Identifier.monitor
        bar.delegate = self
        bar.defaultItemIdentifiers = [Identifier.metrics]

        touchBar = bar
        presentModal(bar)
    }

    func dismiss() {
        guard let touchBar else { return }
        dismissModal(touchBar)
        self.touchBar = nil
    }

    func update(topText: String, graphText: String) {
        topLabel?.stringValue = topText
        bottomLabel?.stringValue = graphText
    }

    private func presentModal(_ bar: NSTouchBar) {
        let selector = NSSelectorFromString("presentSystemModalTouchBar:placement:systemTrayItemIdentifier:")
        guard let method = class_getClassMethod(NSTouchBar.self, selector) else { return }

        typealias Function = @convention(c) (AnyClass, Selector, NSTouchBar, Int64, AnyObject?) -> Void
        let implementation = method_getImplementation(method)
        let function = unsafeBitCast(implementation, to: Function.self)
        function(NSTouchBar.self, selector, bar, 1, nil)
    }

    private func dismissModal(_ bar: NSTouchBar) {
        let selector = NSSelectorFromString("dismissSystemModalTouchBar:")
        guard let method = class_getClassMethod(NSTouchBar.self, selector) else { return }

        typealias Function = @convention(c) (AnyClass, Selector, NSTouchBar) -> Void
        let implementation = method_getImplementation(method)
        let function = unsafeBitCast(implementation, to: Function.self)
        function(NSTouchBar.self, selector, bar)
    }
}

extension TouchBarPrivatePresenter: NSTouchBarDelegate {
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        guard identifier == Identifier.metrics else { return nil }

        let item = NSCustomTouchBarItem(identifier: identifier)

        let top = NSTextField(labelWithString: "CPU --  GPU --  FAN --  PWR --")
        top.font = NSFont.monospacedSystemFont(ofSize: 11.5, weight: .semibold)
        top.textColor = NSColor.white.withAlphaComponent(0.95)
        top.alignment = .left

        let bottom = NSTextField(labelWithString: "C ▁▂▃▅▆  G ▁▂▃▅▆  F ▁▂▃▅▆  W ▁▂▃▅▆")
        bottom.font = NSFont.monospacedSystemFont(ofSize: 10.5, weight: .regular)
        bottom.textColor = NSColor.white.withAlphaComponent(0.72)
        bottom.alignment = .left

        let view = NSView(frame: NSRect(x: 0, y: 0, width: 1085, height: 30))
        top.frame = NSRect(x: 8, y: 14, width: 1077, height: 14)
        bottom.frame = NSRect(x: 8, y: 1, width: 1077, height: 12)
        view.addSubview(top)
        view.addSubview(bottom)

        topLabel = top
        bottomLabel = bottom
        item.view = view
        return item
    }
}
