# Security and privacy

*Deutsch: [Sicherheit und Datenschutz](../../handbuch/09-sicherheit-und-datenschutz.md)*

A program that switches off system services and moves files in `/Library` needs rights you
should not hand out lightly. This chapter explains how LaunchKeeper handles those rights, what it
reads, what leaves your Mac — and what it does not protect you from.

## The principles

1. **Reading is the normal case.** The inventory, the views and the watch change nothing.
2. **First the plan, then the execution.** Every change shows each step and the way back
   beforehand; it runs only on your second click.
3. **One check for everything.** The app, the helper and the command line go through the same
   check with the same rules.
4. **Move, don't delete.** Whatever goes away lands in the quarantine
   ([chapter 8](08-quarantine-and-undo.md)).
5. **Verified, not believed.** After every change, LaunchKeeper reads back whether the entry is
   really in the expected state. A command that reports “success” proves nothing.

## The check

Before a plan is made, a single check decides whether an action is allowed at all. It is an
allowlist, not a blocklist, and it has **no switch that bypasses it** — neither in the app nor as
an option on the command line.

- **Entries from Apple** (`com.apple.*`) and **everything under `/System`** are excluded. The app
  does not even offer **By hand** for them.
- **Remove** deletes only a single launch file that is provably orphaned — and only after a
  backup has been written. Anything that still works is disabled or moved into the quarantine,
  never deleted.
- **Uninstall** takes only files that are provably still the way the package installed them
  (size and checksum); anything another package also lists stays.
- **Targets are resolved from LaunchKeeper's own inventory**, never from a command line. Input
  never becomes a shell command.

The app itself never runs a step with administrator rights: a plan that contains `sudo` goes to
the helper, and the part of the app that runs commands rejects `sudo` on top of that.

## The helper

The helper is the only part of LaunchKeeper that runs with administrator rights
([chapter 4](04-the-helper.md)). It is not set up automatically: if you only want to look, you
get no service with administrator rights.

### Who talks to whom

Each side checks the other's code signature:

- The helper only accepts connections from the LaunchKeeper app — identifier
  `de.paranoidsecurity.LaunchKeeper`, signed with an Apple-issued certificate of the developer
  team `Y2LTPLFG6D`. Every other program is rejected, even one that runs under your name.
- The app only talks to the real helper
  (`de.paranoidsecurity.LaunchKeeper.Helper`, same team).
- The helper takes who is asking from the connection itself, never from the content of the
  request.

### What it accepts

**No commands.** A request contains only “what to do with which entry”: disable, enable again,
remove, move into the quarantine, restore, delete for good, uninstall — and the name of the entry, the quarantine
entry or the package. The helper scans by itself, resolves the entry by itself and sends it
through the same check as the command line.

Two limits apply only to the helper:

- **Entries that belong only to you** — your LaunchAgents, settings in your home folder — it does
  not change. That is the app's job, which does it as you.
- **From places users can write to** (`/Users/`, temporary folders, `/Volumes/`,
  `/opt/homebrew/`, or under a folder that a user without administrator rights can change), it
  moves nothing and puts nothing back there.

### Touch ID — every time

Every change through the helper needs its own right,
`de.paranoidsecurity.LaunchKeeper.modify`. For it, macOS asks for Touch ID or the password of an
**administrator** — for a single action with the text “LaunchKeeper wants to change a
system-level startup item.”

- **No grace period.** A confirmation applies to exactly one request; the next one asks again.
- **Not shared.** The confirmation does not apply to other programs.
- **The queue** asks once for the whole run — for exactly the list whose plan you saw
  beforehand. The dialog states the number: “LaunchKeeper wants to change N startup items.”, for
  a single entry “LaunchKeeper wants to change one startup item.”
  ([chapter 6](06-the-queue.md#run-all)).

If you cancel the dialog, the helper changes nothing.

### One tree, only root writes

What the helper keeps — quarantine, backups, copies of configuration files — lives under
`/Library/Application Support/launchkeeper/`, never in your home folder. The reason: in your home
folder, any program running under your name can rename folders or slip in links. A helper that
checks there and then writes could be redirected between the two — onto system files.

That is why:

- The tree belongs to root and is writable by no one else. The helper creates it and, before
  **every** request, checks the whole path from `/`: real folders, no links, owner root, not
  writable by group and others.
- **Only root writes there** — the helper, or the command line via `sudo`
  (`quarantine restore/purge --apply`); the app and `launchkeeper` without `sudo` only read.
- Before restoring, the helper checks each entry once more: owner, no links, every path matches
  its origin, no origin in your home folder or under `/System`.
- **Deleting for good** (since 1.2) only entries of this tree: the helper first checks that the
  entry is one of its own — owned by root, writable for nobody else — and asks for Touch ID every time. Entries
  of your own quarantine it does not delete.
- Backups never follow links, copy only regular files, and no copy is readable by more people
  than its original.

If something about the tree is wrong, the helper refuses and names the fix:

```bash
sudo chown -R root:wheel '/Library/Application Support/launchkeeper' && sudo chmod -R go-w '/Library/Application Support/launchkeeper'
```

### Reading the background tasks

Since version 0.2.0 the helper also reads macOS's background tasks (Background Task Management,
BTM for short) (`sfltool dumpbtm`). Started as you, this command requires Touch ID; as root it
asks nothing. Because reading changes nothing, the helper does not ask for Touch ID for it.

In return it gives back only what you are allowed to see: the system's sections (user IDs below
500 — root and the service accounts) and **your own**. You do not get to see the login items of
other users of this Mac.

> **A deliberate trade-off:** On a Mac with several users, this means that a user **without**
> administrator rights also sees the system-wide background items — without a prompt — as long
> as the helper is set up. Most of them are readable in `/Library` anyway.

## What leaves your Mac

| | Leaves your Mac? |
|---|---|
| Inventory, views, watch, queue | **no**, everything is local |
| Notifications | no — they go to macOS's Notification Center |
| Checking for updates | yes: to GitHub, where the update catalog of the latest version is kept. By default LaunchKeeper checks by itself; switch it off under Settings › **Updates** › **Check for updates automatically**. **Check for Updates …** in the app menu checks when you choose it |
| Hash for VirusTotal | **no** — **Copy hash** only puts the SHA-256 checksum on the clipboard. Whether you paste it into VirusTotal is up to you |
| Manual | only if you click the link to the manual in the help — it opens GitHub in the browser |
| Telemetry, crash reports, usage statistics | **do not exist** |

Every update is signed and is checked against LaunchKeeper's signing key before it is installed.
The helper comes with the update and starts in the new version after one minute of idle time;
until then, the app runs nothing through an older version.

The `launchkeeper` command line contains no network code itself.

## Where things are kept

| File | Content |
|---|---|
| `~/Library/Logs/launchkeeper/operations.log` | log of every action of the app without administrator rights and of the command line — including refusals and plans |
| `/Library/Logs/launchkeeper/operations.log` | log of every action of the helper |
| `~/Library/Logs/launchkeeper/watch.log` | what the watch noticed ([chapter 7](07-watch.md)) |
| `~/Library/Application Support/launchkeeper/` | your quarantine, backups, copies of configuration files |
| `/Library/Application Support/launchkeeper/` | the same for the helper (root) |
| `~/Library/Application Support/de.paranoidsecurity.LaunchKeeper/queue.json` | the queue, readable only by you |

The log records **what** happened to **which** entry and with what result. The log names the
entry's key — for crontab lines, that key contains the command line (and with it whatever is in
it). The same key also appears in the queue (`queue.json`) and in `watch.log`.

## The limits

LaunchKeeper is a tool for getting an overview and for careful cleanup. It is **not** a virus
scanner and not a protection program. In concrete terms:

- **The watch reports, it does not prevent.** When it reports “New: …”, the entry is already
  there. It relies on file events and a comparison every ten minutes; something that comes and
  goes in between can slip past it.
- **Hints are not verdicts.** An entry marked **Worth a look** — say, a program under `/tmp` or a
  service that starts a shell — is a reason to take a look, not a finding. Conversely,
  **Nothing unusual** does not mean “harmless”.
- **What root controls can hide.** LaunchKeeper sees what macOS shows it. A program that already
  runs with administrator rights can change entries and files so that no tool on the same system
  finds them reliably.
- **Your confirmation is the last hurdle.** Touch ID protects against something happening without
  you — not against confirming a plan you have not read.
- **Your stores are as safe as your user account.** Your quarantine, your logs and the queue live
  in your home folder. Other users cannot read the queue; programs running under your name can.
- **Some things only macOS manages.** LaunchKeeper does not switch login items, system
  extensions, profiles and privacy permissions itself — it only shows where to do it.

## Next

- [Chapter 10 — The `launchkeeper` command line](10-command-line.md)
