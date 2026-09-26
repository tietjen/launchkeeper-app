# LaunchKeeper (app)

The macOS app for [launchkeeper](https://github.com/tietjen/launchkeeper) —
"Autoruns for macOS", visual. Same core (`LaunchKeeperKit`), same guarantees:
a read-only inventory, one gate without bypass, dry-run before every change,
snapshots/quarantine instead of deletion, verification after every write.

**Status: in development (Phase 1 of 7 — window + read-only inventory).**

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

MIT License.
