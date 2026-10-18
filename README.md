# eyerest

A full-screen eye-rest reminder for macOS (the 20-20-20 rule). Every 20 minutes it covers
every display for 20 seconds and asks you to look away into the distance.

- Sits above everything: other windows, full-screen apps, the Dock, the menu bar and notifications, on all Spaces and displays.
- Press Esc or click to skip a reminder.
- Skipped automatically if there has been no mouse or keyboard input for over an hour.
- Nothing runs between reminders: launchd starts a short-lived process that exits on its own.

Requires the Swift compiler (Xcode or the Command Line Tools: `xcode-select --install`).

## Install

```sh
./install.sh
```

Custom timing (seconds):

```sh
EYEREST_INTERVAL=1800 EYEREST_DURATION=30 ./install.sh
```

Show a reminder right now:

```sh
launchctl kickstart gui/$(id -u)/com.eyerest.reminder
```

## Uninstall

```sh
./uninstall.sh
```

## Notes

- The text on the overlay is in Russian; edit the labels in `eyerest.swift` and re-run `./install.sh`.
- If you share your whole screen in a call, viewers will see the overlay too.
