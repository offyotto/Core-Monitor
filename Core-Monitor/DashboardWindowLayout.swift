import AppKit

enum DashboardWindowLayout {
    static let defaultContentSize = NSSize(width: 1_080, height: 720)
    static let minimumContentSize = NSSize(width: 900, height: 640)

    static func targetContentSize(for visibleFrame: CGRect?) -> NSSize {
        guard let visibleFrame,
              visibleFrame.width > 0,
              visibleFrame.height > 0 else {
            return defaultContentSize
        }

        let availableWidth = max(1, visibleFrame.width - 80)
        let availableHeight = max(1, visibleFrame.height - 30)
        let preferredHeight = max(minimumContentSize.height, visibleFrame.height * 0.87)

        return NSSize(
            width: min(defaultContentSize.width, availableWidth),
            height: min(defaultContentSize.height, preferredHeight, availableHeight)
        )
    }

    static func minimumContentSize(for visibleFrame: CGRect?) -> NSSize {
        let available = targetContentSize(for: visibleFrame)
        return NSSize(width: min(minimumContentSize.width, available.width),
                      height: min(minimumContentSize.height, available.height))
    }

    static func shouldResetFrame(windowFrame: CGRect, visibleFrame: CGRect?) -> Bool {
        guard let visibleFrame,
              visibleFrame.width > 0,
              visibleFrame.height > 0 else {
            return windowFrame.width < minimumContentSize.width || windowFrame.height < minimumContentSize.height
        }

        let minimum = minimumContentSize(for: visibleFrame)
        let widthLimit = max(1, visibleFrame.width - 30)
        let heightLimit = max(1, visibleFrame.height)

        return !visibleFrame.intersects(windowFrame) ||
            windowFrame.width < minimum.width ||
            windowFrame.height < minimum.height ||
            windowFrame.width > widthLimit ||
            windowFrame.height > heightLimit
    }
}
