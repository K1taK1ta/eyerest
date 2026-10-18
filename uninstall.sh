#!/bin/sh
# Stop EyeRest and remove the app, the launchd agent and the stats.
set -eu

LABEL=com.eyerest.reminder
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
pkill -f "/EyeRest.app/Contents/MacOS/eyerest" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
rm -rf "$HOME/Applications/EyeRest.app" "$HOME/Library/Application Support/EyeRest"
echo "EyeRest removed."
