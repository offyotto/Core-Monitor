# File: Core-Monitor/MacModelRegistry.swift

## Current Role

- Area: Core app.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/MacModelRegistry.swift`](../../../Core-Monitor/MacModelRegistry.swift) |
| Wiki area | Core app |
| Exists in current checkout | True |
| Size | 10241 bytes |
| Binary | False |
| Line count | 131 |
| Extension | `.swift` |

## Imports

`Foundation`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| enum | `MacFamily` | 2 |
| struct | `MacModelEntry` | 24 |
| enum | `MacModelRegistry` | 32 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `006d70b` | 2026-04-16 | Refresh Mac model registry and fan guidance |
| `3ddebed` | 2026-03-27 | add benchmark |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import Foundation

enum MacFamily: String, CaseIterable, Identifiable {
    case macBookAirMSeries = "MacBook Air M-series"
    case macBookAirIntel = "MacBook Air Intel"
    case macBookProMSeries = "MacBook Pro M-series"
    case macBookProIntel = "MacBook Pro Intel"
    case macMini = "Mac mini"
    case iMac = "iMac"
    case macStudio = "Mac Studio"
    case macPro = "Mac Pro"

    var id: String { rawValue }

    var isAppleSiliconPortable: Bool {
        switch self {
        case .macBookAirMSeries, .macBookProMSeries:
            return true
        case .macBookAirIntel, .macBookProIntel, .macMini, .iMac, .macStudio, .macPro:
            return false
        }
    }
}

struct MacModelEntry: Identifiable, Hashable {
    let hwModel: String
    let friendlyName: String
    let family: MacFamily

    var id: String { hwModel }
}

enum MacModelRegistry {
    static let entries: [MacModelEntry] = [
        .init(hwModel: "MacBookAir7,2", friendlyName: "MacBook Air (13-inch, Early 2015)", family: .macBookAirIntel),
        .init(hwModel: "MacBookAir8,1", friendlyName: "MacBook Air (Retina, 13-inch, 2018)", family: .macBookAirIntel),
        .init(hwModel: "MacBookAir8,2", friendlyName: "MacBook Air (Retina, 13-inch, 2019)", family: .macBookAirIntel),
        .init(hwModel: "MacBookAir9,1", friendlyName: "MacBook Air (Retina, 13-inch, 2020 Intel)", family: .macBookAirIntel),
        .init(hwModel: "MacBookAir10,1", friendlyName: "MacBook Air (M1, 2020)", family: .macBookAirMSeries),
        .init(hwModel: "Mac14,2", friendlyName: "MacBook Air (M2, 2022)", family: .macBookAirMSeries),
```
