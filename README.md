# Caps Lock as the herdr prefix

Makes Caps Lock the prefix key for [herdr](https://herdr.dev) on macOS.

```sh
git clone https://github.com/GHJQ/capslock-herdr-prefix.git
cd capslock-herdr-prefix
./install.sh
```

Then `Caps Lock` + `c` opens a new tab, `Caps Lock` + `|` splits, and so on.

## Why it isn't just a config line

herdr won't take Caps Lock as a key name — `capslock`, `caps_lock`, `caps` and
`CapsLock` are all rejected by `herdr config check`:

```
invalid keybinding: keys.prefix = "capslock"; using fallback
```

That's not a herdr limitation so much as a terminal one. Caps Lock is a lock
modifier: macOS consumes the keypress and it never arrives as a key event, so no
terminal app can bind it.

The way around it is to stop Caps Lock being Caps Lock. `install.sh` remaps it to
**F13** at the HID level with `hidutil`, then binds F13 as the herdr prefix. F13
is the usual pick because no Apple keyboard has one, so nothing else wants it.

## What it changes

| | |
|---|---|
| `hidutil` remap | Caps Lock (`0x700000039`) → F13 (`0x700000068`), applied immediately |
| `~/Library/LaunchAgents/com.local.CapsLockToF13.plist` | Reapplies the remap at login |
| `~/.config/herdr/config.toml` | Sets `[keys] prefix = "f13"` |

The herdr config is patched in place, not overwritten, and backed up to
`config.toml.bak.<timestamp>` first. If herdr rejects the result the backup is
restored and the script exits non-zero.

macOS's built-in Keyboard → Modifier Keys panel can't do this, incidentally — it
only offers Ctrl, Option, Command, Escape and Globe. Hence `hidutil`.

## Caveats

**Caps Lock stops capitalising, everywhere.** This is a system-wide HID remap, not
a per-app one. Every app sees F13.

**The Caps Lock light no longer comes on.** Nothing is toggling the lock state
any more, so there's nothing to light up.

Lighting that LED to indicate prefix mode turns out to be a dead end, in case you
were about to try:

- herdr doesn't expose prefix mode. Its socket API publishes 25 event types, all
  panes, tabs, workspaces and agents — prefix mode lives in the TUI client and
  never crosses the socket. There's nothing to subscribe to.
- The LED API that works without special permissions,
  `IOHIDSetModifierLockState`, sets the *actual* caps-lock state rather than just
  the light. Prefix mode is exactly when you're about to type the next key, so
  `prefix`+`x` would arrive as `X` and fire the `prefix+shift+x` binding instead.
- The clean path — writing the raw HID LED output element — needs Input
  Monitoring, i.e. a signed app bundle. From a plain CLI binary
  `IOHIDManagerOpen` returns `0xe00002e2` (not permitted).

herdr's status bar already shows prefix mode, instantly and for free.

## Uninstall

```sh
./uninstall.sh
```

Removes the LaunchAgent, clears the HID remap, and drops the `prefix = "f13"`
line (leaving any other herdr keybindings alone).

## Using a different key

F13 is not special. `install.sh` takes any key herdr accepts — swap the `F13`
usage code for another from the [HID usage
tables](https://usb.org/document-library/hid-usage-tables-16) and the
`prefix = "f13"` string to match. F14 is `0x700000069`, F15 is `0x70000006A`.
