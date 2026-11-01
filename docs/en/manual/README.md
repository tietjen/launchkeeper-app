# LaunchKeeper — Manual

*Deutsch: [LaunchKeeper — Handbuch](../../handbuch/README.md)*

In the order you need it. The first three chapters are enough to get started.

| | Chapter | What it covers |
|---|---|---|
| 1 | [Installing and the first launch](01-install-and-first-launch.md) | Homebrew or DMG, why the app belongs in /Applications, the first scan, the introduction |
| 2 | [Reading the inventory](02-the-inventory.md) | Categories, the icons in the list, Basic and Expert mode, the next steps |
| 3 | [The views](03-the-views.md) | Background, Packages, App leftovers, Quarantine — one question, one view each |
| 4 | [Setting up the helper](04-the-helper.md) | What it needs administrator rights for, setting up and allowing, updates, restart |
| 5 | [Changing entries](05-changing-entries.md) | Disable, enable, remove, uninstall — first the plan, then the run |
| 6 | [The queue](06-the-queue.md) | Mark, collect, one shared plan, one Touch ID prompt, ways back, “By hand” |
| 7 | [Watch and notifications](07-watch.md) | What gets reported and what doesn't, menu bar, launch at login, missing banners |
| 8 | [Quarantine and ways back](08-quarantine-and-undo.md) | Where removed items go, how they come back, what only works in Terminal |
| 9 | [Security and privacy](09-security-and-privacy.md) | What the helper may and may not do, what leaves the Mac, the limits |
| 10 | [The `launchkeeper` command line](10-command-line.md) | The same inventory in Terminal, scripts, emptying the quarantine |

**In the app:** **⌘?** opens the in-app help — the same topics in short form and searchable,
with a link to this manual. You can bring back the tour from the first launch with
**Help › Show Introduction**.

**For looking things up:** [Feature reference](../features.md) — every feature with its limits.

**For understanding:** [How LaunchKeeper is built](../architecture.md) — the parts, the paths and
the reasons behind them.

## The five principles

When LaunchKeeper behaves differently than you expect, it is almost always because of one of these:

1. **Nothing changes without you.** Scanning and watching only read. LaunchKeeper does not set
   up the helper on its own either — if you only want to look, you don't get a service with
   administrator rights.
2. **Plan → Run → Verify.** Every change shows its plan first; it runs only after a second
   click, and afterwards LaunchKeeper checks whether the entry really is in the expected state.
3. **Removing means quarantine — there is always a way back.** Files are moved or backed up
   first, not simply deleted. Deleting for good only happens explicitly, one entry at a time:
   in the **Quarantine** view with **Delete for good…** (or in Terminal with
   `launchkeeper quarantine purge`). Until that step there is always a way back.
4. **Root only through the helper — and it accepts only “what with which entry”, never
   commands.** Every run asks again for Touch ID or your password; the helper looks up the entry
   itself, checks it itself, and keeps quarantine and backups only in a folder that only root
   can write to.
5. **The same check as the command line; Apple and /System stay untouched.** The app offers
   only what passes the check of `launchkeeper` — without exception and without workarounds.
