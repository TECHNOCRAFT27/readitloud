#!/usr/bin/env bash
# speak.sh — TTS helper for the readitloud Omarchy plugin.
#
#   speak.sh start [--voice X] [--rate X] [--pitch X] [--volume X] [--engine X]
#   speak.sh stop
#   speak.sh status          → exit 0 if speaking, exit 1 if not
#   speak.sh progress        → "<speaking> <fraction> <pos_sec> <dur_sec>"
#   speak.sh check           → report missing dependencies, exit 1 if unusable
#
# Reads clipboard text via wl-paste, synthesizes via edge-tts (or espeak-ng
# fallback), plays through mpv. Toggle state tracked in a PID file.
#
# Dependencies are never installed here: this script only reports what is
# missing so the user can install system packages themselves. See `check`.
set -o pipefail

STATE_DIR="${HOME}/.local/state/readitloud"
PIDFILE="${STATE_DIR}/readitloud-tts.pid"
AUDIO_MP3="${STATE_DIR}/readitloud-tts.mp3"
AUDIO_WAV="${STATE_DIR}/readitloud-tts.wav"
WAYBAR_FILE="/tmp/speaking-status"
MPV_SOCK="${STATE_DIR}/readitloud-tts.sock"
EDGE_TTS_BIN="${HOME}/.local/share/tts-venv/bin/edge-tts"

# Defaults
VOICE="en-IN-NeerjaExpressiveNeural"
RATE="-20%"
PITCH="+0Hz"
VOLUME="+0%"
ENGINE="edge-tts"

cmd="${1:-status}"
shift || true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --voice)   VOICE="$2";   shift 2 ;;
    --rate)    RATE="$2";    shift 2 ;;
    --pitch)   PITCH="$2";   shift 2 ;;
    --volume)  VOLUME="$2";  shift 2 ;;
    --engine)  ENGINE="$2";  shift 2 ;;
    *) break ;;
  esac
done

# Ensure state directory exists with secure permissions
ensure_state_dir() {
  mkdir -p "$STATE_DIR" 2>/dev/null
  chmod 0700 "$STATE_DIR" 2>/dev/null
}

is_speaking() {
  [[ -f "$PIDFILE" ]] || return 1
  local pid
  pid=$(cat "$PIDFILE" 2>/dev/null)
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  pid_is_ours "$pid" && kill -0 "$pid" 2>/dev/null
}

pid_is_ours() {
  local pid="$1"
  local cmdline
  cmdline=$(cat "/proc/$pid/cmdline" 2>/dev/null | tr '\0' ' ')
  [[ "$cmdline" =~ (mpv|edge-tts|espeak-ng|speak.sh) ]]
}

have() { command -v "$1" >/dev/null 2>&1; }

# Map the edge-tts percentage settings onto espeak-ng's scales so `rate`,
# `pitch` and `volume` mean the same thing in offline mode.
pct_to_wpm()      { awk -v p="${1%\%}"  'BEGIN { w = 175 * (1 + p/100); if (w < 80) w = 80; if (w > 400) w = 400; printf "%d", w }'; }
hz_to_pitch()      { awk -v h="${1%%Hz*}"  'BEGIN { p = 50 + h * 2; if (p < 0) p = 0; if (p > 99) p = 99; printf "%d", p }'; }
pct_to_amplitude() { awk -v p="${1%\%}"  'BEGIN { a = 100 * (1 + p/100); if (a < 0) a = 0; if (a > 200) a = 200; printf "%d", a }'; }

# Base tools every engine path needs, regardless of which engine is selected.
BASE_MISSING=()
for tool in wl-paste mpv; do
  have "$tool" || BASE_MISSING+=("$tool")
done

# Engine availability. edge-tts lives in the user-owned venv (see README), so it
# is checked by path rather than on PATH; nothing here is ever installed.
edge_available() { [[ -x "$EDGE_TTS_BIN" ]]; }
espeak_available() { have espeak-ng; }

# Which engine will actually run: the configured one, or espeak-ng as the
# offline fallback when edge-tts is absent. Empty means neither can speak.
effective_engine() {
  if [[ "$ENGINE" == "espeak-ng" ]]; then
    espeak_available && echo espeak-ng
  elif edge_available; then
    echo edge-tts
  elif espeak_available; then
    echo espeak-ng
  fi
}

# Missing optional helpers degrade gracefully: socat/jq only feed `progress`,
# notify-send only feeds notifications. Never fatal.
optional_missing() {
  local tool
  for tool in "$@"; do
    have "$tool" || printf '%s ' "$tool"
  done
}

setup_hint() {
  local tools="$1"
  if have omarchy; then
    echo "  omarchy pkg add $tools"
  elif have pacman; then
    echo "  sudo pacman -S $tools"
  elif have apt-get; then
    echo "  sudo apt install $tools"
  elif have dnf; then
    echo "  sudo dnf install $tools"
  else
    echo "  install with your distribution's package manager: $tools"
  fi
}

# `check` — report whether this machine can speak, and how to fix it if not.
# Read-only: never installs anything, never needs privileges.
run_check() {
  local pkgs=() notes=() optional active

  # Only real package names go in $pkgs: these are what the hint tells the user
  # to install. Anything venv- or path-specific goes in $notes as prose.
  pkgs+=("${BASE_MISSING[@]}")
  active=$(effective_engine)

  if [[ -z "$active" ]]; then
    if [[ "$ENGINE" == "espeak-ng" ]]; then
      # Offline mode is an explicit choice; never silently substitute the
      # network engine for it.
      pkgs+=("espeak-ng")
      notes+=("  espeak-ng is the offline engine and is required by 'engine: espeak-ng'.")
    else
      pkgs+=("espeak-ng")
      notes+=("  Neither engine is available: no edge-tts venv and no espeak-ng.")
    fi
  elif [[ "$active" != "$ENGINE" ]]; then
    notes+=("  $ENGINE unavailable — falling back to espeak-ng (offline, works now).")
  fi

  optional=$(optional_missing socat jq notify-send)

  if (( ${#pkgs[@]} == 0 )); then
    echo "readitloud: ready (engine: $active)"
  else
    echo "readitloud: manual setup required — missing: ${pkgs[*]}"
    echo "Install them yourself; this plugin never installs packages for you:"
    setup_hint "${pkgs[*]}"
  fi

  local note
  for note in "${notes[@]}"; do echo "$note"; done
  [[ -n "$optional" ]] && echo "  optional, not installed: $optional"

  (( ${#pkgs[@]} == 0 ))
}

# notify-send can block when the notification daemon is busy/unreachable;
# never let it delay or hang the speech pipeline.
notify() {
  timeout 2 notify-send -u low "$1" "$2" 2>/dev/null
}

cleanup() {
  rm -f "$PIDFILE" "$AUDIO_MP3" "$AUDIO_WAV" "$WAYBAR_FILE" "$MPV_SOCK"
  # Sweep any temp text file left behind if the session was killed mid-synthesis.
  rm -f "${STATE_DIR}"/text.* 2>/dev/null
}

case "$cmd" in
  check)
    run_check
    exit $?
    ;;

  status)
    if is_speaking; then
      echo "1"
      exit 0
    fi
    echo "0"
    exit 1
    ;;

  stop)
    if [[ -f "$PIDFILE" ]]; then
      pid=$(cat "$PIDFILE" 2>/dev/null)
      if [[ "$pid" =~ ^[0-9]+$ ]] && pid_is_ours "$pid"; then
        kill "$pid" 2>/dev/null
      fi
    fi
    pkill -f "mpv.*readitloud-tts" 2>/dev/null
    pkill -f "[s]peak.sh start" 2>/dev/null
    pkill -f "tts-venv/bin/edge-tts" 2>/dev/null
    if is_speaking; then
      notify "🔇 Stopped" "Text-to-speech stopped"
    fi
    cleanup
    exit 0
    ;;

  start)
    ensure_state_dir

    # If already speaking, stop first (toggle behavior)
    if is_speaking; then
      pid=$(cat "$PIDFILE" 2>/dev/null)
      if [[ "$pid" =~ ^[0-9]+$ ]] && pid_is_ours "$pid"; then
        kill "$pid" 2>/dev/null
      fi
      pkill -f "mpv.*readitloud-tts" 2>/dev/null
      cleanup
      notify "🔇 Stopped" "Text-to-speech stopped"
      exit 0
    fi

    TEXT=$(wl-paste 2>/dev/null)
    if [[ -z "$TEXT" ]]; then
      notify "⚠️ Error" "No text in clipboard"
      exit 1
    fi

    # Fail safe with an actionable message instead of a silent no-op. Notify
    # only carries the short version; `speak.sh check` prints the full report.
    if ! run_check >/dev/null 2>&1; then
      notify "⚠️ Setup required" "Run: speak.sh check  (see README Manual setup)"
      exit 1
    fi

    echo "1" > "$WAYBAR_FILE"
    notify "🔊 Speaking" "Reading selected text..."

    # Both engines synthesize to a file, then play through mpv: one player for
    # both paths keeps progress reporting working offline too, and removes the
    # hard dependency on ALSA's aplay.
    #
    # Clipboard text reaches the engines via a 0600 temp file / stdin, never argv,
    # so it can't be read out of /proc by another local user.
    if [[ "$ENGINE" != "espeak-ng" ]] && edge_available; then
      text_file=$(mktemp "${STATE_DIR}/text.XXXXXX")
      chmod 0600 "$text_file" 2>/dev/null
      printf '%s' "$TEXT" > "$text_file"

      "$EDGE_TTS_BIN" -v "$VOICE" -f "$text_file" \
        --rate "$RATE" --pitch "$PITCH" --volume "$VOLUME" \
        --write-media "$AUDIO_MP3" >/dev/null 2>&1
      rm -f "$text_file"
      MEDIA="$AUDIO_MP3"
    else
      # espeak-ng speaks in words-per-minute (default 175) and has its own
      # pitch/amplitude scales, so translate the same settings rather than
      # ignoring them offline.
      printf '%s' "$TEXT" | espeak-ng -v en-us \
        -s "$(pct_to_wpm "$RATE")" \
        -p "$(hz_to_pitch "$PITCH")" \
        -a "$(pct_to_amplitude "$VOLUME")" \
        -w "$AUDIO_WAV" --stdin >/dev/null 2>&1
      MEDIA="$AUDIO_WAV"
    fi

    if [[ ! -s "$MEDIA" ]]; then
      cleanup
      notify "⚠️ Error" "Synthesis produced no audio — see: speak.sh check"
      exit 1
    fi

    rm -f "$MPV_SOCK"
    mpv "$MEDIA" --no-video --really-quiet \
      --input-ipc-server="$MPV_SOCK" &

    PLAYER_PID=$!
    echo "$PLAYER_PID" > "$PIDFILE"
    wait "$PLAYER_PID" 2>/dev/null

    cleanup
    notify "✅ Done" "Finished reading"
    exit 0
    ;;

  progress)
    # Machine-readable progress: "<speaking> <fraction> <pos_sec> <dur_sec>".
    # speaking=1 while a session is active (even mid-synthesis).
    if ! is_speaking; then
      echo "0 0 0 0"
      exit 0
    fi
    if [[ ! -S "$MPV_SOCK" ]]; then
      echo "1 0 0 0"
      exit 0
    fi
    data=$(printf '%s\n%s\n' \
        '{"command":["get_property_string","time-pos"]}' \
        '{"command":["get_property_string","duration"]}' \
      | socat - UNIX-CONNECT:"$MPV_SOCK" 2>/dev/null)
    vals=$(printf '%s' "$data" | jq -r -s '.[].data' 2>/dev/null)
    pos=$(printf '%s\n' "$vals" | sed -n '1p')
    dur=$(printf '%s\n' "$vals" | sed -n '2p')
    [[ -z "$pos" || "$pos" == "null" ]] && pos=0
    [[ -z "$dur" || "$dur" == "null" ]] && dur=0
    frac=$(awk -v p="$pos" -v d="$dur" 'BEGIN { if (d > 0) printf "%.3f", p/d; else printf "0" }')
    printf '1 %s %s %s\n' "$frac" "$pos" "$dur"
    exit 0
    ;;

  *)
    echo "usage: speak.sh {start|stop|status|progress|check} [--voice X] [--rate X]" >&2
    exit 1
    ;;
esac
