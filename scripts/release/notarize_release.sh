#!/bin/zsh
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <zip-path> <app-path>" >&2
  exit 1
fi

ZIP_PATH="$1"
APP_PATH="$2"
PROFILE_NAME="${NOTARYTOOL_PROFILE:-core-monitor-notary}"

if [[ -z "${NOTARYTOOL_PROFILE:-}" ]]; then
  : "${APPLE_ID:?Set APPLE_ID or NOTARYTOOL_PROFILE}"
  : "${APPLE_APP_SPECIFIC_PASSWORD:?Set APPLE_APP_SPECIFIC_PASSWORD or NOTARYTOOL_PROFILE}"
  : "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID or NOTARYTOOL_PROFILE}"

  xcrun notarytool store-credentials "${PROFILE_NAME}" \
    --apple-id "${APPLE_ID}" \
    --team-id "${APPLE_TEAM_ID}" \
    --password "${APPLE_APP_SPECIFIC_PASSWORD}"
fi

xcrun notarytool submit "${ZIP_PATH}" --keychain-profile "${PROFILE_NAME}" --wait
xcrun stapler staple "${APP_PATH}"

rm -f "${ZIP_PATH}"
ditto -c -k --keepParent "${APP_PATH}" "${ZIP_PATH}"

codesign --verify --deep --strict --verbose=2 "${APP_PATH}"
spctl --assess --type execute --verbose=4 "${APP_PATH}"

echo "Notarized bundle ready at ${ZIP_PATH}"
