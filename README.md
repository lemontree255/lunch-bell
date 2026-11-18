# Lunch Bell

A small native macOS menu bar app that makes lunch hard to forget. **11:21 every day**, or whatever time you choose. SwiftUI + AppKit; no dependencies, accounts, tracking, or network access.

## The alert

A floating window appears above your apps and stays until you choose **I’m going** or **Snooze 10 min**. A Glass sound plays immediately and repeats every 30 seconds until you respond; sound is optional. There is no default Return-key action, so typing in another app should not accidentally dismiss lunch.

This uses an ordinary app window rather than a Notification Centre banner, so it needs no notification permission. The panel is configured to join all Spaces, including full-screen Spaces, using [AppKit’s panel behaviour](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/fullscreenauxiliary). It does not raise the system volume or use Apple’s restricted critical-alert entitlement.

## Install

Requires **macOS 13 Ventura or later**.

1. Download `Lunch-Bell-macOS.zip` from [Releases](https://github.com/lemontree255/lunch-bell/releases).
2. Unzip and move **Lunch Bell.app** to Applications.
3. Open it. Settings appear on the first launch; afterwards use the fork-and-knife menu bar icon.
4. Choose your time, try the alert, and enable **Open at login** if wanted. macOS may require approval in System Settings → General → Login Items.

Releases are ad-hoc signed, **not notarised with an Apple Developer account**. macOS may block a downloaded copy. If you trust the source, use System Settings → Privacy & Security → Open Anyway after the first launch attempt, or build locally.

## Behaviour

- Runs every day, including weekends. Settings are saved locally using UserDefaults.
- Checks every five seconds while running. No reminder while the app is quit or the Mac is shut down.
- If the Mac sleeps through lunch, it catches up after wake until 15:00. For lunch times after 14:00, the catch-up window ends one hour after the configured time, or at midnight if earlier. It does not wake the Mac.
- Snoozes last ten minutes, survive an app restart, and expire at the end of the local calendar day. Acknowledging suppresses further alerts for that day, including after restarting or changing the time.
- Pausing closes a visible alert. Resuming within the catch-up window can show it again if it has not been acknowledged.
- **Try the alert** is a preview: its buttons do not change today's reminder or snooze.
- Muted audio remains muted. The window remains visible; nothing can appear over the macOS lock screen, and full-screen app behaviour can vary.
- Quit from the menu bar icon. To uninstall, quit, turn off Open at login, and remove the app.

## Build

Install Apple’s Command Line Tools (`xcode-select --install`), then:

```sh
./scripts/build.sh
open "dist/Lunch Bell.app"
```

Build a universal Intel + Apple Silicon release with `./scripts/build.sh --universal`. Run schedule regression checks with `./scripts/check.sh`. These use plain Swift assertions, so full Xcode and XCTest are not required. No Xcode project is needed.

To preview without waiting for lunch:

```sh
open "dist/Lunch Bell.app" --args --preview
```

## Licence

MIT. See [LICENSE](LICENSE).
