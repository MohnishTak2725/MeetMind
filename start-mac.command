#!/bin/bash
# MeetMind macOS 1-Click Starter
# Double-click this file in macOS Finder to launch MeetMind.

cd "$(dirname "$0")"

# Start background server
python3 server.py > /dev/null 2>&1 &
SERVER_PID=$!

sleep 1

# Open in Google Chrome (or default browser)
if open -a "Google Chrome" "http://localhost:3000" 2>/dev/null; then
    :
else
    open "http://localhost:3000"
fi

# Close Terminal window automatically
osascript -e 'tell application "Terminal" to close (every window whose name contains "start-mac")' 2>/dev/null &
exit 0
