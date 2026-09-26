# LaunchKeeper (app)

The macOS app for [launchkeeper](https://github.com/tietjen/launchkeeper) —
"Autoruns for macOS", visual. Same core (`LaunchKeeperKit`), same guarantees:
a read-only inventory, one gate without bypass, dry-run before every change,
snapshots/quarantine instead of deletion, verification after every write.

**Status: in development (Phase 5: privileged helper — admin actions with Touch ID, same gate as the CLI).**

## Build

```bash
Scripts/build-app.sh                                   # → dist/LaunchKeeper.app (Developer ID signed)
LAUNCHKEEPER_KIT_PATH=../launchkeeper Scripts/build-app.sh   # against a local launchkeeper checkout
swift test                                             # AppCore tests
```

Requirements: macOS 14+, Swift 6 (Xcode 16+).

## Architecture

- `AppCore` — UI-free logic on top of `LaunchKeeperKit` (loading, filtering, counting); tested.
- `LaunchKeeper` — the SwiftUI app: sidebar by category, table, detail.
- `HelperShared` / `HelperCore` / `LaunchKeeperHelper` — the privileged helper
  (Phase 5): an SMAppService daemon inside the app bundle, reached over XPC with
  code-signing requirements on both sides (team-signed app ↔ team-signed
  helper). It never runs commands it is sent — only "operation + entry key /
  quarantine name / package id" — and resolves, gates, plans and verifies with
  the same engines as the CLI, as root. Every execution needs LaunchKeeper's
  own authorization right (`de.paranoidsecurity.LaunchKeeper.modify`: admin,
  not shared, no grace period → Touch ID or password each time), requested by
  the app and verified again by the helper. `sudo` steps of a plan run
  directly, but only for an allowlist of tools at fixed paths. Audit lines go
  to `/Library/Logs/launchkeeper/operations.log`.
- Set up once: LaunchKeeper › Settings (⌘,) › Einrichten, then allow it in
  System Settings › General › Login Items & Extensions. Keep the app in
  /Applications — launchd starts the helper from inside the bundle.
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
