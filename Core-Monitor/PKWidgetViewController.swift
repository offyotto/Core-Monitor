import AppKit

internal final class PKWidgetViewController: NSViewController {
    private weak var widgetItem: PKWidgetTouchBarItem!
    private var widgetIdentifier: String!

    convenience init(item: PKWidgetTouchBarItem) {
        self.init()
        widgetIdentifier = item.identifier.rawValue
        widgetItem = item
        view = item.widget!.view
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        widgetItem?.widget?.viewWillAppear()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        widgetItem?.widget?.viewDidAppear()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        widgetItem?.widget?.viewWillDisappear()
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        widgetItem?.widget?.viewDidDisappear()
    }
}
