# The views

*Deutsch: [Die Ansichten](../../handbuch/03-die-ansichten.md)*

The list of all entries answers the question “What starts here?”. For other questions,
LaunchKeeper has dedicated **views** — in the sidebar under **Views** and, at the very bottom, the
**Queue**. Each starts with a gray sentence that says what it shows and what you can do there.

| View | The question behind it |
|---|---|
| **Background** | Which app may do what in the background — and why is something off? |
| **Packages** | What did an installer leave behind? |
| **App leftovers** | What remained of deleted apps? |
| **Quarantine** | What did LaunchKeeper take away, and how does it come back? |
| **Watch** | What is new or has changed? |
| **Queue** | What should be done in one go? |

## Background

This view rebuilds what macOS shows under **System Settings › General › Login Items &
Extensions** — the same list, with what is behind it.

- **Open at login** — apps that you (or they themselves) added as login items.
- **Allow in the Background — apps and developers** — one row per app or developer, as in
  System Settings, with the state of the switch on the right:

  | Display | Meaning |
  |---|---|
  | **on** (green) | allowed to run in the background |
  | **off** (gray) | switched off in System Settings |
  | **mixed** (orange) | some of the components on, some off |
  | **App** (blue) | the app itself is registered as a background item |
  | **–** (gray) | nothing registered — neither components nor the app itself |

- **Allow in the Background — no developer** — entries for which macOS knows no developer,
  mostly unsigned tools or scripts. System Settings names them after the program that starts
  them; that is why names like “bash” or “arch” show up there several times. LaunchKeeper writes
  in the second line what is actually behind them.

### Switch or launchd

An entry can be switched off in two ways, and System Settings shows only one of them:

- **The macOS switch** — the one you flip in System Settings. This view shows it as “on” or
  “off”.
- **A launchd setting** — this is how LaunchKeeper (or `launchctl disable`) switches off a
  service. System Settings doesn't see it: it can say “on” there while the service still does
  not start. LaunchKeeper marks such rows with an **orange exclamation mark** (“At least one
  component is disabled via launchd — invisible in System Settings”).

### The detail column

For a row, the right column shows the traffic light, the facts (app or developer entry, team,
number of components) and below them **Components** — each with its state, plus “launchd: off”
and “running” where that applies.

Under the next steps:

- **Toggle in System Settings** — **Open** takes you to the right place. macOS manages this
  switch itself; LaunchKeeper does not write there.
- **Show “…” in inventory** — jumps to the individual component in the list of all entries.
  There it can be controlled on its own, for example disabled via launchd.

## Packages

Installer packages (`.pkg`) leave a **receipt**: a list of all the files they installed. This
view shows every receipt on the Mac with **Package** (the exact package ID), **Version**,
**Installed** (date), **Files**, **Missing** and the **Entries** in the inventory that belong to
the package.

If files are missing, the program was usually deleted already — for example dragged to the
Trash — and the receipt was left behind. The **Only with missing files** button in the toolbar
shows only such packages.

The detail column judges by the package's **own** files. Shared folders like `/Applications`
that a receipt lists don't count — they always exist.

| Finding | Meaning |
|---|---|
| “Installed package” | all of its own files are there |
| “Partly still installed” | some are missing (“… of … own files missing”) |
| “Install receipt without files …” | the program is gone, only the receipt stayed |

Below that is what **starts automatically** with the package, and one of two steps:

- **Uninstall (preview)** — as long as files are still there. Only what is still **unchanged**
  from the package is taken; modified files and files shared with other packages stay. What is
  taken goes into the quarantine and can be restored. Only when nothing of its own is left is the
  receipt forgotten too.
- **Remove receipt** — when all files have long been missing. LaunchKeeper forgets the receipt
  and puts a copy into the quarantine.

Both need administrator rights and run through the helper ([chapter 4](04-the-helper.md)). The
plan shows beforehand, file by file, what moves and what stays
([chapter 5](05-changing-entries.md)).

> An app bundle that has updated itself since installation stays **entirely** in place. Taking
> out the unchanged half would leave a broken app.

## App leftovers

When you delete an app, its settings, caches and data stay behind in `~/Library` (and sometimes
in `/Library`). This view looks for them.

The first time you open it, LaunchKeeper checks which apps are **really** gone — in the
Applications folders, with LaunchServices and with Spotlight (“Checking which apps are really
gone — LaunchServices, Spotlight, app folders …”). That takes about half a minute.

Each row shows the bundle ID, the size and the verdict. At first, only what provably belongs to
a deleted app is shown (verdict `gone`, orange).

### Verdict and reasoning

The detail column shows the verdict with its reasoning:

| Heading | Verdict |
|---|---|
| “Leftovers of a deleted app” | the app is no longer installed — with the evidence for that and what shows it was an app |
| “Data of an installed app” | the app is still there, with the reason |
| “Cannot be attributed reliably” | the verdict is uncertain, for example because another app from the same vendor is still installed |
| “Data of a tool or framework” | no app found — but nothing shows it ever was an app |

The bar is deliberately high: if Spotlight doesn't answer, that means “uncertain”, never “gone”.
And without traces of a real app (sandbox container, saved window state, settings typical of
graphical apps), a folder does not count as an app leftover.

**Also show present/unclear** in the toolbar additionally lists everything that is not clearly
gone — useful when you want to know why something is **not** offered.

**Check again** searches for app leftovers once more. It does not rescan the inventory; that is
what **Rescan** (⌘R) is for.

### Move into quarantine

For a deleted app, the next steps include **Move into quarantine**: settings, caches and app
data go into the quarantine and can be brought back in case the app comes back. Below it, each
individual path is listed with **Show … in Finder**.

> If leftovers are also in `/Library`, moving them needs administrator rights. The app itself
> does not run this action with administrator rights; the sheet then gives the command for
> Terminal ([chapter 5](05-changing-entries.md)).

## Quarantine

Everything LaunchKeeper takes away lands here — **moved, not deleted**. Each row is a quarantine
**entry**: the package or the bundle ID, the number of paths (“… path(s)”), the status (for
example `applied-ok` or `restored`) and the date.

A click on the triangle expands the entry: the original paths, a note if a package receipt was
forgotten in the process (“Package receipt forgotten — a copy is in the quarantine”), and the
buttons:

- **Restore…** — opens the sheet with the plan, as for every action
  ([chapter 5](05-changing-entries.md)). Restoring never overwrites: if something new is at the
  old location by now, that path is skipped and named.
- **Show in Finder** — opens the entry's folder.

**Reload** in the toolbar reads the quarantine again, for example after you changed something in
Terminal.

### Two quarantines

The app and the command line share the quarantine. There are two of them:

| Location | What is kept there |
|---|---|
| `~/Library/Application Support/launchkeeper/quarantine` | what the app took away without administrator rights, and what the command line puts there |
| `/Library/Application Support/launchkeeper/quarantine` | what the helper took away; the folder belongs to root |

The view shows both together. Restoring from the second one runs through the helper and asks
for Touch ID.

> The helper does not restore an entry in **your** quarantine that moved files outside your
> home folder — usually created with the command line: it only puts back what it keeps itself.
> Instead of **Restore…**, the row then says “Terminal only: launchkeeper quarantine restore …”
> with **Copy command**.

### Deleting for good

The app doesn't do that, on purpose. Deleting for good happens only in Terminal, one entry at a
time:

```bash
launchkeeper quarantine purge <name>          # shows the plan only
launchkeeper quarantine purge <name> --apply  # really deletes
```

`purge` always deletes via `sudo`; Terminal asks for your password. More about ways back in
[chapter 8](08-quarantine-and-undo.md), about the command line in
[chapter 10](10-command-line.md).

## Watch

Watch reports when something new wants to start automatically or an entry changes — if you
like, even with the window closed. The number after **Watch** in the sidebar counts the new and
changed entries that did not come from LaunchKeeper itself. How to turn it on and what it reports
is in [chapter 7](07-watch.md).

## Queue

In every view, the rows have a checkbox. When you mark some, the **selection box** (“N
selected”) appears at the top of the detail column, with **Add to queue** and the matching
actions; **Clear selection** removes the checkmarks again. In the queue you work everything out
with **Check plan** and run it with **Run all** — with a single Touch ID prompt for the whole
run. The number after **Queue** counts the open entries. Everything else is in
[chapter 6](06-the-queue.md).

## Next

- [Chapter 4 — Setting up the helper](04-the-helper.md)
