#!/bin/bash
set -e

# ── Colours ────────────────────────────────────────────────────────────────
BOLD="\033[1m"; GREEN="\033[32m"; YELLOW="\033[33m"; RESET="\033[0m"
info()    { echo -e "  ${GREEN}✔${RESET}  $1"; }
prompt()  { echo -e "\n  ${BOLD}$1${RESET}"; }
section() { echo -e "\n${BOLD}$1${RESET}"; echo "────────────────────────────"; }

echo ""
echo -e "${BOLD}  🤖 Claude Usage Tracker — Installer${RESET}"
echo "  Tracks your Claude.ai session in the macOS menu bar."
echo ""

# ── 1. Homebrew ─────────────────────────────────────────────────────────────
section "Step 1 / 4 — Homebrew"
if ! command -v brew &>/dev/null; then
  prompt "Homebrew not found. Installing it now..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  info "Homebrew already installed."
fi

# ── 2. SwiftBar ─────────────────────────────────────────────────────────────
section "Step 2 / 4 — SwiftBar"
if ! brew list --cask swiftbar &>/dev/null; then
  prompt "Installing SwiftBar..."
  brew install --cask swiftbar
else
  info "SwiftBar already installed."
fi

# Set up SwiftBar plugins folder
PLUGINS_DIR=$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null || echo "")
if [ -z "$PLUGINS_DIR" ]; then
  PLUGINS_DIR="$HOME/claude-usage-bar"
  mkdir -p "$PLUGINS_DIR"
  defaults write com.ameba.SwiftBar PluginDirectory "$PLUGINS_DIR"
  info "Created SwiftBar plugins folder at ~/claude-usage-bar"
else
  info "Using existing SwiftBar plugins folder: $PLUGINS_DIR"
fi

# ── 3. Install files ─────────────────────────────────────────────────────────
section "Step 3 / 4 — Installing files"
INSTALL_DIR="$HOME/.claude-usage"
mkdir -p "$INSTALL_DIR/extension"

# Chrome extension — manifest.json
cat > "$INSTALL_DIR/extension/manifest.json" << 'EOF'
{
  "manifest_version": 3,
  "name": "Claude Usage Tracker",
  "version": "1.0",
  "description": "Tracks Claude.ai usage limits for menu bar display",
  "permissions": [
    "nativeMessaging",
    "alarms",
    "cookies"
  ],
  "host_permissions": [
    "https://claude.ai/*"
  ],
  "background": {
    "service_worker": "background.js"
  }
}
EOF

# Chrome extension — background.js
cat > "$INSTALL_DIR/extension/background.js" << 'EOF'
const NATIVE_HOST = "com.claude.usage";

async function fetchAndSend() {
  try {
    const cookie = await chrome.cookies.get({
      url: "https://claude.ai",
      name: "lastActiveOrg"
    });
    if (!cookie) {
      console.warn("Claude Usage Tracker: not logged into claude.ai");
      return;
    }
    const orgId = cookie.value;
    const response = await fetch(`https://claude.ai/api/organizations/${orgId}/usage`);
    if (!response.ok) {
      console.error(`Claude Usage Tracker: API error ${response.status}`);
      return;
    }
    const data = await response.json();
    data._fetched_at = new Date().toISOString();
    chrome.runtime.sendNativeMessage(NATIVE_HOST, data, () => {
      if (chrome.runtime.lastError) {
        console.error("Claude Usage Tracker: native messaging error —", chrome.runtime.lastError.message);
      }
    });
  } catch (e) {
    console.error("Claude Usage Tracker: fetch failed —", e);
  }
}

chrome.runtime.onInstalled.addListener(fetchAndSend);
chrome.runtime.onStartup.addListener(fetchAndSend);
chrome.alarms.create("refresh", { periodInMinutes: 5 });
chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === "refresh") fetchAndSend();
});
EOF

# Native messaging host
cat > "$INSTALL_DIR/native_host.py" << 'EOF'
#!/usr/bin/env python3
import sys, json, struct

def read_message():
    raw = sys.stdin.buffer.read(4)
    if not raw: sys.exit(0)
    length = struct.unpack("@I", raw)[0]
    return json.loads(sys.stdin.buffer.read(length).decode("utf-8"))

def send_message(msg):
    enc = json.dumps(msg).encode("utf-8")
    sys.stdout.buffer.write(struct.pack("@I", len(enc)))
    sys.stdout.buffer.write(enc)
    sys.stdout.buffer.flush()

msg = read_message()
with open("/tmp/claude_usage.json", "w") as f:
    json.dump(msg, f)
send_message({"status": "ok"})
EOF
chmod +x "$INSTALL_DIR/native_host.py"

# SwiftBar plugin
cat > "$PLUGINS_DIR/claude-usage.5m.py" << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# <swiftbar.title>Claude Usage</swiftbar.title>
# <swiftbar.version>1.0</swiftbar.version>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>
# <swiftbar.hideSwiftBar>true</swiftbar.hideSwiftBar>

import json, os
from datetime import datetime, timezone

CACHE_FILE = "/tmp/claude_usage.json"

def battery_symbol(remaining):
    if remaining >= 75: return "battery.100"
    elif remaining >= 50: return "battery.75"
    elif remaining >= 25: return "battery.50"
    elif remaining >= 10: return "battery.25"
    else:                 return "battery.0"

def bar_color(remaining):
    if remaining >= 60: return "#34C759"
    elif remaining >= 25: return "#FF9500"
    else:                 return "#FF3B30"

def time_until(iso_str):
    if not iso_str: return None
    dt = datetime.fromisoformat(iso_str).astimezone(timezone.utc)
    secs = int((dt - datetime.now(timezone.utc)).total_seconds())
    if secs <= 0: return "any moment"
    h, r = divmod(secs, 3600)
    return f"{h}h {r//60}m" if h else f"{r//60}m"

def local_time(iso_str):
    if not iso_str: return None
    return datetime.fromisoformat(iso_str).astimezone().strftime("%a %-I:%M %p")

if not os.path.exists(CACHE_FILE):
    print("? | sfimage=battery.0 sfcolor=#8E8E93")
    print("---")
    print("No data yet — make sure Chrome is open")
else:
    try:
        with open(CACHE_FILE) as f:
            data = json.load(f)

        five_hour  = data.get("five_hour")  or {}
        seven_day  = data.get("seven_day")  or {}
        omelette   = data.get("seven_day_omelette") or {}
        fetched_at = data.get("_fetched_at")

        used      = five_hour.get("utilization", 0)
        remaining = 100 - used
        resets_at = five_hour.get("resets_at")
        col       = bar_color(remaining)

        print(f"{int(remaining)}% | sfimage={battery_symbol(remaining)} color={col}")
        print("---")

        bar = "█" * int(used / 5) + "░" * (20 - int(used / 5))
        print(f"Current session: {int(used)}% used | font=Menlo size=12")
        print(f"{bar} | font=Menlo size=10 color={col} emojize=false")
        reset_in = time_until(resets_at)
        reset_at = local_time(resets_at)
        if reset_in:
            print(f"↺  Resets in {reset_in}  ({reset_at})")
        print("---")

        w_used = seven_day.get("utilization", 0)
        w_resets = seven_day.get("resets_at")
        print(f"Weekly (all models): {int(w_used)}% used")
        if w_resets: print(f"   Resets {local_time(w_resets)}")
        print(f"Weekly (Claude Design): {int(omelette.get('utilization', 0))}% used")

        if fetched_at:
            dt = datetime.fromisoformat(fetched_at.replace("Z", "+00:00")).astimezone()
            print("---")
            print(f"Updated {dt.strftime('%-I:%M %p')} | color=#8E8E93 size=11")

    except Exception as e:
        print("⚠ | sfimage=exclamationmark.triangle color=#FF3B30")
        print("---")
        print(f"Error: {e}")
EOF
chmod +x "$PLUGINS_DIR/claude-usage.5m.py"
info "All files installed."

# ── 4. Chrome extension ─────────────────────────────────────────────────────
section "Step 4 / 4 — Chrome Extension"
prompt "Opening Chrome extensions page..."
open -a "Google Chrome" --args --new-tab
sleep 1
open "chrome://extensions"

echo ""
echo -e "  Please do these 3 things in Chrome:"
echo -e "  ${BOLD}1.${RESET} Enable ${BOLD}Developer mode${RESET} (toggle in top-right corner)"
echo -e "  ${BOLD}2.${RESET} Click ${BOLD}Load unpacked${RESET}"
echo -e "  ${BOLD}3.${RESET} Select this folder:  ${BOLD}$INSTALL_DIR/extension${RESET}"
echo ""
echo -e "  Tip: In the file picker, press ${BOLD}Cmd+Shift+G${RESET} and paste the path above."
echo ""
read -p "  Paste the Extension ID shown on the card (then press Enter): " EXT_ID

# Write native messaging manifest with real extension ID
cat > /tmp/com.claude.usage.json << EOF2
{
  "name": "com.claude.usage",
  "description": "Claude Usage Tracker native host",
  "path": "$INSTALL_DIR/native_host.py",
  "type": "stdio",
  "allowed_origins": ["chrome-extension://$EXT_ID/"]
}
EOF2

NMHOST_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
mkdir -p "$NMHOST_DIR"
cp /tmp/com.claude.usage.json "$NMHOST_DIR/com.claude.usage.json"
info "Native messaging host registered."

# Restart SwiftBar
pkill -x SwiftBar 2>/dev/null || true
sleep 1
open -a SwiftBar
sleep 2
open -g "swiftbar://refreshallplugins"

echo ""
echo -e "${GREEN}${BOLD}  ✅ All done!${RESET}"
echo -e "  Your Claude usage tracker is now live in the menu bar."
echo -e "  It refreshes every 5 minutes while Chrome is open."
echo ""
