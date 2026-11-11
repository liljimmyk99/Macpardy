# Getting started

Build, run and test Macpardy, then play a first game. For what the app does see
[features.md](features.md); for how it's built see [architecture.md](architecture.md).

## Prerequisites

- macOS with **Xcode 26** (the macOS 26.3 SDK). The app targets macOS 26.3+.
- [Tuist](https://tuist.io). CI pins 4.50.2 (`.github/actions/setup-build/action.yml`); use the
  same version locally if you hit generation differences.
- Optional: `swiftlint`. When installed, a build phase enforces the logging rule in
  [`.swiftlint.yml`](../.swiftlint.yml) (see [AGENTS.md](../AGENTS.md#logging)).

## Build and run

```sh
tuist generate            # creates Macpardy.xcodeproj and opens it
tuist generate --no-open  # same, without opening Xcode
```

Run the **Macpardy** scheme in Xcode (⌘R). `Macpardy.xcodeproj` and `.xcworkspace` are
generated and git-ignored: never edit or commit them. Re-run `tuist generate` after you add,
move or delete files, since sources are picked up by glob.

Dependencies (ZIPFoundation, and the `BuzzerCore` package from the
[Macpardy-Buzzer-Server](https://github.com/liljimmyk99/Macpardy-Buzzer-Server) repo) are
declared in `Project.swift` and resolved by Tuist/Xcode.

## Test

```sh
xcodebuild test \
  -project Macpardy.xcodeproj \
  -scheme Macpardy \
  -destination 'platform=macOS'
```

Tests live in `MacpardyTests/`, one file per type. Tests for the buzzer rules live in the
buzzer repo and run there with `swift test`.

## Make a shareable build

```sh
./scripts/export.sh   # ad-hoc signed .app and .dmg in build/exports/
```

See [EXPORTING.md](../EXPORTING.md), including how releases are cut.

## Play a first game

1. Launch the app. The **Control** window opens on the start screen.
2. Pick a built-in game, or **New Board** to build one, or **Import Board…** (⌘O) for a
   `.macpardy`, `.json` or `.csv` file ([csv-import.md](csv-import.md)).
3. Press **Show Display** (⌘D) and drag the Display window to the TV or projector.
4. For phone buzzers, make sure the Mac and phones share a network, then open the Buzzers
   popover (⌘⇧B) or the join screen (⌘J) and have teams scan the QR code.
   No phones? Turn buzzers off in Settings (⌘,).
5. Click a clue (or use the arrow keys and Return), start the timer (⌘T), reveal the answer
   (⌘R), and score teams. Continue to the next round (⌘→) and Final Macpardy (⌘F).

Games auto-save, so after a quit or crash the start screen offers to resume
([architecture.md](architecture.md#persistence-auto-save)).

## Where to go next

- Changing something? [how-to.md](how-to.md) has recipes for the common changes.
- Something broken? [troubleshooting.md](troubleshooting.md).
- Where does a thing live? [file-structure.md](file-structure.md).
