# File: scripts/release/generate_homebrew_cask.sh

## Current Role

- Area: Developer and release scripts.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`scripts/release/generate_homebrew_cask.sh`](../../../scripts/release/generate_homebrew_cask.sh) |
| Wiki area | Developer and release scripts |
| Exists in current checkout | True |
| Size | 1043 bytes |
| Binary | False |
| Line count | 42 |
| Extension | `.sh` |

## Imports

None detected.

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| None detected |  |  |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `4dc3880` | 2026-04-21 | Update GitHub username references |
| `aca5d59` | 2026-04-19 | Add Kernel Panic release payload |
| `210356e` | 2026-04-19 | Add Kernel Panic release payload |
| `7afc598` | 2026-04-15 | Automate releases and sharpen product positioning |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
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

```
