# AGENTS.md

## What this is

**readitloud** is now an **Omarchy plugin** (`readitloud.tts`) that reads clipboard
text aloud on Wayland/Hyprland: press `ALT+S` (or click the TTS bar icon) →
`wl-paste` grabs the selection → `edge-tts` (or `espeak-ng` fallback) synthesizes
→ `mpv` plays; second press stops. A Quickshell popup shows live status and
settings. Toggle/speaking state lives in `/tmp/readitloud-tts.pid` and
`/tmp/speaking-status` (`1` while speaking) is a status hook for external bars.

This repo is now primarily the **plugin source** plus this file and `README.md`.
The plugin is developed and run live on this Omarchy machine at
`~/.config/omarchy/plugins/readitloud.tts/`.

## Current layout

- `~/.config/omarchy/plugins/readitloud.tts/` — the live plugin:
  - `manifest.json` — `id: readitloud.tts`, `kinds: ["bar-widget"]`,
    `entryPoints.barWidget: "Panel.qml"`, defaults for `engine/voice/rate/pitch/volume`.
  - `Panel.qml` — Quickshell bar widget. Owns `open()`/`close()` (the shell routes
    `omarchy-shell shell toggle readitloud.tts` through these) so ALT+S starts and
    stops speech; popup shows status + settings and opens `ttsctl` (Settings…
    via `omarchy-launch-terminal ttsctl` — NOT a hardcoded terminal; alacritty is
    not installed on this machine).
  - `speak.sh` — TTS helper: `speak.sh start [--engine|--voice|--rate|--pitch|--volume]`,
    `stop`, `status` (exit 0 = speaking). `notify()` wraps `notify-send` in
    `timeout 2` so a busy notification daemon can never hang the pipeline.
  - `ttsctl.sh` — settings/control CLI, symlinked to `~/.local/bin/ttsctl`
    (`ttsctl`, `ttsctl show|set|voices|speak|stop|status`). Writes the widget's
    settings into the entry in `~/.config/omarchy/shell.json` (bar layout), which
    hot-reloads and feeds `setting()` in Panel.qml.
- Keybinding: `o.bind("ALT + S", "Read selection aloud", "omarchy-shell shell
  toggle readitloud.tts")` in `~/.config/hypr/bindings.lua`.
- Enabled via `omarchy plugin enable readitloud.tts right` in
  `~/.config/omarchy/shell.json`.

## Troubleshooting live with the shell

- Diagnostics: `tee /tmp/speak.log | cat` your capture, then
  `journalctl --user -u omarchy-shell -f | rg -i "readitloud|error|failed"`.
  A log line like `Plugin widget readitloud.tts failed: ... Cannot assign to
  non-existent property ...` means Panel.qml failed to load → widget not
  registered → `omarchy-shell shell toggle readitloud.tts` is a no-op.
- **QML compile cache**: after editing Panel.qml you may hit stale compiled
  behavior despite "Local plugin changed, reloading". Clear
  `rm -rf ~/.cache/quickshell/qmlcache/*` and `omarchy restart shell`.
- `speak.sh start` writes the PID file only **after** edge-tts synthesis
  completes; `status` can read "not speaking" during the ~2-3 s synthesize →
  playback window. `mpv` keeps the shell command session alive until the audio
  finishes — give commands generous timeouts.

## Omarchy integration facts worth rememberu9 (do not re-derive)

**Always load the `omarchy` skill before touching `~/.config/hypr/`,
`~/.config/omarchy/`, or omarchy commands.**

- Shell plugins are Quickshell QML directories at
  `~/.config/omarchy/plugins/<plugin-id>/` (a `manifest.json` plus `Panel.qml`);
  enabled via the `plugins` array in `~/.config/omarchy/shell.json`. Files
  under that dir hot-reload on save.
- Plugin commands: `omarchy plugin add <git-url> --enable`, `omarchy plugin
  enable <id> [placement]`, `omarchy plugin validate <folder>`, `omarchy plugin
  list`.
- Keybindings: `o.bind("ALT + S", ...)` in `~/.config/hypr/bindings.lua` — never
  emit raw `bind = ...` lines (that was `install.sh`'s bug: it appended to
  `~/.config/hypr/bindings.conf`, which does not exist on Omarchy).
- Bar-widget toggling: `shell` routes `omarchy-shell shell toggle <id>` through
  `bar.summonBarWidget()` → `item.open()` / `item.close()` — NOT through
  `IpcHandler`. Override `open()`/`close()` in the widget. Set `manageIpc: false`.
- Widget settings come from the shell.json entry via `Panel.setting(key, fallback)`
  (see `/usr/share/omarchy/shell/Ui/Panel.qml`); defaults fall back to
  `manifest.json` `barWidget.defaults`.
- `StdioCollector` has a `read` signal (`onRead`), **not** `onDataRead`; use
  `waitForEnd: true` + read `.text` in `onExited` (pomodoro/omanews pattern).
- Never read/write `/usr/share/omarchy/` (read-only, overwritten on update).
- Install dependencies with `omarchy pkg add <pkgs>` (or `omarchy pkg aur add`),
  not `sudo pacman -S` in scripts. `edge-tts` runs from a venv at
  `~/.local/share/tts-venv` because the AUR `python-edge-tts` package is
  abandoned (needs a dozen python deps in a bare `sudo` install).
- No tests, linter, build step, or CI. Individual run: `speak.sh` and `ttsctl`
  from the plugin dir.