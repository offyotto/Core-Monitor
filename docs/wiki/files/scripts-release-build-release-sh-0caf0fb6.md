# File: scripts/release/build_release.sh

## Current Role

- Area: Developer and release scripts.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`scripts/release/build_release.sh`](../../../scripts/release/build_release.sh) |
| Wiki area | Developer and release scripts |
| Exists in current checkout | True |
| Size | 2287 bytes |
| Binary | False |
| Line count | 67 |
| Extension | `.sh` |

## Imports

None detected.

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| None detected |  |  |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `4372e29` | 2026-04-19 | Optimize 14.08 release packaging |
| `608ea0c` | 2026-04-19 | Optimize 14.08 release packaging |
| `675fabf` | 2026-04-17 | Ship 14.0.5 helper recovery release |
| `5b26198` | 2026-04-17 | Align release asset and add Homebrew guide |
| `8bfc685` | 2026-04-16 | Stabilize signing and WeatherKit release packaging |
| `7afc598` | 2026-04-15 | Automate releases and sharpen product positioning |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_DIR="${BUILD_DIR:-${ROOT_DIR}/build/release}"
ARCHIVE_PATH="${ARCHIVE_PATH:-${BUILD_DIR}/Core-Monitor.xcarchive}"
EXPORT_DIR="${EXPORT_DIR:-${BUILD_DIR}/export}"
APP_PATH="${EXPORT_DIR}/Core-Monitor.app"
ZIP_PATH="${ZIP_PATH:-${BUILD_DIR}/Core-Monitor.app.zip}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-${ROOT_DIR}/build/DerivedData/release}"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-6VDP675K4L}"
RELEASE_CODE_SIGN_IDENTITY="${RELEASE_CODE_SIGN_IDENTITY:-Developer ID Application}"
RELEASE_PROVISIONING_PROFILE_SPECIFIER="${RELEASE_PROVISIONING_PROFILE_SPECIFIER:-Mac Team Direct Provisioning Profile: CoreTools.Core-Monitor}"
EXPORT_OPTIONS_PLIST="${EXPORT_OPTIONS_PLIST:-${BUILD_DIR}/exportOptions.plist}"
RELEASE_ARCHS="${RELEASE_ARCHS:-arm64}"

rm -rf "${BUILD_DIR}"
mkdir -p "${EXPORT_DIR}"
mkdir -p "${DERIVED_DATA_PATH}"

xcodebuild \
  -project "${ROOT_DIR}/Core-Monitor.xcodeproj" \
  -scheme Core-Monitor \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM}" \
  ARCHS="${RELEASE_ARCHS}" \
  ONLY_ACTIVE_ARCH=YES \
  EXCLUDED_ARCHS=x86_64 \
  CODE_SIGN_STYLE=Automatic \
  -archivePath "${ARCHIVE_PATH}" \
  archive

cat > "${EXPORT_OPTIONS_PLIST}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
```
