# readitloud

Read clipboard text aloud on Wayland/Hyprland — press **ALT+S** (or click the TTS
bar icon) → clipboard selection is synthesized with `edge-tts` (or `espeak-ng`
fallback) and played through `mpv`; press again to stop.

**readitloud is an Omarchy plugin** (`readitloud.tts`, a bar widget) developed
live on this machine at `~/.config/omarchy/plugins/readitloud.tts/`.

co-writer by opencode
![alt text](image.png)

## Installation

```bash
# add the plugin (run from where this repo is cloned)
omarchy plugin add /path/to/readitloud --enable

# or, if the plugin dir is already in place:
omarchy plugin enable readitloud.tts right
```

### Dependencies

⚠️ **This plugin requires system packages and Python dependencies.**

#### System Packages
The following packages are required and will be installed:
- `mpv` — audio playback for TTS output
- `wl-paste` — clipboard reading on Wayland
- `jq` — JSON processing for settings
- `espeak-ng` — fallback offline TTS engine (no network required)
- `notify-send` — desktop notifications

Install all at once:
```bash
omarchy pkg add mpv wl-paste jq espeak-ng notify-send
```

#### Python Dependencies
`edge-tts` is installed in an isolated Python venv to avoid system-wide dependency conflicts:
```bash
python -m venv ~/.local/share/tts-venv
~/.local/share/tts-venv/bin/pip install edge-tts
```

**Why we use a venv instead of `sudo`:**
- Avoids conflicts with system Python packages
- Doesn't require elevated privileges for Python packages
- Makes uninstallation cleaner and safer
- The AUR `python-edge-tts` package is abandoned, so venv is the recommended approach

### Keybinding

Set in `~/.config/hypr/bindings.lua` (never raw `bind =` lines):

```lua
o.bind("ALT + S", "Read selection aloud", "omarchy-shell shell toggle readitloud.tts")
```

## Removal

```bash
omarchy plugin remove readitloud.tts
```

This removes the plugin from `~/.config/omarchy/plugins/` and its entry in
`~/.config/omarchy/shell.json`.

### Complete Cleanup

To fully remove all traces, including dependencies and temporary files:

```bash
rm -f ~/.local/bin/ttsctl                 # settings CLI symlink
# remove the o.bind("ALT + S", ...) line from ~/.config/hypr/bindings.lua
rm -f /tmp/readitloud-tts.pid /tmp/speaking-status
rm -rf ~/.local/share/tts-venv            # removes edge-tts and its venv
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
├── LICENSE         # MIT
└── README.md       # this file
```

## Security & Privacy

### What This Plugin Accesses
- **Clipboard** (read-only) — only when you press ALT+S
- **Audio output** — via `mpv` for playback
- **Network** (optional) — to Microsoft edge-tts service for speech synthesis
- **Local files** — reads/writes settings to `~/.config/omarchy/shell.json`

### Privacy Options
- **Offline mode available** — Run `ttsctl set engine espeak-ng` to use entirely offline text-to-speech (no network requests)
- **No data collection** — This plugin doesn't collect, log, or send usage data beyond the TTS synthesis itself
- **Clipboard content** — Text you copy is sent to the TTS provider as-is (edge-tts or local espeak-ng). Use offline mode to keep clipboard data local.

### Code Safety
- `ttsctl set voice ...` values are passed as arguments to `edge-tts` / `espeak-ng` — **no shell evaluation**
- All clipboard operations use `wl-paste` (safe Wayland clipboard API)
- No privilege escalation — no `sudo` required after installation

### Open Source & Licensed
- Full source code: [github.com/TECHNOCRAFT27/readitloud](https://github.com/TECHNOCRAFT27/readitloud)
- Licensed under **MIT** — review the LICENSE file for full terms

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
