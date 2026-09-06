#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
mkdir -p "${ROOT_DIR}/build"
TEST_DIR="$(mktemp -d "${ROOT_DIR}/build/helper-lifetime.XXXXXX")"
trap 'rm -rf "${TEST_DIR}"' EXIT
HELPER_PATH="${TEST_DIR}/ventaphobia.smc-helper"
PROBE_PATH="${TEST_DIR}/helper-lifetime-probe.dylib"

if [[ $# -gt 1 ]]; then
  echo "Usage: $0 [built-helper-path]" >&2
  exit 2
elif [[ $# -eq 1 ]]; then
  cp "$1" "${HELPER_PATH}"
else
  xcrun swiftc \
    -swift-version 5 -O -whole-module-optimization \
    -module-name ventaphobia_smc_helper \
    "${ROOT_DIR}/smc-helper/main.swift" \
    "${ROOT_DIR}/smc-helper/SMCHelperXPC.swift" \
    -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist \
    -Xlinker "${ROOT_DIR}/smc-helper/Info.plist" \
    -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __launchd_plist \
    -Xlinker "${ROOT_DIR}/smc-helper/Launchd.plist" \
    -o "${HELPER_PATH}"
fi

xcrun clang -dynamiclib -fobjc-arc -framework Foundation \
  "${ROOT_DIR}/scripts/tests/helper_lifetime_probe.m" -o "${PROBE_PATH}"

# Change only the temporary copy's signature to permit test instrumentation.
codesign --force --sign - --options 0 "${HELPER_PATH}"
codesign --force --sign - "${PROBE_PATH}"
DYLD_INSERT_LIBRARIES="${PROBE_PATH}" "${HELPER_PATH}"
