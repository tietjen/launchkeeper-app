# Changelog

All notable changes to the LaunchKeeper app are documented here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). The engine
underneath is [launchkeeper](https://github.com/tietjen/launchkeeper)
(`LaunchKeeperKit`); its changes are listed there.

## [0.3.2] — 2026-09-27

### Added
- Rows already in the queue are marked in their view: a queue symbol instead
  of the checkbox (blue open, green done, orange refused), whose help names
  the queued action; a click takes the row out of the queue again. The
  detail column says "In der Warteschlange: …" with "Herausnehmen". A
  background row with only some components queued keeps its checkbox and
  shows "x/y".

### Security
- Privileged helper 0.1.9 (launchkeeper 0.12.1): it refuses entries that
  belong to one user (user domain, per-user extension elections, config
  files in a home) — those the app changes itself; a system daemon whose
  program lives in a home stays removable. Uninstalls through the helper
  refuse packages that would move files out of places a non-root user can
  change (/Users, temp directories, /Volumes, /opt/homebrew, or any
  directory on the way not owned by root or writable by everyone), and it
  restores nothing into such places.

## [0.3.1] — 2026-09-27

### Added
- **By hand** in the queue: entries neither the app nor the helper may change
  (login items and background items macOS manages, system extensions, kernel
  extensions, listening programs) can be queued too. The queue shows what to
  do and opens the right place in System Settings; "Check now" reads
  everything afresh (⌘R reuses the cached background-items state) and ticks
  off what is gone or switched off, or you tick it yourself. An incomplete
  scan never counts a missing entry as done. Apple's own entries are never
  offered. (A queue with by-hand items cannot be read by 0.3.0 after a
  downgrade.)

## [0.3.0] — 2026-09-27

### Security
- **Privileged helper 0.1.8: root keeps nothing in your home any more.**
  Four independent reviews (Fable) found that the helper, running as root,
  worked with paths inside `~/Library/Application Support/launchkeeper`,
  which any process of your user can change — renames and symlinks between
  root's check and root's write could redirect a chown, a restore or a
  snapshot onto system files, i.e. a way to root. Present since the helper
  arrived in 0.1.0; fixed now:
  - The helper keeps its quarantine, backups and config snapshots in a tree
    only root can write: `/Library/Application Support/launchkeeper`. It
    creates it when missing and checks the whole chain before every request.
  - It removes and snapshots only in `/Library/LaunchAgents` and
    `/Library/LaunchDaemons`; snapshots never follow symlinks and are never
    more readable than the original.
  - It restores only its own entries, after checking ownership and meaning
    (each file goes back exactly where it came from — never into your home
    or /System). Entries in your own quarantine (made by the CLI or by
    older versions) are restored in Terminal; the app shows the command.
- Earlier in this release cycle (helper 0.1.7): no chown into the home, no
  restore of user-owned entries as root (superseded by the above).

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
- Uses launchkeeper 0.12 (batches: one scan instead of one per entry;
  the root-owned tree) and a batch call in the privileged helper.

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
