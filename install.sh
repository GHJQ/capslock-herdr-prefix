#!/bin/bash
# Make Caps Lock the herdr prefix key, permanently.
#
# herdr can't bind Caps Lock directly (the OS eats it as a lock modifier and it
# never reaches the terminal), so we remap it to F13 at the HID level and bind
# that. F13 is chosen because no Apple keyboard has one, so nothing else claims it.
#
# The remap itself lives in bin/remap, which also binds the prefix. All this
# script adds is a LaunchAgent, so the remap survives a reboot rather than only
# lasting as long as herdr runs.
set -euo pipefail

LABEL="com.local.CapsLockToF13"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMAP="$SCRIPT_DIR/bin/remap"

[[ "$(uname)" == "Darwin" ]] || { echo "macOS only — hidutil is an Apple thing." >&2; exit 1; }
command -v herdr >/dev/null || { echo "herdr not found on PATH. brew install herdr" >&2; exit 1; }

echo "==> Binding the prefix and remapping Caps Lock"
"$REMAP" on

echo "==> Installing LaunchAgent so it survives reboot"
mkdir -p "$(dirname "$PLIST")"
cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$REMAP</string>
    <string>on</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
PLIST_EOF

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo
echo "Done. Caps Lock is now your herdr prefix — try Caps Lock then 'c' for a new tab."
echo
echo "Caps Lock no longer capitalises anything, in any app. ./uninstall.sh reverts it."
