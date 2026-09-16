# Keyboard Battery Bar

A tiny macOS menu bar app that shows the battery level of a Bluetooth keyboard, plus a CLI that prints the same reading.

macOS has no built-in way to see a wireless keyboard's battery level. Many keyboards report it over HID anyway, so this reads it straight from the device. Written against a Keychron K1 SE, but the default device filter is just a name substring you can change.

```
⌨ 63%
```

- Menu bar item, refreshed every 5 minutes and on wake
- Low-battery notifications at 30% / 20% / 10% / 5%
- Turns orange under 30%, red under 15%
- CLI with `--json` / `--quiet` for scripting

## Requirements

macOS 13 or later. Xcode command line tools (`xcode-select --install`).

## Install

One line — downloads, builds, installs the app and the login agent:

```bash
curl -fsSL https://raw.githubusercontent.com/Orbasker/keyboard-battery-bar/main/install.sh | bash
```

With Homebrew, once the [tap](#homebrew-tap) exists:

```bash
brew install orbasker/tap/keyboard-battery-bar
```

Or from a clone:

```bash
git clone https://github.com/Orbasker/keyboard-battery-bar.git
cd keyboard-battery-bar
./build.sh && ./install-agent.sh
```

All three compile from source, which is deliberate: the app is ad-hoc signed, so a
pre-built download would be quarantined and refused by Gatekeeper. Building locally
sidesteps that entirely.

Result: `~/Applications/Keyboard Battery Bar.app`, a CLI at `build/keyboard-battery`,
and a login agent so it starts with you.

## Grant Input Monitoring

Reading the battery means opening the keyboard's HID device, which macOS gates behind **Input Monitoring**. Until you grant it, the menu bar shows an orange `!`.

Open **System Settings → Privacy & Security → Input Monitoring**, click `+`, add `~/Applications/Keyboard Battery Bar.app`, enable it, then quit and reopen the app from its own menu.

> Because the app is ad-hoc signed, macOS ties the grant to the binary's code hash. **Every rebuild invalidates it** and you have to add it again. To avoid that, sign with a stable self-signed identity and pass it through:
>
> ```bash
> CODESIGN_IDENTITY="My Local Dev" ./build.sh
> ```

## CLI

```bash
$ keyboard-battery
Keychron K1 SE: 63%

$ keyboard-battery --json
[{"name":"Keychron K1 SE","percent":63}]

$ keyboard-battery --quiet
63
```

| Flag | Meaning |
| --- | --- |
| `--match <text>` | Device name substring (default `Keychron`) |
| `--all` | Every HID device exposing a battery element |
| `--json` | Machine-readable output |
| `--quiet` | Just the number |

Exit codes: `0` found, `1` no matching device, `3` missing Input Monitoring.

## Other keyboards

Nothing here is Keychron-specific — it reads HID usage page `0x06`, usage `0x20`, which any keyboard may expose. Try `keyboard-battery --all` to see what your hardware reports, then run the app with a different filter:

```bash
defaults write com.ortbasker.keyboardbatterybar deviceFilter -string "Logitech"
```

## Troubleshooting

**The app runs but no icon appears.** The status item is hosted by Control Center. Check whether it is refusing to place the item:

```bash
log show --last 5m --predicate 'process == "KeyboardBatteryBar"' --style compact | grep -i scene
```

A `FBSceneErrorDomain code 2 ("scene-invalidated")` on `…-NSStatusItemView` means Control Center never allocated a menu bar slot, and the item is parked off-screen. Changing `BUNDLE_ID` in `build.sh` to a fresh identifier clears it.

Also note that third-party menu bar items render on the display holding the focused app, so on a multi-monitor setup check the other screens before assuming it is missing.

**It says `!` forever.** Input Monitoring is not granted to *this* build — see above. Re-adding after a rebuild is expected.

## Homebrew tap

`Formula/keyboard-battery-bar.rb` is ready to serve from a personal tap. Homebrew
requires a tap repo to be named `homebrew-<name>`, so create `homebrew-tap` and
copy the formula into it:

```bash
gh repo create Orbasker/homebrew-tap --public --clone
cd homebrew-tap && mkdir -p Formula
curl -fsSLO https://raw.githubusercontent.com/Orbasker/keyboard-battery-bar/main/Formula/keyboard-battery-bar.rb
mv keyboard-battery-bar.rb Formula/
git add -A && git commit -m "Add keyboard-battery-bar" && git push
```

After that `brew install orbasker/tap/keyboard-battery-bar` works for anyone.

Bumping a version means tagging a release, then updating `url` and `sha256` in the
formula:

```bash
curl -fsSL https://github.com/Orbasker/keyboard-battery-bar/archive/refs/tags/vX.Y.tar.gz | shasum -a 256
```

This will not be accepted into homebrew-core — that requires a level of notability
(stars, forks, watchers) a personal utility will not meet. A tap is the supported
route for exactly this case.

## License

MIT
