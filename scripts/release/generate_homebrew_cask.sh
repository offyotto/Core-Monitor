#!/bin/zsh
set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <version> <sha256> <download-url> [output-path]" >&2
  exit 1
fi

VERSION="$1"
SHA256="$2"
DOWNLOAD_URL="$3"
OUTPUT_PATH="${4:-$(cd "$(dirname "$0")/../.." && pwd)/build/release/core-monitor.rb}"

mkdir -p "$(dirname "${OUTPUT_PATH}")"

cat > "${OUTPUT_PATH}" <<EOF
cask "core-monitor" do
  version "${VERSION}"
  sha256 "${SHA256}"

  url "${DOWNLOAD_URL}",
      verified: "github.com/offyotto/Core-Monitor/"
  name "Core-Monitor"
  desc "Native Apple Silicon system monitor with menu bar stats, alerts, and SMC-backed fan control"
  homepage "https://offyotto.github.io/Core-Monitor/"

  depends_on arch: :arm64
  depends_on macos: ">= :monterey"

  app "Core-Monitor.app"

  zap trash: [
    "~/Library/Application Support/Core-Monitor",
    "~/Library/Caches/Core-Monitor",
    "~/Library/Preferences/CoreTools.Core-Monitor.plist",
    "~/Library/Saved Application State/CoreTools.Core-Monitor.savedState"
  ]
end
EOF

echo "Homebrew cask written to ${OUTPUT_PATH}"
