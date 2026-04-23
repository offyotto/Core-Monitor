# File: scripts/release/build_dmg.sh

## Current Role

- Area: Developer and release scripts.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`scripts/release/build_dmg.sh`](../../../scripts/release/build_dmg.sh) |
| Wiki area | Developer and release scripts |
| Exists in current checkout | True |
| Size | 1275 bytes |
| Binary | False |
| Line count | 49 |
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
| `69cc386` | 2026-04-18 | Add DMG release packaging |
| `3fe35bf` | 2026-04-18 | Add DMG release packaging |

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
APP_PATH="${1:-${BUILD_DIR}/export/Core-Monitor.app}"
DMG_PATH_INPUT="${2:-${BUILD_DIR}/Core-Monitor.dmg}"
DMG_OUTPUT_BASE="${DMG_PATH_INPUT%.dmg}"
DMG_PATH="${DMG_OUTPUT_BASE}.dmg"
RW_DMG_PATH="${BUILD_DIR}/Core-Monitor-rw.dmg"
STAGING_DIR="${BUILD_DIR}/dmg-root"
VOLUME_NAME="${VOLUME_NAME:-Core-Monitor}"
RELEASE_CODE_SIGN_IDENTITY="${RELEASE_CODE_SIGN_IDENTITY:-Developer ID Application}"

if [[ ! -d "${APP_PATH}" ]]; then
  echo "App bundle not found at ${APP_PATH}" >&2
  exit 1
fi

rm -rf "${STAGING_DIR}" "${RW_DMG_PATH}" "${DMG_PATH}"
mkdir -p "${STAGING_DIR}"

cp -R "${APP_PATH}" "${STAGING_DIR}/Core-Monitor.app"
ln -s /Applications "${STAGING_DIR}/Applications"

hdiutil create \
  -volname "${VOLUME_NAME}" \
  -srcfolder "${STAGING_DIR}" \
  -fs HFS+ \
  -format UDRW \
  "${RW_DMG_PATH}"

hdiutil convert "${RW_DMG_PATH}" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "${DMG_OUTPUT_BASE}"

codesign \
  --force \
  --sign "${RELEASE_CODE_SIGN_IDENTITY}" \
```
