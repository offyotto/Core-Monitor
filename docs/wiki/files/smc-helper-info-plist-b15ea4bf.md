# File: smc-helper/Info.plist

## Current Role

- Area: Privileged helper target.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`smc-helper/Info.plist`](../../../smc-helper/Info.plist) |
| Wiki area | Privileged helper target |
| Exists in current checkout | True |
| Size | 980 bytes |
| Binary | False |
| Line count | 28 |
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
| `675fabf` | 2026-04-17 | Ship 14.0.5 helper recovery release |
| `e24d811` | 2026-04-16 | :)) |
| `c54c313` | 2026-04-16 | Harden helper client authorization and XPC validation |
| `7185d36` | 2026-04-15 | Improve fan control and alert surfaces |
| `011232b` | 2026-04-11 | Update website install video |
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
	<!--
	 Keep these helper identity fields concrete. This plist is embedded into the
	 helper binary via -sectcreate, so build-setting placeholders like
	 $(EXECUTABLE_NAME) are not expanded here and will break SMJobBless installs.
	-->
	<key>CFBundleExecutable</key>
	<string>ventaphobia.smc-helper</string>
	<key>CFBundleIdentifier</key>
	<string>ventaphobia.smc-helper</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>ventaphobia.smc-helper</string>
	<key>CFBundlePackageType</key>
	<string>BNDL</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>SMAuthorizedClients</key>
	<array>
		<string>anchor apple generic and identifier "CoreTools.Core-Monitor" and certificate leaf[subject.OU] = "6VDP675K4L"</string>
	</array>
</dict>
</plist>
```
