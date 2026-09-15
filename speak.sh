#!/usr/bin/env bash
# speak.sh — TTS helper for the readitloud Omarchy plugin.
#
#   speak.sh start [--voice X] [--rate X] [--pitch X] [--volume X] [--engine X]
#   speak.sh stop
#   speak.sh status          → exit 0 if speaking, exit 1 if not
#
# Reads clipboard text via wl-paste, synthesizes via edge-tts (or espeak-ng
# fallback), plays through mpv. Toggle state tracked in a PID file.
set -o pipefail

PIDFILE="/tmp/readitloud-tts.pid"
AUDIO_MP3="/tmp/readitloud-tts.mp3"
AUDIO_WAV="/tmp/readitloud-tts.wav"
WAYBAR_FILE="/tmp/speaking-status"
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

is_speaking() {
  [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null
}

# notify-send can block when the notification daemon is busy/unreachable;
# never let it delay or hang the speech pipeline.
notify() {
  timeout 2 notify-send -u low "$1" "$2" 2>/dev/null
}

cleanup() {
  rm -f "$PIDFILE" "$AUDIO_MP3" "$AUDIO_WAV" "$WAYBAR_FILE"
}

case "$cmd" in
  status)
    if is_speaking; then
      echo "1"
      exit 0
    fi
    echo "0"
    exit 1
    ;;

  stop)
    if is_speaking; then
      kill "$(cat "$PIDFILE")" 2>/dev/null
      pkill -f "mpv.*readitloud-tts" 2>/dev/null
      notify "🔇 Stopped" "Text-to-speech stopped"
    fi
    cleanup
    exit 0
    ;;

  start)
    # If already speaking, stop first (toggle behavior)
    if is_speaking; then
      kill "$(cat "$PIDFILE")" 2>/dev/null
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

    echo "1" > "$WAYBAR_FILE"
    notify "🔊 Speaking" "Reading selected text..."

    if [[ "$ENGINE" == "edge-tts" ]] && [[ -x "$EDGE_TTS_BIN" ]]; then
      "$EDGE_TTS_BIN" -v "$VOICE" -t "$TEXT" \
        --rate "$RATE" --pitch "$PITCH" --volume "$VOLUME" \
        --write-media "$AUDIO_MP3" >/dev/null 2>&1
      mpv "$AUDIO_MP3" --no-video --really-quiet &
    else
      espeak-ng -v en-us -p 75 -s 110 -w "$AUDIO_WAV" "$TEXT" 2>/dev/null
      aplay "$AUDIO_WAV" >/dev/null 2>&1 &
    fi

    PLAYER_PID=$!
    echo "$PLAYER_PID" > "$PIDFILE"
    wait "$PLAYER_PID" 2>/dev/null

    cleanup
    notify "✅ Done" "Finished reading"
    exit 0
    ;;

  *)
    echo "usage: speak.sh {start|stop|status} [--voice X] [--rate X]" >&2
    exit 1
    ;;
esac