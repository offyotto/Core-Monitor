#!/bin/bash
# Runs on an EC2 Mac instance through SSM Run Command. Read-only hardware checks;
# it never writes to the SMC or starts the fan helper.
set -uo pipefail

RUN_URI="$1"
ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
OUT_DIR="$(mktemp -d /tmp/core-monitor-ec2-mac.XXXXXX)"
STATUS=0

run() {
  local name="$1"
  shift
  echo "== ${name}"
  if "$@" > "${OUT_DIR}/${name}.txt" 2>&1; then
    echo "   ok"
  else
    echo "   FAILED (exit $?)"
    STATUS=1
  fi
}

# Reads keys through the helper's SMC client (IOServiceOpen + IOConnectCallStructMethod),
# the same path the app uses. Passes when the fan count and at least one temperature read.
smc_reads() {
  local key value temps=0
  "${HELPER}" read FNum || return 1
  for key in F0Ac F0Mn F0Mx; do
    value=$("${HELPER}" read "${key}" 2>&1) || true
    echo "${key} ${value}"
  done
  for key in Tp01 Tp05 Tp09 Tp0D Tp1h Tp1t Te05 Te0S Tf04 Tf09 Tg05 Tg0D TC0P TG0P; do
    if value=$("${HELPER}" read "${key}" 2>&1); then
      temps=$((temps + 1))
    fi
    echo "${key} ${value}"
  done
  echo "temperature keys read: ${temps}"
  (( temps > 0 ))
}

# The app's USB-C diagnostics parse PortControllerInfo from AppleSmartBattery.
# Desktop Macs such as the Mac mini have no battery, so its absence is recorded, not failed.
usb_c_controllers() {
  ioreg -rw0 -c AppleSmartBattery | grep PortControllerInfo \
    || echo "No AppleSmartBattery PortControllerInfo on this Mac."
}

HELPER="${OUT_DIR}/ventaphobia.smc-helper"

run system sh -c 'sw_vers; sysctl -n hw.model machdep.cpu.brand_string hw.memsize; uptime'
run thermal pmset -g therm
run helper-build "${ROOT_DIR}/scripts/tests/build_smc_helper.sh" "${HELPER}"
run helper-lifetime "${ROOT_DIR}/scripts/tests/check_helper_lifetime.sh" "${HELPER}"
run smc-reads smc_reads
run usb-c-controllers usb_c_controllers

# EC2 macOS images ship Command Line Tools only. The full test suite needs Xcode,
# which a custom image adds later.
if xcode-select -p 2>/dev/null | grep -q '\.app/'; then
  run xcodebuild-version xcodebuild -version
  run xcodebuild-test xcodebuild test \
    -project "${ROOT_DIR}/Core-Monitor.xcodeproj" \
    -scheme Core-Monitor \
    -destination 'platform=macOS' \
    -resultBundlePath "${OUT_DIR}/Core-Monitor.xcresult" \
    CODE_SIGNING_ALLOWED=NO
else
  echo "Xcode not installed on this image; skipped xcodebuild test." | tee "${OUT_DIR}/xcodebuild-test.txt"
fi

if aws s3 cp --recursive --only-show-errors "${OUT_DIR}" "${RUN_URI}/"; then
  echo "Uploaded results to ${RUN_URI}"
else
  echo "Failed to upload results to ${RUN_URI}" >&2
  STATUS=1
fi
exit "${STATUS}"
