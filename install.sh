#!/bin/sh
# Build eyerest and schedule it with launchd. Re-run to update.
# Env: EYEREST_INTERVAL (seconds between reminders, default 1200), EYEREST_DURATION (seconds shown, default 20).
set -eu

LABEL=com.eyerest.reminder
DIR="$HOME/Library/Application Support/EyeRest"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
INTERVAL="${EYEREST_INTERVAL:-1200}"
DURATION="${EYEREST_DURATION:-20}"

mkdir -p "$DIR" "$HOME/Library/LaunchAgents"
swiftc -O "$(dirname "$0")/eyerest.swift" -o "$DIR/eyerest"

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array><string>$DIR/eyerest</string><string>$DURATION</string></array>
  <key>StartInterval</key><integer>$INTERVAL</integer>
  <key>RunAtLoad</key><false/>
  <key>ProcessType</key><string>Interactive</string>
</dict>
</plist>
PLIST

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "eyerest installed: every ${INTERVAL}s for ${DURATION}s. Try it now: launchctl kickstart gui/$(id -u)/$LABEL"
