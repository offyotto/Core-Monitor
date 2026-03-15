import AppKit
import ObjectiveC.runtime

@MainActor
final class TouchBarPrivatePresenter: NSObject {
    private enum Identifier {
        static let monitor = NSTouchBar.CustomizationIdentifier("com.coremonitor.private.touchbar")
        static let metrics = NSTouchBarItem.Identifier("com.coremonitor.private.touchbar.metrics")
        static let trayItem = "com.coremonitor.private.touchbar.tray" as NSString
    }

    private var touchBar: NSTouchBar?
    private weak var topLabel: NSTextField?
    private weak var bottomLabel: NSTextField?
    private var isPresented = false

    func present() {
        guard touchBar == nil, !isPresented else { return }

        let bar = NSTouchBar()
        bar.customizationIdentifier = Identifier.monitor
        bar.delegate = self
        bar.defaultItemIdentifiers = [Identifier.metrics]

        touchBar = bar
        isPresented = true
        presentModal(bar)
    }

    func dismiss() {
        guard let touchBar else { return }
        dismissModal(touchBar)
        self.touchBar = nil
        isPresented = false
    }

    func update(topText: String, graphText: String) {
        guard isPresented else { return }
        topLabel?.stringValue = topText
        bottomLabel?.stringValue = graphText
    }

    private func presentModal(_ bar: NSTouchBar) {
        let klass: AnyObject = NSTouchBar.self
        let selectorWithPlacement = NSSelectorFromString("presentSystemModalTouchBar:placement:systemTrayItemIdentifier:")
        if let method = class_getClassMethod(NSTouchBar.self, selectorWithPlacement) {
            typealias Function = @convention(c) (AnyObject, Selector, NSTouchBar, Int, NSString) -> Void
            let implementation = method_getImplementation(method)
            let function = unsafeBitCast(implementation, to: Function.self)
            function(klass, selectorWithPlacement, bar, 1, Identifier.trayItem)
            return
        }

        let selectorWithoutPlacement = NSSelectorFromString("presentSystemModalTouchBar:systemTrayItemIdentifier:")
        guard let method = class_getClassMethod(NSTouchBar.self, selectorWithoutPlacement) else {
            isPresented = false
            return
        }
        typealias FallbackFunction = @convention(c) (AnyObject, Selector, NSTouchBar, NSString) -> Void
        let implementation = method_getImplementation(method)
        let function = unsafeBitCast(implementation, to: FallbackFunction.self)
        function(klass, selectorWithoutPlacement, bar, Identifier.trayItem)
    }

    private func dismissModal(_ bar: NSTouchBar) {
        let selector = NSSelectorFromString("dismissSystemModalTouchBar:")
        guard let method = class_getClassMethod(NSTouchBar.self, selector) else {
            isPresented = false
            return
        }

        typealias Function = @convention(c) (AnyObject, Selector, NSTouchBar) -> Void
        let implementation = method_getImplementation(method)
        let function = unsafeBitCast(implementation, to: Function.self)
        function(NSTouchBar.self, selector, bar)
    }
}

extension TouchBarPrivatePresenter: NSTouchBarDelegate {
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        guard identifier == Identifier.metrics else { return nil }

        let item = NSCustomTouchBarItem(identifier: identifier)

        let top = NSTextField(labelWithString: "CPU --  MEM --  FAN --")
        top.font = NSFont.monospacedSystemFont(ofSize: 11.5, weight: .semibold)
        top.textColor = NSColor.labelColor
        top.alignment = .left
        top.lineBreakMode = .byTruncatingTail

        let bottom = NSTextField(labelWithString: "T ▁▂▃▅▆  M ▁▂▃▅▆  C ▁▂▃▅▆  F ▁▂▃▅▆")
        bottom.font = NSFont.monospacedSystemFont(ofSize: 10.5, weight: .regular)
        bottom.textColor = NSColor.secondaryLabelColor
        bottom.alignment = .left
        bottom.lineBreakMode = .byTruncatingTail

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
