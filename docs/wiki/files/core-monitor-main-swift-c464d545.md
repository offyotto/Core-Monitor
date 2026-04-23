# File: Core-Monitor/main.swift

## Current Role

- Area: Core app.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/main.swift`](../../../Core-Monitor/main.swift) |
| Wiki area | Core app |
| Exists in current checkout | True |
| Size | 415 bytes |
| Binary | False |
| Line count | 13 |
| Extension | `.swift` |

## Imports

`AppKit`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| None detected |  |  |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `566777a` | 2026-04-16 | Add explicit macOS app entry point |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import AppKit

if #available(macOS 13.0, *) {
    let coreMonitorAppDelegate = MainActor.assumeIsolated { CoreMonitorApplicationDelegate() }
    let application = NSApplication.shared
    MainActor.assumeIsolated {
        application.delegate = coreMonitorAppDelegate
    }
    _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
} else {
    fatalError("Core Monitor requires macOS 13.0 or newer.")
}
```
