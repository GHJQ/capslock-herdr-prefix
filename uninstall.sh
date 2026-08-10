#!/bin/bash
# Give Caps Lock back its day job.
set -euo pipefail

LABEL="com.local.CapsLockToFKey"
LEGACY_LABEL="com.local.CapsLockToF13"
CONFIG="$HOME/.config/herdr/config.toml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=bin/key.sh
. "$SCRIPT_DIR/bin/key.sh"

# Whatever we bound last. Installs from before the key was configurable have no
# key file and were always F13.
KEY=f13
[[ -f "$KEY_FILE" ]] && KEY=$(tr -d '[:space:]' < "$KEY_FILE")

echo "==> Removing LaunchAgent"
for label in "$LABEL" "$LEGACY_LABEL"; do
  launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
  rm -f "$HOME/Library/LaunchAgents/$label.plist"
done

echo "==> Clearing the HID remap"
"$SCRIPT_DIR/bin/remap" off >/dev/null

echo "==> Reverting the herdr prefix"
if [[ -f "$CONFIG" ]] && grep -q "^prefix = \"$KEY\"$" "$CONFIG"; then
  cp "$CONFIG" "$CONFIG.bak.$(date +%Y%m%d%H%M%S)"
  # Drop only the line we added; leave any other keybindings alone.
  awk -v line="prefix = \"$KEY\"" '$0 != line' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
  herdr server reload-config >/dev/null 2>&1 || true
  echo "    prefix removed; herdr is back to its default ctrl+b"
else
  echo "    no 'prefix = \"$KEY\"' line found — leaving $CONFIG alone"
fi

rm -f "$KEY_FILE"

echo
echo "Done. Caps Lock capitalises again."
