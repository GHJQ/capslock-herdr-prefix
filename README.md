# Caps Lock as the herdr prefix

Makes Caps Lock the prefix key for [herdr](https://herdr.dev) on macOS.

```sh
herdr plugin install GHJQ/capslock-herdr-prefix
herdr plugin action invoke apply --plugin capslock-herdr-prefix
```

**Both lines are needed.** Installing a plugin doesn't run anything — startup
commands fire when the herdr *server* starts, so a plain install leaves the files
on disk and your keyboard untouched. Restarting herdr would do it; the `apply`
action does it now. Then detach and reattach so the client picks up the new
prefix, and `Caps Lock` + `c` opens a new tab, `Caps Lock` + `|` splits, and so
on.

The plugin adds `prefix = "<key>"` under `[keys]` in `~/.config/herdr/config.toml`
itself — herdr plugins can't *declare* a keybinding, but a startup command can
write one. Your config is patched in place and backed up to
`config.toml.bak.<timestamp>` first; if herdr rejects the result the backup goes
straight back and nothing is remapped. Caps Lock is only ever remapped once that
binding is in place, so a failure can't leave you with a dead key.

Check what happened with:

```sh
herdr plugin log list
```

That's where plugin output goes — it isn't printed to your terminal. The plugin
also raises a herdr notification when it binds the prefix, which you'll only see
if you have notifications enabled.

### Or without the plugin

```sh
git clone https://github.com/GHJQ/capslock-herdr-prefix.git
cd capslock-herdr-prefix
./install.sh
```

Same setup, plus a LaunchAgent so the remap is always on rather than only while
herdr is running. Pick this one if you want it to behave like a permanent
keyboard setting. It asks which key to use; `--key f13` skips the question.

## Which key?

Caps Lock has to *become* some other key first (see below), and which one is not
just bookkeeping — pick wrong and the prefix does nothing at all, with no error
to explain why.

| | F12 | F13 |
|---|---|---|
| Apple Terminal | works | **silently does nothing** |
| iTerm2, Ghostty, kitty, WezTerm, Alacritty | works | works |
| Collides with | F12 in other apps — rarely bound, and the real F12 key still works | nothing; no Apple keyboard has an F13 |

**F12 is the default**, because it's the one every terminal already sends. F13 is
the tidier choice, but it's opt-in: the plugin never picks it for you.

That's deliberate, and it's worth knowing why the obvious alternative doesn't
work. The plugin's commands run in the herdr **server**, and the server's
`TERM_PROGRAM` is whichever terminal happened to launch it — not the one a client
is attached from. Those are routinely different, and a client can attach from a
terminal that didn't exist when the server started. Detecting there would confidently
pick F13 for a session that can't receive it, which is the exact failure this is
meant to prevent. Only `install.sh` runs in the terminal you actually type into,
so it's the only place that offers a detected suggestion — and it still asks.

The prefix is also one global setting while clients can attach from several
terminals at once, so it has to work in all of them. F12 does.

Switch at any time from herdr's workspace action menu — *Use F12* / *Use F13* —
or:

```sh
herdr plugin action invoke use-f13 --plugin capslock-herdr-prefix
```

The choice is remembered in `~/.config/herdr/plugins/config/capslock-herdr-prefix/key`,
so the startup hook doesn't re-decide from a different environment later and move
the key under you. `CAPSLOCK_HERDR_KEY=f13` overrides it for one run and becomes
the new saved choice. Any of `f1`–`f20` is accepted if you have your own ideas.

### Why Apple Terminal drops F13

Terminal.app's key map stops at F12. Press F13 and it sends nothing at all — no
escape sequence reaches herdr, so the prefix never fires and there's nothing in
any log to tell you why. Terminals that implement the xterm or kitty keyboard
protocols send `ESC [ 25 ~` for F13 and work fine.

You can teach Terminal.app about F13 by hand — Settings → Profiles → Keyboard →
`+`, key F13, action *Send Text*, `\033[25~` — but choosing F12 is one less thing
to carry between machines.

## Why it isn't just a config line

herdr won't take Caps Lock as a key name — `capslock`, `caps_lock`, `caps` and
`CapsLock` are all rejected by `herdr config check`:

```
invalid keybinding: keys.prefix = "capslock"; using fallback
```

That's not a herdr limitation so much as a terminal one. Caps Lock is a lock
modifier: macOS consumes the keypress and it never arrives as a key event, so no
terminal app can bind it.

The way around it is to stop Caps Lock being Caps Lock. `bin/remap` binds an
F-key as the herdr prefix, then points Caps Lock at it at the HID level with
`hidutil`.

## What it changes

| | plugin | `install.sh` |
|---|---|---|
| `[keys] prefix = "<key>"` in `~/.config/herdr/config.toml` | on first run | on first run |
| `hidutil` remap, Caps Lock (`0x700000039`) → F12 (`0x700000045`) or F13 (`0x700000068`) | on every herdr start | immediately |
| `~/Library/LaunchAgents/com.local.CapsLockToFKey.plist` | — | reapplies the remap at login |

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
a per-app one. Every app sees the F-key.

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
