#!/bin/bash
# MeetMind macOS 1-Click Terminator
# Terminates background server cleanly.

pkill -f "python3 server.py" 2>/dev/null

osascript -e 'tell application "Terminal" to close (every window whose name contains "stop-mac")' 2>/dev/null &
exit 0
