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
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="${RELEASE_CODE_SIGN_IDENTITY}" \
  -archivePath "${ARCHIVE_PATH}" \
  archive

cp -R "${ARCHIVE_PATH}/Products/Applications/Core-Monitor.app" "${APP_PATH}"

codesign --verify --deep --strict --verbose=2 "${APP_PATH}"
ditto -c -k --keepParent "${APP_PATH}" "${ZIP_PATH}"

echo "Release bundle ready at ${ZIP_PATH}"
