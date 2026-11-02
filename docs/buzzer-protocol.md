# Macpardy! Buzzer WebSocket Protocol — v7

All WebSocket messages are JSON objects with a required top-level `type` string field
and an optional `payload` object. Unknown `type` values should be silently ignored by
both sides to allow forward compatibility.

---

## Wire format

```json
{ "type": "<type>", "payload": { ... } }
```

Messages with no payload omit the `payload` key entirely.

---

## Client → Server messages

These messages are sent by the phone browser to the Macpardy app.

### `join`

Sent immediately after the WebSocket connection opens (the page only opens one once it
has a Game PIN, see [Game PIN screen](#game-pin-screen)).
The server validates the `code`; if invalid it responds with `joinRejected`
and closes the connection.

```json
{
  "type": "join",
  "version": 7,
  "code": "AB3XYZ"
}
```

| Field     | Type   | Description                                              |
|-----------|--------|----------------------------------------------------------|
| `version` | int    | Required. Protocol version the client speaks. Currently always `7`. A missing version is not decodable and the message is ignored. |
| `code`    | string | The 6-character join code ("Game PIN") shown on the host's screen. |

---

### `claim`

Asks to take a team. Only valid after a successful `join`; ignored otherwise.
A phone holds at most one team, so a successful claim releases any team it held.
The server answers with `claimAccepted` or `claimRejected`.

```json
{ "type": "claim", "teamID": "6F9619FF-8B86-D011-B42D-00C04FC964FF" }
```

| Field    | Type   | Description                                  |
|----------|--------|----------------------------------------------|
| `teamID` | string | `id` of a team from `joinAccepted` / `teams`. |

---

### `pong`

Sent in response to a `ping` from the server. Resets the 5-second heartbeat TTL.

```json
{ "type": "pong" }
```

---

### `buzz`

The phone's buzzer button was pressed. Only valid after a successful `claim`.
The server decides the result and answers with `buzzerState`. Buzzes received within
75 ms of the first one count as a tie: the lowest score wins, then random.

```json
{ "type": "buzz" }
```

---

### `submitWager`

A Final Macpardy wager. Only valid after a successful `claim` and while wagering is
open. Only the first valid submission counts; after that only the host can change it.
Answered with `wagerLocked` or `wagerRejected`.

```json
{ "type": "submitWager", "amount": 500 }
```

---

### `submitAnswer`

A Final Macpardy answer. Only valid after a successful `claim` and while answering is
open (the Final clue is up). Every team can answer, including teams excluded from
wagering. The latest valid submission counts, so a team can change its answer until the
host reveals the correct response. Answered with `answerSaved` or `answerRejected`.

```json
{ "type": "submitAnswer", "answer": "What is Paris?" }
```

| Field    | Type   | Description |
|----------|--------|-------------|
| `answer` | string | The answer. The server trims it and folds line breaks into spaces; at most `maxLength` characters (200) after that. |

---

## Server → Client messages

These messages are sent by the Macpardy app to one or all phone browsers.

### `joinAccepted`

Sent to the joining phone after a valid join code is received.

```json
{
  "type": "joinAccepted",
  "payload": {
    "version": 7,
    "teams": [
      { "id": "6F9619FF-8B86-D011-B42D-00C04FC964FF", "name": "Team 1", "color": "blue", "claimed": false }
    ]
  }
}
```

| Payload field | Type     | Description                                                     |
|---------------|----------|-----------------------------------------------------------------|
| `version`     | int      | Protocol version the server is speaking. Currently always `7`.  |
| `teams`       | object[] | Teams in display order (at most 4). `claimed` is true while a phone holds the team; the phone disables that team's Join button. `color` is one of `blue`, `red`, `green`, `yellow`, `purple`, `orange`. |

---

### `joinRejected`

Sent when the join code in the `join` message does not match or the client
protocol version is unsupported.
The connection is closed by the server after sending this.
The phone goes back to its Game PIN screen with an error and does **not** reconnect on its
own (see [Game PIN screen](#game-pin-screen)).

Wrong codes are rate limited per remote address (default: more than 5 in 60 s
locks the address out for 30 s). While locked out, even the correct code is
rejected.

```json
{
  "type": "joinRejected",
  "payload": {
    "reason": "Invalid join code",
    "code": "invalidCode"
  }
}
```

| Payload field | Type   | Description                                              |
|---------------|--------|----------------------------------------------------------|
| `reason`      | string | Human-readable rejection reason (English, for logs).     |
| `code`        | string | Machine-readable reason; the page picks its message from this. |

| `code`               | Meaning                                                        |
|----------------------|----------------------------------------------------------------|
| `invalidCode`        | The code doesn't match this session (wrong, or from a finished game). |
| `rateLimited`        | Too many wrong codes from this address.                        |
| `unsupportedVersion` | The page speaks another protocol version (an old open page).   |

---

### `sessionEnded`

Sent to every joined phone when the server is stopped on purpose: the host pressed
**Complete Game**, resumed a saved game, or went back to the launch screen. All of these
start a new session with a new join code (or none), so the old code no longer works. The
server closes the connection right after sending this.

The phone forgets the code and its team, removes `?code=` from the address bar, and shows
an empty Game PIN screen with "Game over. Enter the new Game PIN to play again." It doesn't
show "Unable to find client" for the close that follows.

```json
{ "type": "sessionEnded" }
```

If the phone misses it (the app crashed or was force-quit, the Mac slept), it falls back
on `joinRejected`: a code that worked before and is now `invalidCode` is treated the same way.

---

### `teams`

Broadcast to every joined phone whenever a team is added, renamed, recolored or
removed, or a claim is taken or freed. Same `teams` array as `joinAccepted`.

```json
{ "type": "teams", "payload": { "teams": [ ... ] } }
```

---

### `claimAccepted`

The phone now holds the team. Sent to the claiming phone only; everyone gets the
updated `teams` broadcast. Repeating a claim for the team already held is also
answered with `claimAccepted`.

```json
{ "type": "claimAccepted", "payload": { "teamID": "6F9619FF-8B86-D011-B42D-00C04FC964FF" } }
```

---

### `claimRejected`

The claim was refused; the phone stays on the team picker. For `taken` and
`invalidTeam` a fresh `teams` message is sent just before this one.

```json
{ "type": "claimRejected", "payload": { "reason": "taken" } }
```

| `reason`      | Meaning                                                                    |
|---------------|----------------------------------------------------------------------------|
| `taken`       | Another phone holds the team.                                              |
| `invalidTeam` | No such team (for example the host deleted it).                            |
| `rateLimited` | Too many claims from this address (default: more than 10 in 10 s locks it out for 30 s). |

---

### `removed`

The host removed this phone from its team. The server closes the connection right
after sending this. The phone shows "Removed by host" and does **not** reconnect on
its own. The team keeps its score, and a new phone can claim it.

```json
{ "type": "removed" }
```

---

### `ping`

Heartbeat request sent by the server every 2 seconds to each connected client.
The client must respond with a `pong` within 5 seconds or it is disconnected.

```json
{ "type": "ping" }
```

---

### `state`

> **Reserved.** Defined for a later sub-issue; the server does not send it yet
> (`BuzzerState.broadcastPhase` has no caller).

Broadcast to all authenticated clients when the game phase changes.
Future sub-issues extend the payload to carry additional game context.

```json
{
  "type": "state",
  "payload": {
    "phase": "board"
  }
}
```

| Payload field | Type   | Values                                                                                       |
|---------------|--------|----------------------------------------------------------------------------------------------|
| `phase`       | string | `setup`, `board`, `question`, `answer`, `dailyDouble`, `finalMacpardyCategory`, `finalMacpardyQuestion`, `finalMacpardyAnswer` |

---

## Sandbox entitlements

The server needs both `com.apple.security.network.server` and
`com.apple.security.network.client`. With only `network.server`, a sandboxed `NWListener`
starts and serves the Mac itself (loopback), but every connection from another device is
dropped before `newConnectionHandler` runs. Network.framework handles TCP inside the app,
and the sandbox refuses to register the new connection with the kernel:

```
nw_path_evaluator_create_flow_inner NECP_CLIENT_ACTION_ADD_FLOW … [1: Operation not permitted]
nw_connection_create_from_protocol_on_nw_queue [C33] Failed to create connection from listener
```

These connections never appear in `netstat`, so the only sign is phones timing out. The app
doesn't open outgoing connections; `network.client` is there only for this.
macOS Local Network privacy doesn't apply here: accepting incoming TCP connections doesn't
require it, so no permission prompt appears.

---

## Heartbeat sequence

```
Server                          Phone
  |                               |
  |─── ping ─────────────────────>|
  |                               |
  |<── pong ──────────────────────|   (within 5 s)
  |                               |
  | (repeat every 2 s)            |
```

If no `pong` is received within `heartbeatTTL` (5 s), the server closes the connection
and frees the team the phone held. The check runs on the 2 s ping timer, so the slot is
released between 5 and 7 s after the last pong.
A socket that connects but never sends a valid `join` within the same TTL is also closed.

The phone runs its own watchdog: if it hears nothing from the server for 5 s (for
example Wi-Fi dropped without a TCP close), it closes the socket and treats it as a lost
connection (below).

---

## Game PIN screen

The "Game PIN" players see is the server's 6-character join code.

- Opening the page with no `?code=` (typing `http://<ip>:<port>`; the port is 8472 unless changed in Settings > Buzzers) shows the Game PIN screen.
  No WebSocket is opened until the player submits a PIN, so the 5 s join TTL and the
  wrong-code rate limit don't apply to someone still typing.
- The field upper-cases input and drops anything that isn't a letter or digit; **Join** is
  enabled at 6 characters.
- Opening the page with `?code=` (the QR code) joins straight away, as before.
- On `joinAccepted` the page writes `?code=<PIN>` into the address bar
  (`history.replaceState`) so a refresh rejoins.
- On `joinRejected` the page shows the PIN screen with a message picked from `code`:

| Case | Message | Field |
|------|---------|-------|
| `invalidCode`, PIN never accepted on this page | "Wrong Game PIN. Check the screen and try again." | Kept |
| `invalidCode`, PIN accepted earlier on this page, or it came from `?code=` | "That game has ended or the PIN changed. Enter the Game PIN shown on screen." | Cleared, `?code=` removed |
| `rateLimited` | "Too many attempts. Try again shortly." | Kept |
| `unsupportedVersion` | "This page is out of date. Reload it." | Kept |

## Connection-lost behaviour

The page **doesn't reconnect on its own**. When the WebSocket closes or errors unexpectedly
(no `sessionEnded`, `removed` or `joinRejected` first), or the watchdog fires, the phone:

- goes back to the Game PIN screen with the last accepted PIN filled in, so rejoining is
  one tap on **Join** (then picking the team again);
- shows an **"Unable to find client"** toast (preloaded in the page) that the player can
  dismiss. It also goes away on the next join attempt.

This covers a failed connection after tapping **Join** (app not running, wrong network), a
mid-game network drop, and the app being quit or the Mac going to sleep.

`removed` is unchanged: the phone shows "Removed by host" and stays there.

---

## Team claims and presence

- A team is held by at most one phone; a claim lives exactly as long as the phone's
  connection. When the connection drops (TTL, close, or host removal) the slot is freed
  and anyone with the join code can claim it.
- Scores belong to the team, not the phone, so a freed team keeps its score and whoever
  claims it next inherits it.
- A phone that refreshes gets a new connection, so it can be blocked (`taken`) for up to
  5 s until the server times out the old one.
- The host app marks a team as disconnected once a phone has held it and none does now.

---

---

## Buzzer

### `buzzerState`

Sent to a single phone whenever what its buzzer button shows changes, and right
after `claimAccepted`.

```json
{ "type": "buzzerState", "payload": { "state": "armed" } }
```

| `state`       | Meaning                                                                          |
|---------------|----------------------------------------------------------------------------------|
| `waiting`     | Buzzer disabled (board, answer revealed, another team answering). Pressing it is answered with `tooEarly`. |
| `unavailable` | Daily Double. The button cannot be pressed and the server ignores any `buzz`.    |
| `armed`       | A question is displayed; the team can buzz.                                      |
| `pressed`     | The team buzzed and the tie window is still open.                                |
| `first`       | The team won the buzz and is answering.                                          |
| `lockedOut`   | The team answered wrong and cannot buzz again on this question.                  |
| `tooEarly`    | The team pressed while disabled ("Slow your horses bud, too early"). Transient: the phone returns to `waiting` on its own. |

### `responseTimer`

Broadcast to every joined phone when a team's buzz wins and its response time starts, and
sent to a phone right after `claimAccepted` while one is running (with the time left then).
The server sends no ticks: the phone counts down from `remaining` on its own clock. At zero
the phone shows "Time's up" and waits; nothing is scored automatically.

```json
{ "type": "responseTimer", "payload": { "teamID": "6F9619FF-8B86-D011-B42D-00C04FC964FF", "remaining": 5, "total": 5 } }
```

| Field       | Type   | Description                                                  |
|-------------|--------|--------------------------------------------------------------|
| `teamID`    | string | The answering team.                                          |
| `remaining` | number | Seconds left when sent (tenths).                             |
| `total`     | number | The full response time in seconds (one dot per second).      |

### `responseTimerStopped`

Broadcast when the response time ends: the host marked the answer correct or wrong, revealed
the answer, or left the clue. The phone hides the countdown.

```json
{ "type": "responseTimerStopped" }
```

---

## Final Macpardy wagers

Wagering is open while the Final category is displayed. The host decides when to move
on; teams that haven't wagered then bet everything they have. A team's wager is only
ever sent to that team's own phone.

### `wagerInfo`

Sent to a single phone when wagering opens, after `claimAccepted` while it is open, and
when the host clears the team's wager.

```json
{ "type": "wagerInfo", "payload": { "eligible": true, "max": 1200 } }
```

| Field      | Type | Description                                                                  |
|------------|------|------------------------------------------------------------------------------|
| `eligible` | bool | False when the team's score is zero or less: it cannot wager or win points.  |
| `max`      | int  | Highest wager allowed (the team's score; 0 when not eligible).               |
| `wager`    | int  | Present only if a wager is already locked in (e.g. after a reconnect).       |

### `wagerLocked`

The wager is locked in, either submitted by the phone or set/edited by the host.

```json
{ "type": "wagerLocked", "payload": { "wager": 500 } }
```

### `wagerRejected`

A `submitWager` was refused. `reason` is one of `notOpen`, `notEligible`, `locked`,
`negative`, `overMax`.

```json
{ "type": "wagerRejected", "payload": { "reason": "overMax" } }
```

### `wagerClosed`

Wagering is over; the phone returns to the buzzer.

```json
{ "type": "wagerClosed" }
```

---

## Final Macpardy answers

Answering is open while the Final clue is displayed, locked (read-only) once the host
reveals the correct response, and closed everywhere else. A team's answer is only sent
to that team's own phone; the host sees every answer on the Control window and can show
one team's answer and wager at a time on the Display.

### `answerInfo`

Sent to a single phone when answering opens, when it locks, and after `claimAccepted`
while it is open or locked.

```json
{ "type": "answerInfo", "payload": { "open": true, "maxLength": 200, "answer": "What is Paris?" } }
```

| Field       | Type   | Description                                                         |
|-------------|--------|---------------------------------------------------------------------|
| `open`      | bool   | True while the team can submit or change its answer; false once locked. |
| `maxLength` | int    | Longest answer accepted, in characters.                             |
| `answer`    | string | Present only if the team has saved an answer (e.g. after a reconnect). |

When it opens, the phone fills its answer field from `answer`; later `answerInfo`
messages leave whatever the player is typing alone.

### `answerSaved`

The answer was saved. The phone can still change it while answering is open.

```json
{ "type": "answerSaved", "payload": { "answer": "What is Paris?" } }
```

### `answerRejected`

A `submitAnswer` was refused; the team's previous answer (if any) still stands.
`reason` is one of `notOpen`, `empty`, `tooLong`.

```json
{ "type": "answerRejected", "payload": { "reason": "notOpen" } }
```

### `answerClosed`

Final answering is over (the host left the Final); the phone returns to the buzzer.

```json
{ "type": "answerClosed" }
```

---

## Version history

| Version | Changes                          |
|---------|----------------------------------|
| 1       | Initial release (issue #28). Introduces `join`, `joinRejected`, `joinAccepted`, `ping`, `pong`, `state`. |
| 2       | Issue #29. `joinAccepted.teams` is now an array of `{id, name, color, claimed}` objects. Adds `claim`, `teams`, `claimAccepted`, `claimRejected`, `removed` and rate limiting. |
| 3       | Issue #30. Adds `buzz` and `buzzerState`. |
| 4       | Issue #31. Adds `submitWager`, `wagerInfo`, `wagerLocked`, `wagerRejected` and `wagerClosed`. |
| 5       | Issue #59. Adds `responseTimer` and `responseTimerStopped`. |
| 6       | Issue #61. Adds `sessionEnded` and `joinRejected.code`. The page asks for a Game PIN when opened without `?code=` and no longer reconnects on its own. |
| 7       | Issue #80. Adds `submitAnswer`, `answerInfo`, `answerSaved`, `answerRejected` and `answerClosed`. A page left open from an older version is told to reload, since it couldn't answer. |

## Port

The server listens on port **8472** by default. The host can change it in **Settings > Buzzers**
(1024–65535); it is read once when the server starts, so a change applies to the next game, and
the join URL and QR code are built from the port actually in use. If the port is taken, the
setup screen shows a start error naming it. The wire protocol is unchanged.
