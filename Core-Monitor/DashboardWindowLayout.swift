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

        let safeWidth = max(visibleFrame.width - 80, minimumContentSize.width)
        let safeHeight = max(visibleFrame.height - 90, minimumContentSize.height)

        return NSSize(
            width: min(defaultContentSize.width, max(minimumContentSize.width, min(safeWidth, visibleFrame.width * 0.78))),
            height: min(defaultContentSize.height, max(minimumContentSize.height, min(safeHeight, visibleFrame.height * 0.87)))
        )
    }

    static func shouldResetFrame(windowFrame: CGRect, visibleFrame: CGRect?) -> Bool {
        guard let visibleFrame,
              visibleFrame.width > 0,
              visibleFrame.height > 0 else {
            return windowFrame.width < minimumContentSize.width || windowFrame.height < minimumContentSize.height
        }

        let widthLimit = max(visibleFrame.width - 30, minimumContentSize.width)
        let heightLimit = max(visibleFrame.height - 30, minimumContentSize.height)

        return windowFrame.width < minimumContentSize.width ||
            windowFrame.height < minimumContentSize.height ||
            windowFrame.width > widthLimit ||
            windowFrame.height > heightLimit
    }
}
