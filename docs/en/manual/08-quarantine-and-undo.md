# Quarantine and ways back

*Deutsch: [Quarantäne und Rückwege](../../handbuch/08-quarantaene-und-rueckwege.md)*

LaunchKeeper almost never deletes. What gets taken away during a cleanup — a package, the leftovers
of a deleted app, a service you want to get rid of — is **moved**, not deleted: into the
**quarantine**. From there it can be brought back. This chapter explains where the quarantine is,
how you restore something, and which other ways back there are.

## What the quarantine is

Every action that takes something away creates an **entry** in the quarantine: a folder with

- `manifest.json` — what was moved, from where, when, and with what result; written before the
  first file moves,
- `files/` — the files themselves, under their **original path**:
  `/Library/LaunchDaemons/com.example.plist` becomes `files/Library/LaunchDaemons/com.example.plist`,
- for packages, `receipt/` — a copy of the package receipt, in case it was forgotten.

Moving usually means renaming on the same volume: then it is instant, needs no extra space, and
owner and permissions stay as they were. If a file is on a different volume than the quarantine,
`mv` copies it over and then removes the original.

## Two stores

There are two quarantines, depending on who took something away:

| Store | Location | Who writes there |
|---|---|---|
| **yours** | `~/Library/Application Support/launchkeeper/quarantine` | the app for actions without administrator rights (for example app leftovers in `~/Library`) and the `launchkeeper` command line |
| **the system's** | `/Library/Application Support/launchkeeper/quarantine` | **root only** — the helper for everything that needs administrator rights (package uninstalls, services in `/Library`), and the command line via `sudo` (`quarantine restore/purge --apply`) |

Next to the system quarantine are two more folders of the helper:

```
/Library/Application Support/launchkeeper/
├── quarantine/         what the helper took away
├── backups/            backups of the launch folders before removal
└── config-snapshots/   copies of configuration files before a change
```

This tree belongs to root, and nobody else may write into it. That is intentional: if the helper
worked with administrator rights in your home folder, any program running under your name could
rename a folder or slip in a link between the check and the write — and so get the helper to
overwrite system files. More on this in
[chapter 9](09-security-and-privacy.md#one-tree-only-root-writes).

The app and the command line **both see both stores**; the **Quarantine** view shows all entries
together, newest at the top.

## The Quarantine view

In the sidebar under **Views › Quarantine**. Since 1.2.1 it is a list with selection like the
other views: clicking a row shows everything about that entry in the detail column on the right;
there is nothing to expand any more.

Each row shows

- a **checkbox** — only for entries that can be restored in the app (not for empty ones, restored
  ones, or those that only go back in Terminal),
- the **title**: the package, the app's bundle ID or the entry, with the **kind** below in small
  print: “App leftovers”, “Package uninstalled” or “Entry removed”,
- on the right, the **state** and the **date**.

### Grouped by what is really there

The sections follow what an entry holds **right now** — LaunchKeeper checks on disk whether each
moved path is in the quarantine, rather than relying on the state in `manifest.json` (which says
`applied-fail(5)`, for example, both for an entry that holds nothing and for one that lacks only
one path):

| Section | State in the row | Meaning |
|---|---|---|
| **In the quarantine** | “in the quarantine” (green) | all paths are there and can be restored |
| **Incomplete — only part arrived** | “N of M paths” (orange) | part of it arrived, the rest stayed in place — usually because macOS refused the move ([Full Disk Access](05-changing-entries.md#app-leftovers-and-full-disk-access)) |
| **Empty — nothing moved** | “empty” | attempts where macOS refused the very first step; they hold no files |
| **Restored** | “restored” | the files are back; the entry is only the record of it now |

Empty sections are left out. Within a section the newest entries are at the top.

### The detail column

For the selected entry, the right-hand side shows:

- the title, **Kind**, **State**, **Created** (date and time) and **Store** — “your quarantine”
  or “System quarantine (helper)”, see [above](#two-stores) —, with a sentence below on what the
  state means;
- **Paths**: every original path, with an icon in front showing whether it is in the quarantine
  or not; for packages also “Package receipt forgotten — a copy is in the quarantine”;
- **Reasons**: the evidence that led to the action — for app leftovers, for example, why the app
  counts as deleted;
- the buttons:
  - **Restore…** opens the sheet with the plan — as with every action
    ([chapter 5](05-changing-entries.md)). Only a second click runs it. Empty and restored
    entries have no such button; for entries that only go back in Terminal, the command with
    **Copy command** takes its place ([below](#who-restores-what)).
  - **Show in Finder** opens the entry's folder.
  - **Delete for good…** (since 1.2) deletes the entry with no way back — only after the plan,
    see [below](#deleting-for-good).

### Toolbar

- **Remove empty entries (N)** (since 1.2.1) appears only when **your** quarantine has empty
  entries. After asking (“Remove N empty entries?”) it deletes exactly the entries that hold no
  file — failed attempts — as you, without Touch ID. Entries with files stay; nothing that could
  be restored is lost. Afterwards the line “N empty entries removed.” appears below the
  introduction. Empty entries of **the system's** store are not cleared with it — they stay a
  decision per entry with **Delete for good…** and Touch ID.
- **Reload** reads the quarantine again, for example after you changed something in Terminal.

Since LaunchKeeperKit 0.13.1 no new empty entries appear: if a run moves nothing, the core keeps
no entry either. Before, every retry added an empty entry with the state `applied-fail`;
**Remove empty entries** clears those old ones away.

Several entries at once: set the checkboxes, on the right choose **Restore from quarantine**, then
run it in the [queue](06-the-queue.md) — system entries with a single Touch ID prompt.

### Who restores what

| Entry | Restore |
|---|---|
| in **your** store, all paths in your home folder | the app itself, without administrator rights |
| in **the system's** store | the helper, after Touch ID or password |
| in **your** store, but with paths outside your home folder | **Terminal only** |

The last row mainly concerns packages you uninstalled with the command line: the command line puts
such entries into your store too, but putting them back needs administrator rights. The helper
only restores entries it created itself. Instead of **Restore…**, the detail column therefore
shows “Restore only in Terminal: launchkeeper quarantine restore <name>” with the **Copy command**
button:

```bash
launchkeeper quarantine restore 2026-09-27-101500Z-uninstall-com.example.tool    # the plan first
launchkeeper quarantine restore 2026-09-27-101500Z-uninstall-com.example.tool --apply
```

For the steps that need root, `launchkeeper` asks for your password via `sudo`.

### What the helper refuses

Even for entries in its own store, the helper checks right before putting them back whether it can
trust the entry. It refuses if

- an original path is **in your home folder** — root does not write there,
- an original path is **where users can write**: `/Users/`, the temporary folders, `/Volumes/`,
  `/opt/homebrew/`, or under a folder that a user without administrator rights can change,
- a path is under `/System` or is not a clean absolute path,
- something in the entry does not belong to root, contains a link (symlink), or a path does not
  match its origin.

In the first two cases, the reason names the way that still works: `launchkeeper quarantine
restore <name>` in Terminal.

> **Restoring never overwrites.** If something new is at the original location in the meantime,
> that path is skipped and named in the result.

## Deleting for good

Deleting a quarantine entry for good is the only real deletion in LaunchKeeper. Afterwards there
is no way back. That is why it happens only explicitly and one entry at a time — in the app or in
Terminal.

### In the app

Since 1.2 the **Quarantine** view has **Delete for good…** — since 1.2.1 in the detail column of
the selected entry. The button opens the usual sheet:

- **The plan first.** A single step, `rm -rf -- <entry folder>` — “delete the quarantine entry
  for good — NOT restorable” (the core's messages stay in English); plus the core's note on how
  many paths would be deleted, and a warning if the entry was not created completely.
- **A red notice** above the buttons: “Cannot be restored: the files of this entry are deleted,
  not moved to the Trash. There is no way back afterwards.”
- **Delete for good** runs it — “Delete for good (Touch ID)” when it goes through the helper.
  Return does not trigger this button; it takes a deliberate click.

There are no checkboxes for it and no place in the queue. Restored entries can be deleted too;
then whatever is left of them goes.

### Who deletes what

| Entry | Delete for good |
|---|---|
| in **the system's** store | the helper, after Touch ID or password — every time |
| in **your** store, yours through and through | the app itself, without administrator rights and without Touch ID |
| in **your** store, with files only root may delete | **Terminal only** |

- **The system's store:** everything the app did with administrator rights. Before the helper
  deletes, it checks that the entry is one of its own — it belongs to root and was
  writable for nobody else.
- **Yours through and through** means: every folder in the entry belongs to you and is writable
  for you, and no file is locked or immutable. That is the typical case for app leftovers.
- **With files only root may delete** — for example a package you uninstalled with the command
  line via `sudo`: the sheet shows the plan but cannot run it. Under “Needs administrator rights”
  it explains that the helper only deletes entries it made itself, and gives the command
  `launchkeeper quarantine purge <name> --apply` with **Copy**; in Terminal, macOS asks for your
  password (unlock locked files first with `chflags -R nouchg`). It is the same rule as for
  [restoring](#who-restores-what) such entries.

### In Terminal

```bash
launchkeeper quarantine list                     # what is in there, with names
launchkeeper quarantine purge <name>             # only the plan, nothing is deleted
launchkeeper quarantine purge <name> --apply     # delete permanently — NOT restorable
```

- **Without `--apply`, nothing happens.** The plan states how many paths would be deleted, and
  warns if the entry was not created completely — then check `quarantine restore` first.
- Exactly this one folder is deleted; before that, `launchkeeper` checks that it lies directly
  inside one of the two quarantines. An entry of your store that is yours through and through it
  deletes without `sudo` (since LaunchKeeperKit 0.13); otherwise with `sudo rm -rf`, and Terminal
  asks for your password.
- Afterwards, `launchkeeper` checks that the folder is really gone.

## Other ways back

Not everything goes through the quarantine. Every action names its way back already in the plan
and in the result (the **Way back** line).

### Disable ↔ Enable again

**Disable** only changes a state, not a file. The way back is **Enable again** on the same entry —
in the detail column or in the queue. Disabled entries stay visible in the inventory.

### Backups of the launch folders

**Remove** of an orphaned launch file is the one action that deletes a file. Before that,
LaunchKeeper backs up the launch folders — no backup, no deletion:

| Who | Where to |
|---|---|
| App without administrator rights, command line | `~/Library/Application Support/launchkeeper/backups` |
| Helper | `/Library/Application Support/launchkeeper/backups` |

The way back in the result names the backup. Putting it back happens in Terminal; the command finds
backups in both locations:

```bash
launchkeeper restore <backup>                 # plan
launchkeeper restore <backup> --apply         # copy back
launchkeeper enable <label> --now --apply     # and load again
```

### Copies of configuration files

Before LaunchKeeper changes a configuration file — your crontab, the login window settings —, it
stores a copy: in your home folder under
`~/Library/Application Support/launchkeeper/config-snapshots`, for the helper under
`/Library/Application Support/launchkeeper/config-snapshots`. The way back in the plan names the
command that restores the old state from this copy.

### Ways back in the queue

After a queue run, **Add ways back** creates new entries with the way back for everything that was
done in this session: **Disable** ↔ **Enable again**, and **Restore from quarantine** for everything
that went into the quarantine. There is no entry there for deleted orphaned launch files — their
way back is the backup above. Details in [chapter 6](06-the-queue.md#cleaning-up-and-ways-back).

## Next

- [Chapter 9 — Security and privacy](09-security-and-privacy.md)
