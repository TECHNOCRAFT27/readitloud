#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.json"
EDGE_TTS_BIN="$HOME/.local/share/tts-venv/bin/edge-tts"

PIDFILE="/tmp/speak-toggle.pid"
WAYBAR_FILE="/tmp/speaking-status"
AUDIO_FILE="/tmp/speak.mp3"

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        ENGINE=$(jq -r '.voice.engine // "edge-tts"' "$CONFIG_FILE")
        VOICE=$(jq -r '.voice.voice // "en-IN-NeerjaExpressiveNeural"' "$CONFIG_FILE")
        RATE=$(jq -r '.voice.rate // "-10%"' "$CONFIG_FILE")
        PITCH=$(jq -r '.voice.pitch // "+0Hz"' "$CONFIG_FILE")
        VOLUME=$(jq -r '.voice.volume // "+0%"' "$CONFIG_FILE")
        SHOW_NOTIFS=$(jq -r '.behavior.show_notifications // true' "$CONFIG_FILE")
    else
        ENGINE="edge-tts"
        VOICE="en-IN-NeerjaExpressiveNeural"
        RATE="-10%"
        PITCH="+0Hz"
        VOLUME="+0%"
        SHOW_NOTIFS=true
    fi
}

notify() {
    if [ "$SHOW_NOTIFS" = "true" ]; then
        notify-send -u low "$1" "$2"
    fi
}

if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")
    if kill -0 "$PID" 2>/dev/null; then
        kill "$PID"
        pkill -f "mpv.*$AUDIO_FILE" 2>/dev/null
        rm -f "$PIDFILE" "$WAYBAR_FILE" "$AUDIO_FILE"
        notify "🔇 Stopped" "Text-to-speech stopped"
        exit 0
    fi
    rm -f "$PIDFILE"
fi

load_config

TEXT=$(wl-paste 2>/dev/null)
if [ -z "$TEXT" ]; then
    notify-send -u critical "⚠️ Error" "No text in clipboard"
    exit 1
fi

echo "1" > "$WAYBAR_FILE"
notify "🔊 Speaking" "Started reading selected text..."

if [ "$ENGINE" = "edge-tts" ] && [ -x "$EDGE_TTS_BIN" ]; then
    "$EDGE_TTS_BIN" -v "$VOICE" -t "$TEXT" --rate "$RATE" --pitch "$PITCH" --volume "$VOLUME" --write-media "$AUDIO_FILE"
    mpv "$AUDIO_FILE" --no-video --really-quiet &
else
    espeak-ng -v en-us -p 75 -s 110 -w /tmp/speak.wav "$TEXT"
    aplay /tmp/speak.wav &
fi

ESPYK=$!
echo $ESPYK > "$PIDFILE"
wait $ESPYK
rm -f "$PIDFILE" "$AUDIO_FILE" /tmp/speak.wav
rm -f "$WAYBAR_FILE"
notify "✅ Done" "Finished reading"