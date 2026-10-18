#!/bin/sh
# Build EyeRest.app into ~/Applications and keep it running in the menu bar via launchd.
# Re-run to update. Timing, sound and language are set in the app (menu bar icon > Settings).
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
  <key>CFBundleShortVersionString</key><string>1.3</string>
  <key>CFBundleVersion</key><string>4</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
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
plutil -insert ProgramArguments.0 -string "$BIN" "$P"
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
