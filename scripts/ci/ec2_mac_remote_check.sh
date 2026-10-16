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

# Reads keys through the helper's read-only SMC client (IOServiceOpen +
# IOConnectCallStructMethod), the same path the app uses. The temperature keys
# come from the app's own catalog for this chip. Passes when the fan count and
# at least one CPU temperature read.
smc_reads() {
  local chip fans fan group key value cpu_read=0
  chip="$(sysctl -n machdep.cpu.brand_string)"
  echo "chip ${chip}"

  fans=$("${HELPER}" read FNum) || return 1
  echo "fans ${fans}"
  for (( fan = 0; fan < ${fans%.*}; fan++ )); do
    for key in "F${fan}Ac" "F${fan}Mn" "F${fan}Mx"; do
      value=$("${HELPER}" read "${key}" 2>&1) || value="missing (${value})"
      echo "fan ${key} ${value}"
    done
  done

  while read -r group key; do
    if value=$("${HELPER}" read "${key}" 2>&1); then
      [[ "${group}" == cpu ]] && cpu_read=$((cpu_read + 1))
    else
      value="missing (${value})"
    fi
    echo "${group} ${key} ${value}"
  done < <("${KEY_PROBE}" "${chip}")

  echo "summary $(grep -c '' <("${KEY_PROBE}" "${chip}")) catalog keys, ${cpu_read} CPU temperatures read"
  (( cpu_read > 0 ))
}

# The app's USB-C diagnostics parse PortControllerInfo from AppleSmartBattery.
# Desktop Macs such as the Mac mini have no battery, so its absence is recorded, not failed.
usb_c_controllers() {
  ioreg -rw0 -c AppleSmartBattery | grep PortControllerInfo \
    || echo "No AppleSmartBattery PortControllerInfo on this Mac."
}

HELPER="${OUT_DIR}/ventaphobia.smc-helper"
KEY_PROBE="${OUT_DIR}/smc-key-probe"

run system sh -c 'sw_vers; sysctl -n hw.model machdep.cpu.brand_string hw.memsize; uptime'
run thermal pmset -g therm
run helper-build "${ROOT_DIR}/scripts/tests/build_smc_helper.sh" "${HELPER}"
run helper-lifetime "${ROOT_DIR}/scripts/tests/check_helper_lifetime.sh" "${HELPER}"
run key-probe-build xcrun swiftc -swift-version 5 -O \
  "${ROOT_DIR}/Core-Monitor/SMCTemperatureSensors.swift" \
  "${ROOT_DIR}/scripts/ci/smc-key-probe/main.swift" \
  -o "${KEY_PROBE}"
run smc-reads smc_reads
grep -E '^(chip|fans|summary) ' "${OUT_DIR}/smc-reads.txt"
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
