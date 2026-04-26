#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${ROOT_DIR}/Core-Monitor.xcodeproj"
SCHEME="Core-Monitor"
APP_NAME="Core-Monitor"
BUNDLE_ID="CoreTools.Core-Monitor"
DERIVED_DATA_DIR="${ROOT_DIR}/.codex-build/DerivedData"
CONFIGURATION="Debug"
ACTION="run"

usage() {
  cat <<USAGE
Usage: ./script/build_and_run.sh [--verify] [--logs] [--telemetry]

Builds the Core-Monitor Xcode project, relaunches the app bundle, and optionally
verifies the app process or streams logs.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verify)
      ACTION="verify"
      shift
      ;;
    --logs|--telemetry)
      ACTION="logs"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! -d "${PROJECT_PATH}" ]]; then
  echo "Missing Xcode project: ${PROJECT_PATH}" >&2
  exit 1
fi

echo "Stopping any running ${APP_NAME} instance..."
/usr/bin/pkill -x "${APP_NAME}" 2>/dev/null || true

echo "Building ${SCHEME} from ${PROJECT_PATH}..."
/usr/bin/xcodebuild \
  -quiet \
  -project "${PROJECT_PATH}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -destination "platform=macOS,arch=arm64" \
  -derivedDataPath "${DERIVED_DATA_DIR}" \
  CODE_SIGNING_ALLOWED=NO \
  build

APP_PATH="${DERIVED_DATA_DIR}/Build/Products/${CONFIGURATION}/${APP_NAME}.app"
if [[ ! -d "${APP_PATH}" ]]; then
  echo "Expected app bundle was not produced: ${APP_PATH}" >&2
  exit 1
fi

echo "Launching ${APP_PATH}..."
/usr/bin/open -n "${APP_PATH}"

for _ in {1..40}; do
  if /usr/bin/pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
    echo "${APP_NAME} is running."
    if [[ "${ACTION}" == "verify" ]]; then
      exit 0
    fi
    break
  fi
  /bin/sleep 0.25
done

if ! /usr/bin/pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
  echo "${APP_NAME} did not start within 10 seconds." >&2
  exit 1
fi

if [[ "${ACTION}" == "logs" ]]; then
  echo "Streaming logs for ${BUNDLE_ID}; press Ctrl-C to stop."
  /usr/bin/log stream --style compact --info --predicate "process == '${APP_NAME}' OR subsystem == '${BUNDLE_ID}'"
fi
