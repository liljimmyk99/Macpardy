# Contributing to Macpardy

Thanks for helping. This is the short version; [AGENTS.md](AGENTS.md) is the full guide for
humans and coding agents, and [docs/how-to.md](docs/how-to.md) has recipes.

## Setup

```sh
tuist generate        # needs Xcode 26 and Tuist
xcodebuild test -project Macpardy.xcodeproj -scheme Macpardy -destination 'platform=macOS'
```

See [docs/getting-started.md](docs/getting-started.md).

## Workflow

- Work is tracked in GitHub issues. Open or pick one before a larger change.
- Branch names: `feat/<short-name>-<issue>`; docs-only: `docs/<short-name>`.
- Commits and PR titles follow Conventional Commits: `feat: …`, `fix: …`, `docs: …`.
- PR descriptions start with `Closes #<n>.`, then **What changed**, behaviour changes the
  reviewer should know about, and anything deliberately left out.
- CI runs the tests and a full export on every PR.

## Expectations

- Add tests for new parsing, validation, and game or buzzer rules.
- Put all user-facing text in `Localizable.xcstrings`.
- Use `AppLogger` and the logged button/gesture wrappers; never log clue text, answers or
  Final answers.
- Keep saved file formats loading: new fields optional or defaulted.
- Don't add entitlements or outgoing network features without calling it out in the PR.
- Update the docs in the same PR as the behaviour they describe.
- Don't commit generated output (`Derived/`, `build/`, `*.xcodeproj`), and don't create
  release tags by hand.

## Reporting bugs

Include your macOS version, what you did, and exported logs (Logs window > **Export Logs…**).
For buzzer problems also give the phone's OS and browser. See
[docs/troubleshooting.md](docs/troubleshooting.md).

By contributing you agree your work is released under the [MIT License](LICENSE).
