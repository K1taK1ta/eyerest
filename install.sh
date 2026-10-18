#!/bin/sh
# Build eyerest and keep it running in the menu bar via launchd. Re-run to update or change timing.
# Env (seconds): EYEREST_INTERVAL (default 1200), EYEREST_DURATION (20), EYEREST_LONG_EVERY (7200),
#                EYEREST_LONG_DURATION (300), EYEREST_SNOOZE (300), EYEREST_IDLE_SKIP (3600).
set -eu

LABEL=com.eyerest.reminder
DIR="$HOME/Library/Application Support/EyeRest"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

mkdir -p "$DIR" "$HOME/Library/LaunchAgents"
swiftc -O "$(dirname "$0")/eyerest.swift" -o "$DIR/eyerest"

arg() { printf '    <string>%s</string><string>%s</string>\n' "$1" "$2"; }

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$DIR/eyerest</string>
$(arg --interval "${EYEREST_INTERVAL:-1200}")
$(arg --duration "${EYEREST_DURATION:-20}")
$(arg --long-every "${EYEREST_LONG_EVERY:-7200}")
$(arg --long-duration "${EYEREST_LONG_DURATION:-300}")
$(arg --snooze "${EYEREST_SNOOZE:-300}")
$(arg --idle-skip "${EYEREST_IDLE_SKIP:-3600}")
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
  <key>ProcessType</key><string>Interactive</string>
</dict>
</plist>
PLIST

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "eyerest installed and running: look for the eye icon in the menu bar."
