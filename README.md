# EyeRest

A full-screen eye-rest reminder for macOS, living in the menu bar. Russian and English.

- **Short break** every 20 minutes: every display is covered for 20 seconds with a tip for the eyes.
- **Long break** every 2 hours: 5 minutes, with a suggestion to stand up and move.
- Sits above everything: other windows, full-screen apps, the Dock, the menu bar and notifications, on all Spaces and displays.
- **Snooze** or **Skip** (Esc) right on the overlay.
- **Menu bar icon**: time to the next break, today's stats, *Show now*, *Pause for an hour*, *Off until tomorrow*, *Resume*, *Settings…*, *Quit until next login*.
- **Settings window**: language (Русский / English), short and long break interval and length, long break on/off, snooze length, idle skip, sound at start / end and which sound, stats for today and the last 7 days. Changes apply at once.
- Skipped automatically after a stretch with no mouse or keyboard input (1 hour by default).
- Sleep or a locked screen counts as a break: a break on screen is dropped, the schedule restarts once the Mac is awake and unlocked, and an absence as long as the long break counts as one.
- Plugging in or removing a display during a break re-covers every screen.
- Installed as `~/Applications/EyeRest.app` with its own icon, so System Settings (Login Items) shows it by name and icon. Opening the app again while it runs does nothing.

Requires macOS 14+ and the Swift compiler (Xcode or the Command Line Tools: `xcode-select --install`).

## Install

```sh
./install.sh
```

Re-run it after pulling changes. Timing, sound and language are set in the app: menu bar icon → *Settings…* (⌘,).

Show a break right now from a terminal:

```sh
"$HOME/Applications/EyeRest.app/Contents/MacOS/eyerest" now
```

Settings live in `defaults read com.eyerest.reminder`; stats per day in `~/Library/Application Support/EyeRest/stats.json`.

## Uninstall

```sh
./uninstall.sh
```

## Health notes

The tips shown during breaks come from these sources. The evidence for break timing is weaker than popular advice suggests: treat short eye breaks as a cheap supplement to getting up and moving, not a cure.

**Eyes**

- **20-20-20** (every 20 min, look ~6 m / 20 ft away for 20 s) is recommended by the [American Optometric Association](https://www.aoa.org/healthy-eyes/eye-and-vision-conditions/computer-vision-syndrome). Trials are small and mixed: symptoms eased only while reminders ran ([Talens-Estarelles et al.](https://publications.aston.ac.uk/id/eprint/44152)); another found no effect of 20 s breaks at any interval ([Johnson & Rosenfield](https://www.reviewofoptometry.com/news/article/202020-still-not-enough-to-alleviate-eye-strain)).
- **Blink on purpose**: at a screen people blink 2–3 times less often ([AAO](https://www.aao.org/eye-health/tips-prevention/computer-usage)); blink-reminder software improved dry-eye symptoms in a small trial ([PMC8597488](https://pmc.ncbi.nlm.nih.gov/articles/PMC8597488)).
- **Distance**: about an arm's length, ~64 cm / 25 in ([AAO](https://www.aao.org/eye-health/tips-prevention/computer-usage); [OSHA](https://www.osha.gov/etools/computer-workstations/components/monitors)).
- **Height**: top of the screen at or below eye level, centre 15–20° below ([AOA](https://www.aoa.org/healthy-eyes/eye-and-vision-conditions/computer-vision-syndrome); OSHA).
- **Glare and brightness**: avoid window and overhead glare, match screen brightness to the room ([AOA](https://www.aoa.org/healthy-eyes/eye-and-vision-conditions/computer-vision-syndrome); [AAO](https://www.aao.org/eye-health/tips-prevention/computer-usage); [Mayo Clinic](https://www.mayoclinic.org/diseases-conditions/eye-strain/symptoms-causes/syc-20372403)).
- **Dry eyes**: lubricating drops, a humidifier, glasses instead of contacts now and then (AAO; Mayo Clinic).
- **Long rest**: 15 minutes after 2 hours of continuous screen work (AOA).
- **Eye exams** every 1–2 years (AOA; NHS).
- **Blue-light glasses do not help** with eye strain ([Cochrane review](https://www.cochrane.org/CD013244/)), so EyeRest does not suggest them.

**Desk work**

- Short, frequent breaks beat long, rare ones: 5–10 minutes every hour is better than 20 minutes every 2 hours; get up and move ([HSE, UK](https://www.hse.gov.uk/msd/dse/work-routine.htm)). For a stricter setup, set the long break to every hour in Settings.
- Breaking up sitting with 2 minutes of light walking every 20 minutes improved blood sugar after meals ([Dunstan et al. 2012](https://espace.curtin.edu.au/handle/20.500.11937/9008)); WHO advises replacing sitting with activity of any intensity ([WHO 2020 guidelines](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7719906/)).
- Micro-breaks of up to 10 minutes give a small boost in energy and less fatigue ([Albulescu et al. 2022](https://doaj.org/article/c6f37b6ba159469296b2cb968b65505f)).

EyeRest is a reminder, not medical advice. Persistent eye pain, blurred vision or headaches are a reason to see an eye doctor.

## Icon

The icon is drawn in code: `swift icon/make-icon.swift icon` regenerates `icon/AppIcon.icns` and `icon/AppIcon.png`.

## Development

`swiftc -D PREVIEW eyerest.swift -o /tmp/eyerest-preview && (cd /tmp && ./eyerest-preview)` renders the settings window in both languages to `settings-ru.png` and `settings-en.png`.

## Notes

- If you share your whole screen in a call, viewers will see the overlay too.
