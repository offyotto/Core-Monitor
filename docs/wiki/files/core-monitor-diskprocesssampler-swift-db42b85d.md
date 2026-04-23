# File: Core-Monitor/DiskProcessSampler.swift

## Current Role

- Area: Core app.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/DiskProcessSampler.swift`](../../../Core-Monitor/DiskProcessSampler.swift) |
| Wiki area | Core app |
| Exists in current checkout | True |
| Size | 8283 bytes |
| Binary | False |
| Line count | 239 |
| Extension | `.swift` |

## Imports

`AppKit`, `Combine`, `Darwin`, `Foundation`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| struct | `DiskProcessActivity` | 5 |
| struct | `DiskProcessCounter` | 29 |
| enum | `DiskProcessSampling` | 36 |
| class | `DiskProcessSampler` | 144 |
| func | `start` | 162 |
| func | `stop` | 190 |
| func | `sample` | 211 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `3094642` | 2026-04-16 | Cache disk activity away from menu bar renders |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import AppKit
import Combine
import Darwin
import Foundation

struct DiskProcessActivity: Identifiable, Equatable {
    let name: String
    let readBytes: UInt64
    let writtenBytes: UInt64

    var id: String { name }
    var totalBytes: UInt64 { readBytes + writtenBytes }
    var readLabel: String { Self.formatBytes(readBytes) }
    var writeLabel: String { Self.formatBytes(writtenBytes) }

    static func formatBytes(_ bytes: UInt64) -> String {
        switch bytes {
        case 0..<1024:
            return "\(bytes)B"
        case 1024..<1_048_576:
            return String(format: "%.0fK", Double(bytes) / 1024.0)
        case 1_048_576..<1_073_741_824:
            return String(format: "%.1fM", Double(bytes) / 1_048_576.0)
        default:
            return String(format: "%.1fG", Double(bytes) / 1_073_741_824.0)
        }
    }
}

struct DiskProcessCounter: Equatable {
    let pid: pid_t
    let name: String
    let readBytes: UInt64
    let writtenBytes: UInt64
}

enum DiskProcessSampling {
    static func activities(
        from counters: [DiskProcessCounter],
        previousCounters: [pid_t: DiskProcessCounter],
```
