#!/bin/bash

# Whisper Push-to-Talk for Wayland
# Runs whisper-stream continuously, only types output when key is held
# Requires: input group membership, ydotool, whisper-stream

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# === CONFIGURATION - EDIT THESE ===
WHISPER_BIN="$SCRIPT_DIR/../whisper.cpp/build/bin/whisper-stream"
WHISPER_MODEL="$SCRIPT_DIR/../whisper.cpp/models/ggml-base.en.bin"

# Find your device with: ./find-input-device.sh
# Find keycode with: python3 ./find-keycode.py
INPUT_DEVICE="/dev/input/event7"
KEYCODE=119  # Scroll Lock

# How long to keep typing after key release (seconds)
RELEASE_DELAY=2.0
# ===================================

LOG_FILE="/tmp/whisper-ptt.log"
STATE_FILE="/tmp/whisper-ptt-state"

log() {
    echo "$(date '+%H:%M:%S') $*" | tee -a "$LOG_FILE"
}

cleanup() {
    log "Cleaning up..."
    jobs -p | xargs -r kill 2>/dev/null || true
    rm -f "$STATE_FILE"
    exit 0
}

trap cleanup SIGINT SIGTERM EXIT

check_dependencies() {
    local missing=()

    command -v ydotool >/dev/null || missing+=("ydotool")
    command -v python3 >/dev/null || missing+=("python3")
    [[ -f "$WHISPER_BIN" ]] || missing+=("whisper-stream at $WHISPER_BIN")
    [[ -f "$WHISPER_MODEL" ]] || missing+=("model at $WHISPER_MODEL")

    if [[ ! -r "$INPUT_DEVICE" ]]; then
        echo "ERROR: Cannot read $INPUT_DEVICE"
        echo "Either the device path is wrong, or you need to:"
        echo "  sudo usermod -aG input \$USER"
        echo "  (then log out and back in)"
        echo ""
        echo "Run ./find-input-device.sh to find the correct device"
        exit 1
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "ERROR: Missing: ${missing[*]}"
        exit 1
    fi

    # Check if ydotool daemon is running
    if ! pgrep -x ydotoold >/dev/null; then
        echo "ERROR: ydotool daemon is not running"
        echo "Enable the service: systemctl --user enable --now ydotool"
        exit 1
    fi
}

# Check if key is currently pressed
is_key_pressed() {
    [[ -f "$STATE_FILE" ]] && [[ "$(cat "$STATE_FILE" 2>/dev/null)" == "pressed" ]]
}

# Monitor key state
monitor_key() {
    log "Monitoring keycode $KEYCODE on $INPUT_DEVICE"
    python3 "$SCRIPT_DIR/key-monitor.py" "$INPUT_DEVICE" "$KEYCODE" "$RELEASE_DELAY" "$STATE_FILE"
}

# Process whisper output - runs continuously, only types when key is pressed
process_whisper_output() {
    "$WHISPER_BIN" -m "$WHISPER_MODEL" 2>>"$LOG_FILE" | while read -r line; do
        if is_key_pressed && [[ -n "$line" ]]; then
            # Keep only text after the last [2K (line clear), remove other ANSI codes, brackets, "Thank you.", and trim
            clean_line=$(echo "$line" | sed 's/.*\x1b\[2K//' | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' | sed 's/\[[^]]*\]//g' | sed 's/Thank you\.//g' | sed 's/[[:space:]]\+/ /g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if [[ -n "$clean_line" ]]; then
                log "Typing: $clean_line"
                ydotool type -- "$clean_line "
            fi
        fi
    done
}

cleanup_stale() {
    # Kill any existing key-monitor processes
    pkill -f "key-monitor.py.*$INPUT_DEVICE" 2>/dev/null || true
    rm -f "$STATE_FILE"
}

main() {
    echo "=== Whisper Push-to-Talk (Wayland) ==="
    echo "Device: $INPUT_DEVICE"
    echo "Keycode: $KEYCODE"
    echo ""

    check_dependencies

    > "$LOG_FILE"

    log "Cleaning up any stale processes..."
    cleanup_stale

    echo "idle" > "$STATE_FILE"

    log "Starting key monitor..."
    monitor_key &

    sleep 0.5
    log "Starting whisper-stream (runs continuously)..."
    log "Hold key to dictate. Release to stop."

    process_whisper_output
}

main "$@"
