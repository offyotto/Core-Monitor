# File: smc-helper-Launchd.plist

## Current Role

- Area: Privileged helper target.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`smc-helper-Launchd.plist`](../../../smc-helper-Launchd.plist) |
| Wiki area | Privileged helper target |
| Exists in current checkout | True |
| Size | 362 bytes |
| Binary | False |
| Line count | 14 |
| Extension | `.plist` |

## Imports

None detected.

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| None detected |  |  |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `0fa238c` | 2026-04-02 | commits. |
| `62e4843` | 2026-04-01 | Remove leftover unused CoreVisor files |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>ventaphobia.smc-helper</string>
    <key>MachServices</key>
    <dict>
        <key>ventaphobia.smc-helper</key>
        <true/>
    </dict>
</dict>
</plist>
```
