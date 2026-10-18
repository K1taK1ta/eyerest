#!/bin/sh
# Stop the schedule and remove eyerest.
set -eu

LABEL=com.eyerest.reminder
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
rm -rf "$HOME/Library/Application Support/EyeRest"
echo "eyerest removed."
