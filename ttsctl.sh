#!/usr/bin/env bash
# ttsctl — settings and control CLI for the readitloud Omarchy plugin.
#
#   ttsctl                  Interactive settings menu (TUI)
#   ttsctl show             Print current settings
#   ttsctl set <key> <val>  Change a setting (voice, rate, pitch, volume, engine)
#   ttsctl voices           List available edge-tts voices
#   ttsctl speak            Speak clipboard text (manual test)
#   ttsctl stop             Stop speaking
#   ttsctl status           Check if speaking
set -o pipefail

CONFIG="$HOME/.config/omarchy/shell.json"
PLUGIN_ID="readitloud.tts"
SPEAK_SH="$HOME/.config/omarchy/plugins/readitloud.tts/speak.sh"

# ---- ANSI styling ----
R='\e[0m'; B='\e[1m'; D='\e[2m'; I='\e[3m'
CK='\e[96m'; CG='\e[92m'; CY='\e[93m'; CM='\e[95m'; CR='\e[91m'; CB='\e[94m'
BOX='\e[38;5;214m'; TITLE='\e[38;5;214m'
HIDE='\e[?25l'; SHOW='\e[?25h'

c()  { printf '%b' "${1}"; }
dim(){ printf '%b' "${D}${1}${R}"; }
key(){ printf '%b' "${CK}${B}${1}${R}"; }
val(){ printf '%b' "${CG}${1}${R}"; }
warn(){ printf '%b' "${CY}${B}${1}${R}"; }
bad(){ printf '%b' "${CR}${B}${1}${R}"; }
ok(){ printf '%b' "${CG}${B}${1}${R}"; }

# ---- helpers ----

get_setting() {
  local key="$1"
  jq -r --arg id "$PLUGIN_ID" --arg k "$key" '
    (.bar.layout.left + .bar.layout.center + .bar.layout.right)[]
    | select(.id == $id) | .[$k] // empty
  ' "$CONFIG" 2>/dev/null | head -1
}

set_setting() {
  local key="$1" val="$2"
  local tmp
  tmp=$(mktemp)
  jq --arg id "$PLUGIN_ID" --arg k "$key" --arg v "$val" '
    (.bar.layout.left, .bar.layout.center, .bar.layout.right)
    |= map(if .id == $id then .[$k] = $v else . end)
  ' "$CONFIG" > "$tmp" 2>/dev/null
  if jq -e . "$tmp" >/dev/null 2>&1; then
    mv "$tmp" "$CONFIG"
  else
    rm -f "$tmp"
    echo "$(bad "Error:") failed to update config" >&2
    return 1
  fi
}

# ---- cool-font wordmark (block glyphs, one element per column) ----
W_R=(▄▀█ █▀█ █▀▄ █▀▀ █▀▀ ▀█▀ █▀▀ █▀█ █ █▀▄)
W_B=(█▀█ █▄█ █▄▀ █▄█ █▄▄ ' █ ' ██▄ █▄█ █ █▄▀)
CYC=( "${CY}" "${CG}" "${CM}" "${CB}" "${CK}" )

banner() {
  local tip="$1"
  local box="$BOX"
  printf '%b\n' "  ${box}┌$(printf '─%.0s' {1..40})┐${R}"
  printf '%b' "  ${box}│${R} "
  for g in "${W_R[@]}"; do printf '%b%s ' "${D}${TITLE}${R}" "$g"; done
  printf '%b\n' " ${box}│${R}"
  printf '%b' "  ${box}│${R} "
  for g in "${W_B[@]}"; do printf '%b%s ' "${D}${TITLE}${R}" "$g"; done
  printf '%b\n' " ${box}│${R}"
  printf '%b\n' "  ${box}└$(printf '─%.0s' {1..40})┘${R}"
  printf '%b\n' "${B}${BOX}    readitloud · ttsctl  ${R}  ${D}${I}${tip}${R}"
  echo ""
}

# Animate the wordmark: columns light up left→right in a color cycle.
anim_banner() {
  local tip="$1"
  local box="$BOX" n i col start rest
  printf "${HIDE}"
  printf '%b\n' "  ${box}┌$(printf '─%.0s' {1..40})┐${R}"
  printf '%b\n' "  ${box}│${R}                                        ${box}│${R}"
  printf '%b\n' "  ${box}│${R}                                        ${box}│${R}"
  printf '%b\n' "  ${box}└$(printf '─%.0s' {1..40})┘${R}"
  local total=${#W_R[@]}
  for i in $(seq 1 "$total"); do
    start=""; rest=""
    for n in $(seq 0 $((total - 1))); do
      if (( n < i )); then
        col="${CYC[$(( n % ${#CYC[@]} ))]}"
        start+="${col}${B}${W_R[$n]}${R} "
      else
        rest+="${D}${W_R[$n]}${R} "
      fi
    done
    printf '\e[3A\e[2K'
    printf '%b' "  ${box}│${R} ${start}${rest} ${box}│${R}"
    start=""; rest=""
    for n in $(seq 0 $((total - 1))); do
      if (( n < i )); then
        col="${CYC[$(( n % ${#CYC[@]} ))]}"
        start+="${col}${B}${W_B[$n]}${R} "
      else
        rest+="${D}${W_B[$n]}${R} "
      fi
    done
    printf '\e[1B\e[G\e[2K'
    printf '%b' "  ${box}│${R} ${start}${rest} ${box}│${R}"
    printf '\e[2B\e[G\e[2K'
    sleep 0.03
  done
  printf '%b\n' "${B}${BOX}    readitloud · ttsctl  ${R}  ${D}${I}${tip}${R}"
  printf "${SHOW}"
}

# short marquee ticker — one line, ASCII only, no wrapping
ticker() {
  local msg="( ALT+S ) speak | ( middle-click ) stop | ( right-click ) popup | ttsctl = settings   "
  local i
  printf "${HIDE}"
  for ((i = 1; i <= 12; i++)); do
    msg="${msg:1}${msg:0:1}"
    printf '\r\e[2K%b' "$(dim "  ${msg}")"
    sleep 0.05
  done
  printf '\r\e[2K%b' "$(dim "  ${msg}")"
  printf "${SHOW}"
  printf '\n'
}

# ---- ASCII keycap art ----
key_art() {
  printf '%b\n' "  $(key '⌨') toggles   readitloud"
  printf '%b\n' "  ╭───────╮   ╭───╮"
  printf '%b\n' "  │  $(key 'ALT') ╮ + │ $(key 'S') ╮"
  printf '%b\n' "  ╰───────╯ │ ╰───╯ │"
  printf '%b\n' "            ╰───────╯"
  printf '%b\n' "            $(dim 'press to toggle')   $(dim 'right-click: popup · middle: stop')"
}

show_settings() {
  local voice rate pitch volume engine
  voice=$(get_setting voice)
  rate=$(get_setting rate)
  pitch=$(get_setting pitch)
  volume=$(get_setting volume)
  engine=$(get_setting engine)
  printf '%b\n' "  $(key 'Voice ')  $(val "${voice:-en-IN-NeerjaExpressiveNeural}")"
  printf '%b\n' "  $(key 'Rate   ')  $(val "${rate:--20%}")"
  printf '%b\n' "  $(key 'Pitch  ')  $(val "${pitch:-+0Hz}")"
  printf '%b\n' "  $(key 'Volume ')  $(val "${volume:-+0%}")"
  printf '%b\n' "  $(key 'Engine ')  $(val "${engine:-edge-tts}")"
  echo ""
}

# ---- interactive menu ----

menu() {
  local first=1
  while true; do
    clear
    if (( first )); then
      anim_banner "^  press q to quit  /^"
      ticker
      first=0
    else
      banner "^  press q to quit  /^"
    fi
    show_settings
    key_art
    printf '%b\n' "  $(warn 'Commands:')"
    printf '%b\n' "    $(c "${B}${CK}1${R}") Voice      $(c "${B}${CK}2${R}") Rate       $(c "${B}${CK}3${R}") Pitch"
    printf '%b\n' "    $(c "${B}${CK}4${R}") Volume     $(c "${B}${CK}5${R}") Engine     $(c "${B}${CK}6${R}") List voices"
    printf '%b\n' "    $(c "${B}${CK}7${R}") Speak now  $(c "${B}${CK}8${R}") Stop       $(c "${B}${CK}9${R}") Status"
    printf '%b\n' "    $(c "${B}${CK}q${R}") Quit"
    echo ""
    read -rp "$(c "${CG}${B}  Choose > ${R}")" choice
    case "$choice" in
      1)  read -rp "$(c "${CK}  New voice  > ${R}")" val; set_setting voice "$val" && printf '%b\n' "$(ok '✓') voice = $(val "$(get_setting voice)")";;
      2)  read -rp "$(c "${CK}  New rate (e.g. +0%, -30%) > ${R}")" val; set_setting rate "$val" && printf '%b\n' "$(ok '✓') rate = $(val "$(get_setting rate)")";;
      3)  read -rp "$(c "${CK}  New pitch (e.g. +0Hz, -5Hz) > ${R}")" val; set_setting pitch "$val" && printf '%b\n' "$(ok '✓') pitch = $(val "$(get_setting pitch)")";;
      4)  read -rp "$(c "${CK}  New volume (e.g. +0%, +10%) > ${R}")" val; set_setting volume "$val" && printf '%b\n' "$(ok '✓') volume = $(val "$(get_setting volume)")";;
      5)  read -rp "$(c "${CK}  Engine (edge-tts / espeak-ng) > ${R}")" val; set_setting engine "$val" && printf '%b\n' "$(ok '✓') engine = $(val "$(get_setting engine)")";;
      6)  list_voices;;
      7)  speak_now;;
      8)  if "$SPEAK_SH" stop >/dev/null 2>&1; then printf '%b\n' "$(ok '✓') $(val 'Stopped')"; else printf '%b\n' "$(dim 'not speaking')"; fi;;
      9)  if "$SPEAK_SH" status >/dev/null 2>&1; then printf '%b\n' "$(ok '♪ Speaking now')"; else printf '%b\n' "$(dim '♪ Idle')"; fi;;
      q|Q) clear; break;;
      *)  printf '%b\n' "$(bad '✗') $(warn 'Unknown option')";;
    esac
    echo ""
    read -rp "$(c "${D}  Press Enter...${R}")" _
  done
}

list_voices() {
  local edge_bin="$HOME/.local/share/tts-venv/bin/edge-tts"
  if [[ ! -x "$edge_bin" ]]; then
    printf '%b\n' "$(bad '✗') edge-tts not installed at $edge_bin"
    return 1
  fi
  echo ""
  printf '%b\n' "  $(warn 'Available voices:')"
  "$edge_bin" --list-voices 2>/dev/null | \
    awk 'NR > 2 && NF >= 2 { printf "  %-42s %s\n", $1, $2 }' | \
    while IFS= read -r ln; do
      if [[ "$ln" == *"Female"* ]]; then
        printf '%b\n' "  $(printf '%s' "${CM}${ln%Female*}${R}")Female"
      elif [[ "$ln" == *"Male"* ]]; then
        printf '%b\n' "  $(printf '%s' "${CK}${ln%Male*}${R}")Male"
      else
        printf '%b\n' "  $ln"
      fi
    done
  echo ""
  printf '%b\n' "  $(dim 'Tip:') ttsctl set voice $(val '<name>')"
  printf '%b\n' "       $(dim 'e.g.') ttsctl set voice $(val 'en-US-EmmaNeural')"
}

speak_now() {
  local text
  text=$(wl-paste 2>/dev/null)
  if [[ -z "$text" ]]; then
    printf '%b\n' "$(bad '✗') Clipboard is empty — nothing to speak."
    return 1
  fi
  local v r p vol e
  v=$(get_setting voice); r=$(get_setting rate)
  p=$(get_setting pitch); vol=$(get_setting volume)
  e=$(get_setting engine)

  local frames=( '◐' '◓' '◑' '◒' ) f=0 pid rc
  if [[ -t 1 ]]; then
    "$SPEAK_SH" start \
      --voice "${v:-en-IN-NeerjaExpressiveNeural}" \
      --rate "${r:--20%}" \
      --pitch "${p:-+0Hz}" \
      --volume "${vol:-+0%}" \
      --engine "${e:-edge-tts}" &
    pid=$!
    printf "${HIDE}"
    while kill -0 "$pid" 2>/dev/null; do
      printf '\r%b %b  %s' "$(ok "${frames[$((f % 4))]}")" \
        "$(dim "Speaking...")" "$(val "${v:-en-IN-NeerjaExpressiveNeural}")"
      f=$((f + 1)); sleep 0.12
    done
    wait "$pid"; rc=$?
    printf "${SHOW}"
    if [[ $rc -eq 0 ]]; then
      printf '\r%b\n' "$(ok '✓') $(val 'Finished reading')"
    else
      printf '\r%b\n' "$(bad '✗') $(bad 'Failed')"
    fi
  else
    "$SPEAK_SH" start \
      --voice "${v:-en-IN-NeerjaExpressiveNeural}" \
      --rate "${r:--20%}" \
      --pitch "${p:-+0Hz}" \
      --volume "${vol:-+0%}" \
      --engine "${e:-edge-tts}"
  fi
}

# ---- main ----

case "${1:-menu}" in
  show)     show_settings;;
  set)
    [[ -z "$2" || -z "$3" ]] && {
      printf '%b\n' "$(bad 'usage:') ttsctl set <key> <value>" >&2
      exit 1
    }
    set_setting "$2" "$3" || exit 1
    printf '%b\n' "$(ok '✓') $2 = $(val "$(get_setting "$2")")"
    ;;
  voices)   list_voices;;
  speak)    speak_now;;
  stop)     if "$SPEAK_SH" stop >/dev/null 2>&1; then printf '%b\n' "$(ok '✓') $(val 'Stopped')"; else printf '%b\n' "$(dim 'not speaking')"; fi;;
  status)   if "$SPEAK_SH" status >/dev/null 2>&1; then printf '%b\n' "$(ok '♪ Speaking')"; else printf '%b\n' "$(dim '♪ Idle')"; fi;;
  menu|-h|--help)
    if [[ "${1:-menu}" == "menu" ]] && [[ -t 0 ]]; then
      menu
    else
      printf '%b\n' "$(key 'usage:') ttsctl [show|set|voices|speak|stop|status]"
      printf '%b\n' "       ttsctl            $(dim 'Interactive settings menu')"
    fi
    ;;
  *)        printf '%b\n' "$(bad 'unknown command:') $1" >&2; exit 1;;
esac