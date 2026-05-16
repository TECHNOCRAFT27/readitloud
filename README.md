# Text-to-Speech (TTS) for Selected Text
co-writer by opencode

A script to read selected text aloud using a keyboard shortcut. Supports multiple languages and voices.

## Requirements

- Linux with Hyprland (Wayland)
- `jq` - for config parsing
- `wl-paste` - for clipboard access
- `mpv` - for audio playback
- Python 3.8+ (for edge-tts)

## Quick Install

```bash
# Clone or download this repo
git clone https://github.com/your-repo/speak-toggle.git ~/speak-tts

# Run installer
cd ~/speak-tts
chmod +x install.sh
./install.sh
```

Or manual install:

```bash
# 1. Install dependencies
sudo pacman -S jq mpv python

# 2. Setup TTS engine
python -m venv ~/.local/share/tts-venv
~/.local/share/tts-venv/bin/pip install edge-tts

# 3. Copy script
cp speak-toggle.sh ~/.local/bin/speak-toggle
chmod +x ~/.local/bin/speak-toggle

# 4. Add keybinding (edit ~/.config/hypr/bindings.conf)
bind = mod1, S, exec, ~/.local/bin/speak-toggle

# 5. Reload Hyprland
hyprctl reload
```

## Usage

1. **Copy text** to clipboard (select text + Ctrl+C)
2. **Press Alt+S** to start speaking
3. **Press Alt+S again** to stop

## Configuration

Edit `config.json`:

```json
{
  "voice": {
    "engine": "edge-tts",
    "voice": "en-IN-NeerjaExpressiveNeural",
    "rate": "-10%",
    "pitch": "+0Hz",
    "volume": "+0%"
  },
  "behavior": {
    "stop_on_repress": true,
    "show_notifications": true
  },
  "notifications": {
    "on_start": "🔊 Speaking",
    "on_stop": "🔇 Stopped",
    "on_done": "✅ Done"
  }
}
```

### Available Voices

| Voice | Language/Style |
|-------|----------------|
| `en-IN-NeerjaExpressiveNeural` | Indian female (expressive) |
| `en-IN-NeerjaNeural` | Indian female |
| `en-US-AnaNeural` | US teen/kid |
| `en-US-EmmaNeural` | US adult female |
| `en-GB-MaisieNeural` | UK young female |
| `en-GB-SoniaNeural` | UK adult female |

List all voices:
```bash
~/.local/share/tts-venv/bin/edge-tts --list-voices | grep Female
```

### Speed Options

| Rate | Speed |
|------|-------|
| `-20%` | Very slow |
| `-10%` | Slower (default) |
| `+0%` | Normal |
| `+10%` | Faster |

## File Structure

```
speak-toggle/
├── speak-toggle.sh   # Main script
├── config.json       # Voice settings
├── install.sh        # Auto-installer
└── README.md         # This file
```

## Troubleshooting

**Keybinding not working?**
```bash
# Check if bound
hyprctl binds | grep speak

# Reload config
hyprctl reload
```

**No audio?**
```bash
# Test manually
~/.local/share/tts-venv/bin/edge-tts -v en-IN-NeerjaExpressiveNeural -t "test" --write-media /tmp/test.mp3
mpv /tmp/test.mp3
```

**Check dependencies:**
```bash
which jq mpv wl-paste
```

## Uninstall

```bash
# Remove keybinding from ~/.config/hypr/bindings.conf
# Remove files
rm -rf ~/speak-tts ~/.local/bin/speak-toggle ~/.local/share/tts-venv
```

## License

MIT
