# Setting up the helper

*Deutsch: [Das Hilfsprogramm einrichten](../../handbuch/04-das-hilfsprogramm.md)*

Some things on a Mac only an administrator may change: system services, files in `/Library`,
the firewall, installed packages. For these, LaunchKeeper brings a **helper**. If you only want
to look, you don't need it.

## What it is

The helper is a small service that ships inside the app bundle and runs with **root
privileges**. LaunchKeeper registers it through the macOS interface intended for this
(`SMAppService`); after that, macOS starts it when needed, and after a **quiet minute** it quits
by itself again. So it does not run in the background all the time.

LaunchKeeper uses the helper for two things:

- **Changing what needs administrator rights** — each time only after Touch ID or your password.
- **Reading macOS's Background Task Management (BTM for short)** without macOS asking for
  Touch ID every time (see below).

## Why it doesn't come by itself

LaunchKeeper **deliberately does not set up** the helper on its own. A service with root
privileges is a door, and it should only be open when you need it. If you use LaunchKeeper only
to look around, you don't get one.

## Setting it up

1. **Open Settings** (**⌘,**). In the **Helper for administrator rights** section, click
   **Set up**.

   Or at the first action that needs administrator rights: that action's sheet shows
   “Needs administrator rights” and the **Set up helper** button
   ([chapter 5](05-changing-entries.md)).

2. **Allow it in System Settings.** macOS opens **General › Login Items & Extensions** by itself.
   There, under **Allow in the Background**, turn on the switch for **LaunchKeeper**. If the
   window is already closed, the **Allow in System Settings** button opens it again.

3. **Check again.** Back in LaunchKeeper, click **Check again**. **State** then says
   “set up and allowed”, with the helper's **Version** below it.

You do this once. After that the helper stays set up, across app updates too.

## The states

| State | What it means | What to do |
|---|---|---|
| “not set up” | there is no helper | **Set up** |
| “waiting for your approval in System Settings” | registered, but not allowed yet | **Allow in System Settings**, then **Check again** |
| “set up and allowed” | ready | nothing |
| “not found — the app must be started from its bundle” | macOS cannot find the helper in the app bundle | start the app from the Applications folder |

If something fails, the message from macOS appears in red below.

## Versions and updates

The helper has its own version number (currently **0.2.0**), which is built into the app.
LaunchKeeper compares it with the running helper and **never sends anything** to a helper of a
**different version** — an old one might check authentication differently and fail after you
have confirmed with Touch ID.

After an app update, this is what happens:

1. The update replaces the whole app bundle — the new helper is inside it.
2. The old helper that is still running quits after a **quiet minute**.
3. On the next request, macOS starts the new one from the bundle.

You don't have to do anything for this. If an older one is still running anyway, Settings shows
in orange “An older version of the helper is still running (…). LaunchKeeper runs nothing
through it until it restarts.” and the **Restart helper** button. An action's sheet offers the
same (“Helper outdated”). This is needed mainly for very old helpers that have not yet quit by
themselves.

## Removing it

Once the helper is set up, Settings shows **Remove** instead of **Set up**. After removing it:

- LaunchKeeper no longer runs changes with administrator rights — the sheet for such an action
  gives the command for Terminal instead,
- macOS asks for Touch ID again when Background Task Management is read.

Everything you do without administrator rights keeps working as before. With **Set up**, the
helper comes back at any time.

## What it accepts — and what it doesn't

The helper accepts **no commands**. It understands only “what with which entry”:

| Request | Target |
|---|---|
| disable, enable, remove, move into quarantine | an inventory entry |
| restore | a quarantine entry |
| uninstall | a package, by its exact package ID |

The protocol between the app and the helper also knows “delete for good” (`purge`) for a
quarantine entry. The app never sends this request — deleting for good happens only in Terminal
([chapter 8](08-quarantine-and-undo.md)).

It works out everything else **itself**: it scans the Mac itself, looks up the entry itself and
runs it through the same check as the command line. What doesn't pass there, it doesn't run. A
target that is empty, overlong, contains control characters or starts with `-` like an option is
rejected before that.

Further limits it sets itself:

- **The connection says who is asking, not the request.** It determines the user and the home
  folder from the connection itself.
- **System-wide entries only.** What belongs to a single user — your own LaunchAgents, your
  crontab, extension settings in your account — it does not change. The app does that itself,
  without administrator rights.
- **Removing happens only in `/Library/LaunchAgents` and `/Library/LaunchDaemons`.**
- **Root keeps nothing in your home folder.** It stores quarantine, backups and copies of changed
  settings under `/Library/Application Support/launchkeeper`, a folder only root can write to.
  It checks that this is so before every request.
- **It restores only what it keeps itself** — after checking the owner and the contents of the
  quarantine entry.
- **Uninstalling only from protected locations.** It refuses packages whose files are in places a
  normal user can change (for example `/Users`, temporary folders, `/Volumes`, `/opt/homebrew`).
- **Fixed tools only.** It runs the steps of a plan only if they call one of a few system tools
  at a fixed location (`launchctl`, `mv`, `rm`, `cp`, `pkgutil`, the firewall …) — never a shell.
- **One at a time.** Two changes never run at the same time.
- **Log.** Every change is recorded in `/Library/Logs/launchkeeper/operations.log`.

### Code signature on both sides

The helper accepts connections only from the **genuine LaunchKeeper app** — signed with Apple's
Developer ID certificate by the same developer team. Any other program is turned away, even if
it runs as your user. In turn, the app talks only to the genuine helper signed by the same team.

## Reading Background Task Management without Touch ID

macOS hands out the list of background tasks (`sfltool dumpbtm`) only with administrator rights.
Without the helper, macOS therefore asks for Touch ID on every **fresh** scan: at app launch, on
**⇧⌘R**, on **Check now** in the queue and, with Watch turned on, during its regular check —
which, without the helper, is why that check fetches the list fresh at most every six hours.

With the helper set up, it reads this list as root, and **nobody is asked**. This is pure
reading; the helper does not require authentication for it.

In return, it gives back only what you are allowed to see: the **system-wide** entries and
**your own** — never the login items of other users of this Mac.

> On a Mac with several users, this means: even a user without administrator rights sees the
> system-wide background items through LaunchKeeper without being asked. Most of them they can
> read in `/Library` anyway.

If the helper doesn't answer at some point, LaunchKeeper uses the list from last time instead of
surprising you with a prompt — provided there already is one from this session; otherwise macOS
asks.

## What still asks for Touch ID

The helper only saves the prompts for **reading**. For **changes**, it always asks:

- **Every single action** with administrator rights asks once, right before it runs. The
  approval applies only to that one action; the next one asks again. macOS shows “LaunchKeeper
  wants to change a system-level startup item.”
- **A queue run** asks once for all steps with administrator rights, and the dialog says how many
  there are: “LaunchKeeper wants to change 7 startup items.” — for a single one, “LaunchKeeper
  wants to change one startup item.” ([chapter 6](06-the-queue.md)).

This needs an administrator's credentials — Touch ID or password.

Changes in your own home folder don't go through the helper at all and don't prompt
([chapter 5](05-changing-entries.md)).

## Next

- [Chapter 5 — Changing entries](05-changing-entries.md)
