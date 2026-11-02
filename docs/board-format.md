# Board file format

Boards are saved as `.macpardy` packages. A package is a zip archive:

```
board.json      { "formatVersion": 2, "title": "Trivia Night", "boards": [ ...MacpardyBoard... ] }
images/<file>   one file per question image
```

- A question's image is referenced from `board.json` by relative path:
  `"image": { "path": "images/<question-id>.jpg" }`. Image bytes are never inlined in `board.json`.
- A package with only `board.json` (no `images/`) is valid.
- `title` is the game's name. It's optional: files saved before games had their own name don't
  have it, and older versions of the app ignore it. Each board's own `title` is that round's
  title (e.g. "Warm Up"), set separately in the editor; a blank one is saved as the round's
  name ("Macpardy", "Double Macpardy", "Final Macpardy").
- Only `images/<name>` paths are read; anything else (e.g. `../`) is ignored.
- A missing or corrupt image doesn't stop the board loading; the question screen shows a placeholder.
- Files with a `formatVersion` newer than the app supports are rejected.

## Legacy boards

Format 1 is a plain `.json` file containing `[MacpardyBoard]`. These still open from
"Play", as does a bare `board.json` in the format 2 shape. New boards are
always saved as packages (edited boards are the exception, see below).

## Images

Set in `ImageImporter`:

| | |
|---|---|
| Accepted formats | PNG, JPEG, HEIC/HEIF, GIF (first frame), TIFF, BMP, WebP — checked from file contents |
| Max source file | 25 MB |
| Stored size | Longest side downscaled to 1920 px (smaller images are not upscaled) |
| Stored encoding | PNG if the image has transparency, otherwise JPEG at 85% quality; metadata is dropped |

One image per question, shown on the contestant question screen only (not the answer,
control, or phone buzzer screens).

## Auto-save

The auto-saved game (`Application Support/Macpardy/saved_game.json`) embeds image bytes
(base64), so resuming works even if the original board file was moved or deleted.

Final answers typed on phones (`finalMacpardyAnswers`, team id → answer) and the team shown
on the Display (`finalMacpardyRevealedTeamID`) are saved too. Both are optional, so saves
from before they existed still load; `GameSnapshot.currentSchemaVersion` is unchanged.

## Boards imported from CSV

Games imported from CSV (see [csv-import.md](csv-import.md)) are saved as a plain `.json` file
in the format 2 shape (`{ "formatVersion": 2, "boards": [...] }`), since they have no images.

## Built-in games

The games in `Resources/Games/*.json` are plain `.json` boards in this same format, read by
the same loader as user files. "Edit Board" opens one as a copy and saves a new file; the
bundled file is never written. Auto-saves embed the whole board, so they don't depend on it.

## Editing an existing board

"Edit Board" on the start screen opens a `.json`, `.macpardy` (or `.zip`), or `.csv`
board in the same editor as "Create Game", filled in. Loading goes through `BoardLoader`, which
picks the reader by file extension and reuses the readers above and the CSV importer.

- The editor needs one Macpardy round, one Double Macpardy round, and one Final Macpardy round
  with exactly one clue. The first two rounds must each be exactly 6 categories × 5 clues, and
  every category in a round must have the same point values; any values are fine (the editor
  keeps them), not only the defaults. Anything else is rejected with the round, category and
  count that's wrong.
- The game title is the file's `title`. Files without one use the Macpardy board's title minus
  the " - Macpardy" suffix older versions added, or failing that the file name. Round titles
  load as saved.
- A file that can't be loaded is not partly loaded. The start screen lists what's wrong:
  the field path for JSON (e.g. `boards[0].categories[2].title`), the row and column for CSV.
- Saving an edited board asks where to save it, so the original is only replaced if the user
  picks it. It's saved as plain `.json` unless a clue has a picture, in which case it's a
  `.macpardy` package. Afterwards the user can play it right away.
- Closing the editor window or quitting the app with unsaved edits to a loaded board asks
  Save… / Don't Save / Cancel first. New games ("Create Game") don't ask.
- Auto-saved games can't be opened for editing.
