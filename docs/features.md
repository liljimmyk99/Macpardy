# Features and use cases

What Macpardy does, from the point of view of the people using it. For how it's built, see
[architecture.md](architecture.md).

## Who uses it

| Person | Where | What they do |
|---|---|---|
| **Host** | Control window on their Mac | Builds or loads a game, runs it, keeps score |
| **Audience / contestants** | Display window on a TV or projector | Watch the board, clues, answers, and scores |
| **Teams (optional)** | Phone browser | Join a team, buzz in, submit Final Macpardy wagers |

A game is three rounds, like the TV show: **Macpardy** (6 categories × 5 clues),
**Double Macpardy** (6 × 5), and **Final Macpardy** (one clue). Up to 4 teams play.

## 1. Getting a game

The start screen (Control window) uses the board's look: three tiles styled like board
columns — **Play**, **New Board**, and **Edit Board**. (The tiles are click-only; their
shortcuts live in the **File** menu — see below.) If an auto-saved game
exists, a banner below them shows its round and team count with **Resume** and **Discard**
(Discard asks first).

### Play
- Opens a picker listing the **built-in games** by title, with **Load my own file…** at the
  bottom. Picking a built-in starts it the same way a loaded file does; **Load my own file…**
  opens the file panel for a `.macpardy` package or a `.json` board.
- If an auto-saved game exists, the app first asks: **Resume** it, start a **New Game**
  (discards the save, then shows the picker), or cancel.
- Double-clicking a `.macpardy` file in Finder goes through the same flow as **File > Import
  Board…** (see "File menu" below).

### File menu
Boards can be opened from the menu bar at any time, on the start screen or during a game:

- **New Board** (⌘N) opens the editor with a fresh board.
- **Import Board…** (⌘O) picks a `.macpardy`, `.json`, `.zip`, or `.csv` file.
- **Open Recent** lists the last 10 boards (file names, newest first) with **Clear Menu** at the
  bottom; it shows a disabled "No Recent Boards" when empty. A file that is missing or can't be
  read shows the normal load error and is removed from the list. Boards are added to the list
  when played, edited, or saved from the editor.

After a file is picked (Import, Open Recent, or Finder) the app asks **Play**, **Edit**, or Cancel:

- **Edit** opens it in the editor and never touches a running game. If the editor has unsaved
  changes, the app asks before replacing them.
- **Play** with no game running starts it.
- **Play** during a game asks "End the current game and open this board?" On confirm, the
  buzzer server and sounds stop (as when leaving a game) and the new game starts. Auto-save keeps
  a single slot: the ended game can be resumed only until the new game moves past setup.

### New Board
A sheet with two options:
- **Build in the editor** — opens the *Create Macpardy Game* window (see §2).
- **Import from CSV** — download a template, fill it in a spreadsheet, upload it. Valid files
  are saved as a `.json` board and the game starts. Every problem is listed by row and column;
  nothing is partly imported. Details: [csv-import.md](csv-import.md).

### Built-in games
- Three complete, text-only games ship in the app (`Resources/Games/*.json`), in the same
  format as user boards and loaded through the same parser (`BoardLoader`). A unit test
  checks that every one is valid (6 × 5 rounds, 1 + 2 Daily Doubles, a Final clue).
- Built-in content is English only and isn't localized.

### Edit Board
- Shows the same picker: built-in games first, then **Load my own file…**. A built-in opens as a
  **copy** (suggested name `<Game Title> copy.json`); saving always asks where to put a new
  file, so the bundled originals are never changed.
- Opens a `.json`, `.macpardy` / `.zip`, or `.csv` board in the same editor as New Game,
  pre-filled.
- A file that doesn't fit the editor (not 6 × 5, missing Final, broken JSON, …) shows a sheet
  listing each problem and where it is; the user stays on the start screen.

## 2. Building and editing a board (editor window)

- A new game starts **fully filled with default text** (`Untitled Game`, `Round 1`/`Round 2`,
  `Category N`, `Category N · $VALUE question`/`answer`, a Final Jeopardy category/question/answer),
  standard values (200–1000 / 400–2000), and Daily Doubles pre-placed (1 in Round 1, 2 in
  Round 2). It is valid and playable as is.
- Fields that are empty or still hold their default text get a dashed outline and an icon, live
  as you type, and the bottom bar shows a running count. **Save** (also from the close/quit
  prompt) warns first with the count and where the fields are: **Keep Editing** or
  **Save Anyway**. It never blocks.
- Game title, plus a title per round (blank = the round's default name).
- 6 categories × 5 clues per round with editable point values; one Final Macpardy category
  and clue.
- Per clue: clue text, correct response, **Daily Double** toggle, and an optional **picture**
  (PNG, JPEG, HEIC, GIF, TIFF, BMP, WebP; up to 25 MB, downscaled to 1920 px).
- Tiles show whether a clue is complete, incomplete, or has an image.
- **Save**: new games are always saved as a `.macpardy` package. Edited games save as `.json`,
  or `.macpardy` if any clue has a picture. After saving, the host can **Play Now**
  (new games too).
- When editing an existing board, closing the window or quitting the app with unsaved changes
  asks **Save… / Don't Save / Cancel**.

## 3. Running a game (Control + Display)

The Control window uses the Display's board look. Its toolbar shows the round title and
progress, a **Buzzers** button (hidden when buzzers are off in Settings), **Show Display**, and on the board **Final Macpardy** and
**Next Round**. On the board phase the host picks clues from a copy of the Display board; Daily
Doubles (a gold **DD** badge) and clues with pictures are marked for the host only. The arrow
keys move a gold highlight over the open tiles (played ones are skipped) and Return or Space opens
the highlighted clue; pointing at a tile with the mouse moves the highlight too. The highlight
shows on the Display as well, so the room can see which clue is coming. Team scores
run along the bottom with ±100 buttons (right-click a team to reset its score).

The **Buzzers** button shows the Game PIN and how many teams have a phone; its dot turns orange
when a phone stops responding. It opens a popover with the QR code, Game PIN, the page address
(the copy button copies the full link with the PIN), and
each team's phone status with **Remove phone**. **Show Join Screen on Display** (⌘J, also in the
**Game** menu) puts the QR code, page address, Game PIN and each team's phone status over
whatever the Display shows, so a late or dropped phone can join mid-game; a TV icon on the
Buzzers button shows it's up. It comes down when pressed again, when the phase changes (opening
a clue, returning to the board, …), or when the buzzer server stops. Setup already shows it, so
the button is greyed out there. The Display window, opened with
**Show Display** (⌘D), mirrors the phase full-screen with a scoreboard along the bottom. ⌘D
works from the launch screen too: until a game is picked, the Display shows a "Waiting for the
host to start a game…" screen, so it can go up on the TV early.

| Phase | Host (Control) | Display |
|---|---|---|
| **Setup** | Team cards (max 4): rename, pick a color swatch, remove, **Add Team**; buzzer panel with QR code, Game PIN, page address, and how many teams have a phone; **Start Game**. With buzzers off: no phone status, and the panel just says buzzers are off | Buzzer QR code, page address, and Game PIN, with a card per team showing **Connected** / **Not connected**; "Waiting to start game…" if the buzzer server isn't running. With buzzers off: a card per team with its name only |
| **Board** | Pick a clue from the board (click, or arrow keys + Return); **Next Round**; show/hide the Display window | The board, played tiles blanked, the host's highlighted tile |
| **Daily Double** | Pick the team and wager (quick-wager buttons), **Show Question** | Daily Double splash |
| **Question** | Clue as a big tile, correct response (host only) with **Reveal Answer**, who buzzed first with their response timer (5 s by default) (or the Daily Double team and wager), question timer ring (15 s by default; start/pause/reset/±5 s), ✓/✗ score buttons on each team card (only the Daily Double team's on a Daily Double), **Return to Board** in the toolbar | Clue (and picture, if any), timer; response-timer dots above the answering team's score |
| **Answer** | Same screen, answer revealed; score buttons, **Return to Board** | Correct response |
| **Final – Category** | Watch each team's wager status, enter or edit wagers, **Reveal Question** | Final category |
| **Final – Question / Answer** | Each team's wager and the answer typed on its phone, reveal answer, adjust scores; after the reveal, **Show on Display** puts one team's answer and wager on screen (tap again to hide), **Complete Game** | Final clue, then response, with the spotlighted team's answer and wager |

Scoring rules the app applies:
- Each team gets **correct / wrong** buttons for the clue's value (or its Daily Double or
  Final wager). With no clue up they become ±100 / ±200 manual adjustments. Scores can be reset.
- On a normal clue, *wrong* locks that team's buzzer and re-arms the others; *correct* stops
  the buzzers. Daily Double and Final scoring never touch the buzzers.
- **Response timer** (phone buzzers only): when a team's buzz wins, the question timer
  pauses and the team gets 5 s to answer, shown as dots on the Control window, above the
  team's score on the Display, and on every phone. Nothing is scored when it runs out; the
  host marks correct or wrong (any time, even before it runs out). *Wrong* resumes the
  question timer where it paused so the other teams can buzz; *correct* leaves it stopped.
  Revealing the answer or returning to the board cancels it.
- Final Macpardy: teams at $0 or below are excluded and wager 0. A team with no wager when the
  question is revealed bets everything.
- **Complete Game** clears the auto-save and sends the Control window back to the launch
  screen; the Display stays open on its waiting screen. The buzzer server stops, so phones go
  back to their Game PIN screen ("Game over…"); the next game gets a new Game PIN.

Sound: the Control Mac plays a buzzer on a wrong answer, a warning over the last 5 seconds of
the timer, stings for Daily Double and Final Macpardy, and quiet music on the board. The
toolbar's **Sound** menu turns effects and music off. See [sounds.md](sounds.md).

## 4. Phone buzzers (optional)

A game works without phones. When the game starts, the app serves a page on the local network.

- **No buzzers (#74):** turn off **Use phone buzzers** in **Settings > Buzzers** to play with
  no phones or Wi-Fi. The server never starts, so there's no Game PIN, QR code or page
  address; setup only asks for team names and colors, the Buzzers toolbar button and ⌘⇧B are
  gone, and teams answer out loud. Turning it off mid-game drops any joined phones; turning it
  back on starts a new session with a new Game PIN.

- **Joining:** scan the QR code (joins straight away), or open the page address shown on the
  Display and type the 6-character **Game PIN**; then pick a team. One phone per team; a
  claimed team's Join button is disabled for everyone else. A wrong PIN shows an error and
  the player can try again.
- **Android + Chrome (#90):** if Chrome shows `ERR_TOO_MANY_RETRIES`, the phone hasn't let
  Chrome reach local devices: allow **Nearby devices** in Settings › Apps › Chrome ›
  Permissions. The join panels on Control and the Display say so. See
  [buzzer-protocol.md](buzzer-protocol.md#android-chrome-shows-err_too_many_retries-90).
- **Buzzing:** the buzzer is live only while a normal clue is shown. Buzzing early shows a
  "too early" message. On a Daily Double the button can't be pressed.
- **First buzz:** the first buzz the Mac receives wins; buzzes within ~75 ms count as a tie,
  won by the lower score (equal scores: random).
- **Response time:** the winning team has 5 s to answer. Every phone shows the countdown as
  dots under the buzzer ("Answer now" on the answering phone, "<team> is answering" on the
  others, "Time's up" at zero) until the host judges the answer.
- **Wrong answer:** that team is locked out for the rest of the clue; the others can buzz again.
- **Final Macpardy:** while the category is shown, each eligible phone gets a wager screen
  with its max (its score). Only the first submission counts; after that only the host can
  change it. Excluded teams are told they can't win points.
- **Final answers:** while the Final clue is shown, every phone (excluded teams too) gets an
  answer box. **Send answer** (or Enter) saves it; the team can change it until the Final
  timer runs out or the host reveals the correct response, when it locks and the phone shows
  what was sent. Adding time (+5 s) or resetting the timer while the clue is up reopens it.
  If the timer never runs (e.g. the Display isn't open), answers stay open until the reveal. Answers
  are trimmed to one line, at most 200 characters. Only the host sees them until they show
  one on the Display. Teams that never had a phone get no answer row, so games without
  buzzers look as before.
- **Joining mid-game (#83):** the host can put the join screen on the Display at any time
  after setup (see §3); the Game PIN is the same one the game started with.
- **Connection:** a phone can sit in the background or with its screen locked without
  losing its team; when the player comes back, the page reconnects on its own and the phone
  gets its team back. A phone whose connection closes, or that stops answering for 60 s,
  counts as disconnected; the Control and Display windows flag the team. If the page's one
  automatic rejoin fails, it goes back to the Game PIN screen with its PIN filled in and a
  dismissible "Unable to find client" toast; tapping **Join** rejoins (and restores the
  team). The Mac doesn't nap or idle-sleep while the buzzer server runs. The host can remove
  a team's phone (team and score kept) and the phone can rejoin.
- **Game over:** when the game is completed, a save is resumed, or the host leaves the game,
  every phone returns to an empty Game PIN screen ("Game over…"). An old PIN is refused with
  "That game has ended or the PIN changed".
- Abuse limits: wrong Game PINs and claim attempts are rate limited per address.
- **Why did a phone drop?** **View Logs** in the Buzzers popover opens the Logs window (§6d),
  showing all categories; pick **Buzzer** to see only the phones. Each disconnect is one line with the team, the phone's IP, how long
  it was connected and why; when the phone rejoins, its own report says whether its screen was
  locked or the page hidden.

Wire details: [buzzer-protocol.md](buzzer-protocol.md).

## 5. Saving and resuming

- Once play starts, every game action auto-saves (debounced 300 ms) to `saved_game.json` in
  the app's Application Support folder (sandboxed:
  `~/Library/Containers/jbkiv.Macpardy/Data/Library/Application Support/Macpardy/`).
  Pictures are embedded, so a crash or quit can be resumed from **Play** even if
  the board file moved. This holds for built-in games too: a save keeps the whole board and
  doesn't refer to the bundled file, so it still resumes after an app update changes or
  removes that game.
- Resuming starts a new buzzer session; phones go back to the Game PIN screen and rejoin
  with the new PIN.
- A save that's corrupt or from a different schema version is discarded, not migrated.

## 6. Sharing the app

`scripts/export.sh` builds an ad-hoc signed `.app` and `.dmg` for trusted sharing (not
notarized). See [EXPORTING.md](../EXPORTING.md).

## 6a. Undo and redo

**Edit > Undo / Redo** (⌘Z / ⇧⌘Z) work in two places, each window with its own history, and the
menu items name the action (e.g. "Undo Award Points").

- **Board editor:** Edit Title, Rename Round, Edit Category, Edit Clue, Edit Answer, Change
  Value, Toggle Daily Double, Add Image, Remove Image. Typing in one field within about a second
  is one step; moving to another field, clue or round starts a new one. Undoing back to the saved
  board clears the unsaved-changes indicator. The history clears when the editor closes or loads
  another board.
- **Control window, scores only:** Award Points, Deduct Points, Reset Score. Undo and redo save
  the game and the phones see the restored scores. Clearing a clue, advancing a round, and adding
  or removing teams are not undoable, and the score history clears when a game starts or resumes
  or the round advances, so an undo can't change a score from an earlier round.

## 6b. Settings

**Macpardy > Settings…** (⌘,) opens a standard Settings window. Changes apply immediately and
are remembered (`UserDefaults`, keys in `AppSettings`).

- **Sound:** sound effects and music, the same switches as the toolbar's Sound menu.
- **Game:** question timer length (5–60 s in 5 s steps, default 15), answer time after a buzz
  (3–30 s, default 5), starting team count (1–4, default 3) and starting team names (up to 100
  characters; empty uses "Team N"). Timer lengths apply the next time a timer starts; team
  settings apply to games started afterwards.
- **Display:** animations on or off (default on). They are also off whenever macOS
  **Reduce Motion** is on.
- **Buzzers:** **Use phone buzzers** (default on; off plays without phones, see §4), applied
  right away; server port (1024–65535, default 8472), applied the next time the server starts.

## 6c. Display animations

The Display window (not Control) animates, unless turned off in Settings or macOS Reduce Motion
is on:

- **Board intro:** at the start of each round the category titles appear one by one, then the
  clue tiles turn over together. It plays once per round, not when returning from a clue, and
  not when a saved game resumes.
- **Clue flip:** the clue (and its answer) turns to face the room.
- **Phase transitions:** setup and board fade; the Daily Double splash scales in with a gold
  burst; Final Macpardy slides in.
- **Phone buzzer page:** screens rise in, team rows slide in one by one, the buzzer pulses green
  when armed and gold when you're up, and it shakes when locked out or too early. The response
  dots fade out. It follows the phone's own Reduce Motion setting (the Settings toggle only
  affects the Display).
- **Scores:** the number rolls to its new value and flashes gold when it rises, red when it falls.

## 6d. Logs

The app keeps its own log so a host can see why phones won't connect or drop off.

- **Help > Show Logs** (⌥⌘L), or **View Logs** in the Buzzers popover, opens the **Logs**
  window. It opens on **All** categories, showing Info and above, and updates live.
- Toolbar: pick the **run** (this session, live, or an earlier launch by date), the
  **category** (All, Buzzer, Network, Control, Display, Storage), the **minimum level**, a
  **team**, and search messages, teams and addresses. Text can be selected and copied.
- The list follows new lines while it's scrolled to the bottom; scrolling up pauses it and
  shows **Jump to Latest**.
- Each launch writes its own log file, so a previous session can be read after a relaunch.
  The app keeps the 10 most recent launches and at most 20 MB, deleting the oldest at launch
  (one launch's file stops growing at 5 MB).
- **Export Logs…** saves one `.zip`: every kept launch as a readable `.log` file (and the raw
  `.jsonl`), plus `system-info.txt` (app and macOS version, Mac model, buzzer port and
  protocol, whether the server is running, local IP addresses, team count). The save panel
  notes that it contains team names, local IP addresses and phone browser info. Nothing is
  uploaded; the host sends the file if they want to.
- The same lines go to Console.app (subsystem `jbkiv.Macpardy`), unredacted.

What the buzzer lines mean: [buzzer-protocol.md](buzzer-protocol.md#troubleshooting-disconnects).

## 7. Keyboard shortcuts

**Help > Keyboard Shortcuts** (⌘/), or the keyboard button in the Control toolbar, opens a window
listing every shortcut by area (File, Edit, Game, Timer, Editor, View, Window, App, Help). It is
built from the shortcut catalog, so it always matches the menus; the tables below add the keys
that belong to individual screens.

Game shortcuts live in the **Game** menu in the menu bar. Items are always listed and greyed out
when they don't apply to the current phase. File-menu items work anywhere; the editor's ⌘S still belongs to its button, so it works only
while the editor is up. Every shortcut is defined once in
`App/Commands/ShortcutCatalog.swift`.

| Where | Shortcut | Action |
|---|---|---|
| File menu | ⌘O | **Import Board…** (then Play or Edit) |
| File menu | ⌘N | **New Board** |
| New Board sheet | Esc | Cancel |
| Board error sheet | Return | OK |
| Editor window | ⌘S | **Save Game** |
| Editor window | Tab / ⇧Tab | Move between the clue and response fields (and the Final category) |
| Any window | ⌘, | Open **Settings** |
| Any window | ⌘/ | Open **Keyboard Shortcuts** |
| Any window | ⌥⌘L | Open **Logs** |
| Control, any phase in a game (buzzers on) | ⌘⇧B | Open the **Buzzers** popover |
| Control, any phase after setup (buzzers on) | ⌘J | Show / hide the **join screen** on the Display |
| Control, launch screen or any phase | ⌘D | **Show Display** (waiting screen until a game is picked) |
| Control, Board | ⌘F | **Final Macpardy** |
| Control, Board | ⌘→ | **Next Round** |
| Control, Board | ← ↑ → ↓ | Move the highlight between open tiles (shown on the Display too) |
| Control, Board | Return / Space | Open the highlighted clue |
| Control, Question / Answer | ⌘B | **Return to Board** |
| Control, Question | ⌘R | **Reveal Answer** (also Final question) |
| Control, Question / Final | ⌘T | Start / pause the timer |
| Control, Question / Final | ⌘← | Reset the timer |
| Control, Question / Final | ⌘− / ⌘+ | Timer −5 s / +5 s |

## Not built yet

Open issues at the time of writing: sounds (#27), animations (#25), and a fix for the control
panel question picker (#26). Also out of scope today: exporting a game to CSV, round titles in
CSV, and contestants submitting written Final answers from their phones.
