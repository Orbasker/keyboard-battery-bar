#!/bin/bash
set -euo pipefail

REPO="Orbasker/keyboard-battery-bar"
REF="${KBB_REF:-main}"

if [ "$(uname -s)" != "Darwin" ]; then
    echo "This installer is macOS only." >&2
    exit 1
fi

if ! xcrun --find swiftc >/dev/null 2>&1; then
    echo "Swift compiler not found. Install the command line tools first:" >&2
    echo "    xcode-select --install" >&2
    exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> Downloading $REPO@$REF"
curl -fsSL "https://codeload.github.com/$REPO/tar.gz/$REF" | tar -xzf - -C "$WORK"

SRC="$(/usr/bin/find "$WORK" -maxdepth 1 -type d -name 'keyboard-battery-bar-*' | head -1)"
[ -n "$SRC" ] || { echo "Download did not contain the expected source tree." >&2; exit 1; }

cd "$SRC"
./build.sh
./install-agent.sh

cat <<'DONE'

==> Installed.

One manual step is left, because reading a keyboard's battery means opening its
HID device and macOS gates that behind Input Monitoring:

  1. System Settings > Privacy & Security > Input Monitoring
  2. Click +, add ~/Applications/Keyboard Battery Bar.app, turn it on
  3. Click the menu bar icon and choose Quit, then reopen the app

Until then the menu bar shows an orange "!".
DONE
