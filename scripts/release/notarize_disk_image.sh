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
elif [[ -n "${APPLE_ID:-}" || -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" || -n "${APPLE_TEAM_ID:-}" ]]; then
  : "${APPLE_ID:?Set APPLE_ID or NOTARYTOOL_PROFILE}"
  : "${APPLE_APP_SPECIFIC_PASSWORD:?Set APPLE_APP_SPECIFIC_PASSWORD or NOTARYTOOL_PROFILE}"
  : "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID or NOTARYTOOL_PROFILE}"

  xcrun notarytool store-credentials "${PROFILE_NAME}" \
    --apple-id "${APPLE_ID}" \
    --team-id "${APPLE_TEAM_ID}" \
    --password "${APPLE_APP_SPECIFIC_PASSWORD}"

  submit_with_keychain_profile "${DMG_PATH}"
elif [[ -n "${NOTARYTOOL_PROFILE:-}" ]]; then
  echo "Keychain profile '${PROFILE_NAME}' was not found." >&2
  echo "NOTARYTOOL_PROFILE is only a local keychain profile name, not a portable GitHub Actions secret." >&2
  echo "Configure APP_STORE_CONNECT_API_KEY_BASE64 with APP_STORE_CONNECT_KEY_ID and APP_STORE_CONNECT_ISSUER_ID, or APPLE_ID with APPLE_APP_SPECIFIC_PASSWORD and APPLE_TEAM_ID." >&2
  exit 1
else
  echo "Missing notarization credentials." >&2
  echo "Configure APP_STORE_CONNECT_API_KEY_BASE64 with APP_STORE_CONNECT_KEY_ID and APP_STORE_CONNECT_ISSUER_ID, or APPLE_ID with APPLE_APP_SPECIFIC_PASSWORD and APPLE_TEAM_ID." >&2
  exit 1
fi

xcrun stapler staple "${DMG_PATH}"
xcrun stapler validate "${DMG_PATH}"
codesign --verify --verbose=2 "${DMG_PATH}"
spctl --assess --type open --context context:primary-signature --verbose=4 "${DMG_PATH}"

echo "Notarized disk image ready at ${DMG_PATH}"
