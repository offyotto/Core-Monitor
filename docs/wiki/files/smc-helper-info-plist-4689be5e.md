# File: smc-helper-Info.plist

## Current Role

- Area: Privileged helper target.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`smc-helper-Info.plist`](../../../smc-helper-Info.plist) |
| Wiki area | Privileged helper target |
| Exists in current checkout | True |
| Size | 824 bytes |
| Binary | False |
| Line count | 23 |
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
| `7185d36` | 2026-04-15 | Improve fan control and alert surfaces |
| `011232b` | 2026-04-11 | Update website install video |
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
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>BNDL</string>
    <key>CFBundleVersion</key>
    <string>$(CURRENT_PROJECT_VERSION)</string>
	<key>SMAuthorizedClients</key>
	<array>
		<string>identifier "$(CORE_MONITOR_APP_BUNDLE_IDENTIFIER)" and anchor apple generic and certificate leaf[subject.OU] = "$(DEVELOPMENT_TEAM)"</string>
	</array>
</dict>
</plist>
```
