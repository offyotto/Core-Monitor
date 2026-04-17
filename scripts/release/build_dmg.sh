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
  --timestamp \
  "${DMG_PATH}"

codesign --verify --verbose=2 "${DMG_PATH}"

rm -rf "${STAGING_DIR}" "${RW_DMG_PATH}"

echo "Release disk image ready at ${DMG_PATH}"
