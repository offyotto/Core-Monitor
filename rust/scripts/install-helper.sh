#!/bin/bash
# Installs the Rust smc-helper as a launchd daemon. Run with sudo.
#   sudo rust/scripts/install-helper.sh <path-to-helper> [client-requirement]
# The default requirement only admits the signed Core-Monitor release build.
set -euo pipefail

HELPER="${1:?usage: install-helper.sh <helper-binary> [client-requirement]}"
REQUIREMENT="${2:-anchor apple generic and identifier \"CoreTools.Core-Monitor\" and certificate leaf[subject.OU] = \"6VDP675K4L\"}"
RUST_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LABEL="ventaphobia.smc-helper"
DEST="/Library/PrivilegedHelperTools/${LABEL}"
PLIST="/Library/LaunchDaemons/${LABEL}.plist"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "install-helper.sh must run as root" >&2
  exit 1
fi

launchctl bootout "system/${LABEL}" 2>/dev/null || true
install -d -m 755 /Library/PrivilegedHelperTools
install -m 544 -o root -g wheel "${HELPER}" "${DEST}"
ESCAPED="$(printf '%s' "${REQUIREMENT}" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/[\/|]/\\&/g')"
sed "s|@CLIENT_REQUIREMENT@|${ESCAPED}|" "${RUST_DIR}/packaging/${LABEL}.plist.in" > "${PLIST}"
chown root:wheel "${PLIST}"
chmod 644 "${PLIST}"
launchctl bootstrap system "${PLIST}"
echo "Installed ${LABEL}"
