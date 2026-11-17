#!/bin/bash
# Make Caps Lock the herdr prefix key, permanently.
#
# herdr can't bind Caps Lock directly (the OS eats it as a lock modifier and it
# never reaches the terminal), so we remap it to a spare F-key and bind that.
#
# The remap itself lives in bin/remap, which also binds the prefix. All this
# script adds is the choice of key and, on macOS, a LaunchAgent, so the remap
# survives a reboot rather than only lasting as long as herdr runs. On Linux the
# GNOME setting bin/remap writes already persists, so there's nothing to add.
#
# usage: ./install.sh [--key fN]
set -euo pipefail

LABEL="com.local.CapsLockToFKey"
LEGACY_LABEL="com.local.CapsLockToF13"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMAP="$SCRIPT_DIR/bin/remap"
# shellcheck source=bin/key.sh
. "$SCRIPT_DIR/bin/key.sh"

case "$(uname)" in
  Darwin) PLATFORM=macos ;;
  Linux)  PLATFORM=linux ;;
  *) echo "macOS and Linux only." >&2; exit 1 ;;
esac
command -v herdr >/dev/null || { echo "herdr not found on PATH. See https://herdr.dev to install it." >&2; exit 1; }

KEY=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --key) KEY="${2:-}"; shift 2 ;;
    --key=*) KEY="${1#--key=}"; shift ;;
    *) echo "usage: ./install.sh [--key fN]" >&2; exit 2 ;;
  esac
done

if [[ -n "$KEY" ]]; then
  valid_key "$KEY" || { echo "not an F-key: $KEY" >&2; exit 2; }
elif [[ -t 0 ]]; then
  # Worth asking rather than guessing: get this wrong and the prefix does
  # nothing at all, with no error to explain why.
  suggested=$(terminal_default)
  echo "Caps Lock has to become some other key before herdr can bind it."
  echo
  echo "  1) F12 — every terminal sends it, including Apple Terminal and GNOME Terminal."
  echo "           Caps Lock will shadow F12 in other apps (rarely bound;"
  echo "           the real F12 key still works)."
  echo "  2) F13 — most keyboards don't have one, so nothing else wants it."
  echo "           Needs iTerm2, Ghostty, kitty, WezTerm or Alacritty —"
  echo "           Apple Terminal drops F13 and the prefix never fires."
  echo
  echo "Detected terminal: ${TERM_PROGRAM:-${TERM:-unknown}} — suggesting $(upper "$suggested")"
  default_choice=1; [[ "$suggested" == "f13" ]] && default_choice=2
  read -r -p "Choice [$default_choice]: " answer
  case "${answer:-$default_choice}" in
    1) KEY=f12 ;;
    2) KEY=f13 ;;
    f*) valid_key "$answer" && KEY="$answer" || { echo "not an F-key: $answer" >&2; exit 2; } ;;
    *) echo "not a choice: $answer" >&2; exit 2 ;;
  esac
else
  KEY="$SAFE_KEY"
  echo "==> No TTY to ask on; going with $(upper "$KEY"), which every terminal sends."
  echo "    Re-run with --key f13 if you only ever attach from terminals that send it."
fi

echo "==> Binding the prefix and remapping Caps Lock to $(upper "$KEY")"
"$REMAP" on "$KEY"

if [[ "$PLATFORM" == linux ]]; then
  echo
  echo "Done. Caps Lock is now your herdr prefix — try Caps Lock then 'c' for a new tab."
  echo "If Caps Lock still capitalises, log out and back in so GNOME rereads ~/.config/xkb."
  echo
  echo "Caps Lock no longer capitalises anything, in any app. ./uninstall.sh reverts it."
  exit 0
fi

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

# Older installs used a key-specific label; only one of these should be loaded.
launchctl bootout "gui/$(id -u)/$LEGACY_LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LEGACY_LABEL.plist"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo
echo "Done. Caps Lock is now your herdr prefix — try Caps Lock then 'c' for a new tab."
echo
echo "Caps Lock no longer capitalises anything, in any app. ./uninstall.sh reverts it."
