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
  CODE_SIGN_STYLE=Automatic \
  -archivePath "${ARCHIVE_PATH}" \
  archive

cat > "${EXPORT_OPTIONS_PLIST}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>teamID</key>
  <string>${DEVELOPMENT_TEAM}</string>
  <key>signingCertificate</key>
  <string>${RELEASE_CODE_SIGN_IDENTITY}</string>
  <key>provisioningProfiles</key>
  <dict>
    <key>CoreTools.Core-Monitor</key>
    <string>${RELEASE_PROVISIONING_PROFILE_SPECIFIER}</string>
  </dict>
</dict>
</plist>
EOF

xcodebuild \
  -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportPath "${EXPORT_DIR}" \
  -exportOptionsPlist "${EXPORT_OPTIONS_PLIST}"

codesign --verify --deep --strict --verbose=2 "${APP_PATH}"
ditto -c -k --keepParent "${APP_PATH}" "${ZIP_PATH}"

echo "Release bundle ready at ${ZIP_PATH}"
