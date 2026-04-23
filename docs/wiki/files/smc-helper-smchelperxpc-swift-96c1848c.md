# File: smc-helper/SMCHelperXPC.swift

## Current Role

- Area: Privileged helper target.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`smc-helper/SMCHelperXPC.swift`](../../../smc-helper/SMCHelperXPC.swift) |
| Wiki area | Privileged helper target |
| Exists in current checkout | True |
| Size | 475 bytes |
| Binary | False |
| Line count | 9 |
| Extension | `.swift` |

## Imports

`Foundation`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| protocol | `SMCHelperXPCProtocol` | 2 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `675fabf` | 2026-04-17 | Ship 14.0.5 helper recovery release |
| `c54c313` | 2026-04-16 | Harden helper client authorization and XPC validation |
| `0fa238c` | 2026-04-02 | commits. |
| `62e4843` | 2026-04-01 | Remove leftover unused CoreVisor files |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import Foundation

@objc protocol SMCHelperXPCProtocol {
    nonisolated func setFanManual(_ fanID: Int, rpm: Int, withReply reply: @escaping (NSString?) -> Void)
    nonisolated func setFanAuto(_ fanID: Int, withReply reply: @escaping (NSString?) -> Void)
    nonisolated func readValue(_ key: String, withReply reply: @escaping (NSNumber?, NSString?) -> Void)
    nonisolated func readControlMetadata(withReply reply: @escaping (NSString?, NSNumber?, NSString?) -> Void)
}
```
