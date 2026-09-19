# Security notes

`readitloud` runs as the logged-in user and does not require privilege escalation.

## Runtime capabilities

- Reads the Wayland clipboard only when the user activates the widget or CLI.
- Uses `mpv`/`aplay` for local audio playback.
- Uses `edge-tts` optionally for network speech synthesis, or `espeak-ng` for offline speech.
- Stores settings under the user's `~/.config/omarchy` directory and temporary audio/state files under `/tmp`.

## Dependencies

The system packages documented in `README.md` are runtime dependencies, not an installer payload. They provide clipboard access, audio playback, JSON settings handling, notifications, and the offline TTS fallback. The optional `edge-tts` package is installed into the user-owned virtual environment at `~/.local/share/tts-venv`.

For a fully offline setup, run:

```bash
ttsctl set engine espeak-ng
```

No telemetry or background service is included. See `README.md` for installation, removal, and cleanup instructions.
