# Feature reference

*Deutsch: [Funktionsreferenz](../funktionen.md)*

Every feature by area: **where** it is, **what** it does, **where its limit** lies. For looking
things up — for learning there is the [manual](manual/), for understanding
[How LaunchKeeper is built](architecture.md).

Two terms come up often: the **background tasks** (Background Task Management, BTM for short) are
the list in which macOS keeps apps' login items and background services. The **dump** is the list
of background tasks as read by `sfltool dumpbtm`.

- [Window and views](#window-and-views)
- [Inventory and detail column](#inventory-and-detail-column)
- [Actions](#actions)
- [Queue](#queue)
- [Watch and notifications](#watch-and-notifications)
- [Helper](#helper)
- [Quarantine](#quarantine)
- [Settings](#settings)
- [Help and introduction](#help-and-introduction)
- [Keyboard shortcuts](#keyboard-shortcuts)
- [Limits and fixed values](#limits-and-fixed-values)
- [What LaunchKeeper does not do](#what-launchkeeper-does-not-do)

## Window and views

| What | Where | Limit |
|---|---|---|
| **Main window** | — | There is **one** main window (since 1.1.0). Opening from the menu bar, a notification or the Help menu brings it to the front, even from the Dock. Minimum size 980 × 560. |
| **Sidebar** | left | Sections *Inventory* (All entries, Orphaned), *Categories*, *Views* (Background, Packages, App leftovers, Quarantine, Watch) and *Batch processing* (Queue). The counts follow **Hide Apple**, not the search — they stay put while you type. |
| **Categories** | sidebar | only categories with entries: Launch Items, Login Items & Background, App Extensions, System Extensions & Kexts, Privileged Helper Tools, Scheduled, Legacy Persistence, Shell Startup, Plug-in Directories, Network, Profiles / MDM, Privacy (TCC). **Scheduled** also shows launchd services with a schedule. The command line uses the same category names. |
| **Inventory table** | center | Columns: checkbox, icons (at most three), Name, Category, Origin, Signature, Path. All except checkbox and icons are sortable; default: Name ascending. The selection is tied to the stable key and survives a rescan. |
| **Search** | toolbar, only in inventory views | searches name, label, key, path, program, bundle ID, team and app; case does not matter |
| **Hide Apple** | toolbar | default **on**. If you jump to an Apple entry (watch, notification, **Show in inventory**), it switches itself off. |
| **Basic / Expert mode** | toolbar, *View › Expert mode* (⌥⌘E) | is remembered; applies to the inventory's detail column |
| **Rescan** | toolbar, *View* (⌘R) | reuses this session's dump of the background tasks; locked while a scan is running |
| **Full rescan** | *View* (⇧⌘R) | also queries the background tasks again (`sfltool dumpbtm`) — the first time after a longer idle period can take minutes |
| **Status bar** | bottom, floating | appears only while scanning (with progress text) or when the inventory is incomplete — then it names the sources that did not answer |
| **Background** | sidebar › Views | the same list as *System Settings › General › Login Items & Extensions*: **Open at login**, then one row per app or developer with a switch (on, off, mixed, App, –). An orange mark flags components that are off via launchd — invisible in System Settings. Entries without a developer have their own section. |
| **Packages** | sidebar › Views | installer receipts (`pkgutil`): Package, Version, Installed, Files, Missing, Entries. **Only with missing files** shows only packages that are missing something. |
| **App leftovers** | sidebar › Views | loads the first time it is opened (about 30 s: LaunchServices, Spotlight, app folders). Shows only apps that are **provably** gone; **Also show present/unclear** shows all verdicts. **Check again** searches only the leftovers again, not the inventory. |
| **Quarantine** | sidebar › Views | both quarantines in one list — see [Quarantine](#quarantine). No detail column. |
| **Watch** | sidebar › Views | the count counts new and changed entries that LaunchKeeper did not cause itself |
| **Queue** | sidebar › Batch processing | the count counts open entries |
| **Check for Updates …** | *LaunchKeeper* menu | only in the installed app (a bundle with an update feed); dimmed in a developer build |

## Inventory and detail column

### The icons in the list

| Icon | Means | Limit |
|---|---|---|
| ⚠︎ orange | **Orphaned** — the source is provably missing | — |
| leaf, gray | **Leftover** — only an entry in the background tasks remains | replaces **Orphaned** when both apply; macOS cleans up such entries itself |
| signature, red | **Not signed** | — |
| eye, yellow | **Worth a look** | a hint to check, **not** a malware verdict |
| pause, gray | **Disabled** | launchd override, pluginkit choice, commented-out cron line … |
| play, green | **Running** right now | — |

### The check hints

| Hint (core) | In the app |
|---|---|
| `third-party-plist-runs-system-binary` | third-party entry runs a macOS program |
| `shell-interpreter-service` | starts a shell or interpreter |
| `unsigned-executable` | program is not signed (or only ad hoc) |
| `temp-or-hidden-path` | program lives in a temporary or hidden folder |
| `user-writable-daemon-binary` | system service whose program can be changed without administrator rights |
| `downloads-executable` | program is started straight from “Downloads” |

### Detail column

| What | Where | Limit |
|---|---|---|
| **Basic mode** | right, default | traffic light (Nothing unusual · Leftover · Worth a look · Orphaned), one sentence in plain language, the facts (running, signed by, from package …) and the **Next steps**. **Show all details** expands the expert sections for this one entry. |
| **Expert mode** | ⌥⌘E | identity and state, Files (with **Show in Finder**), Finding, Origin & signature, Control (level, actions, mechanism, reason), Sources, all metadata |
| **Verify signature thoroughly** | Expert mode › Origin & signature | on demand, not during the scan: `codesign --verify --strict`, Gatekeeper, Hardened Runtime, certificate chain, SHA-256 |
| **Next steps** | Basic mode | only what the check allows: Remove · Disable (reversible) · Enable again · Move into quarantine · Copy hash for VirusTotal · Show in Finder · **Not controllable here** with the reason. A lock marks steps that need administrator rights. |
| **Run…** | on a next step | opens the plan sheet (see [Actions](#actions)) |
| **Copy command** | on a next step without an app action | the `launchkeeper` command without `--apply` — in the Terminal it first shows the plan |
| **Copy hash for VirusTotal** | next step | only for program code (Mach-O or the main program of a bundle); not for configuration files and not for Apple's platform paths (`/System`, `/usr`, `/bin`, `/sbin`). No network: the hash only lands on the clipboard. |
| **Selected rows** | checkbox in every view | at the top of the detail column the **selection panel** (“N selected”), below it still the explanation of the clicked row (movable divider, since 1.1.2) |
| **In the queue: …** | detail column | if the entry is in the queue, a note names the action; **Take out** takes it out again |

## Actions

Every action goes through the same sheet: **plan** (dry run, nothing changes) → **Run** (second
click) → **verified result**.

| What | Where | Limit |
|---|---|---|
| **Disable** | Next steps, queue | only for active entries; reversible with Enable |
| **Enable again** | Next steps, queue | only for disabled entries |
| **Remove** | Next steps, queue | only if the check allows it — for launchd entries only for **orphaned** ones. A leftover goes into the quarantine; an orphaned launch file is deleted, after a backup has been made. |
| **Move into quarantine** | Next steps (after **Disable**), queue | for working entries: first disabled, then the launch file moves into the quarantine. The program itself stays. |
| **Move leftovers into quarantine** | App leftovers | never through the helper (the “app is gone” check needs the user's LaunchServices); if the plan would need administrator rights, the sheet shows the Terminal command. Data in `~/Library/Containers` (and `Group Containers`) needs **Full Disk Access** for LaunchKeeper — without it macOS refuses the move, and the run stops at the first refused step. If it moved nothing, since kit 0.13.1 no empty quarantine entry is left behind. |
| **Restore from quarantine** | Quarantine, queue | see [Quarantine](#quarantine) |
| **Uninstall package** | Packages › detail column, queue | **always** needs administrator rights. Takes only files that still come unchanged from the package; changed and shared ones stay. Everything goes into the helper's quarantine. |
| **Remove receipt** | Packages, when none of its own files are left | forgets the installer receipt; a copy stays in the quarantine |
| **Plan sheet** | after **Run…** | each step in words, the command below it; notes from the core and the way back. It cannot be cancelled during planning and execution. Why **Run** is missing is always shown visibly below the plan. |
| **Run (Touch ID)** | plan sheet | appears when the plan has steps with administrator rights and the helper is set up, allowed and in this app's version |
| **Without the helper** | plan sheet | button **Set up helper** or **Allow in System Settings**, **Open Settings**, and the Terminal command with `--apply` to copy |
| **Outdated helper** | plan sheet | **Restart helper**; until then the app sends it nothing |
| **Helper ran nothing** | result | **Restart and try again** then recomputes the plan |
| **Incomplete** | result | since 1.2.1 with an explanation when the cause is known; if macOS denies access to `~/Library/Containers`, also **Open Full Disk Access** |
| **While the queue is running** | plan sheet | **Run** is locked until the run is over |
| **Log** | — | the app's own actions: `~/Library/Logs/launchkeeper/operations.log` (the same file as the command line); the helper's actions: `/Library/Logs/launchkeeper/operations.log` |

What needs administrator rights is decided by the same core as in the Terminal: system services
(launchd domain `system`), launch files under `/Library/`, system-wide login scripts, the
firewall, quarantine leftovers outside your home folder, and every package uninstall. App
extensions (pluginkit) and your crontab need none.

## Queue

| What | Where | Limit |
|---|---|---|
| **Selecting** | checkboxes in Inventory, Background, Packages, App leftovers, Quarantine | checkboxes are separate per view and survive switching between views. A Background row stands for its components. |
| **Add to queue** | right column, as soon as something is selected | one button per possible action with “n of m” — only the entries the action fits. Afterwards the used checkboxes disappear. |
| **Add to the queue as “By hand”** | right column | for selected entries without an automatic action; **never** for Apple's own |
| **Queued rows** | in every view | a queue icon instead of the checkbox (blue open, green done, orange refused or failed); a click takes the row out. A Background row with only some of its components queued shows “x/y”. |
| **One target, one entry** | — | an entry is never in the queue twice; adding it again replaces the action |
| **Sections** | list | since 1.2.1: **Open**, **Failed or refused**, **Done**, **By hand** (before, one section “Automatic”); empty ones are left out |
| **Reason in the row** | row | “failed: …”/“refused: …” with a short reason in words when known (“macOS denies access — Full Disk Access missing”, “nothing left to do”), otherwise the core's message |
| **Failed or refused** | section footer | says that these entries did not run, or not completely, and names the common cause (Full Disk Access) when it applies. Buttons **Open Full Disk Access** (only then), **Try again** (failed and refused back to open; **Run all** then tries them once more), **Remove from the list** (nothing is run) |
| **Detail of a failed entry** | right column | a **Failed** or **Refused** section: explanation, the unchanged **Message**, **Open Full Disk Access** / **Try again** / **Remove from the list** — also after a restart (the run's outcome is not kept, the state is) |
| **Changing the action** | row in the queue | among the actions the entry offers; the plan is checked again |
| **Check plan** | bottom | computes all open entries in **one** pass — one scan for all Disable/Enable/Remove. Rejected and failed ones are checked again. |
| **Run all** | bottom, ↩ | checks open plans first. Then all entries with administrator rights in **one** call to the helper with **one** Touch ID prompt that states the number — then the rest. One failure does not stop the others. |
| **Touch ID cancelled** | — | if all administrator entries come back as “not authorized”, the rest do not run either: “not run — authentication cancelled” |
| **Without the helper** | — | entries with administrator rights are rejected with a reason; the rest run |
| **Stop** | bottom, during the run | after the current entry; the rest is reported as “not run”. Also applies to the part in the helper. |
| **Order** | — | first all steps with administrator rights, then the rest; within each, Remove, Disable and Enable before Restore and Uninstall. An entry gets only one action per run. |
| **Note on overlaps** | row | if a package is queued for uninstall and at the same time an entry from that package, the row says that the entry's action becomes unnecessary |
| **Add ways back (n)** | bottom, after a run | only for entries finished **in this session**: Disable ↔ Enable, and Restore for everything that went into the quarantine |
| **By hand** | own section | instructions and a button to the right place in System Settings. Checked off automatically when a **complete** scan no longer finds the entry, or an entry that was active when queued is now off; with an incomplete scan only “off” counts. |
| **Check now** | *By hand* section | scans afresh, including the background task switches that ⌘R takes from the cache |
| **Network services** | *By hand* section | are **never** checked off automatically — a program that has quit also disappears from the list; you check them off (and reopen them) yourself |
| **Clear** | bottom | with a confirmation; nothing is run, what has been run stays run |
| **Remove finished** | bottom | takes out successful and checked-off entries; open, rejected and failed ones stay |
| **Saving** | automatic | `~/Library/Application Support/de.paranoidsecurity.LaunchKeeper/queue.json`, readable only by you (0600, folder 0700). Entries and states are saved, not the plans; an interrupted run is back to “open” after launch. |
| **Unreadable entries** | note at the top | an entry this version cannot read (say, from a newer one) is dropped on its own. The file stays unchanged next to it as `queue-unreadable-<date>.json`; if this copy cannot be created, LaunchKeeper does not save the queue until the next launch. |

## Watch and notifications

| What | Where | Limit |
|---|---|---|
| **Watch on/off** | *Watch* view (switch at the top), Settings › Watch, menu bar (**Turn off watch**) | the setting works even without an open window; when you turn it on, macOS asks once for permission to send notifications |
| **Immediately** | — | when something writes to an autostart location (LaunchAgents/-Daemons, PrivilegedHelperTools, StartupItems, SystemExtensions, paths.d, Applications folders, loginwindow, crontab, shell startup files …), LaunchKeeper rescans after **5 s** of quiet — with the stored dump of the background tasks |
| **Regularly** | — | a full comparison every **10 minutes**. With the helper always with a fresh dump of the background tasks; without it at most every **6 hours** (macOS asks for Touch ID for it — a cancelled dialog counts too) |
| **Comparison** | — | against the last **complete** inventory; an incomplete one is never compared (“Last check incomplete, not compared”). Apple's own entries and pure run states (running, loaded) do not count. |
| **Own changes** | list | what LaunchKeeper changed itself (also up to **30 s** after an action) is listed with “by LaunchKeeper” and **never** reported |
| **List** | *Watch* view | newest first, at most **200**; **Clear list** clears only the display, not the log file. At launch the app reads the latest entries from the log. |
| **Log** | — | `~/Library/Logs/launchkeeper/watch.log` — the same JSON lines as `launchkeeper watch` |
| **Entry detail** | right column | category, path, identifier, changed fields, when and why it was noticed, what became of the notification; **Show in inventory** |
| **Notification** | macOS | only for **new** and **changed** entries, not for own ones and not for removals. A click opens the entry (or the watch, if it is gone). |
| **What became of the notification** | Detail › Noticed › Notification | only what can be measured: not sent and why, rejected by macOS (with error), handed over and in Notification Center or not, released while LaunchKeeper was in front, clicked. Applies to this session, at most **200** entries. |
| **Menu bar** | eye, while the watch is on | state, the last **5** changes by others, **Open LaunchKeeper**, **Turn off watch**, **Quit LaunchKeeper** |
| **Launch at login** | Settings › Watch | via `SMAppService.mainApp`; LaunchKeeper then opens its window and keeps watching when you close it |
| **Turning off** | — | forgets the baseline; the next time you turn it on, it takes a new one |

## Helper

| What | Where | Limit |
|---|---|---|
| **Setting up** | Settings (⌘,) › Helper for administrator rights, or in the plan sheet | then allow it in *System Settings › General › Login Items & Extensions*, then **Check again**. LaunchKeeper never sets it up by itself. |
| **State** | Settings | set up and allowed · waiting for your approval · not set up · not found (app not started from its bundle); plus the version |
| **Removing** | Settings | administrator actions no longer work afterwards; scanning asks for the background tasks by itself again |
| **Restart helper** | Settings, plan sheet | appears when a different version than the app's is running; until then the app sends it nothing |
| **Touch ID / password** | macOS dialog | anew for **every** execution, no grace period; the queue asks once per run and states the number |
| **What it runs** | — | Disable, Enable, Remove, Move into quarantine for system-wide entries — it removes and backs up launch files only in `/Library/LaunchAgents` and `/Library/LaunchDaemons`; Restore and Delete for good only of its own quarantine entries; package uninstall |
| **What it rejects** | — | a user's entries (user domain, app extensions, files in the home folder) — the app changes those itself without administrator rights; moving from places that non-administrators can change (`/Users`, temporary folders, `/Volumes`, `/opt/homebrew`, any folder on the path that does not belong to root or is writable by everyone) |
| **Tools** | — | only `launchctl`, `rm`, `cp`, `mv`, `mkdir`, `defaults`, `pkgutil`, `cksum` and `socketfilterfw`, at fixed paths; any other step is rejected |
| **Reading the background tasks** | on every fresh scan | as root, without Touch ID; returns only the system-wide sections and your own, never those of other users |
| **Updates** | — | comes with the app; quits after **60 s** of idle time, launchd starts the new version on the next call |
| **Storage** | — | quarantine, backups and configuration copies under `/Library/Application Support/launchkeeper` (only root writes there); log under `/Library/Logs/launchkeeper` |

## Quarantine

| What | Where | Limit |
|---|---|---|
| **Two quarantines** | *Quarantine* view | your own (`~/Library/Application Support/launchkeeper/quarantine`, the same as the command line's) and the helper's (`/Library/Application Support/launchkeeper/quarantine`, owned by root) — in one list, newest first |
| **List with selection** | list | since 1.2.1 like the other views: a click shows the entry in the detail column, nothing is expanded |
| **Row** | list | checkbox (see *Selecting*), title (package, the app's bundle ID or entry), the kind below it (“App leftovers”, “Package uninstalled”, “Entry removed”), state and date on the right |
| **Sections** | list | by what the entry holds **right now** — read from disk, not from the status in the manifest: **In the quarantine** (all paths there), **Incomplete — only part arrived** (“N of M paths”), **Empty — nothing moved** (with an explanation below), **Restored** |
| **Detail column** | right column | title, **Kind**, **State**, **Created**, **Store** (“your quarantine” / “System quarantine (helper)”), an explanation of the state; **Paths** with an icon per path (in the quarantine or not) and **Package receipt forgotten**, if a receipt is included; **Reasons** (the evidence, such as why the app counts as deleted) |
| **Restore…** | detail column | opens the plan sheet; missing for empty and restored entries. The helper's entries go through the helper (Touch ID), your own with files in the home folder without administrator rights. |
| **Terminal only** | detail column | an entry of **your** quarantine that would have to put back files outside your home folder (from the command line or an older version): **Copy command** gives `launchkeeper quarantine restore <name>` |
| **What the helper puts back** | — | only entries it created itself, after checking ownership and meaning: every file exactly to its origin, never to `/System`, never into your home folder, never to places users can change |
| **Show in Finder** | detail column | the entry's folder |
| **Delete for good…** | detail column | since 1.2; opens the plan sheet: one step `rm -rf -- <entry folder>`, the number of paths, red notice “Cannot be restored …”. Run with **Delete for good** or “Delete for good (Touch ID)” — by click only, never with ↩. The helper's entries are deleted by the helper (only its own, Touch ID every time); your own that are yours through and through by the app without administrator rights; yours with files only root may delete only by the Terminal (`launchkeeper quarantine purge <name> --apply`). One at a time, not in the queue; restored entries too |
| **Remove empty entries (n)** | toolbar | since 1.2.1; only when **your** quarantine has empty entries. With a confirmation; deletes only entries without any file (failed attempts), as you, without Touch ID; afterwards “n empty entries removed.” Empty entries of the system quarantine not in one go — those one at a time with **Delete for good…** |
| **Reload** | toolbar | reads the entries again, for example after changes in the Terminal |
| **Selecting** | checkbox | only for entries that can be restored in the app — not for empty, restored or **Terminal only** ones |

## Settings

Settings (⌘,) have four sections:

| Section | Content |
|---|---|
| **Helper for administrator rights** | state, version, Set up helper / Allow in System Settings / Remove, Check again, Restart helper for an outdated version |
| **Watch** | **Watch for new autostart entries**, **Notify about new or changed entries** (default **on**), **Notifications according to macOS** (allowed · not allowed · not asked yet · allowed, but without banners), **Send test notification**, **Ask for permission** (only while undecided), **Open notification settings**, the note about banners during screen sharing, **Launch at login** |
| **Help** | **Show introduction at launch** (default **on**), **Show introduction now**, **Open Help** |
| **Updates** | version and build, **Check for updates automatically**, **Check for updates now** — only in the installed app |

## Help and introduction

| What | Where | Limit |
|---|---|---|
| **LaunchKeeper Help** | *Help* (⌘?), Settings › Help | its own window, **10** chapters (Overview, The Inventory, The Views, Actions and Safety, The Helper, The Queue, Watch and Notifications, Keyboard Shortcuts, Command Line, Frequently Asked Questions), search across all texts; each chapter links to the matching part of the documentation — **Keyboard Shortcuts** to the [Keyboard shortcuts](#keyboard-shortcuts) section of this reference, the others to a chapter of the manual |
| **Open Handbook …** | *Help* | this manual on GitHub — in German or English, like the interface; so does “Read more in the handbook” in every help chapter |
| **Introduction** | at first launch, *Help › Show Introduction*, Settings › Help | **10** steps: 7 as a card on the window (sidebar, list, detail column, toolbar, views, watch, queue), welcome, helper and end as a sheet. It opens hidden columns and scrolls the sidebar to the matching row; if a card does not appear after **1 s**, the step comes as a sheet. Starts by itself once per session; can be switched off in the introduction (**Show at launch**) and in Settings. |
| **Language** | — | interface, help and the helper's Touch ID dialog in German or English according to the system language, otherwise English. In German the categories have German names (the command line uses the English ones). Messages from the core (plans, refusal reasons) are in English in both languages, as on the command line. |

## Keyboard shortcuts

| | |
|---|---|
| ⌘R | Rescan (stored dump of the background tasks) |
| ⇧⌘R | Full rescan, including the background tasks |
| ⌥⌘E | Basic or Expert mode |
| ⌘, | Settings |
| ⌘? | LaunchKeeper Help |
| ↩ | in the plan sheet: Run (not for **Delete for good**) · in the queue: Run all |
| esc | in the plan sheet: Cancel |

## Limits and fixed values

| | |
|---|---|
| Regular comparison of the watch | 600 s (10 minutes) |
| Quiet period after a file change | 5 s (plus 2 s of coalescing by FSEvents) |
| Fresh dump of the background tasks without the helper (watch) | at most every 6 hours |
| Own change after an action ends | 30 s |
| Watch list | 200 entries |
| Remembered notification results | 200, this session only |
| Entries in the menu bar | 5 |
| `sfltool dumpbtm` during scanning and in the helper | 150 s (environment variable `LAUNCHKEEPER_BTM_TIMEOUT`) |
| App waiting for the helper's dump | 200 s |
| Waiting for a helper action | 900 s; for a queue run 3,600 s |
| Version query to the helper | 5 s |
| Idle time after which the helper quits | 60 s |
| Entries per helper run | 500 |
| Dialog text of a run | at most 200 characters, must state the number when there is more than one entry |
| Target of a request | at most 1,024 bytes, no control characters, does not start with “-” |
| Attempts in the Touch ID / password dialog | 3, no grace period |
| System-wide sections of the background tasks | UIDs below 500 |
| App leftovers check | about 30 s |
| Introduction | 10 steps, 1 s until the fallback sheet |
| Help | 10 chapters |

## What LaunchKeeper does not do

- **Switches that macOS manages itself** — login items and background services in the background
  tasks, system and kernel extensions, configuration profiles, privacy permissions, programs that
  accept network connections. For these there is **By hand** in the queue.
- **Entries from Apple** (`com.apple.*`) and everything under `/System` — read only, even with
  administrator rights.
- **Deleting for good without your explicit click** — only one entry at a time, after the plan,
  never with ↩ and never in the queue.
- **Uploading anything** — not even to VirusTotal. The only thing that goes to the network is the
  update check.
- **Showing other users' entries** — the helper does not hand them out.
- **Sending commands to the helper** — it accepts only “what to do with which entry” and plans by
  itself.
