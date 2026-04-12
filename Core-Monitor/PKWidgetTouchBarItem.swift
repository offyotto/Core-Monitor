import AppKit

internal final class PKWidgetTouchBarItem: NSCustomTouchBarItem {
    internal private(set) var widget: PKWidget?

    override var customizationLabel: String! {
        get { widget?.customizationLabel }
        set { widget?.customizationLabel = newValue ?? "Widget" }
    }

    convenience init?(widget: PKWidgetInfo) {
        self.init(widget: widget, identifier: NSTouchBarItem.Identifier(widget.bundleIdentifier))
    }

    convenience init?(widget: PKWidgetInfo, identifier: NSTouchBarItem.Identifier) {
        guard let clss = widget.principalClass as? PKWidget.Type else {
            return nil
        }

        self.init(identifier: identifier)
        self.widget = clss.init()
        self.widget?.customizationLabel = widget.name
        viewController = PKWidgetViewController(item: self)
    }

    private var defaultSnapshotView: NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 140, height: TB.stripH))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(calibratedWhite: 0.18, alpha: 1).cgColor
        container.layer?.cornerRadius = TB.pillRadius
        container.layer?.masksToBounds = true

        let imageView = NSImageView(frame: NSRect(x: 12, y: 6, width: 18, height: 18))
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 14, weight: .medium))
        imageView.contentTintColor = .white

        let label = NSTextField(labelWithString: widget?.customizationLabel ?? "Widget")
        label.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        label.textColor = .white
        label.sizeToFit()
        label.frame = NSRect(
            x: imageView.frame.maxX + 8,
            y: floor((container.bounds.height - label.frame.height) / 2),
            width: min(label.frame.width, 96),
            height: label.frame.height
        )

        container.addSubview(imageView)
        container.addSubview(label)
        return container
    }

    private var snapshotView: NSView {
        widget?.prepareForCustomization()

        if let customImage = widget?.imageForCustomization {
            return NSImageView(image: customImage)
        }

        let sourceView = viewController?.view ?? view
        guard let image = sourceView.touchBarSnapshotImage() else {
            return defaultSnapshotView
        }

        let imageView = NSImageView(image: image)
        imageView.imageScaling = .scaleAxesIndependently

        let container = NSView(frame: NSRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(calibratedWhite: 0.18, alpha: 1).cgColor
        container.layer?.cornerRadius = TB.pillRadius
        container.layer?.masksToBounds = true
        imageView.frame = container.bounds
        imageView.autoresizingMask = [.width, .height]
        container.addSubview(imageView)
        return container
    }
}

private extension NSView {
    func touchBarSnapshotImage() -> NSImage? {
        let size = if bounds.width > 0 && bounds.height > 0 {
            bounds.size
        } else {
            fittingSize
        }

        guard size.width > 0, size.height > 0 else {
            return nil
        }

        let renderBounds = NSRect(origin: .zero, size: size)
        frame = renderBounds
        layoutSubtreeIfNeeded()

        guard let bitmap = bitmapImageRepForCachingDisplay(in: renderBounds) else {
            return nil
        }

        cacheDisplay(in: renderBounds, to: bitmap)
        let image = NSImage(size: renderBounds.size)
        image.addRepresentation(bitmap)
        return image
    }
}
