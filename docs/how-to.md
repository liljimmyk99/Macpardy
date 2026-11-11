# How-to recipes

Step-by-step recipes for common changes. The conventions behind them are in
[AGENTS.md](../AGENTS.md); where files live is in [file-structure.md](file-structure.md).

After any recipe that adds, moves or deletes files, run `tuist generate --no-open`, then run
the tests (see [getting-started.md](getting-started.md#test)).

## Add a screen or subview

1. Create a folder per screen under `Macpardy/Views/`:
   ```
   SomeView/
     SomeView.swift              # the struct, its state, a short `body`
     Components/                 # subviews used only by this screen
     Extensions/SomeView+Extension.swift
   ```
   Shared pieces go in `Views/Shared/`.
2. Take colors and fonts from `MacpardyTheme`, never literals.
3. Use `LoggedButton` / `.onLoggedTapGesture` instead of `Button` / `.onTapGesture`, with a
   location such as `"Control › Timer › Pause"`. Add `.logPresentation(_:isPresented:)` to
   sheets, alerts, popovers and file pickers, and `.logCommit(_:text:)` to text fields.
4. If it's a new window, register the scene in `App/MacpardyApp.swift` with
   `.restorationBehavior(.disabled)` like the others
   ([architecture.md](architecture.md#windows-scenes)).

## Add a localized string

1. Add the key to `Macpardy/Localizable.xcstrings`, scoped by screen:
   `control.question.button.reveal_answer`, shared ones under `common.*`.
2. Use it as a `LocalizedStringKey` in views or `String(localized:)` in code.
3. English only for now; never hardcode user-facing English. Log text is the exception
   (developer English, not localized).

## Add a color

Add a color set in `Macpardy/Assets.xcassets` (`Theme/` or `Team/`), re-run `tuist generate`
so `MacpardyAsset` picks it up, then expose it on `MacpardyTheme`.

## Add a setting

1. Add a key, default and clamped accessor in `Services/AppSettings.swift`
   (see how `questionTimerSeconds` clamps stored values).
2. Add the control under `Views/Settings/SettingsView/` (a component in `Components/`).
3. Add `settings.*` strings and log the change with `log.change("Type.field", from:, to:)`.
4. Document it in [features.md §6b](features.md#6b-settings) and test the clamping in
   `MacpardyTests/`, injecting a throwaway `UserDefaults`.

## Add or change a keyboard shortcut

1. Define it once in `App/Commands/ShortcutCatalog.swift` (`AppShortcut`); menu items and
   buttons read from there so two actions can't collide.
2. Wire the menu item in `App/Commands/` (`GameCommands`, `FileCommands`, ...), passing
   `source: .menu` to the logged button.
3. Update the shortcut tables in [features.md §7](features.md#7-keyboard-shortcuts) **and** the
   table in [README.md](../README.md#keyboard-shortcuts).

## Add or replace a sound

- Replace a sound: drop a `.wav` with the same name into `Macpardy/Resources/Sounds/`.
- Add a sound: add a case to `SoundEffect` in `Services/Sound/SoundEffect.swift` (the raw value is the
  file name), add the `.wav`, and trigger it from a `SoundCue` or call site.
  Update [sounds.md](sounds.md).

## Change a saved file format

Boards and auto-saves outlive app versions, so this is a contract
([AGENTS.md](../AGENTS.md#file-formats-are-a-contract)).

1. Add new fields as optional or defaulted so old files still load.
2. Bump `BoardPackage.formatVersion` or `GameSnapshot.currentSchemaVersion` only for a
   breaking change.
3. Add a test that loads an old-format fixture.
4. Update [board-format.md](board-format.md) in the same PR.

## Change the buzzer protocol or phone page

1. The rules live in the `BuzzerCore` package in the
   [Macpardy-Buzzer-Server](https://github.com/liljimmyk99/Macpardy-Buzzer-Server) repo; the
   phone page `buzzer.html` is there too. Change and test them there (`swift test`).
2. Release the package with its **Release** workflow, then bump the pinned version in
   `Project.swift`.
3. New game commands go on `BuzzerBackend`, and state a fresh server needs goes in
   `BuzzerState.resync()`. Test `BuzzerState` with `FakeBuzzerBackend`.
4. Update [buzzer-protocol.md](buzzer-protocol.md) in the same change. Bump
   `BuzzerConstants.protocolVersion` or `BuzzerHostConstants.hostProtocolVersion` only for
   breaking changes.

## Add a new CSV column or import rule

Follow [csv-import.md](csv-import.md); update the template `docs/csv-import-example.csv` and
add parser tests (`CSVBoardImporter` is a stateless enum, easy to test).

## Add a test

XCTest in `MacpardyTests/<Type>Tests.swift`, class marked `@MainActor`,
`@testable import Macpardy`. Inject time, randomness and directories instead of using the
real ones (`BuzzTieResolver`'s `randomIndex`, `GameSaveStore(baseDirectory:)`). To assert on
logging use `LogCapture.capture { … }` (Debug builds). Image fixtures: `TestImages.swift`.

## Change entitlements

Avoid it. The app is sandboxed with user-selected file read/write and network server/client
only. If a change truly needs more, call it out in the PR: `scripts/export.sh` checks the
exact set.

## Open a pull request

Branch `feat/<short-name>-<issue>` (docs-only: `docs/<short-name>`). Title and commits follow
Conventional Commits (`feat:`, `fix:`, `docs:`). Start the description with `Closes #<n>.`,
then **What changed**, behaviour changes to know about, and anything left out. Update docs in
the same PR. See [CONTRIBUTING.md](../CONTRIBUTING.md).

## Cut a release

Bump `MARKETING_VERSION` in `Project.swift` in its own PR and merge it, then run the
**Release** workflow on `master`:

```sh
gh workflow run release.yml --ref master
```

Don't create tags by hand. Details in [EXPORTING.md](../EXPORTING.md#releasing).
