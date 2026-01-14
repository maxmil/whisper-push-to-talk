#!/usr/bin/env python3
"""
Key monitor for push-to-talk functionality.
Reads raw input events and writes state to a file.

Usage: key-monitor.py <device> <keycode> <release_delay> <state_file>
"""

import struct
import sys
import threading

def main():
    if len(sys.argv) != 5:
        print(f"Usage: {sys.argv[0]} <device> <keycode> <release_delay> <state_file>")
        sys.exit(1)

    device = sys.argv[1]
    keycode = int(sys.argv[2])
    release_delay = float(sys.argv[3])
    state_file = sys.argv[4]

    EVENT_SIZE = 24
    EV_KEY = 1

    release_timer = None

    def write_state(state):
        with open(state_file, 'w') as f:
            f.write(state)
        print(f"State: {state}", flush=True)

    write_state('idle')

    with open(device, 'rb') as dev:
        while True:
            data = dev.read(EVENT_SIZE)
            if len(data) < EVENT_SIZE:
                break

            _, _, ev_type, ev_code, ev_value = struct.unpack('llHHi', data)

            if ev_type == EV_KEY and ev_code == keycode:
                if ev_value == 1:  # Press
                    if release_timer:
                        release_timer.cancel()
                        release_timer = None
                    write_state('pressed')

                elif ev_value == 0:  # Release
                    if release_timer:
                        release_timer.cancel()
                    # Delay before marking as released (keeps typing during delay)
                    release_timer = threading.Timer(
                        release_delay,
                        lambda: write_state('idle')
                    )
                    release_timer.start()

if __name__ == '__main__':
    main()
