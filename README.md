# LaunchKeeper (app)

The macOS app for [launchkeeper](https://github.com/tietjen/launchkeeper) —
"Autoruns for macOS", visual. Same core (`LaunchKeeperKit`), same guarantees:
a read-only inventory, one gate without bypass, dry-run before every change,
snapshots/quarantine instead of deletion, verification after every write.

**Status: in development (read-only so far: inventory with basic/expert detail, background, packages, app leftovers, quarantine — actions next).**

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
- Coming: a privileged helper (SMAppService daemon, XPC, Touch ID) that never runs
  commands it is sent — only "operation + entry key" through the same gate and
  engine as the CLI — and Sparkle updates.

## Conventions

- **Comments to industry best practice:** DocC `///` on every type, property,
  initializer and function (summary line, then `- Parameters:` /
  `- Returns:` / `- Throws:` where they apply); inline `//` comments say *why*
  — constraints, safety rules, lessons from live runs — never what the code
  plainly does. A file header names what the file is for.
- UI text is German by default (`defaultLocalization: "de"`), English follows.
- Swift 6 strict concurrency; scans and checks never run on the main thread.

MIT License.
