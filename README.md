# Keychron Battery

A tiny macOS menu bar app that shows the battery level of a Bluetooth Keychron keyboard, plus a CLI that prints the same reading.

macOS has no built-in way to see a Keychron's battery level. The keyboard reports it over HID, so this reads it directly.

```
⌨ 63%
```

- Menu bar item, refreshed every 5 minutes and on wake
- Low-battery notifications at 30% / 20% / 10% / 5%
- Turns orange under 30%, red under 15%
- CLI with `--json` / `--quiet` for scripting

## Requirements

macOS 13 or later. Xcode command line tools (`xcode-select --install`).

## Build and install

```bash
git clone https://github.com/Orbasker/keyboard-battery-bar.git
cd keyboard-battery-bar
./build.sh
```

That builds `~/Applications/Keychron Battery.app` and a CLI at `build/keychron-battery`.

To launch it at login:

```bash
./install-agent.sh
```

## Grant Input Monitoring

Reading the battery means opening the keyboard's HID device, which macOS gates behind **Input Monitoring**. Until you grant it, the menu bar shows an orange `!`.

Open **System Settings → Privacy & Security → Input Monitoring**, click `+`, add `~/Applications/Keychron Battery.app`, enable it, then quit and reopen the app from its own menu.

> Because the app is ad-hoc signed, macOS ties the grant to the binary's code hash. **Every rebuild invalidates it** and you have to add it again. To avoid that, sign with a stable self-signed identity and pass it through:
>
> ```bash
> CODESIGN_IDENTITY="My Local Dev" ./build.sh
> ```

## CLI

```bash
$ keychron-battery
Keychron K1 SE: 63%

$ keychron-battery --json
[{"name":"Keychron K1 SE","percent":63}]

$ keychron-battery --quiet
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

Nothing here is Keychron-specific — it reads HID usage page `0x06`, usage `0x20`, which any keyboard may expose. Try `keychron-battery --all` to see what your hardware reports, then run the app with a different filter:

```bash
defaults write com.ortbasker.keychronbattery deviceFilter -string "Logitech"
```

## Troubleshooting

**The app runs but no icon appears.** The status item is hosted by Control Center. Check whether it is refusing to place the item:

```bash
log show --last 5m --predicate 'process == "KeychronBattery"' --style compact | grep -i scene
```

A `FBSceneErrorDomain code 2 ("scene-invalidated")` on `…-NSStatusItemView` means Control Center never allocated a menu bar slot, and the item is parked off-screen. Changing `BUNDLE_ID` in `build.sh` to a fresh identifier clears it.

Also note that third-party menu bar items render on the display holding the focused app, so on a multi-monitor setup check the other screens before assuming it is missing.

**It says `!` forever.** Input Monitoring is not granted to *this* build — see above. Re-adding after a rebuild is expected.

## License

MIT
