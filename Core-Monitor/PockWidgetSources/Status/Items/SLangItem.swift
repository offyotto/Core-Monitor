//
//  SLangItem.swift
//  Status
//
//  Status widget item for Core Monitor.
//

import AppKit
import Carbon
import Foundation
import UniformTypeIdentifiers

final class SLangItem: StatusItem {
    private var tisInputSource: TISInputSource?
    private let iconView = NSImageView(frame: NSRect(x: 0, y: 0, width: 26, height: 26))
    private var currentTheme: TouchBarTheme = .dark

    init() {
        didLoad()
    }

    deinit {
        didUnload()
    }

    var view: NSView { iconView }

    func didLoad() {
        iconView.imageAlignment = .alignCenter
        iconView.frame.size = NSSize(width: 18, height: 18)
        reload()
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(selectedKeyboardInputSourceChanged),
            name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
    }

    func didUnload() {
        DistributedNotificationCenter.default().removeObserver(
            self,
            name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil
        )
    }

    func apply(theme: TouchBarTheme) {
        currentTheme = theme
        reload()
    }

    func reload() {
        let newInputSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        if tisInputSource?.name == newInputSource.name {
            return
        }

        tisInputSource = newInputSource
        guard let inputSource = tisInputSource else {
            iconView.image = nil
            return
        }

        var iconImage: NSImage?
        if let imageURL = inputSource.iconImageURL {
            for url in [imageURL.retinaImageURL, imageURL.tiffImageURL, imageURL] {
                if let image = NSImage(contentsOf: url) {
                    iconImage = image
                    break
                }
            }
        }

        if iconImage == nil {
            // Try a reasonable named image fallback first
            if let named = NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 15, weight: .regular)) {
                iconImage = named
            } else {
                // Fall back to a generic content type icon from NSWorkspace
                // Use UTType.data as a neutral, universally available type
                if #available(macOS 12.0, *) {
                    iconImage = NSWorkspace.shared.icon(for: .data)
                } else {
                    // Fallback for older macOS versions
                    iconImage = NSWorkspace.shared.icon(forFileType: "public.data")
                }
            }
        }

        if let resolvedImage = iconImage, shouldTintInputSource(resolvedImage) {
            iconImage = resolvedImage.tint(color: currentTheme.primaryTextColor)
        }

        iconView.image = iconImage?.resizeWhileMaintainingAspectRatioToSize(size: NSSize(width: 18, height: 18))
    }

    private func shouldTintInputSource(_ image: NSImage) -> Bool {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return false
        }

        let dividedHeight = round((bitmap.size.height * 0.84375) / 4.0)
        let dividedWidth = round((bitmap.size.width * 0.84375) / 4.0)
        var blackSamples = 0

        for pointX in stride(from: 4, through: 1, by: -1) {
            for pointY in stride(from: 4, through: 1, by: -1) {
                let x = Int(dividedWidth) * (pointX + 1)
                let y = Int(dividedHeight) * (pointY + 1)
                guard let color = bitmap.colorAt(x: x, y: y) else {
                    continue
                }
                let ciColor = CIColor(color: color)
                if ciColor?.red == 0 && ciColor?.green == 0 && ciColor?.blue == 0 {
                    blackSamples += 1
                }
            }
        }

        return blackSamples > 10
    }

    @objc private func selectedKeyboardInputSourceChanged() {
        reload()
    }
}

private extension TISInputSource {
    func value<T>(forProperty propertyKey: CFString, type: T.Type) -> T? {
        guard let value = TISGetInputSourceProperty(self, propertyKey) else {
            return nil
        }
        return Unmanaged<AnyObject>.fromOpaque(value).takeUnretainedValue() as? T
    }

    var name: String? {
        value(forProperty: kTISPropertyLocalizedName, type: String.self)
    }

    var iconImageURL: URL? {
        value(forProperty: kTISPropertyIconImageURL, type: URL.self)
    }

    var iconRef: IconRef? {
        OpaquePointer(TISGetInputSourceProperty(self, kTISPropertyIconRef)) as IconRef?
    }
}

private extension URL {
    var retinaImageURL: URL {
        var components = pathComponents
        let filename = components.removeLast()
        let ext = pathExtension
        let retinaFilename = filename.replacingOccurrences(of: "." + ext, with: "@2x." + ext)
        return NSURL.fileURL(withPathComponents: components + [retinaFilename])!
    }

    var tiffImageURL: URL {
        deletingPathExtension().appendingPathExtension("tiff")
    }
}

private extension NSImage {
    var height: CGFloat { size.height }
    var width: CGFloat { size.width }

    func tint(color: NSColor) -> NSImage {
        let image = copy() as! NSImage
        image.lockFocus()
        color.set()
        let imageRect = NSRect(origin: .zero, size: image.size)
        imageRect.fill(using: .sourceAtop)
        image.unlockFocus()
        return image
    }

    func copy(size: NSSize) -> NSImage? {
        let frame = NSMakeRect(0, 0, size.width, size.height)
        guard let rep = bestRepresentation(for: frame, context: nil, hints: nil) else {
            return nil
        }

        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }
        return rep.draw(in: frame) ? image : nil
    }

    func resizeWhileMaintainingAspectRatioToSize(size: NSSize) -> NSImage? {
        let newSize: NSSize
        let widthRatio = size.width / width
        let heightRatio = size.height / height

        if widthRatio > heightRatio {
            newSize = NSSize(width: floor(width * widthRatio), height: floor(height * widthRatio))
        } else {
            newSize = NSSize(width: floor(width * heightRatio), height: floor(height * heightRatio))
        }

        return copy(size: newSize)
    }
}
