# File: App-Info.plist

## Current Role

- Area: Repository support.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`App-Info.plist`](../../../App-Info.plist) |
| Wiki area | Repository support |
| Exists in current checkout | True |
| Size | 1308 bytes |
| Binary | False |
| Line count | 36 |
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
| `3bc472e` | 2026-04-22 | Add export compliance plist flag |
| `675fabf` | 2026-04-17 | Ship 14.0.5 helper recovery release |
| `c54c313` | 2026-04-16 | Harden helper client authorization and XPC validation |
| `7185d36` | 2026-04-15 | Improve fan control and alert surfaces |
| `b09dbec` | 2026-04-14 | Tighten app copy and weather privacy behavior |
| `011232b` | 2026-04-11 | Update website install video |
| `7b5f1e0` | 2026-04-08 | Publish Sparkle test update 11.2.9 |
| `419e331` | 2026-04-08 | Publish Sparkle 11.2.4 update |
| `62e4843` | 2026-04-01 | Remove leftover unused CoreVisor files |
| `61a73aa` | 2026-03-15 | Commit ig |
| `81e0938` | 2026-03-13 | Add auto fan aggressiveness slider and fix QEMU boot/display defaults |

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
	<key>CFBundleDevelopmentRegion</key>
	<string>$(DEVELOPMENT_LANGUAGE)</string>
	<key>CFBundleExecutable</key>
	<string>$(EXECUTABLE_NAME)</string>
	<key>CFBundleIdentifier</key>
	<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$(PRODUCT_NAME)</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$(MARKETING_VERSION)</string>
	<key>CFBundleVersion</key>
	<string>$(CURRENT_PROJECT_VERSION)</string>
	<key>CoreMonitorPrivilegedHelperLabel</key>
	<string>$(PRIVILEGED_HELPER_LABEL)</string>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.utilities</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSLocationWhenInUseUsageDescription</key>
	<string>Core-Monitor uses your location for the optional Touch Bar weather item.</string>
	<key>SMPrivilegedExecutables</key>
	<dict>
		<key>ventaphobia.smc-helper</key>
		<string>anchor apple generic and identifier "ventaphobia.smc-helper" and certificate leaf[subject.OU] = "6VDP675K4L"</string>
	</dict>
</dict>
</plist>
```
