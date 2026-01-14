#!/bin/bash

# Whisper Push-to-Talk Installation Script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/whisper-push-to-talk"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
WHISPER_MODEL="base.en"

echo "=== Whisper Push-to-Talk Installer ==="
echo ""

# Check for required commands
check_dependencies() {
    local missing=()

    command -v python3 >/dev/null || missing+=("python3")
    command -v ydotool >/dev/null || missing+=("ydotool")
    command -v git >/dev/null || missing+=("git")
    command -v cmake >/dev/null || missing+=("cmake")

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Missing dependencies: ${missing[*]}"
        echo "Install with: sudo apt install ${missing[*]}"
        exit 1
    fi

    # Check for SDL2 dev headers
    if ! pkg-config --exists sdl2 2>/dev/null; then
        echo "Missing: libsdl2-dev (required for whisper-stream)"
        echo "Install with: sudo apt install libsdl2-dev"
        exit 1
    fi

    echo "[OK] Dependencies installed"
}

# Check group memberships
check_groups() {
    local need_logout=false

    if groups | grep -q '\binput\b'; then
        echo "[OK] User is in 'input' group"
    else
        echo "[!!] User is NOT in 'input' group"
        echo "     Run: sudo usermod -aG input $USER"
        need_logout=true
    fi

    if groups | grep -q '\buinput\b'; then
        echo "[OK] User is in 'uinput' group"
    else
        echo "[!!] User is NOT in 'uinput' group"
        echo "     Run: sudo groupadd -f uinput && sudo usermod -aG uinput $USER"
        need_logout=true
    fi

    if $need_logout; then
        echo ""
        echo "     Log out and back in, then run this installer again"
        exit 1
    fi
}

# Set up uinput permissions for ydotool
setup_uinput() {
    if [[ -w /dev/uinput ]]; then
        echo "[OK] /dev/uinput is writable"
    else
        echo "[!!] /dev/uinput is not writable by your user"
        echo "     Create a udev rule:"
        echo '     echo '\''KERNEL=="uinput", GROUP="uinput", MODE="0660"'\'' | sudo tee /etc/udev/rules.d/99-uinput.rules'
        echo "     Then: sudo udevadm control --reload-rules && sudo udevadm trigger"
        exit 1
    fi
}

# Clone and build whisper.cpp
install_whisper() {
    local whisper_dir="$INSTALL_DIR/whisper.cpp"
    local whisper_bin="$whisper_dir/build/bin/whisper-stream"

    if [[ -f "$whisper_bin" ]]; then
        echo "[OK] whisper.cpp already built"
        return
    fi

    echo ""
    echo "Installing whisper.cpp..."

    if [[ ! -d "$whisper_dir" ]]; then
        echo "  Cloning whisper.cpp..."
        git clone https://github.com/ggerganov/whisper.cpp "$whisper_dir"
    fi

    echo "  Building with SDL2 support..."
    cd "$whisper_dir"
    cmake -B build -DWHISPER_SDL2=ON
    cmake --build build --config Release

    if [[ ! -f "$whisper_bin" ]]; then
        echo "[!!] Build failed - whisper-stream not found"
        exit 1
    fi

    echo "[OK] whisper.cpp built"
}

# Download whisper model
install_model() {
    local model_file="$INSTALL_DIR/whisper.cpp/models/ggml-${WHISPER_MODEL}.bin"

    if [[ -f "$model_file" ]]; then
        echo "[OK] Model $WHISPER_MODEL already downloaded"
        return
    fi

    echo ""
    echo "Downloading whisper model ($WHISPER_MODEL)..."
    cd "$INSTALL_DIR/whisper.cpp"
    ./models/download-ggml-model.sh "$WHISPER_MODEL"

    if [[ ! -f "$model_file" ]]; then
        echo "[!!] Model download failed"
        exit 1
    fi

    echo "[OK] Model downloaded"
}

# Copy files to install directory
install_files() {
    echo ""
    echo "Installing to $INSTALL_DIR..."

    mkdir -p "$INSTALL_DIR"
    cp "$SCRIPT_DIR/whisper-push-to-talk.sh" "$INSTALL_DIR/"
    cp "$SCRIPT_DIR/key-monitor.py" "$INSTALL_DIR/"
    cp "$SCRIPT_DIR/find-keycode.py" "$INSTALL_DIR/"
    cp "$SCRIPT_DIR/find-input-device.sh" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR"/*.sh "$INSTALL_DIR"/*.py

    # Update paths in the script to use local whisper.cpp
    sed -i "s|^WHISPER_BIN=.*|WHISPER_BIN=\"$INSTALL_DIR/whisper.cpp/build/bin/whisper-stream\"|" \
        "$INSTALL_DIR/whisper-push-to-talk.sh"
    sed -i "s|^WHISPER_MODEL=.*|WHISPER_MODEL=\"$INSTALL_DIR/whisper.cpp/models/ggml-${WHISPER_MODEL}.bin\"|" \
        "$INSTALL_DIR/whisper-push-to-talk.sh"

    echo "[OK] Files installed"
}

# Enable ydotool service
enable_ydotool_service() {
    if systemctl --user is-active --quiet ydotool 2>/dev/null; then
        echo "[OK] ydotool service is running"
    else
        echo "Enabling ydotool service..."
        systemctl --user enable --now ydotool
        if systemctl --user is-active --quiet ydotool 2>/dev/null; then
            echo "[OK] ydotool service started"
        else
            echo "[!!] Failed to start ydotool service"
            exit 1
        fi
    fi
}

# Install systemd services
install_services() {
    echo ""
    echo "Installing systemd user service..."

    mkdir -p "$SYSTEMD_USER_DIR"

    # Update the service file with actual install path
    sed "s|%h/whisper-push-to-talk|$INSTALL_DIR|g" \
        "$SCRIPT_DIR/whisper-push-to-talk.service" \
        > "$SYSTEMD_USER_DIR/whisper-push-to-talk.service"

    systemctl --user daemon-reload

    echo "[OK] Service installed"
    echo ""
    echo "To enable and start:"
    echo "  systemctl --user enable --now whisper-push-to-talk"
}

main() {
    check_dependencies
    check_groups
    setup_uinput
    enable_ydotool_service
    install_files
    install_whisper
    install_model
    install_services

    echo ""
    echo "=== Installation Complete ==="
    echo ""
    echo "Before starting, edit the configuration in:"
    echo "  $INSTALL_DIR/whisper-push-to-talk.sh"
    echo ""
    echo "Set your INPUT_DEVICE and KEYCODE, then:"
    echo "  systemctl --user enable --now ydotoold"
    echo "  systemctl --user enable --now whisper-push-to-talk"
    echo ""
    echo "To find your input device and keycode:"
    echo "  $INSTALL_DIR/find-input-device.sh"
    echo "  python3 $INSTALL_DIR/find-keycode.py"
}

main "$@"
