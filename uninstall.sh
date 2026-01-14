#!/bin/bash

# Whisper Push-to-Talk Uninstall Script

set -uo pipefail

INSTALL_DIR="$HOME/whisper-push-to-talk"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"

echo "=== Whisper Push-to-Talk Uninstaller ==="
echo ""

# Stop and disable services
stop_services() {
    echo "Stopping services..."

    if systemctl --user is-active --quiet whisper-push-to-talk 2>/dev/null; then
        systemctl --user stop whisper-push-to-talk
        echo "  Stopped whisper-push-to-talk"
    fi

    if systemctl --user is-enabled --quiet whisper-push-to-talk 2>/dev/null; then
        systemctl --user disable whisper-push-to-talk
        echo "  Disabled whisper-push-to-talk"
    fi
}

# Remove service files
remove_services() {
    echo ""
    echo "Removing service files..."

    if [[ -f "$SYSTEMD_USER_DIR/whisper-push-to-talk.service" ]]; then
        rm -f "$SYSTEMD_USER_DIR/whisper-push-to-talk.service"
        echo "  Removed whisper-push-to-talk.service"
    fi

    systemctl --user daemon-reload
}

# Remove installed files
remove_files() {
    echo ""
    echo "Removing installed files..."

    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
        echo "  Removed $INSTALL_DIR"
    else
        echo "  Install directory not found (already removed?)"
    fi
}

# Clean up temp files
cleanup_temp() {
    echo ""
    echo "Cleaning up temporary files..."

    rm -f /tmp/whisper-ptt-state
    rm -f /tmp/whisper-ptt.log
    echo "  Done"
}

# Remove user from groups and udev rules
cleanup_system() {
    echo ""
    read -p "Remove uinput group membership and udev rules? (requires sudo) [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "  Skipped"
        return
    fi

    # Remove user from uinput group
    if groups | grep -q '\buinput\b'; then
        sudo gpasswd -d "$USER" uinput 2>/dev/null && echo "  Removed $USER from uinput group"
    fi

    # Remove udev rule
    if [[ -f /etc/udev/rules.d/99-uinput.rules ]]; then
        sudo rm -f /etc/udev/rules.d/99-uinput.rules
        sudo udevadm control --reload-rules && sudo udevadm trigger
        echo "  Removed udev rule"
    fi

    echo ""
    echo "  Note: You may also want to remove yourself from the 'input' group:"
    echo "    sudo gpasswd -d $USER input"
    echo "  (Only do this if no other apps need it)"
}

main() {
    read -p "This will remove whisper-push-to-talk. Continue? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Cancelled"
        exit 0
    fi

    echo ""
    stop_services
    remove_services
    remove_files
    cleanup_temp
    cleanup_system

    echo ""
    echo "=== Uninstall Complete ==="
    echo ""
    echo "Note: ydotool was not removed (other apps may use it)."
    echo "To remove it if unused:"
    echo "  sudo apt remove ydotool"
}

main "$@"
