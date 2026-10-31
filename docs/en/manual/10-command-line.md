# The `launchkeeper` command line

*Deutsch: [Die Kommandozeile `launchkeeper`](../../handbuch/10-kommandozeile.md)*

Underneath the app works a command-line tool: `launchkeeper`. It reads the same inventory, goes
through the same check and writes to the same stores — the app uses its building blocks. It is
the way for scripts, for a quick look over SSH and for the few things that exist only in the
Terminal.

This chapter shows the most important commands. The tool's full manual is in its
[README](https://github.com/tietjen/launchkeeper#readme).

## Installing

With Homebrew:

```bash
brew trust tietjen/tap          # once, from Homebrew 7 on — third-party taps are not trusted otherwise
brew install tietjen/tap/launchkeeper
```

Homebrew installs the finished, Apple-notarized program for Apple silicon and Intel. You get new
versions with `brew upgrade launchkeeper`. To check that everything is right:

```bash
launchkeeper --version     # 0.12.2
launchkeeper doctor        # which sources answer
```

It runs on macOS 14 and later. The app does not need the tool — it is a separate way to the same
data.

## Two rules up front

**Without `--apply`, nothing happens.** Every command that changes something only shows the plan
without `--apply` — each step with the exact command, and the way back:

```
DRY-RUN — nothing executed (dry-run is the default).
plan:
  1. /bin/launchctl disable gui/501/com.example.script
  2. /bin/launchctl bootout gui/501/com.example.script

undo later with: launchkeeper enable com.example.script
execute for real with: --apply
```

**You start it as yourself, not with `sudo`.** If a step needs root — a service in the system
domain, a file under `/Library`, the firewall, a package — `launchkeeper` calls `sudo` for
exactly that step, and the Terminal asks for your password. It never asks for blanket
administrator rights, and it never uses a shell.

The check is the same as in the app: it rejects entries from Apple and everything under
`/System`, and there is no option that bypasses this.

## Looking

```bash
launchkeeper list                       # the inventory as a table (also without “list”)
launchkeeper list --orphans             # only orphaned entries, with the reason
launchkeeper list --running             # only entries that are running right now
launchkeeper list --disabled            # only disabled ones
launchkeeper list --user                # only your domain (--system: only the system's)
launchkeeper list --category network    # one category
launchkeeper list --origin manual       # by origin: apple, homebrew, app-store, receipt, manual, unknown
launchkeeper list --all                 # also Apple's internal entries

launchkeeper inspect 07                 # everything about one entry
launchkeeper inspect 07 --verify        # signature in depth: seal, certificate chain, Gatekeeper, SHA-256
launchkeeper background                 # like System Settings › Login Items & Extensions
launchkeeper receipts                   # the installer packages behind the inventory (--missing, --all)
launchkeeper leftovers                  # what deleted apps left behind (--all: also unclear cases)
launchkeeper doctor                     # self-test: which source answered
```

You address an entry by its number from `list`, its label, its name or a unique part of it. The
numbers are the same in all commands as long as the inventory is complete. If a source did not
answer — usually the background tasks (Background Task Management, BTM for short) after a
timeout — `list` says so, and commands that change something then do not accept numbers. The
label always works.

> The first query of the background tasks can take minutes after a longer idle period — as in
> the app. After that it takes seconds.

### For scripts

Almost every command supports `--json`: `list`, `inspect`, `doctor`, `background`, `receipts`,
`leftovers`, `diff`, `snapshot`, `quarantine list`, `watch` and all commands that change
something. On top of that there is `list --csv` for a spreadsheet and `list --markdown` for a
report.

## Comparing

```bash
launchkeeper snapshot --name before-update      # save the whole inventory
launchkeeper snapshot list                      # what has been saved
launchkeeper diff                               # what has changed since the last snapshot
launchkeeper diff before-update --exit-code     # exit code 1 if there are differences
```

The snapshots are kept under `~/Library/Application Support/launchkeeper/inventory/`. `diff`
compares entry by entry: new, gone, and which fields have changed. `--state` adds whether
something is loaded or running. With `--exit-code`, a nightly script notices when a new autostart
entry has appeared.

## Changing

```bash
launchkeeper disable 07                     # plan
launchkeeper disable 07 --apply             # run, then verify
launchkeeper enable 07 --now --apply        # way back; --now loads the service again
launchkeeper disable a b c --apply          # several at once, with a single scan

launchkeeper remove <entry>                 # delete an orphaned launch file — after a backup
launchkeeper remove <entry> --working       # disable a working entry and move
                                            #   its launch file into the quarantine
```

`disable` and `enable` reach further than `launchd`: app extensions, lines of your crontab, login
scripts of the login window and firewall rules — each with a copy of the source before the first
change, wherever there is a file to lose. `remove` without `--working` rejects anything that
still works, and names the command that works instead.

Every action is verified afterwards, and every one — even a rejected one or a mere plan — is
recorded in the log `~/Library/Logs/launchkeeper/operations.log`.

## Cleaning up

```bash
launchkeeper uninstall <package-id>                 # what would go, what stays and why
launchkeeper uninstall <package-id> --list          # every single file
launchkeeper uninstall <package-id> --apply         # move into the quarantine

launchkeeper leftovers <bundle-id>                  # leftovers of a deleted app: plan
launchkeeper leftovers <bundle-id> --apply          # move into the quarantine
```

You address the package by its exact ID (from `launchkeeper receipts`), never by a part of it.
Only what is provably still the way the package installed it is moved.

## The quarantine

```bash
launchkeeper quarantine                          # = quarantine list: both stores
launchkeeper quarantine restore <name>           # plan
launchkeeper quarantine restore <name> --apply   # put back — never overwrites
launchkeeper quarantine purge <name>             # plan
launchkeeper quarantine purge <name> --apply     # delete for good — NOT recoverable
```

`purge` is the only real deletion in LaunchKeeper, and it exists only here. What the two stores
are, and when putting things back works only in the Terminal, is described in
[chapter 8](08-quarantine-and-undo.md).

## Backups of the launch folders

```bash
launchkeeper backup --label before        # back up launch folders and disable overrides (changes nothing)
launchkeeper restore <backup>             # plan
launchkeeper restore <backup> --apply     # copy back
```

`restore` also finds the backups that the app's helper created under
`/Library/Application Support/launchkeeper/backups`. Files are put back only into the four launch
folders (`~/Library/LaunchAgents`, `~/Library/LaunchDaemons`, `/Library/LaunchAgents`,
`/Library/LaunchDaemons`), and each file is checked against the backup's checksum before and
after writing.

## Watching

```bash
launchkeeper watch                          # new, removed and changed entries, continuously
launchkeeper watch --notify                 # plus a notification per change
launchkeeper watch --interval 600           # full comparison every 600 seconds (default 300)
launchkeeper watch --json                   # as JSON lines
```

As in the app, the first complete check is the baseline; incomplete checks are skipped, never
reported as “removed”. `Ctrl-C` ends the watch.

## What the app and the command line share

| | Shared |
|---|---|
| **Quarantine** | Both see both stores. The command line writes to yours (`~/Library/Application Support/launchkeeper/quarantine`), the app's helper to the system's. Only root writes to the system's — the helper, or the command line via `sudo` (`quarantine restore/purge --apply`); without `sudo` the command line only reads it. |
| **Watch** | Both append their findings to `~/Library/Logs/launchkeeper/watch.log`, in the same format. After launch, the app also shows what `launchkeeper watch` has recorded. |
| **Log** | Actions without administrator rights — from the app as well as from the Terminal — are recorded in `~/Library/Logs/launchkeeper/operations.log`; the helper's in `/Library/Logs/launchkeeper/operations.log`. |
| **Backups** | `launchkeeper restore` finds yours and the helper's. |

In the queue, under **Command**, each entry shows the matching command line for you to select —
with `--apply`, so it runs. Where the detail column does not run a step itself, it offers **Copy
command** — without `--apply`, the command first shows the plan in the Terminal.

## When to use which

| Task | Better |
|---|---|
| Overview, understanding entries, changing them one by one or in bulk | the app |
| Many changes with administrator rights | the app — one Touch ID prompt for the whole queue |
| Watching with notifications, even with the window closed | the app |
| Scripts, nightly comparisons, JSON, CSV | the command line |
| Deleting from the quarantine for good | **only** the command line |
| Putting back entries from your store whose paths lie outside your home folder | **only** the command line |
| Creating and restoring backups of the launch folders | the command line |
| Checking another system from its files (Time Machine backup, drive) | **only** the command line: `launchkeeper list --root <folder>` |

> The command line also has `launchkeeper resetbtm` — resetting macOS's background tasks. That
> is the one command **without a way back**: macOS cannot read the previous state back in, and
> the registrations return only once the apps they belong to run again. Read the section about it
> in the README first.

## Next

- [Back to the manual overview](README.md)
