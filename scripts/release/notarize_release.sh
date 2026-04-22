#!/bin/zsh
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <zip-path> <app-path>" >&2
  exit 1
fi

ZIP_PATH="$1"
APP_PATH="$2"
PROFILE_NAME="${NOTARYTOOL_PROFILE:-core-monitor-notary}"
APP_STORE_CONNECT_KEY_PATH="${APP_STORE_CONNECT_KEY_PATH:-}"

submit_with_api_key() {
  local key_path="$1"
  : "${APP_STORE_CONNECT_KEY_ID:?Set APP_STORE_CONNECT_KEY_ID when using App Store Connect API key notarization}"
  : "${APP_STORE_CONNECT_ISSUER_ID:?Set APP_STORE_CONNECT_ISSUER_ID when using App Store Connect API key notarization}"

  xcrun notarytool submit "${ZIP_PATH}" \
    --key "${key_path}" \
    --key-id "${APP_STORE_CONNECT_KEY_ID}" \
    --issuer "${APP_STORE_CONNECT_ISSUER_ID}" \
    --wait
}

if [[ -n "${APP_STORE_CONNECT_API_KEY_BASE64:-}" ]]; then
  APP_STORE_CONNECT_KEY_PATH="${RUNNER_TEMP:-/tmp}/AuthKey_${APP_STORE_CONNECT_KEY_ID:-api}.p8"
  echo -n "${APP_STORE_CONNECT_API_KEY_BASE64}" | base64 -D > "${APP_STORE_CONNECT_KEY_PATH}"
  submit_with_api_key "${APP_STORE_CONNECT_KEY_PATH}"
elif [[ -n "${APP_STORE_CONNECT_KEY_PATH}" ]]; then
  submit_with_api_key "${APP_STORE_CONNECT_KEY_PATH}"
elif xcrun notarytool history --keychain-profile "${PROFILE_NAME}" >/dev/null 2>&1; then
  xcrun notarytool submit "${ZIP_PATH}" --keychain-profile "${PROFILE_NAME}" --wait
elif [[ -n "${APPLE_ID:-}" || -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" || -n "${APPLE_TEAM_ID:-}" ]]; then
  : "${APPLE_ID:?Set APPLE_ID or NOTARYTOOL_PROFILE}"
  : "${APPLE_APP_SPECIFIC_PASSWORD:?Set APPLE_APP_SPECIFIC_PASSWORD or NOTARYTOOL_PROFILE}"
  : "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID or NOTARYTOOL_PROFILE}"

  xcrun notarytool store-credentials "${PROFILE_NAME}" \
    --apple-id "${APPLE_ID}" \
    --team-id "${APPLE_TEAM_ID}" \
    --password "${APPLE_APP_SPECIFIC_PASSWORD}"

  xcrun notarytool submit "${ZIP_PATH}" --keychain-profile "${PROFILE_NAME}" --wait
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

xcrun stapler staple "${APP_PATH}"

rm -f "${ZIP_PATH}"
ditto -c -k --keepParent "${APP_PATH}" "${ZIP_PATH}"

codesign --verify --deep --strict --verbose=2 "${APP_PATH}"
spctl --assess --type execute --verbose=4 "${APP_PATH}"

echo "Notarized bundle ready at ${ZIP_PATH}"
