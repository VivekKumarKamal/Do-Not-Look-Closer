#!/bin/bash
# Launch Don't look closer in the background
# (Running directly bypasses macOS LaunchServices restrictions on unsigned apps)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_BINARY="${SCRIPT_DIR}/Don't look closer.app/Contents/MacOS/BreakReminder"

# Check if already running
if pgrep -f "BreakReminder" > /dev/null 2>&1; then
    echo "Don't look closer is already running."
    exit 0
fi

# Check if built
if [ ! -f "${APP_BINARY}" ]; then
    echo "App not built yet. Run: bash build.sh"
    exit 1
fi

# Launch in background, detached from terminal
nohup "${APP_BINARY}" > /dev/null 2>&1 &
disown

echo "✅ Don't look closer started! Check your menu bar for the 👁 icon."
