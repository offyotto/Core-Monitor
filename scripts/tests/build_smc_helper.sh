#!/bin/bash
# Builds the SMC helper with Command Line Tools only, so it also works on Macs without Xcode.
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <output-path>" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

xcrun swiftc \
  -swift-version 5 -O -whole-module-optimization \
  -module-name ventaphobia_smc_helper \
  "${ROOT_DIR}/smc-helper/main.swift" \
  "${ROOT_DIR}/smc-helper/SMCHelperXPC.swift" \
  "${ROOT_DIR}/Shared/SMCFanDetection.swift" \
  "${ROOT_DIR}/Shared/FanControlLease.swift" \
  -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist \
  -Xlinker "${ROOT_DIR}/smc-helper/Info.plist" \
  -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __launchd_plist \
  -Xlinker "${ROOT_DIR}/smc-helper/Launchd.plist" \
  -o "$1"
