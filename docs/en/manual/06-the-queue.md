# The queue

*Deutsch: [Die Warteschlange](../../handbuch/06-die-warteschlange.md)*

You change one entry through its detail column ([chapter 5](05-changing-entries.md)). For twenty
entries that is tedious — and each one that needs administrator rights asks for Touch ID
separately. That is what the **queue** is for: in every view you collect what should happen,
check the plan for everything at once, and run it in one go.

## Selecting entries

Every row has a **checkbox** at the front — in the inventory, in the categories, in
**Background**, **Packages**, **App leftovers**, and **Quarantine**. Each view remembers its
checkboxes on its own: you can collect in the inventory, continue in **Packages**, and come back
without losing anything.

As soon as something is selected, the **selection panel** appears at the top of the detail
column: “N selected” and below it **Add to queue**. If you have also clicked a row, its
explanation still appears below; you can move the divider between them. That way you can read up
on a single entry while the selection stays in place.

### What is offered

Under **Add to queue** there is one button per action, with a counter, for example
**Disable — 3 of 4**. Not every action fits every entry; the button only adds the entries it
fits. What is offered is what the detail column also offers as a next step — the same check, the
same rules.

| View | Actions |
|---|---|
| Inventory, categories, Background | **Disable**, **Enable again**, **Remove**, **Move into quarantine** — depending on the entry |
| Packages | **Uninstall package** |
| App leftovers | **Move leftovers into quarantine** |
| Quarantine | **Restore from quarantine** |

If there is no automatic action for any of the selected entries, it says “None of the selected
entries has an automatic action.” Entries whose switch macOS manages itself are collected in the
list **“N without an automatic action”**; the button **Add to the queue as “By hand”** puts them
into the [By hand](#by-hand) section. Apple's entries don't appear there — nobody should change
anything about those.

A row in **Background** stands for all **Components** of an app. If you select it, its components
land in the queue individually; the counter then counts components, not rows.

After the click you see “N added to the queue” with the button **Open queue**. The checkboxes
used are cleared — in other views too, if the same entry was selected there as well. **Clear
selection** removes the checkmarks in the current view; what is already in the queue stays there.

> An entry is never in the queue twice. If you add it again with a different action, it keeps its
> row and gets the new action.

### How you recognize queued entries

A row that is already in the queue shows a **queue symbol** instead of the checkbox. The color
tells you its state:

| Color | Meaning |
|---|---|
| blue | open |
| green | done |
| orange | refused or failed |

When you hover over it, the tooltip names the action. **Clicking the symbol takes the entry out
again** — nothing is run. The detail column can do the same: at the top it says “In the queue: …”
with the button **Take out**.

For a row in **Background** of which only some components are queued, the checkbox stays and a
fraction like **2/3** appears next to it: two of three components are in the queue, the rest can
still be selected.

## The queue

You find it in the sidebar under **Batch processing › Queue**. The number next to it counts the
entries that are not finished yet.

The list has two sections:

- **Automatic** — what LaunchKeeper runs itself.
- **By hand** — what you do yourself at the place named (see [below](#by-hand)).

Each row in the **Automatic** section shows the entry's name, the view it came from, its state in
words, and on the right the chosen action. If the entry offers more than one action, this is a
pop-up menu: you can switch from **Disable** to **Move into quarantine**, for example. The plan is
checked again afterwards. The **×** at the end takes the row out.

The symbol at the front shows the state:

| Symbol | State |
|---|---|
| empty circle | “plan not checked yet” |
| filled circle, blue | “ready” |
| lock, blue | “ready · Touch ID” — needs administrator rights |
| checkmark, green | “done and verified” |
| warning triangle, orange | “failed: …” |
| raised hand, orange | “refused: …” — nothing was run |
| pointing hand, purple | “by hand” |

Clicking a row shows the details on the right: **Action**, **From the view**, the **Command** you
would use to do the same in Terminal (with `--apply`), and — after the check — the **Plan** with
every step (a lock marks steps that need administrator rights); after the run, the **Result** with
the **Way back**. **Show in inventory** jumps to the entry.

### Conflicts

If a package is queued for uninstalling and at the same time an entry that this package installed
is queued too, the entry shows in orange: “The package … is uninstalled in the same queue — this
action is then unnecessary.” The uninstall takes its files along anyway. Take the entry out in
that case.

## Check plan

**Check plan** works out in one pass what would happen for all open entries — without changing
anything. For this, LaunchKeeper reads the inventory once, not once per entry. While it computes,
the bottom shows “Computing the plan for all entries …”.

Afterwards each row is either **ready**, **ready · Touch ID**, or **refused** with a reason.
Another **Check plan** checks refused and failed entries again — perhaps you have set up the
helper in the meantime, or a file is back.

Below the list is a line like “12 entries · 9 open · 2 done · 1 refused or failed”.

## Run all

**Run all** (or **↩**) runs all open automatic entries. If you have not checked the plan yet,
LaunchKeeper does that first; only what the check allowed is run. If steps that need administrator
rights are pending, the button is called **Run all (Touch ID)**.

The order:

1. **First all steps that need administrator rights** — through the helper, with **one** Touch ID
   prompt for all of them together. The dialog states the count: “LaunchKeeper wants to change 7
   startup items.” (for a single one: “LaunchKeeper wants to change one startup item.”). That way
   LaunchKeeper asks while you are still sitting in front of the screen.
2. **Then the rest**, which do without administrator rights.

Within each group, removing and disabling run before restoring and uninstalling. Progress shows at
the bottom as “N of M done”.

- **One failure does not stop the others.** Each entry has its own result.
- **Stop** halts after the entry that is currently running. There are no half-done jobs; the rest
  is reported as “stopped — not run”.
- **If you cancel the Touch ID prompt**, nothing that needs administrator rights is changed
  (“Authentication cancelled or denied — nothing changed”). Then the remaining entries don't run
  either (“not run — authentication cancelled”): cancelling means “do nothing”.

If a step needs administrator rights but the helper is not set up (or is still the old version
after an update), LaunchKeeper refuses the entry: “needs administrator rights — set up the helper
in Settings”. How to do that is in [chapter 4](04-the-helper.md). App leftovers whose plan needs
administrator rights are not run by the helper; they get “needs administrator rights — possible in
Terminal only”.

> A run with administrator rights takes at most **500** entries. With more, LaunchKeeper refuses
> them before Touch ID is asked (“too many entries for one run (at most 500) — please run it in
> parts”).

After the run, LaunchKeeper reads the inventory, the quarantine, and the app leftovers once more.
The [watch](07-watch.md) lists everything the run changed as “by LaunchKeeper” and does not report
it.

## Cleaning up and ways back

Below the list are three buttons:

- **Clear** takes all entries out of the queue — after the question “Clear the queue?” with
  **Clear — nothing runs**. What has already run stays run.
- **Remove finished** takes out all entries that ran successfully or were ticked off. Open,
  refused, and failed ones stay.
- **Add ways back (N)** puts the way back into the queue for every action that was done **in this
  session**: **Disable** ↔ **Enable again**, and for everything that went into the quarantine,
  **Restore from quarantine**. The button only appears when there are such ways back.

> Ways back exist only for runs in this session. A “done” that comes from the saved queue after a
> restart proves nothing about the state of the Mac — LaunchKeeper offers no way back for it. In
> that case you find the way back in the [quarantine](08-quarantine-and-undo.md) or in the entry's
> detail column.

## What remains after a restart

The queue survives a restart of the app: entries and their state are kept in

```
~/Library/Application Support/de.paranoidsecurity.LaunchKeeper/queue.json
```

Only its owner can read the file — it lists what is to run with administrator rights. The plans
themselves are not saved; after the restart it says “plan not checked yet” again, and a run that
quitting interrupted counts as open again.

If LaunchKeeper cannot read individual entries of the file — for example because a newer version
wrote it and you switched back —, only those are missing, not the whole queue. A notice then
appears at the top, and the unchanged file is kept next to it as
`queue-unreadable-<date>.json`, also readable only by you. If this copy cannot be created,
LaunchKeeper does not save the queue at all until the next launch, so that nothing is
overwritten. **OK** hides the notice.

## By hand

Some switches are managed by macOS alone, and it lets no other app touch them — login items,
system extensions, configuration profiles, privacy permissions, kernel extensions. LaunchKeeper
intentionally does not write there. Such entries are in the **By hand** section, each with short
instructions and, where there is one, an **Open System Settings** button that opens the right
place:

| Kind | Where |
|---|---|
| Login items, background registrations | System Settings › General › Login Items & Extensions — switch it off at the app or developer, or delete the app |
| System extensions | delete the app they belong to, or switch the extension off in it; switch under Login Items & Extensions › Extensions (macOS 14: Privacy & Security › Extensions) |
| Configuration profiles | System Settings › General › Device Management — profiles installed by a management (MDM) cannot be removed there |
| Privacy permissions | System Settings › Privacy & Security, switch it off in the matching section |
| Network services | quit the program or switch it off in its own settings; the firewall blocks incoming connections (System Settings › Network › Firewall) |
| Kernel extensions | only the vendor's uninstaller (or its app), then restart — no button |

The detail column shows the same instructions, the button, **Show in Finder**, and the **Done**
switch.

### Ticking off

You don't have to tick things off yourself. **Check now** below the section reads the inventory
afresh — including the System Settings switches that **⌘R** takes from the cache — and ticks off
what has **disappeared**, or is **switched off** if it was switched on when it was queued. The
same happens after every other finished scan while the queue is open.

Two exceptions:

- If the scan was **incomplete** (a source did not respond), “disappeared” does not count — only
  “switched off”.
- **You tick off network services yourself.** A program that accepts connections is only in the
  inventory while it runs. If it disappears, it may only have been quit. The row then says “not
  listening right now — maybe just quit; tick it off yourself”. Only tick it off when it is not
  listening again after the next start either.

With the checkbox at the front of the row, you tick off an entry yourself or reopen it.
**Remove finished** clears away ticked-off entries too.

## Next

- [Chapter 7 — Watch and notifications](07-watch.md)
