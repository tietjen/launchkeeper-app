# Changelog

All notable changes to the LaunchKeeper app are documented here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). The engine
underneath is [launchkeeper](https://github.com/tietjen/launchkeeper)
(`LaunchKeeperKit`); its changes are listed there.

## [1.1.2] — 2026-09-30

### Changed
- With ticked rows, the detail column shows the selection panel on top and,
  below it, still the explanation of the clicked row (resizable divider);
  before, the panel replaced it (TJ).

### Fixed
- The toolbar buttons of the Pakete, App-Reste and Quarantäne views explain
  themselves on hover; "Neu prüfen" in App-Reste says it only searches the
  leftovers again, not the inventory.

## [1.1.1] — 2026-09-30

### Fixed
- Introduction (TJ's test of 1.1.0): a step outlines everything its card
  talks about — all three toolbar buttons, all four rows under "Ansichten",
  the watch row and the watch switch. The sidebar scrolls the row a step
  talks about into view first, and the watch and queue steps open their view,
  so the card points at the row instead of falling back to the middle of the
  window. The views and toolbar cards list their items one per line; the
  watch card and the help say where the watch is switched on.

## [1.1.0] — 2026-09-30

### Added
- Help: Help › "LaunchKeeper-Hilfe" (⌘?) opens a help window with chapters —
  overview and workflow, the inventory and its symbols, the views, actions and
  safety, the helper, the queue, watch and notifications, keyboard shortcuts,
  the command line and frequent questions — and a search over all of it.
  German and English, like the rest of the app.
- Introduction at launch: step by step it outlines the parts of the window
  (sidebar, list, detail column, toolbar, views, watch, queue) and explains
  them in a card next to them; welcome, helper and end come as a sheet. It
  opens hidden columns it needs and falls back to a sheet where a card cannot
  appear. Switch it off in the introduction ("Beim Start zeigen") or in
  Settings › Hilfe; Help › "Einführung zeigen" and Settings start it again.

### Changed
- LaunchKeeper has one main window. Opening it again (menu bar, a
  notification, the Help menu) brings it forward, also when minimized.
- The quarantine view names the real way to delete for good (`launchkeeper
  quarantine purge` in Terminal) instead of a feature to come.

## [1.0.0] — 2026-09-28

The first stable release: every planned phase is done and the acceptance
test on a second Mac passed (installation, updates, helper, Touch ID, the
queue, the watch, the CLI from Homebrew).

### Changed
- Far fewer Touch ID prompts. Reading Background Task Management (`sfltool
  dumpbtm`) makes macOS ask for administrator authentication — on launch,
  ⇧⌘R, "Jetzt prüfen" and, with the watch on, every ten minutes. With the
  helper set up, the helper reads it as root and nothing is asked. Without
  the helper, the watch's periodic check reads it fresh at most every six
  hours (a cancelled dialog counts as a read); file events still trigger
  quick rescans at once. If the helper is there but fails, the kept dump is
  used instead of asking, and the watch waits six hours before trying again.
- Needs launchkeeper 0.12.2.

### Security
- Privileged helper 0.2.0 with a new read-only call, `readBTM`, that asks
  for no authorization. Trust decision: it hands back only the system's
  sections (UIDs below 500) and the caller's own — the caller's UID comes
  from the XPC connection — never other users' login items. On a Mac with
  several users, a user without administrator rights can therefore see the
  system-wide background items through LaunchKeeper without a dialog; most
  of them are readable from /Library anyway. Only the team-signed app can
  call the helper.

### Added
- Settings › Beobachtung explains the most common reason for a missing
  banner: macOS suppresses banners while the screen is shared or mirrored
  (found in the acceptance test on a second Mac used via Screen Sharing).

## [0.3.5] — 2026-09-28

### Added
- Notifications can be checked from the app. Settings › Beobachtung shows
  what macOS allows ("Mitteilungen laut macOS": allowed, not allowed, not
  asked yet, allowed without banners) and offers "Test-Mitteilung senden",
  "Mitteilungseinstellungen öffnen" (LaunchKeeper's page in System Settings)
  and, while undecided, "Erlaubnis anfragen".
- Every watch record says what became of its notification — only what can
  be measured: refused by macOS (with its error), handed over and listed in
  the Notification Center or not, released for display while LaunchKeeper
  was in front, clicked — or why none was sent (own action, removal,
  notifications off, not allowed). Found on a second Mac, where a
  notification went missing without a trace. The permission line refreshes
  when you come back from System Settings.

## [0.3.4] — 2026-09-28

### Fixed
- The queue's buttons were truncated in a narrow column ("Erledigte e…",
  "Alle ausfüh…"). The footer now wraps onto two or three rows instead, and
  every queue button (also "Herausnehmen", "Markierung aufheben", "Jetzt
  prüfen", the add buttons of the selection panel) names itself and explains
  what it does on hover.

## [0.3.3] — 2026-09-28

### Changed
- Network listeners queued "by hand" are no longer ticked off automatically.
  A listener is in the inventory only while its program runs, so its
  disappearance may just mean the program quit. The row says so and the
  user ticks it off (and can open it again even when it is gone).

### Fixed
- The saved queue is read item by item: an entry this version cannot read
  (for example one written by a newer version before a downgrade) drops
  alone instead of emptying the whole queue. Whenever something could not be
  read, the file is kept unchanged as `queue-unreadable-<date>.json` next to
  `queue.json` (owner-only) and the queue shows a notice once. If that copy
  cannot be made, the app does not save the queue in that session, so the
  only copy is never overwritten.

### Security
- `queue.json` and its copies are created owner-only (0600) from the first
  byte instead of being written and then restricted, and the app's support
  folder is set to 0700.
- Note: versions before 0.3.3 lose the whole queue when they meet an entry
  they cannot read — downgrading below 0.3.3 may empty it.

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
