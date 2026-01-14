#!/bin/bash

# Helper to find keyboard input device and keycodes for Wayland push-to-talk

set -euo pipefail

echo "=== Keyboard Input Device Finder ==="
echo ""

# Check if user is in input group
if groups | grep -q '\binput\b'; then
    echo "[OK] You are in the 'input' group"
else
    echo "[ERROR] You are NOT in the 'input' group"
    echo "  Run: sudo usermod -aG input $USER"
    echo "  Then log out and back in"
    echo ""
    exit 1
fi

echo ""
echo "=== Available Keyboard Devices ==="
echo ""

# List keyboard devices
for dev in /dev/input/event*; do
    if [[ -r "$dev" ]]; then
        name=$(cat "/sys/class/input/$(basename "$dev")/device/name" 2>/dev/null || echo "unknown")
        if echo "$name" | grep -qi 'keyboard\|kbd'; then
            echo "  $dev - $name"
        fi
    fi
done

echo ""
echo "=== Test a Device ==="
echo "Run this command to see keycodes (press Ctrl+C to stop):"
echo ""
echo "  sudo evtest /dev/input/eventX"
echo ""
echo "Or without sudo (if in input group):"
echo ""
echo "  evtest /dev/input/eventX"
echo ""
echo "Press the key you want to use and note the keycode number."
echo "Common keycodes:"
echo "  Caps Lock = 58"
echo "  Right Alt = 100"
echo "  Right Ctrl = 97"
echo "  Scroll Lock = 70"
echo "  Pause = 119"
