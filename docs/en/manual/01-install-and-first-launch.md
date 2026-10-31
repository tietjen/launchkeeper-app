# Installing and the first launch

*Deutsch: [Installieren und der erste Start](../../handbuch/01-installieren-und-erster-start.md)*

LaunchKeeper shows everything on your Mac that **starts automatically**, and explains each entry
in plain language. It changes nothing without you: every change shows its plan first, can be
undone, and is verified afterwards.

This chapter gets the app onto your Mac and explains the window.

## Requirements

- **macOS 14** (Sonoma) or later.
- Apple silicon or Intel Mac — the app is universal.

## Installing

### From the disk image

1. Download `LaunchKeeper-<version>.dmg` from the
   [releases on GitHub](https://github.com/tietjen/launchkeeper-app/releases).
2. Open the disk image and drag **LaunchKeeper** onto the **Applications** folder next to it.

The app is signed with a Developer ID and **notarized** by Apple; the app and the disk image
carry the ticket (“stapled”). Gatekeeper therefore lets it launch without asking — even without
an internet connection.

### With Homebrew

```bash
brew trust tietjen/tap
brew install --cask tietjen/tap/launchkeeper-app
```

You need the first line **once**, from Homebrew 7 on: otherwise Homebrew does not trust
third-party taps.

> **Keep the app in the Applications folder.** macOS starts the helper for administrator rights
> ([chapter 4](04-the-helper.md)) from inside the app bundle. If the app is somewhere else or is
> not started from its bundle, LaunchKeeper reports the helper as “not found — the app must be
> started from its bundle”.

## Language

LaunchKeeper speaks **English and German** and follows the language of macOS. With any other
system language, the app appears in English.

The **categories** in the sidebar are translated too (“Launch Items”, “App Extensions” … — in
German they have German names). Only what comes unchanged from the core underneath
(LaunchKeeperKit) is in English in both languages: the **reasons** a change is refused with
([chapter 5](05-changing-entries.md)), and some raw values such as the origin (`homebrew`,
`manual` …) or the state of a quarantine entry (`applied-ok`).

## The first launch

### The introduction

At the first launch, an **introduction** walks you through the window in ten steps. Each step
frames the part of the window it is about — the sidebar, the list, the detail column, the three
toolbar buttons, the views, the watch, the queue — and explains it in a card next to it. The
welcome, the helper and the closing step appear as a sheet in the middle of the window.

- **Let's go** starts it, **Continue** and **Back** page through, **Close** stops partway through.
- **Skip** on the first card closes the introduction right away.
- A click outside the card or **Esc** also ends it.

**Turning it off:** The first and the last card have **Show at launch**. Uncheck it, and the
introduction no longer appears at the next launch. The same setting is in Settings (**⌘,**)
under **Help** as **Show introduction at launch**.

**Bringing it back:** any time via **Help › Show Introduction**, or in Settings under **Help**
with **Show introduction now**.

The same menu has **Help › LaunchKeeper Help** (**⌘?**): the short version of this manual,
organized by chapter and searchable.

### The first scan

Right after launch, LaunchKeeper reads the **inventory** — everything that starts automatically
on this Mac. Meanwhile, the **status bar** at the bottom of the window says
“Reading the inventory …”.

> **The very first scan can take minutes.** Part of the inventory comes from macOS's Background
> Task Management (BTM for short). If the service behind it has been idle for a while, it
> re-checks all registered programs on the first query. The status bar then says “Reading the
> inventory — the first Background Task Management query can take a few minutes …”. After that
> it takes seconds.

**Touch ID at launch?** macOS hands out the list of background tasks only with administrator
rights. Without the helper set up, macOS therefore asks for Touch ID or your password at launch.
If you cancel, this part is missing, and the status bar reports the inventory as incomplete
([chapter 2](02-the-inventory.md)). With the helper, LaunchKeeper reads this list without asking
([chapter 4](04-the-helper.md)).

## The window

LaunchKeeper has **one main window**. If you open it again — from the menu bar, from a
notification or from the Help menu — the same window comes to the front, even if it is
minimized in the Dock.

Three columns:

- **On the left**, the sidebar: under **Inventory**, “All entries” and “Orphaned”, below them the
  **Categories** that occur on this Mac, then the **Views** (Background, Packages, App leftovers,
  Quarantine, Watch), and at the very bottom, under **Batch processing**, the **Queue**. The
  number after a row says how many entries it holds.
- **In the middle**, the list of entries — or, for a view, its own list.
- **On the right**, the detail column: what the selected entry means and what you can do. With
  nothing selected, it says “Nothing selected”.

### The toolbar

At the top right are three buttons, from the left:

| Button | What it does |
|---|---|
| **Expert mode** | switches the detail column between the summary and all details (⌥⌘E) |
| **Hide Apple** | hides or shows Apple's own system entries |
| **Rescan** | reads the inventory again (⌘R) |

The icons show the **current state**; the tooltip says what a click does. Next to them is the
**search field**. Some views bring their own buttons — for example **Only with missing files**
for packages ([chapter 3](03-the-views.md)).

### The status bar at the bottom

The **status bar** floats at the bottom edge of the window and appears only when there is
something to say: during a scan with its progress, and afterwards as a warning as long as the
inventory is **incomplete**. Otherwise it is gone.

## The eye in the menu bar

As long as **Watch** is running, an **eye** sits in the menu bar — even with no window open. From
there you open LaunchKeeper, see the latest changes and turn off the watch. More about this in
[chapter 7](07-watch.md).

## Updates

LaunchKeeper updates itself (through the Sparkle update framework):

- **Automatically:** The app checks for new versions on its own. You can turn this off in
  Settings under **Updates** with **Check for updates automatically**.
- **By hand:** **LaunchKeeper › Check for Updates …** or, in Settings, **Check for updates
  now**. The installed **Version** is shown there as well.

Every update is **signed** with LaunchKeeper's key, and the app verifies this signature before it
installs anything. The check goes to GitHub, where the releases are — that is the only internet
connection LaunchKeeper makes on its own.

The helper comes with the update and switches to the new version by itself after a quiet minute
([chapter 4](04-the-helper.md)).

## Settings

**LaunchKeeper › Settings…** (**⌘,**) has four sections:

| Section | What it covers |
|---|---|
| **Helper for administrator rights** | set up, check, remove ([chapter 4](04-the-helper.md)) |
| **Watch** | watch, notifications, launch at login ([chapter 7](07-watch.md)) |
| **Help** | introduction at launch, show the introduction now, open Help |
| **Updates** | version, automatic checks, check now |

## Next

- [Chapter 2 — Reading the inventory](02-the-inventory.md)
