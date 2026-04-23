# File: Core-Monitor/KernelPanicMusicPlayer.swift

## Current Role

- Area: Kernel Panic / Weird Mode.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/KernelPanicMusicPlayer.swift`](../../../Core-Monitor/KernelPanicMusicPlayer.swift) |
| Wiki area | Kernel Panic / Weird Mode |
| Exists in current checkout | True |
| Size | 2452 bytes |
| Binary | False |
| Line count | 114 |
| Extension | `.swift` |

## Imports

`AVFoundation`, `Foundation`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| enum | `KernelPanicMusicCue` | 3 |
| class | `KernelPanicMusicPlayer` | 45 |
| func | `play` | 50 |
| func | `pause` | 89 |
| func | `resume` | 93 |
| func | `stop` | 107 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `4372e29` | 2026-04-19 | Optimize 14.08 release packaging |
| `608ea0c` | 2026-04-19 | Optimize 14.08 release packaging |
| `aca5d59` | 2026-04-19 | Add Kernel Panic release payload |
| `210356e` | 2026-04-19 | Add Kernel Panic release payload |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import AVFoundation
import Foundation

enum KernelPanicMusicCue: String, Equatable {
    case silence
    case phaseOne
    case phaseTwo
    case phaseThree

    var resourceName: String? {
        switch self {
        case .silence:
            return nil
        case .phaseOne:
            return "kernelpanic_phase1"
        case .phaseTwo:
            return "kernelpanic_phase2"
        case .phaseThree:
            return "kernelpanic_phase3"
        }
    }

    var resourceExtension: String? {
        switch self {
        case .silence:
            return nil
        default:
            return "m4a"
        }
    }

    var volume: Float {
        switch self {
        case .silence:
            return 0
        case .phaseOne:
            return 0.7
        case .phaseTwo:
            return 0.78
        case .phaseThree:
```
