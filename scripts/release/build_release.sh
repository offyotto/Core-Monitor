#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_DIR="${BUILD_DIR:-${ROOT_DIR}/build/release}"
ARCHIVE_PATH="${ARCHIVE_PATH:-${BUILD_DIR}/Core-Monitor.xcarchive}"
EXPORT_DIR="${EXPORT_DIR:-${BUILD_DIR}/export}"
APP_PATH="${EXPORT_DIR}/Core-Monitor.app"
ZIP_PATH="${ZIP_PATH:-${BUILD_DIR}/Core-Monitor.zip}"

rm -rf "${BUILD_DIR}"
mkdir -p "${EXPORT_DIR}"

xcodebuild \
  -project "${ROOT_DIR}/Core-Monitor.xcodeproj" \
  -scheme Core-Monitor \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "${ARCHIVE_PATH}" \
  archive

cp -R "${ARCHIVE_PATH}/Products/Applications/Core-Monitor.app" "${APP_PATH}"

codesign --verify --deep --strict --verbose=2 "${APP_PATH}"
ditto -c -k --keepParent "${APP_PATH}" "${ZIP_PATH}"

echo "Release bundle ready at ${ZIP_PATH}"
