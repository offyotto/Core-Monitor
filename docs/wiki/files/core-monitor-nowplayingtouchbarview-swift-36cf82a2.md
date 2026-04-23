# File: Core-Monitor/NowPlayingTouchBarView.swift

## Current Role

- Area: Touch Bar and Pock widget runtime.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/NowPlayingTouchBarView.swift`](../../../Core-Monitor/NowPlayingTouchBarView.swift) |
| Wiki area | Touch Bar and Pock widget runtime |
| Exists in current checkout | True |
| Size | 5491 bytes |
| Binary | False |
| Line count | 169 |
| Extension | `.swift` |

## Imports

`AppKit`, `MediaPlayer`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `NowPlayingTouchBarView` | 3 |
| func | `setup` | 29 |
| func | `updateFromNowPlaying` | 58 |
| func | `currentNowPlayingInfo` | 77 |
| func | `musicAppNowPlayingInfo` | 86 |
| func | `clean` | 120 |
| func | `placeholderArtwork` | 126 |
| func | `applyTheme` | 164 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `4db7203` | 2026-04-16 | Reduce redundant Touch Bar and menu refresh work |
| `2664fd1` | 2026-04-11 | Update Core Monitor |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
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
```
