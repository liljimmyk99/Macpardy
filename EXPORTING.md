# Exporting Macpardy

The export script builds a Release version of the app with Hardened Runtime and an ad-hoc code signature, then creates both a standalone app and a compressed DMG:

```sh
./scripts/export.sh
```

The outputs are written to `build/exports/`. To choose another output directory:

```sh
./scripts/export.sh /path/to/exports
```

The script requires Git, Tuist, Xcode command-line tools, and the macOS `codesign`, `ditto`, `diskutil`, and `hdiutil` utilities. It verifies the app signature and DMG before exporting.

The build number (`CFBundleVersion`) is the number of commits in the current branch, so it goes up with every merge to `master` and an export of the same commit always gets the same number. To set it yourself:

```sh
BUILD_NUMBER=42 ./scripts/export.sh
```

## Releasing

Releases are published by GitHub Actions (`.github/workflows/release.yml`). To cut one:

1. Open a PR that bumps `MARKETING_VERSION` in `Project.swift` (for example `0.4.1` → `0.5.0`) and merge it.
2. That's it. When `Project.swift` changes on `master`, the workflow reads the version and, if there is no tag with that number yet, runs the tests, runs `./scripts/export.sh`, then creates the tag (the bare version, such as `0.5.0`) and a GitHub release with generated notes and `Macpardy.dmg` attached.

If the tag already exists, the workflow does nothing, so other edits to `Project.swift` don't publish a release. If a release fails partway (for example a flaky runner), fix the cause and re-run the workflow from the Actions tab, or start it by hand with **Run workflow**.

Every pull request also runs `.github/workflows/ci.yml`, which runs the tests and a full export and attaches the DMG to the run, so a broken export shows up before it is merged.

Both workflows run on GitHub's `macos-26` runner with Xcode 26.3 or a later 26.x and the Tuist version pinned in `.github/actions/setup-build/action.yml`. Update both there when the project moves to a newer Xcode or Tuist.

## Sharing limits

An ad-hoc signature does not identify a developer and cannot be notarized. macOS may warn recipients that the app is from an unidentified developer or cannot be checked for malicious software. A DMG does not remove this warning. For a recipient who trusts the copy, Finder may allow opening it by Control-clicking the app, choosing **Open**, then confirming **Open** again. System policies may still block it.

For a smoother install for other people, the app must be signed with a Developer ID certificate and notarized by Apple. The export produced here is intended for trusted sharing, not Mac App Store distribution.
