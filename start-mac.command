#!/bin/bash
# MeetMind macOS Starter
cd "$(dirname "$0")"

# Start Python API server in background
python3 server.py >/dev/null 2>&1 &

sleep 1

# Open in Chrome or default browser
if ! open -a "Google Chrome" "http://localhost:3000" 2>/dev/null; then
    open "http://localhost:3000"
fi

# Auto-close the launcher terminal window
osascript -e 'tell application "Terminal" to close (every window whose name contains "start-mac")' 2>/dev/null &
exit 0
