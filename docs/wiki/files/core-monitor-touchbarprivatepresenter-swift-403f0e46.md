# File: Core-Monitor/TouchBarPrivatePresenter.swift

## Current Role

- Area: Touch Bar and Pock widget runtime.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/TouchBarPrivatePresenter.swift`](../../../Core-Monitor/TouchBarPrivatePresenter.swift) |
| Wiki area | Touch Bar and Pock widget runtime |
| Exists in current checkout | True |
| Size | 1043 bytes |
| Binary | False |
| Line count | 40 |
| Extension | `.swift` |

## Imports

`AppKit`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `TouchBarPrivatePresenter` | 4 |
| func | `attach` | 9 |
| func | `present` | 13 |
| func | `dismiss` | 27 |
| func | `dismissToSystemTouchBar` | 34 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `011232b` | 2026-04-11 | Update website install video |
| `31da3f2` | 2026-04-06 | ui update |
| `0fa238c` | 2026-04-02 | commits. |
| `3651f98` | 2026-03-29 | Remove CoreVisor and virtualization support |
| `34b59ac` | 2026-03-29 | Update app UI and website branding |
| `b436125` | 2026-03-28 | Improve Touch Bar behavior, CoreVisor UI, and docs |
| `3252194` | 2026-03-27 | Clean repo and keep only active Core-Monitor project |
| `61a73aa` | 2026-03-15 | Commit ig |
| `81e0938` | 2026-03-13 | Add auto fan aggressiveness slider and fix QEMU boot/display defaults |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import AppKit

@available(macOS 13.0, *)
@MainActor
final class TouchBarPrivatePresenter: NSResponder {
    private var activeTouchBar: NSTouchBar?
    private var previousMode: String?
    private var isVisible = false

    func attach(to window: NSWindow) {
        window.touchBar = nil
    }

    func present(touchBar: NSTouchBar) {
        if let activeTouchBar, isVisible {
            CMDismissTouchBarFromTop(activeTouchBar)
            isVisible = false
        }

        previousMode = previousMode ?? CMCurrentTouchBarPresentationMode()
        activeTouchBar = touchBar
        isVisible = true

        CMPresentTouchBarOnTop(touchBar, 1)
        CMSetTouchBarPresentationMode("app")
    }

    func dismiss() {
        guard isVisible, let activeTouchBar else { return }
        CMDismissTouchBarFromTop(activeTouchBar)
        self.activeTouchBar = nil
        isVisible = false
    }

    func dismissToSystemTouchBar() {
        dismiss()
        CMSetTouchBarPresentationMode(previousMode ?? "appWithControlStrip")
    }
}
```
