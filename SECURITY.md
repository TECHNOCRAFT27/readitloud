# Security notes

`readitloud` runs as the logged-in user and does not require privilege
escalation. This plugin requires manual setup: it ships no speech engine and
installs nothing on the user's behalf.

## Runtime capabilities

- Reads the Wayland clipboard only when the user activates the widget or CLI.
- Uses `mpv` for local audio playback of the synthesized speech.
- Uses `edge-tts` optionally for network speech synthesis, or `espeak-ng` for
  offline speech.
- Stores settings under the user's `~/.config/omarchy` directory, and runtime
  state (PID file, synthesized audio, IPC socket, temp text) under
  `~/.local/state/readitloud`, created mode 0700.
- Passes clipboard text to the engines via a 0600 temp file (`edge-tts -f`) or
  stdin (`espeak-ng --stdin`), never argv, so it cannot be read out of `/proc`.

## No automatic installation

The plugin contains no `sudo`, no `pkexec`, no package manager invocation and
no install prompts, at runtime or in setup code.

- System dependencies (`wl-paste`, `mpv`, `espeak-ng`, and optionally `jq`,
  `socat`, `libnotify`) are documented in `README.md` with per-distribution
  install commands. The user runs them.
- The optional `edge-tts` package is installed by the user into the
  user-owned virtual environment at `~/.local/share/tts-venv`. It is never
  installed system-wide and never requires root.
- `speak.sh check` and `ttsctl doctor` are read-only: they inspect the
  environment and print what is missing. They install nothing.

When a dependency is absent the plugin reports it rather than failing silently:
the widget popup shows a Setup required state, `speak.sh start` exits with a
notification pointing at the README, and `ttsctl doctor` prints the install
command for the detected distribution.

## Offline setup

For a fully offline setup, no network-capable engine is needed:

```bash
ttsctl set engine espeak-ng
```

No telemetry or background service is included. See `README.md` for
installation, manual setup, removal, and cleanup instructions.
