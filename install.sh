#!/bin/bash

set -e

echo "=== Speak Toggle Installer ==="

# Detect install location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
TTS_DIR="${TTS_DIR:-$HOME/.local/share/tts-venv}"

echo "Install location: $INSTALL_DIR"
echo "TTS venv location: $TTS_DIR"

# Check dependencies
echo ""
echo "[1/5] Checking dependencies..."
MISSING=()
for cmd in jq wl-paste mpv; do
    if ! command -v $cmd &> /dev/null; then
        MISSING+=($cmd)
    fi
done

if [ ${#MISSING[@]} -ne 0 ]; then
    echo "Missing: ${MISSING[*]}"
    echo "Install with: sudo pacman -S ${MISSING[*]}"
    exit 1
fi
echo "All dependencies OK"

# Setup TTS venv
echo ""
echo "[2/5] Setting up edge-tts..."
if [ ! -d "$TTS_DIR" ]; then
    python -m venv "$TTS_DIR"
fi
$TTS_DIR/bin/pip install --quiet edge-tts
echo "edge-tts installed"

# Install script
echo ""
echo "[3/5] Installing script..."
mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/speak-toggle.sh" "$INSTALL_DIR/speak-toggle"
chmod +x "$INSTALL_DIR/speak-toggle"
echo "Script installed to $INSTALL_DIR/speak-toggle"

# Update config with correct path
echo ""
echo "[4/5] Configuring..."
TTS_BIN="$TTS_DIR/bin/edge-tts"

# Backup existing binding if exists
BINDING_LINE="bind = mod1, S, exec, $INSTALL_DIR/speak-toggle"
HYPR_CONF="$HOME/.config/hypr/bindings.conf"

if [ -f "$HYPR_CONF" ]; then
    if ! grep -q "speak-toggle" "$HYPR_CONF"; then
        echo "" >> "$HYPR_CONF"
        echo "# Speak Toggle - Text to Speech" >> "$HYPR_CONF"
        echo "$BINDING_LINE" >> "$HYPR_CONF"
        echo "Keybinding added to $HYPR_CONF"
    else
        echo "Keybinding already exists"
    fi
else
    echo "Warning: $HYPR_CONF not found"
fi

# Reload Hyprland
echo ""
echo "[5/5] Reloading Hyprland..."
hyprctl reload 2>/dev/null || echo "Could not reload Hyprland (may need manual reload)"

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Usage:"
echo "  1. Copy text to clipboard (Ctrl+C)"
echo "  2. Press Alt+S to speak"
echo "  3. Press Alt+S again to stop"
echo ""
echo "To change voice, edit: $SCRIPT_DIR/config.json"
echo ""
echo "To change keybinding, edit: $HOME/.config/hypr/bindings.conf"