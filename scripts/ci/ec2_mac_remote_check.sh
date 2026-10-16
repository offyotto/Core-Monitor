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

run system sh -c 'sw_vers; sysctl -n hw.model machdep.cpu.brand_string hw.memsize; uptime'
run thermal pmset -g therm
run smc-ioreg ioreg -r -c AppleSMC -l -w0
run hpm-ioreg ioreg -r -c AppleHPMDevice -l -w0
run helper-lifetime "${ROOT_DIR}/scripts/tests/check_helper_lifetime.sh"

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
