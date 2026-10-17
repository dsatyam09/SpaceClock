# SpaceClock

A tiny floating clock and countdown timer for macOS that **follows you everywhere**: across every desktop (Space) when you three-finger swipe, and on top of full-screen apps, PDFs and slides.

Built for studying and deep work: a glance at the corner of your screen tells you the time or how long is left, without leaving what you're doing.

## Features

- **Always visible.** Floats above other windows, appears on every Space, and works over full-screen apps.
- **Countdown timer.** Click ⏱ to pick 1–60 minutes or enter a custom time (`7`, `2:30`, `1h 15m`, `90s`). Pause, resume, restart or stop at any time. When the time is up it flashes red and chimes.
- **Attention-grabbing colors.** The text cycles through bright colors every 22 seconds, with a brief border pulse on each change (can be turned off).
- **Stays out of your way.** No Dock icon, never steals keyboard focus, drag it anywhere and it remembers its spot.
- **Customizable.** Size (Small to Huge), opacity, 12/24-hour time, optional seconds and date, lock position, launch at login.
- **Lightweight.** A single Swift file, no dependencies, no network access, no data collection.

## Requirements

- macOS 13 (Ventura) or later
- Apple's Command Line Tools, for the Swift compiler. If you don't have them, run:

  ```sh
  xcode-select --install
  ```

## Install

```sh
git clone https://github.com/dsatyam09/SpaceClock.git
cd SpaceClock
./build.sh
open ~/Applications/SpaceClock.app
```

`build.sh` compiles the app and puts it in `~/Applications/SpaceClock.app`. Because you build it yourself on your own Mac, macOS doesn't show any "unidentified developer" warning.

After that, open it anytime from Spotlight (**⌘ Space**, type **SpaceClock**).

## Usage

| Action | How |
|---|---|
| Start a timer | Click **⏱** on the clock and pick a time, or **Custom…** |
| Pause / resume a timer | Double-click the clock |
| Dismiss "Time's up!" | Click the clock |
| Move the clock | Drag it |
| All settings | Right-click the clock, or click the 🕒 icon in the menu bar |
| Show / hide seconds | Double-click the clock when no timer is running |
| Start automatically | Menu → **Launch at Login** |
| Quit | Menu → **Quit SpaceClock** (or **⌘Q** while the menu is open) |

If **Launch at Login** reports an error, add the app manually under **System Settings → General → Login Items**.

## Known limitations

Some presentation apps (Keynote, PowerPoint) can take over the whole display when playing a slideshow, which hides every other window, including SpaceClock. If that happens, play the slideshow in a window instead.

## Uninstall

1. Quit SpaceClock from its menu.
2. Delete `~/Applications/SpaceClock.app`.
3. Optionally remove its saved settings:

   ```sh
   defaults delete io.github.dsatyam09.SpaceClock
   ```

## Contributing

Issues and pull requests are welcome. All the code is in [`SpaceClock.swift`](SpaceClock.swift); run `./build.sh` after a change to rebuild and try it.

## License

[MIT](LICENSE)
