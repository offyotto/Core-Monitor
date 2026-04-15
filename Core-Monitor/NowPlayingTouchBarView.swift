import AppKit
import MediaPlayer

final class NowPlayingTouchBarView: NSView, TouchBarThemable {
    var theme: TouchBarTheme = .dark {
        didSet { applyTheme() }
    }

    private let artworkView = NSImageView(frame: .zero)
    private let titleLabel = NSTextField(labelWithString: "Now Playing")

    private var refreshTimer: Timer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func setup() {
        wantsLayer = false

        artworkView.wantsLayer = true
        artworkView.layer?.cornerRadius = 6
        artworkView.layer?.masksToBounds = true
        artworkView.imageScaling = .scaleProportionallyUpOrDown
        artworkView.image = placeholderArtwork()

        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1

        addSubview(artworkView)
        addSubview(titleLabel)

        applyTheme()
        updateFromNowPlaying()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: TB.refreshInterval, repeats: true) { [weak self] _ in
            self?.updateFromNowPlaying()
        }
        if let refreshTimer {
            refreshTimer.tolerance = TB.refreshInterval * 0.2
            RunLoop.main.add(refreshTimer, forMode: .common)
        }

    }

    private func updateFromNowPlaying() {
        let info = currentNowPlayingInfo()

        let title = clean(info[MPMediaItemPropertyTitle] as? String)
        let artist = clean(info[MPMediaItemPropertyArtist] as? String)

        titleLabel.stringValue = title ?? "Now Playing"
        titleLabel.toolTip = artist

        if let artwork = info[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork {
            artworkView.image = artwork.image(at: NSSize(width: 28, height: 28))
        } else {
            artworkView.image = placeholderArtwork()
        }

        needsLayout = true
        needsDisplay = true
    }

    private func currentNowPlayingInfo() -> [String: Any] {
        if let info = MPNowPlayingInfoCenter.default().nowPlayingInfo,
           info[MPMediaItemPropertyTitle] != nil || info[MPMediaItemPropertyArtwork] != nil {
            return info
        }

        return musicAppNowPlayingInfo()
    }

    private func musicAppNowPlayingInfo() -> [String: Any] {
        let script = """
        tell application "Music"
            if it is running then
                if player state is playing or player state is paused then
                    set trackName to name of current track
                    set artistName to artist of current track
                    return trackName & linefeed & artistName
                end if
            end if
        end tell
        return ""
        """

        guard let appleScript = NSAppleScript(source: script) else {
            return [:]
        }

        var error: NSDictionary?
        guard let output = appleScript.executeAndReturnError(&error).stringValue,
              !output.isEmpty else {
            return [:]
        }

        let parts = output.components(separatedBy: .newlines)
        let title = parts.first.flatMap(clean)
        let artist = parts.dropFirst().first.flatMap(clean)

        var info: [String: Any] = [:]
        if let title { info[MPMediaItemPropertyTitle] = title }
        if let artist { info[MPMediaItemPropertyArtist] = artist }
        return info
    }

    private func clean(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func placeholderArtwork() -> NSImage? {
        let size = NSSize(width: 22, height: 22)
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor(calibratedWhite: 0.90, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 8, yRadius: 8).fill()

        let symbol = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold))
        symbol?.isTemplate = true
        symbol?.draw(in: NSRect(x: 6, y: 6, width: 10, height: 10))

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 150, height: TB.stripH)
    }

    override func layout() {
        super.layout()

        let artSize = NSSize(width: 22, height: 22)
        let artX: CGFloat = 4
        let artY = floor((bounds.height - artSize.height) / 2)
        artworkView.frame = NSRect(x: artX, y: artY, width: artSize.width, height: artSize.height)

        let labelX = artworkView.frame.maxX + 10
        let labelY = floor((bounds.height - 14) / 2) + 1
        let availableWidth = max(bounds.width - labelX - 4, 0)
        titleLabel.sizeToFit()
        let titleWidth = min(titleLabel.frame.width, availableWidth)
        titleLabel.frame = NSRect(x: labelX, y: labelY, width: titleWidth, height: 14)
    }

    private func applyTheme() {
        titleLabel.textColor = theme.primaryTextColor
    }
}
