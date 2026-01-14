# Whisper Push-to-Talk

Push-to-talk dictation for Wayland/GNOME using [whisper.cpp](https://github.com/ggerganov/whisper.cpp).

Hold a key to dictate, release to stop. Text is typed directly into the focused application.

## Prerequisites

Install these before running the installer:

```bash
sudo apt install ydotool python3 git cmake libsdl2-dev
```

The installer will automatically clone, build whisper.cpp, and download a model.

## Installation

1. **Add yourself to required groups**:

   ```bash
   # For reading keyboard events
   sudo usermod -aG input $USER

   # For ydotool (virtual input injection)
   sudo groupadd -f uinput
   sudo usermod -aG uinput $USER
   ```

2. **Create udev rule for /dev/uinput**:

   ```bash
   echo 'KERNEL=="uinput", GROUP="uinput", MODE="0660"' | sudo tee /etc/udev/rules.d/99-uinput.rules
   sudo udevadm control --reload-rules && sudo udevadm trigger
   ```

3. **Log out and back in** for group changes to take effect.

4. **Run the installer**:

   ```bash
   ./install.sh
   ```

5. **Configure your input device and key**:

   Find your keyboard device:
   ```bash
   ~/whisper-push-to-talk/find-input-device.sh
   ```

   Find your preferred keycode:
   ```bash
   python3 ~/whisper-push-to-talk/find-keycode.py /dev/input/eventX
   ```

   Edit `~/whisper-push-to-talk/whisper-push-to-talk.sh` and set:
   - `INPUT_DEVICE` - Your keyboard's event device (e.g., `/dev/input/event6`)
   - `KEYCODE` - Your chosen key (e.g., `119` for Pause)
   - `WHISPER_BIN` - Path to whisper-stream binary
   - `WHISPER_MODEL` - Path to whisper model file

6. **Enable and start the service**:

   ```bash
   systemctl --user enable --now whisper-push-to-talk
   ```

## Usage

Hold your configured key to dictate. Release to stop. The transcribed text will be typed into whatever application has focus.

### Recommended Keys

Avoid modifier keys (Ctrl, Alt, Shift) as they affect the typed output. Good choices:

| Key         | Keycode |
|-------------|---------|
| Pause       | 119     |
| Scroll Lock | 70      |
| F9          | 67      |

## Configuration

Edit `~/whisper-push-to-talk/whisper-push-to-talk.sh`:

```bash
# Input device (find with find-input-device.sh)
INPUT_DEVICE="/dev/input/event6"

# Keycode (find with find-keycode.py)
KEYCODE=70  # Scroll Lock

# How long to keep typing after key release
RELEASE_DELAY=2.0

# Whisper paths
WHISPER_BIN="$SCRIPT_DIR/../whisper.cpp/build/bin/whisper-stream"
WHISPER_MODEL="$SCRIPT_DIR/../whisper.cpp/models/ggml-base.en.bin"
```

## Troubleshooting

### "Cannot read /dev/input/eventX"

Add yourself to the input group and log out/in:
```bash
sudo usermod -aG input $USER
```


## Uninstalling

```bash
./uninstall.sh
```

This stops the service, removes installed files, removes groups and cleans up. It leaves ydotool.

## Files

- `whisper-push-to-talk.sh` - Main script
- `key-monitor.py` - Monitors keyboard for push-to-talk key
- `find-keycode.py` - Helper to find keycodes
- `find-input-device.sh` - Helper to find input devices
- `install.sh` - Installation script
- `uninstall.sh` - Uninstallation script
- `whisper-push-to-talk.service` - Systemd service file

## License

MIT
