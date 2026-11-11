# Troubleshooting

## A phone can't open the buzzer page

First look at the Logs window (⌥⌘L, or Help > Show Logs). If the Mac logs a
`TCP connection from …` line when the phone tries, the request reached the app and the problem
is in the page or the game state. If it logs nothing, the connection never arrived, so check
the network and the phone.

1. **Same network?** The built-in server only serves phones on the Mac's network. Guest Wi-Fi
   and "client isolation" on routers block phone-to-Mac traffic. For players on other networks
   use the [self-hosted server](self-hosting.md).
2. **Buzzers on?** Settings (⌘,) > Buzzers > **Use phone buzzers**. The port (default 8472)
   applies the next time the server starts.
3. **macOS prompt?** Allow incoming connections / local network access for Macpardy if macOS
   asked and it was declined (System Settings > Privacy & Security).
4. **Android + Chrome shows `ERR_TOO_MANY_RETRIES`?** Chrome needs Android's **Nearby devices**
   (local network) permission to reach a device on the Wi-Fi. Grant it in Android Settings >
   Apps > Chrome > Permissions, then reload. Samsung Internet often already has it. The Mac sees
   no connection at all in this case.
5. **Scanned QR but wrong address?** The join URL uses the Mac's local IP. If the Mac has
   several interfaces (VPN, Ethernet and Wi-Fi), the join screen may show an address the phone
   can't reach; disconnect the VPN or join from the same network the Mac is on.

## Phones keep dropping

Open the Logs window and filter by the team or phone. The reason for each drop is logged
(network loss, page backgrounded, timeout). **Export Logs…** writes a file you can attach to a
bug report. Logs never contain clue text, answers or Final answers.

## "Reconnecting to the buzzer server…" (self-hosted)

Control shows this when the Mac lost its connection to your server. The room is kept for a
30–60 s grace period; if the Mac reconnects within it, play continues. After that the server
ends the session and the error offers to restart the buzzers. See
[self-hosting.md](self-hosting.md) and the server repo's guide.

## A board won't load

The error sheet names the file problem. Check [board-format.md](board-format.md) (`.macpardy`
and `.json`) or [csv-import.md](csv-import.md) (`.csv` column headers are fixed English names).
A sandboxed app can only read files you picked in the open dialog.

## Resume a crashed game

Games auto-save. Relaunch and use the resume option on the start screen
([architecture.md](architecture.md#persistence-auto-save)).

## Build problems

- **Missing project or `MacpardyAsset` symbols:** run `tuist generate --no-open`. Re-run it after
  adding, moving or deleting files or color sets.
- **Package resolution errors:** the `BuzzerCore` pin in `Project.swift` must be a released
  version of the buzzer repo.
- **SwiftLint `unlogged_tap` failure:** use `LoggedButton` / `.onLoggedTapGesture`, or add
  `// swiftlint:disable:next unlogged_tap - <reason>`.
- **macOS warns the exported app is from an unidentified developer:** expected for ad-hoc
  signed builds, see [EXPORTING.md](../EXPORTING.md#sharing-limits).
- **Wrong Xcode:** the project needs Xcode 26 with the macOS 26.3 SDK
  (`xcode-select -p` to check).
