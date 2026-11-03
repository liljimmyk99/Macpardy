# File structure

Where things live, and where new things should go. See [architecture.md](architecture.md) for
how the pieces fit together.

## Repository root

```
.
├── AGENTS.md                 Guide for agents/contributors: build, conventions, workflow
├── README.md                 Short overview and quick start
├── EXPORTING.md              Building a shareable .app / .dmg
├── Project.swift             Tuist manifest: targets, settings, Info.plist, ZIPFoundation
├── Config/
│   └── Macpardy.entitlements    Sandbox, user-selected files, network server + client
├── Macpardy/                App target sources and resources
├── MacpardyTests/           Unit tests (XCTest)
├── docs/                     Design and format docs
├── scripts/
│   └── export.sh             Release build, ad-hoc signing, .dmg
└── Macpardy-icon.svg         App icon source
```

Generated and ignored: `Macpardy.xcodeproj`, `Macpardy.xcworkspace`, `Derived/`,
`build/`, `derivedData/`.

## `Macpardy/` (app target)

```
Macpardy/
├── App/
│   └── MacpardyApp.swift        @main app, windows, app delegate, GameState ⇄ buzzer wiring
├── Models/                       Game data and app-wide observable state (BoardDefaults: new-board content)
│   ├── Game.swift                rounds + currentRound + teams
│   ├── MacpardyBoard.swift       one round: title, round kind, categories (+ sample board)
│   ├── MacpardyRound.swift       macpardy | doubleMacpardy | finalMacpardy
│   ├── Category.swift
│   ├── Question.swift            value, clue, response, played, Daily Double, image
│   ├── QuestionImage.swift       image path + bytes; controls whether bytes are encoded
│   ├── Team.swift                name, score, color (max 4)
│   ├── GamePhase.swift           setup, board, question, answer, dailyDouble, final…
│   ├── GameState.swift           @Observable game in progress; all game actions
│   ├── GameSnapshot.swift        Codable auto-save payload (schemaVersion)
│   └── BoardEditorSession.swift  Launch screen ⇄ editor ⇄ app handoff, unsaved-changes prompts
├── Services/                     Non-UI logic and I/O
│   ├── AppLogger.swift           AppLogger categories + MacpardyLogger facade (os.Logger + LogCenter)
│   ├── Logging/                  App-owned log (#81, see architecture.md#logging)
│   │   ├── LogEntry.swift            Level, category, one line; JSON Lines + text formats
│   │   ├── LogRingBuffer.swift       Fixed-size newest-N buffer
│   │   ├── LogCenter.swift           @Observable: live lines for the Logs window, feeds the store
│   │   ├── LogFileStore.swift        actor: one .jsonl per launch, flushing, retention
│   │   ├── LogExporter.swift         Export Logs… zip + LogArchiveDocument
│   │   └── SystemInfoReport.swift    system-info.txt
│   ├── GameTimerService.swift    GameTimer (15 s countdown)
│   ├── Sound/                    SoundEffect (sounds + phase cues), SoundPlayer (see sounds.md)
│   ├── GameSaveStore.swift       actor: auto-save read/write/clear
│   ├── FileManagerService.swift  FileDocument for boards, security-scoped reads, file names
│   ├── BoardPackage.swift        .macpardy zip + JSON read/write, UTType
│   ├── BoardLoader.swift         "Edit Board" loader → BoardDraft or LoadError
│   ├── BundledGameLibrary.swift  Lists/loads the built-in games from the app bundle
│   ├── BoardLoader+Messages.swift  Localized error text for load failures
│   ├── ImageImporter.swift       Question picture validation/downscale/re-encode
│   ├── CSVImport/
│   │   ├── CSVParser.swift           RFC 4180 reader/writer
│   │   ├── CSVBoardImporter.swift    Schema, validation, CSV → boards
│   │   ├── CSVBoardImporter+Messages.swift  Localized issue text
│   │   ├── CSVBoardTemplate.swift    Downloadable template
│   │   └── CSVImportDocuments.swift  FileDocuments for the template and JSON export
│   └── Buzzer/                   Phone buzzer server (see buzzer-protocol.md)
│       ├── BuzzerState.swift         @Observable bridge between the app and the server
│       ├── BuzzerServer.swift        actor: NWListener, HTTP + WebSocket, sessions, heartbeat
│       ├── ClientSession.swift       One connection's state and send()
│       ├── WebSocketFrameParser.swift  Frame decoding
│       ├── BuzzerMessage.swift       ServerMessage / ClientMessage JSON
│       ├── BuzzerEngine.swift        Armed / locked-out / answering rules
│       ├── BuzzTieResolver.swift     Picks the winner of near-simultaneous buzzes
│       ├── TeamClaimRegistry.swift   Which phone holds which team
│       ├── FinalWagerBook.swift      Final Macpardy wager limits and submissions
│       ├── FinalAnswerBook.swift     Final Macpardy answers typed on phones (open / locked)
│       ├── AttemptRateLimiter.swift  Join-code / claim rate limiting
│       ├── JoinCodeGenerator.swift   6-char codes without look-alike characters
│       ├── QRCodeGenerator.swift     Join URL → QR image
│       ├── DisconnectReason.swift    Why a phone was dropped; close codes; LogDuration
│       ├── PhoneDisconnectReport.swift  The phone's `diag` report on its last connection
│       ├── UserAgentSummary.swift    "Safari 18 on iOS 18.1" from a User-Agent
│       ├── LocalNetworkInterfaces.swift  The Mac's IPv4 addresses; which one phones use
│       ├── NetworkPathSummary.swift  "Wi-Fi (en0)" for Mac network-change lines
│       └── BuzzerConstants.swift     Default port, timeouts, tie window, limits, protocol version
├── Views/
│   ├── LaunchScreenView/         Start screen: Play / New Board / Edit Board tiles, resume banner
│   ├── BoardLoadErrorView.swift  Sheet listing problems with a file
│   ├── Control/                  Host-facing (Control and editor windows)
│   │   ├── ControlView/              Main host screen (see below)
│   │   ├── CreateMacpardyGameView/   Board editor window
│   │   │   ├── Models/BoardDraft.swift  Editor state, shape validation, makeBoards()
│   │   │   ├── Models/UnfilledField.swift  Fields that are empty or still default text
│   │   │   └── Components/              Draft board, tiles, question/image editors, titles
│   │   └── NewGameView/              New Game sheet: editor or CSV import
│   ├── Display/
│   │   └── PresentationView/     TV/projector screen (animated, see MacpardyMotion): board, question, answer, Daily
│   │                             Double, Final, timer, scoreboard, mid-game join screen
│   ├── Logs/
│   │   └── LogsView/             Logs window: run / category / level / team filters, search,
│   │                             follow-latest list, Export Logs… (Models/LogFilter.swift)
│   ├── Settings/                 Settings window panes
│   ├── Shortcuts/                Keyboard Shortcuts window
│   └── Shared/                   Theme, buttons, headers, image placeholder, WindowCloseGuard
├── Resources/
│   ├── Buzzer/buzzer.html        Phone buzzer page (HTML + CSS + JS in one file)
│   └── Games/*.json              Built-in games (board format; bundled as a folder)
├── Assets.xcassets               App icon, accent color, Theme/ and Team/ color sets
└── Localizable.xcstrings         All UI strings (String Catalog)
```

### `Views/Control/ControlView/`

```
ControlView/
├── ControlView.swift             Phase content + team score strip, board-blue, window toolbar
├── Extensions/                   Window title/subtitle, when the score strip shows
└── Components/
    ├── ControlViewContent.swift  Switches the content on GamePhase
    ├── ControlToolbar.swift      Buzzers, Show Display, Final Macpardy, Next Round
    ├── BuzzerStatusButton/       Toolbar button + popover: join info, join screen on Display, phone per team, remove phone
    ├── TeamScoreStripView/       Team scores along the bottom: ±100 on the board, ✓/✗ on a clue, reset via context menu
    ├── Phases/                   One folder per phase
    │   ├── SetupControlView/         Team cards (name, color swatches), buzzer join panel, Start Game
    │   ├── BoardControlView/         Host copy of the Display board; click a tile to open it
    │   ├── QuestionControlView/      Clue tile, host-only response + Reveal Answer, buzz status, timer
    │   ├── DailyDoubleControlView/   Team picker, wager input, quick wagers
    │   ├── FinalMacpardyCategoryControlView/  Wager status per team
    │   └── FinalMacpardyControlView/ Final clue/answer, Complete Game
    ├── ScoreControlsView/        Correct / wrong buttons per team; Final answers + Show on Display
    └── TimerControlsView/        Countdown ring; start/pause, reset, ±5 s
```

### View folder pattern

Every screen follows the same layout, so new UI should too:

```
SomeView/
├── SomeView.swift                The view struct, its state, a short body
├── Components/                   Subviews used only here (nested folders allowed)
├── Extensions/SomeView+Extension.swift   Computed properties and @ViewBuilder helpers
└── Models/                       (optional) view-specific value types, e.g. BoardDraft
```

## `MacpardyTests/`

One `<Type>Tests.swift` per type under test:

| File | Covers |
|---|---|
| `BoardPackageTests` | Package read/write, legacy JSON, limits, path safety |
| `BoardLoaderTests` | Edit Board loading and error locations |
| `BundledGameLibraryTests` | Every built-in game is valid; edit-copy filename; resume without the bundle |
| `CSVParserTests`, `CSVBoardImporterTests` | CSV parsing and import validation |
| `ImageImporterTests` | Formats, size limits, downscaling, re-encoding |
| `QuestionImageAutoSaveTests` | Images embedded in auto-saves |
| `SessionLifecycleTests` | Auto-save / resume / buzzer session lifecycle |
| `BuzzerEngineTests`, `BuzzTieResolverTests` | Buzz rules and tie-breaking |
| `TeamClaimRegistryTests`, `AttemptRateLimiterTests` | Team claims, rate limits |
| `FinalWagerBookTests`, `FinalWagerDefaultsTests` | Final Macpardy wagers |
| `FinalAnswerBookTests`, `FinalAnswerGameStateTests` | Final Macpardy answers from phones, Display spotlight |
| `BuzzerProtocolTests`, `WebSocketFrameParserTests` | Wire messages and frames, `join` with / without / garbage `diag` |
| `DisconnectReasonTests`, `PhoneDisconnectReportTests`, `UserAgentSummaryTests` | Disconnect reasons, close codes, durations, phone reports, browser names |
| `LocalNetworkInterfacesTests`, `BuzzerServerTests` | Join IP choice, network path text, HTTP header parsing |
| `LogRingBufferTests`, `LogFileStoreTests`, `LogFilterTests`, `LogExporterTests` | Live buffer, JSON Lines, retention, filters, export zip and system info |
| `TestImages` | Helper for building image fixtures |

## `docs/`

| File | Topic |
|---|---|
| `features.md` | What the app does, by user and game phase |
| `architecture.md` | State, windows, phases, persistence, buzzer subsystem |
| `file-structure.md` | This file |
| `board-format.md` | `.macpardy` / `.json` formats, images, auto-save, editing rules |
| `csv-import.md`, `csv-import-example.csv` | CSV layout and a complete example |
| `buzzer-protocol.md` | WebSocket protocol between `buzzer.html` and the app |

## Where new code goes

| Adding… | Put it in |
|---|---|
| A new game rule or state | `GameState` (method) + `GameSnapshot` if it must survive a resume |
| A new data field on boards | `Models/` + keep old files decoding + `board-format.md` |
| Pure logic (parsing, rules) | `Services/`, `nonisolated`, with a test in `MacpardyTests/` |
| File or network I/O | An `actor` in `Services/` |
| A host screen | `Views/Control/…` using the view folder pattern |
| An audience screen | `Views/Display/PresentationView/Components/…` |
| Something used by both | `Views/Shared/` |
| Buzzer behaviour | `Services/Buzzer/` + `buzzer.html` + `buzzer-protocol.md` |
| UI text | `Localizable.xcstrings` |
