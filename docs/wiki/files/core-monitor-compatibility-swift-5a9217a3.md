# File: Core-Monitor/Compatibility.swift

## Current Role

- Area: Core app.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/Compatibility.swift`](../../../Core-Monitor/Compatibility.swift) |
| Wiki area | Core app |
| Exists in current checkout | True |
| Size | 5460 bytes |
| Binary | False |
| Line count | 174 |
| Extension | `.swift` |

## Imports

`SwiftUI`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| extension | `Color` | 2 |
| extension | `Font` | 26 |
| struct | `CMPanel` | 32 |
| func | `body` | 35 |
| struct | `BasicPanel` | 49 |
| func | `body` | 51 |
| extension | `View` | 57 |
| func | `cmPanel` | 59 |
| func | `basicPanel` | 62 |
| func | `cmGlassBackground` | 66 |
| func | `cmLiquidGlassCard` | 72 |
| func | `cmKerning` | 107 |
| func | `cmNumericTextTransition` | 116 |
| func | `cmPulseSymbolEffect` | 125 |
| func | `cmBounceSymbolEffect` | 134 |
| func | `cmHandleSpaceKeyPress` | 143 |
| func | `cmHideWindowToolbarBackground` | 155 |
| func | `cmRemoveWindowToolbarTitle` | 164 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `9b8b37f` | 2026-04-16 | Guard liquid glass effect for older toolchains |
| `31da3f2` | 2026-04-06 | ui update |
| `0fa238c` | 2026-04-02 | commits. |
| `3ddebed` | 2026-03-27 | add benchmark |
| `3252194` | 2026-03-27 | Clean repo and keep only active Core-Monitor project |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import SwiftUI

extension Color {
    static let cmBackground = Color(red: 0.93, green: 0.93, blue: 0.93)
    static let cmSurface = Color.white
    static let cmSurfaceRaised = Color(red: 0.96, green: 0.96, blue: 0.96)
    static let cmSurfaceSoft = Color(red: 0.90, green: 0.90, blue: 0.90)
    static let cmBorder = Color.black.opacity(0.28)
    static let cmBorderBright = Color.black.opacity(0.45)
    static let cmAmber = Color(red: 1.00, green: 0.78, blue: 0.31)
    static let cmGreen = Color(red: 0.45, green: 0.93, blue: 0.74)
    static let cmRed = Color(red: 1.00, green: 0.45, blue: 0.47)
    static let cmBlue = Color.black
    static let cmPurple = Color.black
    static let cmMint = Color(red: 0.18, green: 0.18, blue: 0.18)
    static let cmTextPrimary = Color.black
    static let cmTextSecondary = Color(red: 0.20, green: 0.20, blue: 0.20)
    static let cmTextDim = Color(red: 0.38, green: 0.38, blue: 0.38)

    static let bBackground = Color.white
    static let bSurface = Color.white
    static let bBorder = Color.black.opacity(0.92)
    static let bText = Color.black
    static let bDim = Color.black.opacity(0.55)
}

extension Font {
    static func cmMono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

private struct CMPanel: ViewModifier {
    var accent: Color = .clear

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.cmSurface)
```
