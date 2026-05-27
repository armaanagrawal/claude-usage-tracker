#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# <swiftbar.title>Claude Usage</swiftbar.title>
# <swiftbar.version>1.0</swiftbar.version>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>false</swiftbar.hideLastUpdated>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>
# <swiftbar.hideSwiftBar>true</swiftbar.hideSwiftBar>

import json
import os
from datetime import datetime, timezone

CACHE_FILE = "/tmp/claude_usage.json"

def battery_symbol(remaining):
    if remaining >= 75: return "battery.100"
    elif remaining >= 50: return "battery.75"
    elif remaining >= 25: return "battery.50"
    elif remaining >= 10: return "battery.25"
    else:                 return "battery.0"

def color(remaining):
    if remaining >= 60: return "#34C759"   # green
    elif remaining >= 25: return "#FF9500" # amber
    else:                 return "#FF3B30" # red

def time_until(iso_str):
    """Returns a human-readable 'Xh Ym' string until the given UTC ISO timestamp."""
    if not iso_str:
        return None
    dt = datetime.fromisoformat(iso_str).astimezone(timezone.utc)
    now = datetime.now(timezone.utc)
    delta_secs = int((dt - now).total_seconds())
    if delta_secs <= 0:
        return "any moment"
    h, rem = divmod(delta_secs, 3600)
    m = rem // 60
    if h > 0:
        return f"{h}h {m}m"
    return f"{m}m"

def local_time(iso_str):
    """Returns a formatted local time string like 'Sun 1:29 PM'."""
    if not iso_str:
        return None
    dt = datetime.fromisoformat(iso_str).astimezone()
    return dt.strftime("%a %-I:%M %p")

def main():
    # ── No data yet ──────────────────────────────────────────────────────────
    if not os.path.exists(CACHE_FILE):
        print("? | sfimage=battery.0 sfcolor=#8E8E93")
        print("---")
        print("No data yet")
        print("Make sure Chrome is open and the extension is loaded")
        return

    try:
        with open(CACHE_FILE) as f:
            data = json.load(f)

        # ── Parse fields ──────────────────────────────────────────────────────
        five_hour  = data.get("five_hour")  or {}
        seven_day  = data.get("seven_day")  or {}
        omelette   = data.get("seven_day_omelette") or {}
        fetched_at = data.get("_fetched_at")

        session_used      = five_hour.get("utilization", 0)
        session_remaining = 100 - session_used
        session_resets_at = five_hour.get("resets_at")

        weekly_used      = seven_day.get("utilization", 0)
        weekly_resets_at = seven_day.get("resets_at")

        design_used = omelette.get("utilization", 0)

        # ── Menu bar line (icon only, coloured) ───────────────────────────────
        sym = battery_symbol(session_remaining)
        col = color(session_remaining)
        print(f"{int(session_remaining)}% | sfimage={sym} color={col}")

        # ── Dropdown ──────────────────────────────────────────────────────────
        print("---")

        # Session block
        reset_in   = time_until(session_resets_at)
        reset_time = local_time(session_resets_at)

        bar_filled = int(session_used / 5)       # 0-20 blocks
        bar_empty  = 20 - bar_filled
        bar        = "█" * bar_filled + "░" * bar_empty

        print(f"Current session: {int(session_used)}% used | font=Menlo size=12")
        print(f"{bar} | font=Menlo size=10 color={col} emojize=false")
        if reset_in and reset_time:
            print(f"↺  Resets in {reset_in}  ({reset_time})")
        print("---")

        # Weekly block
        print(f"Weekly (all models): {int(weekly_used)}% used")
        if weekly_resets_at:
            print(f"   Resets {local_time(weekly_resets_at)}")
        print(f"Weekly (Claude Design): {int(design_used)}% used")

        # Footer
        print("---")
        if fetched_at:
            fetched_dt = datetime.fromisoformat(fetched_at.replace("Z", "+00:00")).astimezone()
            print(f"Updated {fetched_dt.strftime('%-I:%M %p')} | color=#8E8E93 size=11")

    except Exception as e:
        print("⚠ | sfimage=exclamationmark.triangle color=#FF3B30")
        print("---")
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
