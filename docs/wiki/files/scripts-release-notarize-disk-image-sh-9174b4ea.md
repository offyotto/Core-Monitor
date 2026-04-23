# File: scripts/release/notarize_disk_image.sh

## Current Role

- Area: Developer and release scripts.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`scripts/release/notarize_disk_image.sh`](../../../scripts/release/notarize_disk_image.sh) |
| Wiki area | Developer and release scripts |
| Exists in current checkout | True |
| Size | 2228 bytes |
| Binary | False |
| Line count | 60 |
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
| `04afad0` | 2026-04-22 | Fix release notarization credential fallback |
| `69cc386` | 2026-04-18 | Add DMG release packaging |
| `675fabf` | 2026-04-17 | Ship 14.0.5 helper recovery release |
| `7afc598` | 2026-04-15 | Automate releases and sharpen product positioning |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
#!/bin/zsh
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <dmg-path>" >&2
  exit 1
fi

DMG_PATH="$1"
PROFILE_NAME="${NOTARYTOOL_PROFILE:-core-monitor-notary}"
APP_STORE_CONNECT_KEY_PATH="${APP_STORE_CONNECT_KEY_PATH:-}"

submit_with_api_key() {
  local artifact_path="$1"
  local key_path="$2"
  : "${APP_STORE_CONNECT_KEY_ID:?Set APP_STORE_CONNECT_KEY_ID when using App Store Connect API key notarization}"
  : "${APP_STORE_CONNECT_ISSUER_ID:?Set APP_STORE_CONNECT_ISSUER_ID when using App Store Connect API key notarization}"

  xcrun notarytool submit "${artifact_path}" \
    --key "${key_path}" \
    --key-id "${APP_STORE_CONNECT_KEY_ID}" \
    --issuer "${APP_STORE_CONNECT_ISSUER_ID}" \
    --wait
}

submit_with_keychain_profile() {
  local artifact_path="$1"
  xcrun notarytool submit "${artifact_path}" --keychain-profile "${PROFILE_NAME}" --wait
}

if [[ -n "${APP_STORE_CONNECT_API_KEY_BASE64:-}" ]]; then
  APP_STORE_CONNECT_KEY_PATH="${RUNNER_TEMP:-/tmp}/AuthKey_${APP_STORE_CONNECT_KEY_ID:-api}.p8"
  echo -n "${APP_STORE_CONNECT_API_KEY_BASE64}" | base64 -D > "${APP_STORE_CONNECT_KEY_PATH}"
  submit_with_api_key "${DMG_PATH}" "${APP_STORE_CONNECT_KEY_PATH}"
elif [[ -n "${APP_STORE_CONNECT_KEY_PATH}" ]]; then
  submit_with_api_key "${DMG_PATH}" "${APP_STORE_CONNECT_KEY_PATH}"
elif xcrun notarytool history --keychain-profile "${PROFILE_NAME}" >/dev/null 2>&1; then
  submit_with_keychain_profile "${DMG_PATH}"
elif [[ -z "${NOTARYTOOL_PROFILE:-}" ]]; then
  : "${APPLE_ID:?Set APPLE_ID or NOTARYTOOL_PROFILE}"
```
