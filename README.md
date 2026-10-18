# eyerest

A full-screen eye-rest reminder for macOS (the 20-20-20 rule), living in the menu bar.

- **Short break** every 20 minutes: every display is covered for 20 seconds with a tip for the eyes.
- **Long break** every 2 hours: 5 minutes, with a suggestion to stand up and move.
- Sits above everything: other windows, full-screen apps, the Dock, the menu bar and notifications, on all Spaces and displays.
- **Snooze 5 min** or **Skip** (Esc) right on the overlay.
- **Menu bar icon**: time to the next break, today's stats (done / skipped / snoozed), *Show now*, *Pause for an hour*, *Off until tomorrow*, *Resume*, *Quit until next login*.
- Skipped automatically if there has been no mouse or keyboard input for over an hour.
- Sleep or a locked screen counts as a break: the schedule restarts when you come back, and an absence of 5+ minutes counts as the long break.

Requires the Swift compiler (Xcode or the Command Line Tools: `xcode-select --install`).

## Install

```sh
./install.sh
```

Custom timing, in seconds (all optional):

```sh
EYEREST_INTERVAL=1800 EYEREST_DURATION=30 EYEREST_LONG_EVERY=5400 EYEREST_LONG_DURATION=600 ./install.sh
```

Also `EYEREST_SNOOZE` (default 300) and `EYEREST_IDLE_SKIP` (default 3600).

Show a break right now from a terminal:

```sh
"$HOME/Library/Application Support/EyeRest/eyerest" now
```

Stats are kept per day in `~/Library/Application Support/EyeRest/stats.json`.

## Uninstall

```sh
./uninstall.sh
```

## Notes

- The text on the overlay and in the menu is in Russian; edit the strings in `eyerest.swift` and re-run `./install.sh`.
- If you share your whole screen in a call, viewers will see the overlay too.
