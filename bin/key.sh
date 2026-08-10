# Which F-key Caps Lock becomes, and the HID usage that names it.
# Sourced by bin/remap, bin/bind-prefix and the install scripts — not executable.

CONFIG_DIR="${CAPSLOCK_HERDR_CONFIG_DIR:-$HOME/.config/herdr/plugins/config/capslock-herdr-prefix}"
KEY_FILE="$CONFIG_DIR/key"

valid_key() {
  case "$1" in
    f[1-9]|f1[0-9]|f20) return 0 ;;
    *) return 1 ;;
  esac
}

# F13-F20 only reach the app if the terminal emits them. Apple Terminal has no
# mapping past F12 and drops them silently — the prefix just never fires. F12 is
# the one every terminal already sends, so anything we don't recognise gets that.
terminal_default() {
  case "${TERM_PROGRAM:-}" in
    iTerm.app|ghostty|WezTerm) echo f13; return ;;
  esac
  case "${TERM:-}" in
    xterm-kitty|alacritty*) echo f13; return ;;
  esac
  echo f12
}

# f13 -> 0x700000068. F1-F12 are HID usages 0x3A-0x45, F13-F20 are 0x68-0x6F.
hid_usage() {
  n=${1#f}
  if [ "$n" -le 12 ]; then id=$((0x39 + n)); else id=$((0x5B + n)); fi
  printf '0x7000000%02X\n' "$id"
}

save_key() {
  mkdir -p "$CONFIG_DIR"
  printf '%s\n' "$1" > "$KEY_FILE"
}

# An explicit choice wins, then whatever we settled on last time. We only guess
# when there's neither — and the guess is written down, so the startup hook can't
# re-decide from a different environment later and move the key under you.
resolve_key() {
  if [ -n "${CAPSLOCK_HERDR_KEY:-}" ]; then
    if ! valid_key "$CAPSLOCK_HERDR_KEY"; then
      echo "CAPSLOCK_HERDR_KEY is not an F-key: $CAPSLOCK_HERDR_KEY" >&2
      return 1
    fi
    save_key "$CAPSLOCK_HERDR_KEY"
    echo "$CAPSLOCK_HERDR_KEY"
    return 0
  fi

  if [ -f "$KEY_FILE" ]; then
    saved=$(tr -d '[:space:]' < "$KEY_FILE")
    if valid_key "$saved"; then
      echo "$saved"
      return 0
    fi
    echo "$KEY_FILE doesn't name an F-key; picking one instead" >&2
  fi

  guess=$(terminal_default)
  save_key "$guess"
  echo "$guess"
}
