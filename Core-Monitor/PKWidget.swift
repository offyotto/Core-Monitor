import AppKit

class PKWidget: NSObject {
    var customizationLabel: String = "Widget"

    var view: NSView {
        assertionFailure("PKWidget subclasses must override `view`.")
        return NSView(frame: .zero)
    }

    required override init() {
        super.init()
    }

    func viewWillAppear() {}
    func viewDidAppear() {}
    func viewWillDisappear() {}
    func viewDidDisappear() {}
    func prepareForCustomization() {}

    var imageForCustomization: NSImage? { nil }
}

struct PKWidgetInfo: Equatable {
    let bundleIdentifier: String
    let principalClass: AnyClass?
    let name: String

    static func == (lhs: PKWidgetInfo, rhs: PKWidgetInfo) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier
    }
}
