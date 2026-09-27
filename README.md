# LaunchKeeper (app)

The macOS app for [launchkeeper](https://github.com/tietjen/launchkeeper) —
"Autoruns for macOS", visual. Same core (`LaunchKeeperKit`), same guarantees:
a read-only inventory, one gate without bypass, dry-run before every change,
snapshots/quarantine instead of deletion, verification after every write.

**Status: test releases (0.1.x) — inventory, actions with the privileged helper, watch, in-app updates.**

## Installation (macOS 14+)

```
brew install --cask tietjen/tap/launchkeeper-app
```

Or by hand: download `LaunchKeeper-<version>.dmg` from the
[releases](https://github.com/tietjen/launchkeeper-app/releases), open it and
drag LaunchKeeper into Applications. The app is universal (Apple silicon +
Intel), signed with a Developer ID and notarized; the DMG carries a stapled
ticket, so Gatekeeper accepts it offline too. Keep the app in /Applications —
launchd starts its privileged helper from inside the bundle.

Updates arrive in the app (LaunchKeeper › Nach Updates suchen …, or
automatically): Sparkle installs only DMGs signed with the project's EdDSA
key. The helper comes with the update and restarts in the new version.

## Build

```bash
Scripts/build-app.sh                                   # → dist/LaunchKeeper.app (Developer ID signed)
LAUNCHKEEPER_KIT_PATH=../launchkeeper Scripts/build-app.sh   # against a local launchkeeper checkout
swift test                                             # AppCore tests
```

### Localization

German and English. Keys are the German source text; translations live in
`Localization/Localizable.xcstrings` (open it in Xcode, or edit the JSON).
After changing UI text run `Scripts/localize.sh` — it collects every
localizable string through the compiler, adds new ones (English marked
"new") and drops unused ones; `Scripts/localize.sh --check` (CI) fails while a
string lacks its translation. `build-app.sh` compiles the catalog into the
bundle's `de.lproj`/`en.lproj`; other system languages fall back to English.

### Cutting a release (maintainer)

Bump `VERSION`, add a `## [x.y.z]` section to `CHANGELOG.md`, commit, then push
the tag `vx.y.z` to GitHub: `.github/workflows/release.yml` runs
`Scripts/release.sh` (universal build, notarize + staple app and DMG, Sparkle
signature, `appcast.xml`) and publishes the release — the in-app feed is
`releases/latest/download/appcast.xml`. Rehearse locally without Apple:
`Scripts/release.sh x.y.z --no-notarize` (needs `rbw` unlocked for the
Sparkle key).

Requirements: macOS 14+, Swift 6 (Xcode 16+).

## Architecture

- `AppCore` — UI-free logic on top of `LaunchKeeperKit` (loading, filtering, counting); tested.
- `LaunchKeeperGUI` — the SwiftUI app (installed as `LaunchKeeper.app`): sidebar, table, detail, queue.
- `HelperShared` / `HelperCore` / `LaunchKeeperHelper` — the privileged helper
  (Phase 5): an SMAppService daemon inside the app bundle, reached over XPC with
  code-signing requirements on both sides (team-signed app ↔ team-signed
  helper). It never runs commands it is sent — only "operation + entry key /
  quarantine name / package id" — and resolves, gates, plans and verifies with
  the same engines as the CLI, as root. Every execution needs LaunchKeeper's
  own authorization right (`de.paranoidsecurity.LaunchKeeper.modify`: admin,
  not shared, no grace period → Touch ID or password each time). The app sends
  an empty authorization; the helper requests the right on it with interaction
  allowed, so macOS asks in the user's session right before the action. The
  app never sends requests to a helper of another version and offers a restart. `sudo` steps of a plan run
  directly, but only for an allowlist of tools at fixed paths. Audit lines go
  to `/Library/Logs/launchkeeper/operations.log`. The quarantine lives in the
  user's home, so root trusts nothing there it did not make itself: entries
  the helper creates stay root-owned, it never chowns into the home, missing
  quarantine directories are created through descriptors without following
  symlinks, and it restores or purges only entries that are root-owned from
  the entry down (helper 0.1.7).
- Set up once: LaunchKeeper › Settings (⌘,) › Einrichten, then allow it in
  System Settings › General › Login Items & Extensions. Keep the app in
  /Applications — launchd starts the helper from inside the bundle.
- Watch (Phase 7): the CLI's `InventoryWatcher` inside the app. Every scan of
  the app (launch, ⌘R, after an action, FSEvents on autostart locations, a full
  check every ten minutes) is compared with the last complete one; incomplete
  scans are never compared. New or changed entries become macOS notifications
  (a click selects the entry); changes LaunchKeeper made itself are listed as
  its own, never notified. Events go to `~/Library/Logs/launchkeeper/watch.log`,
  the same JSON lines as `launchkeeper watch`. While on, an eye in the menu bar;
  optional launch at login (`SMAppService.mainApp`).
- Taking away a working entry (kit 0.10, `remove --working`): offered after
  "Deaktivieren" as "In die Quarantäne verschieben" — disabled, then its plist
  moved into the quarantine (restorable in the app), never deleted.
- Coming: Sparkle updates.

## Conventions

- **Comments to industry best practice:** DocC `///` on every type, property,
  initializer and function (summary line, then `- Parameters:` /
  `- Returns:` / `- Throws:` where they apply); inline `//` comments say *why*
  — constraints, safety rules, lessons from live runs — never what the code
  plainly does. A file header names what the file is for.
- UI text is German by default (`defaultLocalization: "de"`), English follows.
- Swift 6 strict concurrency; scans and checks never run on the main thread.

MIT License.
