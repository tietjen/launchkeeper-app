# Changing entries

*Deutsch: [Einträge ändern](../../handbuch/05-eintraege-aendern.md)*

Every change in LaunchKeeper takes the same path: **first the plan, then your second click, then
the check.** Nothing happens on the side, and most things can be undone.

This chapter describes the single action. You handle many entries at once through the queue
([chapter 6](06-the-queue.md)) — with the same checks.

## The flow

### 1. Run…

In the detail column, under **Next steps**, you find the actions that are possible for this
entry. Each one has a **Run…** button on the right. Clicking it changes nothing yet — it opens a
sheet.

### 2. The plan

The sheet carries the name of the action, for example “Disable”. First it shows “Computing the
plan — the inventory is read again for it …”: LaunchKeeper computes the plan against the
**current** state of the Mac, not against the state from five minutes ago.

Then the plan appears under the heading “This would happen — nothing has changed yet:”:

- **every step in words**, numbered,
- below it, **in small print, the command** that runs for it — to read and copy,
- a **lock** next to every step that needs administrator rights,
- **notes** from the core (LaunchKeeperKit): what stays, what is skipped, what to watch out for,
- the **way back**: “Way back: …” — how you undo the change.

If the check refuses the action, you see the **reason** with a raised hand instead of the plan
(see [The check](#the-check)).

### 3. The second click

At the bottom are **Cancel** and **Run**. If the plan needs administrator rights, the button is
called **Run (Touch ID)**, and above it is “Needs administrator rights — after the click macOS
asks for Touch ID or your password.”

Only this click changes something. While it runs: “Running, then verifying …”.

### 4. The check afterwards

LaunchKeeper trusts no return value. After running, it looks up whether the entry **really** is
in the expected state — it asks launchd for the state of the service, and for a removal it looks
in the file system. The result:

| Message | Meaning |
|---|---|
| “Done and verified” | changed, and the change is visible |
| “Incomplete: …” | a step failed, or the check does not see the change |
| Reason with a raised hand | refused — nothing ran |

Notes and the way back are shown here too. If LaunchKeeper recognises the cause of a failure,
since 1.2.1 an explanation in words also appears below “Incomplete: …” — for the commonest case,
missing Full Disk Access, with the **Open Full Disk Access** button
(see [App leftovers and Full Disk Access](#app-leftovers-and-full-disk-access)).

### 5. Done

**Done** closes the sheet. LaunchKeeper then rescans the inventory and reloads app leftovers and
the quarantine, so that all views show the new state.

> While the queue is running, **Run** stays grayed out: “The queue is running — this can run
> afterwards.” Two changes at once would spoil each other's check.

## The actions

| Next step | Where | What happens |
|---|---|---|
| **Disable (reversible)** | Inventory | prevents the automatic start; **Enable again** undoes it |
| **Enable again** | Inventory | lifts the disabling |
| **Remove** | Inventory, only for provably orphaned entries | takes the leftover away (see below) |
| **Move into quarantine** | Inventory, for working entries | disables it and moves the launch file into the quarantine |
| **Uninstall (preview)** | Packages | moves a package's unmodified files into the quarantine |
| **Remove receipt** | Packages | forgets a receipt without files, copy in the quarantine |
| **Move into quarantine** | App leftovers | moves the leftovers of a deleted app into the quarantine |
| **Restore…** | Quarantine | puts a quarantine entry back in its old place |

### Disabling and enabling

What “disable” means depends on who holds the entry's switch:

| Kind | Disable | Enable |
|---|---|---|
| LaunchAgent, LaunchDaemon | set a lock with launchd and stop the service | lift the lock |
| App extension | set to “don't use” | back to “use” |
| Line in your crontab | comment it out, with a marker | remove the marker |
| Login/logout script | set it aside | put it back |
| Firewall rule | block incoming connections | allow them again |

A disabled entry stays visible in the inventory, with the gray pause symbol — that way **Enable
again** finds it again.

> System Settings does not see a launchd lock. Under Login Items & Extensions, a service disabled
> this way can still show as “on”. The **Background** view marks that
> ([chapter 3](03-the-views.md)).

### Remove

**Remove** exists only for entries that provably do nothing anymore — the program is gone, only
the launch file is left. What happens then is stated in the sentence below the step:

- **“Deletes the orphaned launch file; a backup is made first.”** — for an orphaned launch file
  (`.plist`) in one of the launch folders. Before deleting, LaunchKeeper backs up the whole
  folder. If this backup cannot be written, nothing is deleted. The way back in the plan names the
  backup.
- **“Moves the leftover into the quarantine — restorable at any time.”** — for other leftovers: a
  helper tool that no service starts anymore, an outdated startup item, a search path file whose
  folders are all missing.

LaunchKeeper never deletes something that still works.

### Move into quarantine (working entries)

If an entry that still works should disappear completely, this step follows **Disable**. It
**disables** the entry and **moves** its launch file into the quarantine — nothing is deleted. The
program itself stays.

Because the lock stays in place, the entry does not start even if an app recreates its launch
file. Disabling is the gentler step and is usually enough; that is why it comes first.

Entries managed by a configuration profile (MDM) don't get this step: there, the profile decides.

### App leftovers and Full Disk Access

Many apps keep their data in a container of their own under `~/Library/Containers` (or
`~/Library/Group Containers`). macOS protects this data from other apps — **even after the app
itself has been deleted**. If LaunchKeeper does not have **Full Disk Access**, macOS refuses to
move the container.

This is how it shows:

- The sheet says “Incomplete: …” and below it (since 1.2.1): “macOS refused the move: other apps’
  data in ~/Library/Containers is protected, even when the app is deleted. …” with the **Open Full
  Disk Access** button.
- In the [queue](06-the-queue.md#failed-or-refused) the entry is listed under **Failed or refused**
  with “macOS denies access — Full Disk Access missing”.

The fix:

1. **Open Full Disk Access** — or by hand: System Settings › Privacy & Security › Full Disk
   Access.
2. Switch **LaunchKeeper** on there (if it is not in the list, add it with **+**).
3. **Restart LaunchKeeper** — macOS gives the access only to a freshly started program.
4. Try again: in the sheet, **Run…** once more; in the queue, **Try again** and then **Run all**.

Granting Full Disk Access is your decision; LaunchKeeper does not ask for it on its own. Without
it, leftovers outside the containers — caches, settings (`Preferences`) and the like — still
move. But a run stops at the first refused step: if an app has a container, moving its leftovers
needs the access. Whatever was moved before the refused step is in the quarantine (section
**Incomplete**, [chapter 8](08-quarantine-and-undo.md#grouped-by-what-is-really-there)). If the
run moved nothing at all, since LaunchKeeperKit 0.13.1 LaunchKeeper keeps no empty quarantine
entry either.

## The check

Behind every action is **the same check as in the `launchkeeper` command line**. It is a list of
what is allowed — not a list of what is forbidden — and it has no back door: there is no switch
that bypasses it.

Permanently protected are:

- **Apple's entries** (`com.apple.*`),
- **everything under `/System`**,
- Apple's own extensions and programs.

Under **Next steps**, the app only offers what passes this check. A refusal can still happen —
when something changed between the scan and the plan, because the plan works with the new state.

The reasons come from the core (LaunchKeeperKit) and are in English in both languages. Some
examples:

| Reason | What it means |
|---|---|
| “Apple system component (com.apple.*) — read-only by policy” | an entry from Apple |
| “not orphaned — a working component must be disabled (reversible), not deleted; …” | it still works — disable instead of remove |
| “managed by a configuration profile (MDM) — the profile decides, not launchkeeper” | a profile manages it |

Two messages come from the app itself:

- “Authentication cancelled or denied — nothing changed” — you cancelled the Touch ID prompt.
- “The helper ran nothing — nothing on the Mac has changed.” — the helper could not be reached.
  **Restart and try again** usually helps: LaunchKeeper restarts the helper and computes the plan
  once more. **Open Settings** takes you to the helper's settings.

## When administrator rights are needed

| Needs administrator rights | Doesn't need them |
|---|---|
| System services (LaunchDaemons and other services in the system domain) | your own LaunchAgents in `~/Library/LaunchAgents` |
| Files in `/Library`, including LaunchAgents in `/Library/LaunchAgents` | App extensions |
| System-wide login/logout scripts | Lines in your crontab |
| Firewall rules | App leftovers in `~/Library` |
| Package uninstalls and removing receipts | Restoring from your own quarantine, if everything was in your home folder |
| Leftovers outside your home folder | |

**With the helper**, LaunchKeeper runs steps that need administrator rights through it and asks
for Touch ID or your password **once per action**, right before running. The approval applies
only to this one action.

**Without the helper**, the sheet shows the plan but does not run it. Below it is “Needs
administrator rights” with **Set up helper** (or **Allow in System Settings** if it is only
waiting for approval), **Open Settings**, and “Or now in Terminal:” with the ready-made command
and **Copy**. In Terminal, macOS then asks for your password. Setting up is covered in
[chapter 4](04-the-helper.md).

**Without administrator rights**, everything runs directly from the app. There is no prompt, and
the helper is not involved.

> **App leftovers in `/Library`** are not run with administrator rights by the app, even with the
> helper: only the app in your session can check whether the app is really gone, not a system
> service. The sheet then says “The app does not run this action with administrator rights yet.
> Terminal can; macOS asks for your password there:” and shows the command.

## Quarantine instead of trash

Whatever LaunchKeeper takes away, it **moves** into the quarantine instead of deleting it:
leftovers, launch files of working entries, package files, app leftovers. From there you get it
back with **Restore…** ([chapter 3](03-the-views.md), [chapter 8](08-quarantine-and-undo.md)).

The only exception is the orphaned launch file on **Remove** — and that is backed up first.
Deleting from the quarantine for good happens only explicitly, one entry at a time: in the
**Quarantine** view with **Delete for good…** or in Terminal with
`launchkeeper quarantine purge`.

## Backups

Before LaunchKeeper overwrites or deletes something, it backs up the state:

- before removing a launch file, the whole launch folder,
- before changing your crontab or the login/logout scripts, their complete contents.

The backups are in `~/Library/Application Support/launchkeeper/` (`backups`,
`config-snapshots`). What the helper backs up is in
`/Library/Application Support/launchkeeper/`. The way back in the plan tells you how to restore a
backup.

## The log

Every action leaves a line in the log — plans and refusals too:

| Log | What it contains |
|---|---|
| `~/Library/Logs/launchkeeper/operations.log` | what the app does without administrator rights; the same file the command line uses |
| `/Library/Logs/launchkeeper/operations.log` | what the helper does with administrator rights |

## Not controllable here

Some switches are managed by macOS alone, and it lets no other app touch them: login items and
background services of apps, system extensions, kernel extensions, configuration profiles,
privacy permissions. For such entries, **Next steps** shows **Not controllable here** with the
reason and the place where the switch is.

This is not a gap but intentional: LaunchKeeper does not write to macOS's Background Task
Management (BTM). It still shows you the way. If you select such entries and put them there with
**Add to the queue as “By hand”**, the **By hand** section shows instructions with a button that
opens the right place in System Settings. After **Check now**, LaunchKeeper ticks off what has
been done. More in [chapter 6](06-the-queue.md).

## Next

- [Chapter 6 — The queue](06-the-queue.md)
