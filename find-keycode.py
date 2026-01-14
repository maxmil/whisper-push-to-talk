#!/usr/bin/env python3
"""Press any key to see its keycode. Ctrl+C to exit."""

import struct
import sys

device = sys.argv[1] if len(sys.argv) > 1 else "/dev/input/event6"
EVENT_SIZE = 24
EV_KEY = 1

print(f"Reading from {device}")
print("Press any key to see its keycode (Ctrl+C to exit)...")
print()

with open(device, 'rb') as dev:
    while True:
        data = dev.read(EVENT_SIZE)
        if len(data) < EVENT_SIZE:
            break
        _, _, ev_type, ev_code, ev_value = struct.unpack('llHHi', data)
        if ev_type == EV_KEY:
            action = {0: "released", 1: "pressed", 2: "repeat"}.get(ev_value, "?")
            print(f"Keycode: {ev_code:3d}  ({action})")
