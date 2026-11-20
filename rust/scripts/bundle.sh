#!/bin/bash
# Builds the release binaries and assembles build/rust/Core-Monitor.app.
# Set CODESIGN_IDENTITY to sign the app and helper (required for fan control).
set -euo pipefail

RUST_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${RUST_DIR}/../build/rust"
TARGET="${TARGET:-aarch64-apple-darwin}"
VERSION="$(sed -n 's/^version = "\(.*\)"/\1/p' "${RUST_DIR}/Cargo.toml" | head -1)"

cargo build --manifest-path "${RUST_DIR}/Cargo.toml" --release --target "${TARGET}" -p core-monitor -p smc-helper

APP="${OUT_DIR}/Core-Monitor.app"
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Library/LaunchServices" "${APP}/Contents/Resources"
cp "${RUST_DIR}/target/${TARGET}/release/core-monitor" "${APP}/Contents/MacOS/core-monitor"
cp "${RUST_DIR}/target/${TARGET}/release/smc-helper" "${APP}/Contents/Library/LaunchServices/ventaphobia.smc-helper-rs"
sed "s/@VERSION@/${VERSION}/g" "${RUST_DIR}/packaging/Info.plist" > "${APP}/Contents/Info.plist"
ICON="${RUST_DIR}/../Core-Monitor/Assets.xcassets/AppIcon.appiconset/icon-512.png"
[[ -f "${ICON}" ]] && cp "${ICON}" "${APP}/Contents/Resources/AppIcon.png"

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  codesign --force --options runtime --identifier ventaphobia.smc-helper-rs --sign "${CODESIGN_IDENTITY}" \
    "${APP}/Contents/Library/LaunchServices/ventaphobia.smc-helper-rs"
  codesign --force --options runtime --sign "${CODESIGN_IDENTITY}" "${APP}"
fi
echo "${APP}"
