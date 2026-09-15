# readitloud

Read clipboard text aloud on Wayland/Hyprland — press **ALT+S** (or click the TTS
bar icon) → clipboard selection is synthesized with `edge-tts` (or `espeak-ng`
fallback) and played through `mpv`; press again to stop.

**readitloud is an Omarchy plugin** (`readitloud.tts`, a bar widget) developed
live on this machine at `~/.config/omarchy/plugins/readitloud.tts/`.

co-writer by opencode

## Installation

```bash
# add the plugin (run from where this repo is cloned)
omarchy plugin add /path/to/readitloud --enable

# or, if the plugin dir is already in place:
omarchy plugin enable readitloud.tts right
```

### Dependencies

- `omarchy pkg add mpv wl-paste jq espeak-ng notify-send
- `edge-tts` runs from a venv at `~/.local/share/tts-venv`:
  ```bash
  python -m venv ~/.local/share/tts-venv
  ~/.local/share/tts-venv/bin/pip install edge-tts
  ```
  (the AUR `python-edge-tts` package is abandoned; the venv avoids a dozen
  python deps in a bare `sudo` install)

### Keybinding

Set in `~/.config/hypr/bindings.lua` (never raw `bind =` lines):

```lua
o.bind("ALT + S", "Read selection aloud", "omarchy-shell shell toggle readitloud.tts")
```

## Usage

1. **Copy text** to the clipboard (select + Ctrl+C, or `wl-copy`)
2. **Press ALT+S** (or left-click the TTS icon) — starts speaking
3. **Press ALT+S again** (or middle-click) — stops
4. **Right-click** the icon — status/settings popup; **Settings…** opens `ttsctl`

## Settings

**`ttsctl`** is the settings/control CLI (symlinked to `~/.local/bin/ttsctl`):

```
ttsctl               interactive menu
ttsctl show          current settings
ttsctl set <key> <val>   set voice, rate, pitch, volume or engine
ttsctl voices        list available edge-tts voices
ttsctl speak         speak clipboard now (manual test)
ttsctl stop          stop speaking
ttsctl status        is speaking?
```

Settings are written to the `readitloud.tts` entry in
`~/.config/omarchy/shell.json` and hot-reload into the widget.

| Setting | Example values |
|---------|----------------|
| `voice` | `en-IN-NeerjaExpressiveNeural`, `en-US-EmmaNeural` |
| `rate`  | `+0%`, `-10%`, `-20%` (slower) |
| `pitch` | `+0Hz`, `-5Hz` |
| `volume`| `+0%`, `+10%` |
| `engine`| `edge-tts`, `espeak-ng` |

List all voices: `ttsctl voices` (or
`~/.local/share/tts-venv/bin/edge-tts --list-voices | grep Female`).

## File Structure

This repo **is** the plugin source; install it by linking (or `omarchy plugin
add`) this folder into `~/.config/omarchy/plugins/` (the live copy lives at
`~/.config/omarchy/plugins/readitloud.tts/`).

```
readitloud/
├── manifest.json   # plugin manifest (kind: bar-widget, settings defaults)
├── Panel.qml       # Quickshell bar widget + popup (open/close tie to speech)
├── speak.sh        # TTS helper: start/stop/status
├── ttsctl.sh       # settings CLI → ~/.local/bin/ttsctl
└── README.md       # this file
```

## Troubleshooting

**ALT+S does nothing** (widget failed to load):
```bash
journalctl --user -u omarchy-shell -f | rg -i "readitloud|error|failed"
# e.g. "Cannot assign to non-existent property" → QML error → rm -rf ~/.cache/quickshell/qmlcache/* && omarchy restart shell
```

**Stale behavior after editing Panel.qml**:
```bash
rm -rf ~/.cache/quickshell/qmlcache/*
omarchy restart shell
```

**No audio / no speech**: test manually:
```bash
~/.local/share/tts-venv/bin/edge-tts -v en-IN-NeerjaExpressiveNeural -t "test" --write-media /tmp/test.mp3
mpv /tmp/test.mp3
which jq mpv wl-paste
```

## License

MIT