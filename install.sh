#!/bin/bash
# Make Caps Lock the herdr prefix key.
#
# herdr can't bind Caps Lock directly (the OS eats it as a lock modifier and it
# never reaches the terminal), so we remap it to F13 at the HID level and bind
# that. F13 is chosen because no Apple keyboard has one, so nothing else claims it.
set -euo pipefail

LABEL="com.local.CapsLockToF13"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
CONFIG="$HOME/.config/herdr/config.toml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMAP="$SCRIPT_DIR/bin/remap"

[[ "$(uname)" == "Darwin" ]] || { echo "macOS only — hidutil is an Apple thing." >&2; exit 1; }
command -v herdr >/dev/null || { echo "herdr not found on PATH. brew install herdr" >&2; exit 1; }

echo "==> Remapping Caps Lock to F13"
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

echo "==> Pointing herdr's prefix at F13"
mkdir -p "$(dirname "$CONFIG")"
touch "$CONFIG"
BACKUP="$CONFIG.bak.$(date +%Y%m%d%H%M%S)"
cp "$CONFIG" "$BACKUP"

# Patch in place rather than overwrite — you may have other herdr settings.
awk '
  /^[[:space:]]*\[keys\][[:space:]]*$/ { in_keys = 1; seen_keys = 1; print; next }
  /^[[:space:]]*\[/ && !/^[[:space:]]*\[keys\][[:space:]]*$/ {
    if (in_keys && !done) { print "prefix = \"f13\""; done = 1 }
    printf "%s", held; held = ""
    in_keys = 0; print; next
  }
  in_keys && /^[[:space:]]*prefix[[:space:]]*=/ { printf "%s", held; held = ""; print "prefix = \"f13\""; done = 1; next }
  in_keys && /^[[:space:]]*$/ { held = held $0 "\n"; next }
  { printf "%s", held; held = ""; print }
  END {
    if (in_keys && !done) { print "prefix = \"f13\""; done = 1 }
    printf "%s", held
    if (!seen_keys) { print ""; print "[keys]"; print "prefix = \"f13\"" }
  }
' "$BACKUP" > "$CONFIG"

if herdr config check 2>&1 | grep -q "invalid keybinding"; then
  echo "!! herdr rejected the config; restoring $BACKUP" >&2
  cp "$BACKUP" "$CONFIG"
  exit 1
fi

herdr server reload-config >/dev/null 2>&1 || true

echo
echo "Done. Caps Lock is now your herdr prefix — try Caps Lock then 'c' for a new tab."
echo "Config backup: $BACKUP"
echo
echo "Caps Lock no longer capitalises anything, in any app. ./uninstall.sh reverts it."
