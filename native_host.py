#!/usr/bin/env python3
"""
Native messaging host for Claude Usage Tracker Chrome extension.
Receives usage JSON from the extension and writes it to a file for SwiftBar.
"""
import sys
import json
import struct

CACHE_FILE = "/tmp/claude_usage.json"

def read_message():
    raw_length = sys.stdin.buffer.read(4)
    if len(raw_length) == 0:
        sys.exit(0)
    length = struct.unpack("@I", raw_length)[0]
    message = sys.stdin.buffer.read(length).decode("utf-8")
    return json.loads(message)

def send_message(message):
    encoded = json.dumps(message).encode("utf-8")
    sys.stdout.buffer.write(struct.pack("@I", len(encoded)))
    sys.stdout.buffer.write(encoded)
    sys.stdout.buffer.flush()

def main():
    message = read_message()
    with open(CACHE_FILE, "w") as f:
        json.dump(message, f)
    send_message({"status": "ok"})

if __name__ == "__main__":
    main()
