# File: Core-Monitor/AppVersion.swift

## Current Role

- Area: Core app.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/AppVersion.swift`](../../../Core-Monitor/AppVersion.swift) |
| Wiki area | Core app |
| Exists in current checkout | True |
| Size | 760 bytes |
| Binary | False |
| Line count | 21 |
| Extension | `.swift` |

## Imports

`Foundation`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| enum | `AppVersion` | 2 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `81ce4d9` | 2026-04-14 | Save current Core-Monitor rescue changes |
| `011232b` | 2026-04-11 | Update website install video |
| `deca3a0` | 2026-04-09 | Publish Sparkle test update 11.2.10 |
| `7b5f1e0` | 2026-04-08 | Publish Sparkle test update 11.2.9 |
| `591aecf` | 2026-04-08 | Publish Sparkle test update 11.2.8 |
| `9aef922` | 2026-04-08 | Publish Sparkle test update 11.2.7 |
| `9615be6` | 2026-04-08 | Publish Sparkle test update 11.2.6 |
| `bf8496e` | 2026-04-08 | Publish Sparkle 11.2.5 update |
| `419e331` | 2026-04-08 | Publish Sparkle 11.2.4 update |
| `0124c65` | 2026-04-08 | Publish Sparkle test update 11.2.3 |
| `1738288` | 2026-04-08 | Publish Sparkle test update 11.22 |
| `a4dc9d6` | 2026-04-08 | Publish Sparkle update for 11.2.1 |
| `0fa238c` | 2026-04-02 | commits. |
| `3651f98` | 2026-03-29 | Remove CoreVisor and virtualization support |
| `b436125` | 2026-03-28 | Improve Touch Bar behavior, CoreVisor UI, and docs |
| `3ddebed` | 2026-03-27 | add benchmark |
| `3252194` | 2026-03-27 | Clean repo and keep only active Core-Monitor project |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import Foundation

enum AppVersion {
    static var current: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let shortVersion = (info["CFBundleShortVersionString"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let build = (info["CFBundleVersion"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

        switch (shortVersion, build) {
        case let (version?, build?) where !version.isEmpty && !build.isEmpty && build != version:
            return "\(version) (\(build))"
        case let (version?, _) where !version.isEmpty:
            return version
        case let (_, build?) where !build.isEmpty:
            return build
        default:
            return "Development"
        }
    }
}
```
