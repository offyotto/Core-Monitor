#!/bin/bash
# Runs on an EC2 Mac instance through SSM Run Command. Installs Xcode from an
# Apple-signed .xip in the project's private S3 bucket, so the instance can be
# saved as an image that already has Xcode.
set -euo pipefail

XIP_URI="$1"
WORK_DIR="$(mktemp -d /private/var/tmp/xcode-install.XXXXXX)"
trap 'rm -rf "${WORK_DIR}"' EXIT

echo "== Downloading ${XIP_URI}"
aws s3 cp --only-show-errors "${XIP_URI}" "${WORK_DIR}/Xcode.xip"

echo "== Checking the archive signature"
pkgutil --check-signature "${WORK_DIR}/Xcode.xip" | tee "${WORK_DIR}/signature.txt"
grep -q "signed Apple Software" "${WORK_DIR}/signature.txt"

echo "== Expanding (this takes a while)"
(cd "${WORK_DIR}" && xip --expand Xcode.xip)
rm -f "${WORK_DIR}/Xcode.xip"

APP_PATH="$(find "${WORK_DIR}" -maxdepth 1 -name 'Xcode*.app' -print -quit)"
if [[ -z "${APP_PATH}" ]]; then
  echo "No Xcode app found in the archive." >&2
  exit 1
fi

rm -rf /Applications/Xcode.app
mv "${APP_PATH}" /Applications/Xcode.app
xcode-select --switch /Applications/Xcode.app/Contents/Developer
xcodebuild -license accept
xcodebuild -runFirstLaunch
xcodebuild -version
