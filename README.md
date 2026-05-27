# Claude Usage Tracker 🤖🔋

A lightweight macOS menu bar widget that tracks your **Claude.ai Pro session usage** in real time — with a colour-coded battery icon that shifts from green → amber → red as your limit fills up.

![Menu bar showing 92% remaining in green](https://placeholder.com/screenshot)

## What it shows

| Menu bar | Meaning |
|----------|---------|
| 🟢 `92%` | 92% of session remaining — you're fine |
| 🟡 `45%` | Getting into the amber zone |
| 🔴 `8%`  | Nearly out — resets soon |

Click the icon for the full breakdown:

```
Current session: 8% used
█░░░░░░░░░░░░░░░░░░░
↺ Resets in 4h 28m  (Thu 3:19 AM)
────────────────────
Weekly (all models): 7% used
   Resets Sun 1:29 PM
Weekly (Claude Design): 0% used
────────────────────
Updated 10:48 PM
```

## How it works

- A **Chrome extension** fetches your usage from Claude.ai's internal API every 5 minutes (using your existing browser session — no API key needed)
- It passes the data to a **native Python script** which writes it to `/tmp/claude_usage.json`
- A **SwiftBar plugin** reads that file and renders the battery icon in the menu bar

## Requirements

- macOS
- Google Chrome (logged into claude.ai)
- A Claude.ai account (free or Pro)
- [Homebrew](https://brew.sh) (the installer will set it up if missing)

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/claude-usage-tracker/main/install.sh | bash
```

The installer handles everything. The only manual step is loading the Chrome extension (Chrome requires a human click for security) — the script will walk you through it.

**Your total effort: ~2 minutes, 3 clicks.**

## Manual installation

If you'd rather not run a curl-pipe-bash, here are the steps:

### 1. Install SwiftBar

```bash
brew install --cask swiftbar
```

Open SwiftBar and choose a plugins folder when prompted.

### 2. Copy the SwiftBar plugin

Copy `swiftbar-plugin.py` into your SwiftBar plugins folder and rename it `claude-usage.5m.py` (the `5m` tells SwiftBar to refresh every 5 minutes).

### 3. Load the Chrome extension

1. Open Chrome → `chrome://extensions`
2. Enable **Developer mode** (top-right toggle)
3. Click **Load unpacked** → select the `extension/` folder from this repo
4. Note the **Extension ID** shown on the card

### 4. Register the native messaging host

```bash
# Replace YOUR_EXTENSION_ID with the ID from step 3
EXT_ID="YOUR_EXTENSION_ID"

mkdir -p ~/.claude-usage
cp native_host.py ~/.claude-usage/native_host.py
chmod +x ~/.claude-usage/native_host.py

cat > /tmp/com.claude.usage.json << EOF
{
  "name": "com.claude.usage",
  "description": "Claude Usage Tracker native host",
  "path": "$HOME/.claude-usage/native_host.py",
  "type": "stdio",
  "allowed_origins": ["chrome-extension://$EXT_ID/"]
}
EOF

mkdir -p "$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
cp /tmp/com.claude.usage.json "$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.claude.usage.json"
```

### 5. Trigger the first data fetch

1. Go to `chrome://extensions` → Claude Usage Tracker → click **Service Worker**
2. In the console, run: `fetchAndSend()`

The menu bar icon will update within seconds.

## Colour thresholds

| Remaining | Colour |
|-----------|--------|
| 60–100%   | 🟢 Green |
| 25–60%    | 🟡 Amber |
| 0–25%     | 🔴 Red   |

## Files

```
.
├── install.sh          # One-command installer
├── extension/
│   ├── manifest.json   # Chrome extension config
│   └── background.js   # Fetches usage data every 5 min
├── native_host.py      # Receives data from extension, writes to disk
└── swiftbar-plugin.py  # Reads from disk, renders the menu bar icon
```

## Privacy

No data ever leaves your machine. The extension reads your usage directly from Claude.ai using your existing browser session, and writes it to a local temp file (`/tmp/claude_usage.json`). Nothing is sent to any third-party server.
