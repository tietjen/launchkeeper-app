# Changelog

All notable changes to the LaunchKeeper app are documented here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). The engine
underneath is [launchkeeper](https://github.com/tietjen/launchkeeper)
(`LaunchKeeperKit`); its changes are listed there.

## [Unreleased]

### Security
- **Privileged helper 0.1.7 closes two ways to root through the quarantine**
  (found by an independent review; present since the helper arrived in
  0.1.0). The quarantine lives in the user's home, which any process of the
  user can change. (1) The helper chowned the quarantine's bookkeeping back
  to the user as root — a symlink placed there redirected that chown onto a
  system directory. (2) A restore moved back, as root, whatever the entry
  held to whatever its manifest named — after the entry had been handed to
  the user, both could be swapped, and one legitimate Touch ID for
  "Restore" would have placed a foreign file anywhere as root.
  Now the helper never chowns into the home; entries it creates stay
  root-owned (readable, not changeable by the user); missing quarantine
  directories are created through directory descriptors without following
  symlinks; restoring or purging as root requires the entry, its manifest
  and every path below it to be root-owned and free of symlinks. Entries an
  older helper handed over are therefore refused for restores with
  administrator rights — check them and move them back by hand.

### Added
- Batch processing: tick entries in any view (inventory, background, packages,
  app leftovers, quarantine); the detail column then offers the possible
  actions with "n of m" and adds them to the **queue** (bottom of the sidebar).
  In the queue every entry's action can be switched or the entry removed;
  "Check plan" works out all of them against ONE scan, "Run all" asks for
  Touch ID once for every administrator step, shows progress per entry and
  overall, can be stopped after the entry in progress, and a failure does not
  stop the rest. Finished actions can queue their way back (enable ↔ disable,
  restore from the quarantine). The queue survives a restart.
- Uses launchkeeper 0.11 batches (one scan instead of one per entry) and a
  batch call in the privileged helper (0.1.5).

## [0.2.0] — 2026-09-27

### Added
- English. The app follows the system language: German or English; any
  other language falls back to English. All 312 texts of the interface —
  views, next steps, verdicts, risk hints, notifications, menus, settings —
  plus the Touch ID / password prompt of the helper.
- `Localization/Localizable.xcstrings` (String Catalog, editable in Xcode) as
  the single source of translations; `Scripts/localize.sh` collects the
  strings through the compiler and `--check` fails CI when one lacks an
  English translation.

### Changed
- Privileged helper 0.1.4: brings the prompt of its authorization rule up to
  date (German and English) on existing installations; the rest of the rule
  is left as it is.

Messages that come from the launchkeeper engine (plans, refusals, gate
reasons) stay English in both languages, as in the CLI.

## [0.1.1] — 2026-09-27

The first update through Sparkle — it exists to prove the update path.

### Changed
- Privileged helper 0.1.3 (no functional change): after the update the app
  runs the helper from the new bundle; an older helper still running is
  detected and restarted, as since 0.1.0.
- Releases are built by GitHub Actions from the tag (notarized, stapled,
  Sparkle-signed); a manual probe run checks the pipeline without publishing.
- README: installation via Homebrew (`brew install --cask tietjen/tap/launchkeeper-app`).

## [0.1.0] — 2026-09-27

First public test release.

### Added
- Inventory of everything that starts automatically (LaunchAgents/Daemons,
  login items, extensions, helpers, cron, shell startup, network listeners,
  profiles …) with categories, search, badges and an Apple filter.
- Basic and expert detail view: what an entry is, whether it runs, who signed
  it, where it came from, what it really executes — and the next steps.
- Dedicated views: background items (as in System Settings), installer
  packages, leftovers of removed apps, the quarantine, the watch.
- Actions with a plan first and verification after: disable/enable, move
  leftovers and working launch plists into the quarantine, restore, uninstall
  packages — the same gate as the CLI, no bypass.
- Privileged helper (SMAppService) for administrator steps: Touch ID or
  password each time, only "operation + entry", never commands.
- Watch: file-system events and a periodic full check report new or changed
  entries as notifications; LaunchKeeper's own changes are labelled, not
  notified. Menu-bar item while watching, optional launch at login.
- "Copy hash for VirusTotal" for programs (no upload, no network).
- In-app updates via Sparkle (EdDSA-signed, notarized DMGs from GitHub).
