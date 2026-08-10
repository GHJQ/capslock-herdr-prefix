#!/bin/bash
# Give Caps Lock back its day job.
set -euo pipefail

LABEL="com.local.CapsLockToF13"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
CONFIG="$HOME/.config/herdr/config.toml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Removing LaunchAgent"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$PLIST"

echo "==> Clearing the HID remap"
"$SCRIPT_DIR/bin/remap" off >/dev/null

echo "==> Reverting the herdr prefix"
if [[ -f "$CONFIG" ]] && grep -q '^prefix = "f13"$' "$CONFIG"; then
  cp "$CONFIG" "$CONFIG.bak.$(date +%Y%m%d%H%M%S)"
  # Drop only the line we added; leave any other keybindings alone.
  awk '!/^prefix = "f13"$/' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
  herdr server reload-config >/dev/null 2>&1 || true
  echo "    prefix removed; herdr is back to its default ctrl+b"
else
  echo "    no 'prefix = \"f13\"' line found — leaving $CONFIG alone"
fi

echo
echo "Done. Caps Lock capitalises again."
