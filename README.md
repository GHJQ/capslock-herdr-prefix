# Caps Lock as the herdr prefix

Makes Caps Lock the prefix key for [herdr](https://herdr.dev) on macOS.

```sh
herdr plugin install GHJQ/capslock-herdr-prefix
```

`Caps Lock` + `c` now opens a new tab, `Caps Lock` + `|` splits, and so on.

That's the whole install. The plugin adds `prefix = "f13"` under `[keys]` in
`~/.config/herdr/config.toml` on first run — herdr plugins can't declare a
keybinding, but a startup command can write one, so it does. Your config is
patched in place and backed up to `config.toml.bak.<timestamp>` first; if herdr
rejects the result the backup goes straight back and nothing is remapped.

Caps Lock is only remapped once that binding is in place, so a failure here
can't leave you with a key that does nothing at all.

### Or without the plugin

```sh
git clone https://github.com/GHJQ/capslock-herdr-prefix.git
cd capslock-herdr-prefix
./install.sh
```

Same setup, plus a LaunchAgent so the remap is always on rather than only while
herdr is running. Pick this one if you want it to behave like a permanent
keyboard setting.

## Why it isn't just a config line

herdr won't take Caps Lock as a key name — `capslock`, `caps_lock`, `caps` and
`CapsLock` are all rejected by `herdr config check`:

```
invalid keybinding: keys.prefix = "capslock"; using fallback
```

That's not a herdr limitation so much as a terminal one. Caps Lock is a lock
modifier: macOS consumes the keypress and it never arrives as a key event, so no
terminal app can bind it.

The way around it is to stop Caps Lock being Caps Lock. `bin/remap` binds **F13**
as the herdr prefix, then points Caps Lock at F13 at the HID level with
`hidutil`. F13 is the usual pick because no Apple keyboard has one, so nothing
else wants it.

## What it changes

| | plugin | `install.sh` |
|---|---|---|
| `[keys] prefix = "f13"` in `~/.config/herdr/config.toml` | on first run | on first run |
| `hidutil` remap, Caps Lock (`0x700000039`) → F13 (`0x700000068`) | on every herdr start | immediately |
| `~/Library/LaunchAgents/com.local.CapsLockToF13.plist` | — | reapplies the remap at login |

Both routes run the same `bin/remap`, and it always does those first two rows in
that order — the remap is skipped entirely if the binding can't be written.

**The plugin has no shutdown hook** — plugin v1 doesn't offer one, so quitting
herdr leaves Caps Lock remapped. Run the *Restore Caps Lock* action to undo it:

```sh
herdr plugin action invoke restore --plugin capslock-herdr-prefix
```

Your other HID remaps are left alone. `hidutil --set` replaces the entire
`UserKeyMapping` table rather than merging into it, so `bin/remap` reads the
current table, edits only the Caps Lock entry, and writes the rest back
untouched. The LaunchAgent runs `bin/remap` for the same reason — which means it
needs the clone to stay put. Move it and re-run `./install.sh`.

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
herdr plugin uninstall capslock-herdr-prefix   # plugin route
./uninstall.sh                                  # install.sh route
```

`uninstall.sh` removes the LaunchAgent, clears the HID remap, and drops the
`prefix = "f13"` line (leaving any other herdr keybindings alone). Uninstalling
the plugin stops it reapplying the remap but doesn't clear the current one — run
the *Restore Caps Lock* action first, or `hidutil property --set
'{"UserKeyMapping":[]}'`.

## Using a different key

F13 is not special. `install.sh` takes any key herdr accepts — swap the `F13`
usage code for another from the [HID usage
tables](https://usb.org/document-library/hid-usage-tables-16) and the
`prefix = "f13"` string to match. F14 is `0x700000069`, F15 is `0x70000006A`.
