#!/bin/sh
# Build EyeRest.app into ~/Applications and keep it running in the menu bar via launchd.
# Re-run to update or change timing.
# Env (seconds): EYEREST_INTERVAL (default 1200), EYEREST_DURATION (20), EYEREST_LONG_EVERY (7200),
#                EYEREST_LONG_DURATION (300), EYEREST_SNOOZE (300), EYEREST_IDLE_SKIP (3600).
set -eu

LABEL=com.eyerest.reminder
SRC="$(cd "$(dirname "$0")" && pwd)"
APP="$HOME/Applications/EyeRest.app"
BIN="$APP/Contents/MacOS/eyerest"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Build the bundle aside, then swap it in, so a failed build leaves the installed app alone.
mkdir -p "$TMP/EyeRest.app/Contents/MacOS" "$TMP/EyeRest.app/Contents/Resources"
swiftc -O "$SRC/eyerest.swift" -o "$TMP/EyeRest.app/Contents/MacOS/eyerest"
cp "$SRC/icon/AppIcon.icns" "$TMP/EyeRest.app/Contents/Resources/AppIcon.icns"
cat > "$TMP/EyeRest.app/Contents/Info.plist" <<'INFO'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>com.eyerest.reminder</string>
  <key>CFBundleName</key><string>EyeRest</string>
  <key>CFBundleDisplayName</key><string>EyeRest</string>
  <key>CFBundleExecutable</key><string>eyerest</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.1</string>
  <key>CFBundleVersion</key><string>2</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
INFO
codesign --force --sign - "$TMP/EyeRest.app" >/dev/null 2>&1

# launchd plist, built with plutil so paths with &, < or quotes stay valid XML.
P="$TMP/agent.plist"
plutil -create xml1 "$P"
plutil -insert Label -string "$LABEL" "$P"
plutil -insert ProgramArguments -array "$P"
i=0
add() { plutil -insert "ProgramArguments.$i" -string "$1" "$P"; i=$((i + 1)); }
add "$BIN"
add --interval;      add "${EYEREST_INTERVAL:-1200}"
add --duration;      add "${EYEREST_DURATION:-20}"
add --long-every;    add "${EYEREST_LONG_EVERY:-7200}"
add --long-duration; add "${EYEREST_LONG_DURATION:-300}"
add --snooze;        add "${EYEREST_SNOOZE:-300}"
add --idle-skip;     add "${EYEREST_IDLE_SKIP:-3600}"
plutil -insert AssociatedBundleIdentifiers -array "$P"
plutil -insert AssociatedBundleIdentifiers.0 -string "$LABEL" "$P"
plutil -insert RunAtLoad -bool YES "$P"
plutil -insert KeepAlive -dictionary "$P"
plutil -insert KeepAlive.SuccessfulExit -bool NO "$P"
plutil -insert ProcessType -string Interactive "$P"
plutil -lint "$P" >/dev/null

# Everything is built and valid: now replace the running version.
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents"
rm -rf "$APP"
mv "$TMP/EyeRest.app" "$APP"
rm -f "$HOME/Library/Application Support/EyeRest/eyerest" "$HOME/Library/Application Support/EyeRest/eyerest.swift"
cp "$P" "$PLIST"
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "EyeRest installed in $APP and running: look for the eye icon in the menu bar."
