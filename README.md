# Macpardy

A macOS app for hosting a Jeopardy-style trivia night ("Macpardy!"). The host runs the game
from a control window, the room watches a full-screen display on a TV or projector, and teams
can buzz in from their phones over the local network. No accounts, no server, no internet.

## Features

- Build a game in the editor (6 × 5 boards for two rounds, plus Final Macpardy), with Daily
  Doubles and optional pictures on clues
- Or fill in a CSV template in any spreadsheet app and import it
- Open, edit, and re-save existing games (`.macpardy` packages, `.json`, `.csv`)
- Separate host and audience windows, with timer, scores, Daily Double and Final wagers
- Phone buzzers: scan a QR code, pick a team, buzz; fair tie-breaking, a 5 s response timer and wrong-answer lockout;
  Final wagers and answers typed on the phone, with each team's answer shown on the Display;
  or turn buzzers off in Settings to play with no phones or Wi-Fi
- Display animations (board intro, clue flips, Daily Double, score changes), switchable in Settings
- Auto-save, so a game can be resumed after a quit or crash

Full walkthrough: [docs/features.md](docs/features.md).

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| ⌘O / ⌘N | File menu: **Import Board…** (play or edit), **New Board**; **Open Recent** lists the last 10 boards |
| ⌘S | Editor: **Save Game** |
| ⌘T | Start / pause the timer |
| ⌘R | **Reveal Answer** |
| ⌘, | **Settings** (sound, timers, starting teams, buzzers on/off and port) |
| ⌘/ | **Keyboard Shortcuts** window (also the keyboard button in the Control toolbar) |
| ⌥⌘L | **Logs** window: why phones dropped, with **Export Logs…** |
| ⌘D | **Show Display** |
| ⌘B | **Return to Board** (on a clue) |
| ⌘⇧B | **Buzzers** popover (when buzzers are on) |
| ⌘J | Show / hide the buzzer **join screen** on the Display (mid-game, when buzzers are on) |
| ⌘F | **Final Macpardy** (from the board) |
| ⌘→ | **Next Round** (from the board) |
| ⌘← | Reset the timer |
| ⌘− / ⌘+ | Timer −5 s / +5 s |

Everything except the start screen and editor ones is in the **Game** menu, which greys out items that don't apply. Where each one applies: [docs/features.md §7](docs/features.md#7-keyboard-shortcuts).

## Quick start

Requires macOS 26.3+, Xcode 26, and [Tuist](https://tuist.io).

```sh
tuist generate   # generates and opens Macpardy.xcodeproj
```

Run the **Macpardy** scheme. To make a shareable build, see [EXPORTING.md](EXPORTING.md).

## Docs

| | |
|---|---|
| [AGENTS.md](AGENTS.md) | Build, test, conventions, and workflow for contributors and coding agents |
| [docs/features.md](docs/features.md) | What the app does and how a game flows |
| [docs/architecture.md](docs/architecture.md) | State, windows, phases, persistence, buzzer subsystem |
| [docs/file-structure.md](docs/file-structure.md) | Where everything lives |
| [docs/board-format.md](docs/board-format.md) | Board file formats |
| [docs/csv-import.md](docs/csv-import.md) | Creating a game from CSV |
| [docs/buzzer-protocol.md](docs/buzzer-protocol.md) | Phone ⇄ app WebSocket protocol |
