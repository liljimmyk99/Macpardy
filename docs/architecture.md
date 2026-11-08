# Architecture

How the app is put together. For what it does, see [features.md](features.md); for where files
live, see [file-structure.md](file-structure.md).

## Big picture

```
                         ┌──────────────────────── MacpardyApp (App) ────────────────────────┐
                         │  owns:  GameState   BuzzerState   BoardEditorSession.shared       │
                         │  keeps BuzzerState in sync with GameState via .onChange(…)        │
                         └──────┬───────────────────────┬──────────────────────┬─────────────┘
                                │                       │                      │
                    Window "control"         Window "display"      Window "create-macpardy"
              LaunchScreenView → ControlView   PresentationView     CreateMacpardyGameView
                   (host)                       (TV / projector)        (board editor)
                                │
          ┌─────────────────────┼─────────────────────────────┐
          ▼                     ▼                             ▼
   Board files            GameSaveStore (actor)          BuzzerServer (actor)
   BoardPackage           Application Support/           Network.framework, default port 8472
   BoardLoader            saved_game.json                HTTP GET / → buzzer.html
   CSVBoardImporter                                      WebSocket /ws ⇄ phones
   ImageImporter                                         BuzzerRoom (actor): the rules
```

Everything runs in one process on the host's Mac. There is no backend, and the app never
opens outgoing connections.

## Windows (scenes)

Defined in `App/MacpardyApp.swift`:

| Window id | Default | Content |
|---|---|---|
| `control` | Opens at launch | `LaunchScreenView` until a game is chosen (`hasSelectedGame`), then `ControlView` |
| `display` | Suppressed; opened with Show Display (⌘D), also from the launch screen | `PresentationView` while a game is loaded, otherwise `WaitingForGameView` |
| `create-macpardy` | Suppressed; opened from New Game / Edit | `CreateMacpardyGameView` |
| `shortcuts` | Suppressed; Help > Keyboard Shortcuts | `KeyboardShortcutsView` |
| `logs` | Suppressed; Help > Show Logs, Buzzers popover > View Logs | `LogsView` (see [Logging](#logging)) |

Only `control` opens at launch: the other windows are `.restorationBehavior(.disabled)`, so
they never reappear from a previous session. Closing the Control window quits the app
(`MacpardyAppDelegate.controlWindow`), which closes every other window.

`MacpardyAppDelegate` intercepts quit (`applicationShouldTerminate`) so the editor can ask
to save unsaved edits. `Views/Shared/WindowCloseGuard` does the same for closing the editor
window, since SwiftUI has no close hook outside document apps.

## Menu commands

Keyboard shortcuts are defined once, in `App/Commands/ShortcutCatalog.swift` (`AppShortcut`),
and applied with `.keyboardShortcut(_ shortcut: AppShortcut)`; don't write raw
`.keyboardShortcut("x", …)` calls (Return/Esc via `.defaultAction` / `.cancelAction` are fine).
`ShortcutCatalogTests` fails if two shortcuts share a key or one takes a reserved system key.
The catalog also lists the system's own shortcuts (⌘, ⌃⌘F ⌘Z …, `isSystemProvided`) so the
Keyboard Shortcuts window (`Views/Shortcuts`, opened by `HelpCommands` and a toolbar button) is
complete; those are never bound with `.keyboardShortcut`. `ShortcutFormatter` draws the glyphs,
and `ShortcutGroups` orders the window. Adding a catalog entry adds it to the window.

`GameCommands` (the **Game** menu, attached to the Control window scene with `.commands`) calls
the same `GameState` methods as the on-screen buttons. Which items apply in a phase comes from
`GameCommandAvailability`, which `ControlToolbar` also reads. Each shortcut belongs either to a
menu item or to a button, never both. The Buzzers popover's open state is
`BuzzerState.isPopoverPresented` so the menu can open it.

`FileCommands` (the **File** menu) drives `BoardOpenCoordinator`, an `@Observable` created in
`MacpardyApp`. The coordinator owns the import picker, the Play / Edit choice, the "end the
current game?" and "replace editor changes?" confirmations, and the load-error sheet. They are
presented at the root of the Control window by `BoardOpenDialogs`, so they work on the start
screen and mid-game. `RecentBoards` keeps Open Recent in `NSDocumentController` (so the sandbox
remembers access to each file), behind a small storage protocol for tests.

## Undo / redo

Each window has its own `UndoManager` (SwiftUI's `\.undoManager`), and the standard Edit menu
shows its steps. The editor's `EditorUndoController` (`CreateMacpardyGameView/Models`) watches
`currentDraft`; `EditorUndoHistory` is the pure part that names a change (`EditorChange`) and
decides whether it continues the previous step (same field, within 1 s). An undo applies the
saved `BoardDraft` back to the editor's `@State`, and the history ignores the resulting change.
`EditorUndoController.registersTypingSteps` turns off text steps if a focused field's own typing
undo ever stacks up with them. In the Control window, `GameState.setScore` is the only place
scores change and registers the inverse on `scoreUndoManager`, which `ControlView` sets.

## State

### `GameState` (`Models/GameState.swift`)
The single source of truth for a game in progress. `@Observable`, main-actor, injected with
`.environment(gameState)` into the Control and Display windows.

- `game: Game` — the rounds (`[MacpardyBoard]`), `currentRound`, and `teams`.
- `phase: GamePhase` — which screen is up (see below).
- Per-clue state: `currentQuestion`, `currentCategoryTitle`, `dailyDoubleTeamID`,
  `dailyDoubleWager`, `finalMacpardyWagers`, `finalMacpardyAnswers` (typed on phones, #80),
  `finalMacpardyRevealedTeamID` (the team spotlighted on the Display), and a `GameTimer` (15 s).
- Buzz-in response (#59): `answeringTeamID` and a second `GameTimer`, `responseTimer`
  (`GameState.responseSeconds`, 5 s). `teamBuzzedIn(_:)` pauses the question timer and starts
  the response timer; `judgeResponse(teamID:isCorrect:)` ends it and, on wrong, resumes the
  question timer. Phase changes call `cancelResponse()`. `responseCountdown` is what the
  screens draw. None of this is auto-saved.
- All game actions are methods on `GameState` (`selectQuestion`, `revealAnswer`,
  `adjustScore`, `advanceRound`, `setFinalWager`, …). Views call these; they don't mutate
  `game` directly. Each action ends with `triggerSave()`.

### Data model (`Models/`)

```
Game
 ├─ rounds: [MacpardyBoard]        id, title (round title), round: MacpardyRound
 │    └─ categories: [Category]    id, title
 │         └─ questions: [Question] id, value, clue, response,
 │                                  hasBeenPlayed, isDailyDouble, image: QuestionImage?
 ├─ currentRound: Int
 └─ teams: [Team]                   id, name, score, color   (max 4)
```

`MacpardyRound` is `macpardy | doubleMacpardy | finalMacpardy`. A board file's game title is
stored next to the boards, not on them (see [board-format.md](board-format.md)).

### Game phases (`Models/GamePhase.swift`)

```
 setup ──startGame──▶ board ──selectQuestion──▶ question ──revealAnswer──▶ answer
                       ▲  │                        ▲                         │
                       │  └──(Daily Double)──▶ dailyDouble ─submitWager─┘    │
                       └────────────────────── showBoard ◀───────────────────┘

 board ──advanceRound (next is Final)──▶ finalMacpardyCategory  (phones wager)
        ──revealFinalMacpardyQuestion──▶ finalMacpardyQuestion  (phones answer)
        ──revealAnswer──▶ finalMacpardyAnswer  (answers locked; host spotlights teams)
        ──Complete Game──▶ endGame() → setup, then back to the launch screen
```

**Complete Game** goes through the `\.completeGame` environment action that `MacpardyApp`
gives the Control window: `GameState.endGame()` (stops timers, cancels a pending save,
returns to `setup`), `hasSelectedGame = false`, then the save is cleared. With no game
selected the Display window shows `WaitingForGameView` instead of `PresentationView`.

Both the Control detail pane (`ControlView+Extension`, `ControlViewContent`) and the Display
(`PresentationView+Extension.phaseContent`) switch on `phase`. Adding a phase means updating
both switches, the localized phase names, and `MacpardyApp.buzzerMode`.

### `BoardEditorSession` (`Models/BoardEditorSession.swift`)
A shared `@Observable` mailbox between the launch screen, the editor window, and the app:
a loaded `BoardDraft` waiting to be edited, boards the user chose to **Play Now**, and
"save before closing?" requests. It's a singleton because the app delegate needs it on quit.

The editor's own state is `BoardDraft` (`Views/Control/CreateMacpardyGameView/Models/`),
a plain value type. `BoardDraft(boards:…)` loads a board into it (validating the 6 × 5 shape)
and `makeBoards()` turns it back into `[MacpardyBoard]`.

## Board files

| Type | Role |
|---|---|
| `BoardPackage` | Read/write `.macpardy` zip packages (`board.json` + `images/`), plain format-2 JSON, and legacy format-1 JSON. Guards against zip bombs and path traversal. |
| `MacpardyBoardsDocument`, `MacpardyJSONBoardDocument` | SwiftUI `FileDocument`s used by save panels |
| `FileManagerService` | Security-scoped reads of user-picked files, default file names |
| `BoardLoader` | "Edit Board": picks a reader by extension (`.json`, `.macpardy`/`.zip`, `.csv`), returns a `BoardDraft` or a `LoadError` that pinpoints the problem |
| `CSVBoardImporter`, `CSVParser`, `CSVBoardTemplate` | CSV → boards, collecting every issue with its row/column |
| `ImageImporter` | Validates, downscales, and re-encodes question pictures |

Formats and limits: [board-format.md](board-format.md), [csv-import.md](csv-import.md).

## Persistence (auto-save)

```
GameState action ─▶ triggerSave() ─▶ GameSnapshot(from: self)
                                        │  debounce 300 ms (cancel previous Task)
                                        ▼
                         GameSaveStore.shared.save(snapshot)   (actor; atomic write)
                         Application Support/Macpardy/saved_game.json
```

- Nothing is saved during `setup`.
- `GameSnapshot` carries `schemaVersion`; a mismatched or corrupt save is discarded on load.
- Pictures are embedded as base64, so a resumed game doesn't need the original board file.
- "Play" checks for a save first and offers to resume (`GameState.restore`).
- **Complete Game** clears the save.

## Phone buzzers

Code: the rules are in the `BuzzerCore` package (`Packages/MacpardyBuzzer`), centred on
`BuzzerRoom`; the Network.framework transport and the app bridge are in `Services/Buzzer/`.
Protocol: [buzzer-protocol.md](buzzer-protocol.md).

```
 MacpardyApp ──syncTeams / syncScores / setMode / openWagering / setAnswering──▶ BuzzerState (@Observable, main actor)
      ▲                                                                │ keeps the latest state; resync() after start
      │  onWagerSubmitted, onAnswerSubmitted, firstBuzzTeamID,         ▼
      │  claimed/disconnected teams                    BuzzerBackend (protocol): start → PIN + URLs + events, stop, commands
      │                                                                │
      │                                  EmbeddedBuzzerBackend (built-in): local IP, port setting, PIN, NWPathMonitor
      │                                                                │ owns both
      │                                  ┌──────────────── BuzzerServer (actor, transport, default :8472)
      │                                  │                   NWListener, HTTP, WebSocket handshake + frames
      │                                  │                   └─ ClientSession per connection (a BuzzerConnection)
      │                                  │ connect / receive(text:) / disconnect(reason:)      ▲ send / close
      │                                  ▼                                                     │
      └──── BuzzerRoomEvent stream ◀── BuzzerRoom (actor, BuzzerCore, no I/O) ─────────────────┘
                                          │  BuzzerScheduler: clock + heartbeat / tie-window timers
                                          ├─ TeamClaimRegistry   who holds which team
                                          ├─ BuzzerEngine        armed/locked-out/answering
                                          │    └─ BuzzTieResolver  75 ms window, low score wins
                                          ├─ FinalWagerBook      Final wagers & limits
                                          ├─ FinalAnswerBook     Final answers (open / locked)
                                          └─ AttemptRateLimiter  join code / claim / uiEvent attempts
```

- **Server lifecycle:** started when a game is selected, stopped when the app returns to the
  launch screen (including after Complete Game), restarted (new join code) on resume.
  `startServer()` does nothing while `AppSettings.buzzersEnabled()` is off, and `MacpardyApp`
  starts / stops the server when the setting changes during a game. Stopping sends
  `sessionEnded` to joined phones first so they return to their Game PIN screen.
- **Backends (#102):** `BuzzerState` doesn't know where the server runs. It talks to a
  `BuzzerBackend`: `start()` returns a `BuzzerBackendSession` (Game PIN, bare page address
  `baseURL` shown as text, join link with `?code=` for the QR code and Copy, and the
  `BuzzerRoomEvent` stream), `stop()`, and one method per game command. `BuzzerState` keeps
  the game's latest teams, scores, mode, Final wagering and answering, and after a start
  replays them with `resync()` (a self-hosted server will reuse it when the Mac reconnects,
  #104). `EmbeddedBuzzerBackend` is the built-in server: it picks the Mac's local IPv4
  address, reads the port from Settings, generates the Game PIN, owns the `BuzzerRoom` and
  `BuzzerServer`, and runs the `NWPathMonitor`. Start errors are `BuzzerBackendError`s whose
  text becomes `startError`. Tests drive `BuzzerState` with `FakeBuzzerBackend`.
- **Join screen (#83):** `BuzzerState.isJoinScreenOnDisplay` puts the setup screen's join
  panel (`PresentationView.buzzerJoinContent()`) over any later phase on the Display. It's UI
  state, never saved; `MacpardyApp` clears it on every phase change and `stopServer()` clears
  it too. `GameCommandAvailability.canShowJoinScreen` gates the popover button and ⌘J.
- **App → server:** `MacpardyApp` watches `GameState` and pushes teams, scores, the buzzer
  mode (`armed` on a normal question, `unavailable` on Daily Double, `disabled` otherwise), and
  Final wagering open/closed (open exactly while `phase == .finalMacpardyCategory`), and
  Final answering (`GameState.finalAnswerWindow`: open on `.finalMacpardyQuestion` while the
  timer has time left, locked once `GameTimer.isExpired` or on `.finalMacpardyAnswer`, closed
  otherwise; synced whenever that value changes).
  It also forwards `BuzzerState.firstBuzzTeamID` to `GameState.teamBuzzedIn`, and sends the
  response timer's start / stop to the phones when `answeringTeamID` changes (the phones
  count down themselves).
- **Room → app:** one ordered `BuzzerRoomEvent` stream (claimed teams, first buzz, wager and
  answer submissions, joined-phone count, transport failure), surfaced as `BuzzerState`
  properties. The same events will travel over the host protocol to a self-hosted server (#104).
- **Host actions:** score buttons call `GameState.judgeResponse` and then
  `teamAnsweredWrong` / `teamAnsweredCorrect` on normal clues; the toolbar's Buzzers popover can remove a team's phone.
- **Rules are separated from I/O (#100, #101):** `BuzzerRoom` (an actor in `BuzzerCore`) holds
  a game's phones and every rule: the Game PIN and protocol version check with rate limits,
  team claims and restoring a returning `device`, the heartbeat ping and TTL eviction, buzzes
  and the tie window, the response timer, Final wagers and answers, `uiEvent` and `diag`
  logging, and `sessionEnded` on stop. It talks to phones only through `BuzzerConnection`
  (send a `ServerMessage`, close with a `DisconnectReason`, remote key, User-Agent) and reads
  time and schedules timers through an injected `BuzzerScheduler`, so `BuzzerRoomTests` use
  fake phones and a test clock. The join code is passed in. `BuzzerServer` is only the
  transport: the listener, HTTP and `buzzer.html`, the WebSocket handshake and frames, mapping
  Network.framework errors to a `DisconnectReason`, and the App Nap / idle-sleep activity. It
  hands the room each text message and reports why a connection ended. The value types
  (`BuzzerEngine`, `TeamClaimRegistry`, the books, `AttemptRateLimiter`,
  `WebSocketFrameParser`, the messages) are in the package too, all `public` and `Sendable`
  with no `MainActor` isolation, tested with `swift test`. #102 put a `BuzzerBackend`
  in front of the room so the app can also use a self-hosted server (#99).
- Constants (default port, heartbeat, tie window, rate limits, protocol version) are in
  `BuzzerConstants`, in the package. `AppSettings.defaultBuzzerPort` reads the default port from
  it; the port the host picked in Settings comes from `AppSettings.buzzerPort()`.
- **Package logging:** `BuzzerCore` can't use `AppLogger` (or OSLog, which isn't on Linux).
  Package code logs through the `BuzzerLogging` protocol: a level, the message, a kind
  (`plain`, `state`, `phone`) that becomes the verbose-log prefix, and `team:` / `remote:`.
  Helpers mirror `MacpardyLogger` (`info`, `state`, `phone`, `change`, …). The app passes
  `AppBuzzerLogger`, which forwards to `AppLogger.buzzer`, so those lines reach the Logs
  window with their filters. The content rules are the same.
- **Diagnostics (#81):** every path that drops a phone ends in the room's `removeSession` with
  a `DisconnectReason` (the transport passes its own through `disconnect(_:reason:)`), which
  logs one line: team (or IP), a 4-character id from the connection UUID, connected time and
  reason (close code, `NWError`, seconds since the last pong, …). The room keeps each phone's
  User-Agent (`UserAgentSummary` shortens it) and the last team it held. A phone's `join` may carry `PhoneDisconnectReport` (`diag`), logged as a
  "Phone report" line. While the server runs, `EmbeddedBuzzerBackend` runs an `NWPathMonitor` and logs
  Mac network changes (`NetworkPathSummary`); `LocalNetworkInterfaces` picks the join IP and
  lists every candidate when none is usable.
- The phone UI is a single self-contained page, `Resources/Buzzer/buzzer.html`, served from
  the app bundle.

## Logging

```
 AppLogger.buzzer.info("…", team:, remote:)      (MacpardyLogger, nonisolated, any thread)
      ├─▶ os.Logger  "\(message, privacy: .public)"   → Console.app
      └─▶ LogCenter.submit(LogEntry)  ── two AsyncStreams ──┐
                                                            ├─▶ LogCenter (@Observable, main actor)
                                                            │     ring buffer, last 5,000 lines → Logs window (live)
                                                            └─▶ LogFileStore (actor, detached consumer, in order)
                                                                  Application Support/Macpardy/Logs/
                                                                  macpardy-<launch, ISO 8601 basic>.jsonl
```

- **Facade:** `AppLogger.control/display/database/buzzer/network` are `MacpardyLogger`s with
  `debug/info/notice/warning/error(_:team:remote:)`. Messages are plain strings, written
  unredacted: the log never leaves the Mac unless the user exports it.
- **`LogEntry`** (`Services/Logging/`): id, date (ms), level, category, message, optional team
  and IP. Stored as JSON Lines; unreadable lines are skipped when reading.
- **`LogCenter`** starts in `MacpardyApp.init` and drains the streams. Lines logged before that
  wait in the streams (bounded).
- **`LogFileStore`** appends through a `FileHandle`, batching and flushing at most about once a
  second (immediately past 64 KB). `MacpardyAppDelegate.applicationWillTerminate` flushes,
  waiting at most 0.5 s. It never logs through `AppLogger` (that would loop).
- **Retention:** at launch, earlier runs are pruned oldest first to 9 files and 15 MB, leaving
  room for the new run (one file, capped at 5 MB), so the folder stays within 10 runs / 20 MB.
  Empty earlier runs are always deleted.
- **Viewer:** `Views/Logs/LogsView` reads `LogCenter.entries` live, or an earlier run through
  `LogFileStore.readRun`. `LogFilter` (category, minimum level, team, search) is a pure value
  with tests; it defaults to Buzzer, Info and above.
- **Export:** `LogExporter.makeArchive` zips each run as readable `logs/*.log` and raw
  `raw/*.jsonl` plus `system-info.txt` (`SystemInfoReport`), off the main actor. The view saves
  it with `.fileExporter` (`LogArchiveDocument`). Nothing is uploaded.

### Verbose log

Issue #87 makes a run reconstructable from its log alone. On top of the `info`-and-up lines
above, every user action and state change gets a `.debug` line. There is no setting: the Logs
window's level filter starts at Info, so these stay hidden until it's lowered to Debug, but
they are always written to the run file and included in exports. They reuse the existing
categories (Display window → `display`; Control, editor, Settings, menus, lifecycle →
`control`; buzzer models and phones → `buzzer`; save/load → `storage`) and start with a
searchable prefix:

| Prefix | Logged by | Example |
|---|---|---|
| `tap:` | `LoggedButton`, `.onLoggedTapGesture` | `tap: Control › Score strip › Team 2 'Blue' Correct +400` |
| `menu:` | `LoggedButton(…, source: .menu)` in `App/Commands` | `menu: Game › Reveal answer` |
| `shortcut:` | the same buttons when a key press triggered them (`NSApp.currentEvent`), board arrow keys | `shortcut: ⌘R Game › Reveal answer` |
| `nav:` | `.logPresentation`, file picker results (`UIActionLog.filePicked`), Settings tabs | `nav: alert 'Save changes?' presented` |
| `app:` | `MacpardyApp`, `MacpardyAppDelegate`, `.logWindowLifecycle` | `app: scenePhase active → inactive` |
| `state:` | the models, `MacpardyLogger.change` / `.state` | `state: Team 2 'Blue' score: 400 → 800 (+400, correct)` |
| `phone:` | `BuzzerRoom` (every inbound message but `pong`, and `uiEvent`) | `phone: Blue (10.0.0.4 #a1b2): buzz` |

- **Helpers** (`Services/Logging/VerboseLogging.swift`): `MacpardyLogger.change(_:from:to:reason:team:)`
  logs `state: <field>: <old> → <new> (<reason>)` and nothing when the value didn't change.
  `LogDescribable` gives models a safe one-line form (`Question` → `$400 DD #1A2B3C4D`, never
  its text); `LogLabel` passes text that is already formatted. View helpers live in
  `Views/Shared/Logging/`.
- **Models** log where the change happens: `GameState` (phase, clue as
  `R1 · 'Rivers' · $400 (C1 row 2)`, scores with a `ScoreReason`, Daily Double, Final wagers and
  answer lengths, teams, round), `GameTimer` (start, pause, resume, reset, ±time, expiry; never
  a tick), `BuzzerState`, `BoardEditorSession`, `EditorUndoController` (edit location such as
  `editClue r1.c1.q2.clue`, undo, redo), `SoundPlayer`, `RecentBoards`, `BoardOpenCoordinator`
  and `GameSaveStore`. `SettingsChangeLog` diffs the Settings values on every `UserDefaults`
  change, as `state: AppSettings.<name>: old → new`.
- **Content rule:** IDs, titles, team names, scores, wagers and file names only. Clue text,
  answer text, typed editor text and Final answers are never logged; text fields log their
  length when committed (`.logCommit`: Return, focus loss, or going away), never per keystroke.
- **Tests:** `LogCapture.capture { … }` (Debug builds only) collects what was logged inside the
  closure through a `TaskLocal` checked in `LogCenter.submit`. `LogVolumeTests` plays a scripted
  4-team game: about 1,700 lines and 320 KB, well under the 5 MB run cap.
- **Guardrail:** the `unlogged_tap` SwiftLint rule flags a bare `Button` or `.onTapGesture` in
  `Views/` (except `Views/Logs/`, which is exempt so filtering logs doesn't spam them).

## Cross-cutting

- **Concurrency:** default isolation is `MainActor`; pure logic is `nonisolated`; I/O lives
  in actors. See [AGENTS.md](../AGENTS.md#conventions).
- **Localization:** String Catalog `Localizable.xcstrings`, dotted keys per screen.
- **Logging:** `AppLogger` categories `control`, `display`, `database` (Storage), `buzzer`,
  `network`; see [Logging](#logging).
- **Sandbox:** user-selected file read/write and network server + client. The client
  entitlement is only for accepting buzzer connections (see
  [buzzer-protocol.md](buzzer-protocol.md#sandbox-entitlements)).
- **Build:** Tuist (`Project.swift`) generates the Xcode project; `scripts/export.sh` makes
  a shareable build.
