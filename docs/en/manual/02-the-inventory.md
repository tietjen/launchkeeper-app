# Reading the inventory

*Deutsch: [Das Inventar lesen](../../handbuch/02-das-inventar.md)*

The **inventory** is the list of everything that starts or is loaded automatically on this Mac.
LaunchKeeper reads it at launch and every time you ask for it. Reading changes nothing — a scan
does not write a single file.

## What counts as autostart

More than System Settings shows. LaunchKeeper assigns every find to one of twelve
**categories**. The sidebar shows only those that actually have entries on your Mac. The command
line `launchkeeper` ([chapter 10](10-command-line.md)) uses the same category names as the
English app:

| Category | What belongs to it |
|---|---|
| **Launch Items** | LaunchAgents and LaunchDaemons — the classic background services — and their running jobs |
| **Login Items & Background** | login items and background services that apps have registered with macOS |
| **App Extensions** | Quick Look, Spotlight, Share, widgets, Finder extensions … |
| **System Extensions & Kexts** | system extensions (network filters, VPN, security, drivers) and kernel extensions |
| **Privileged Helper Tools** | helper tools with administrator rights that apps install in `/Library/PrivilegedHelperTools` |
| **Scheduled** | what runs on a schedule: cron, at, maintenance scripts, scheduled wake — and LaunchAgents with a schedule |
| **Legacy Persistence** | outdated mechanisms: login/logout scripts, StartupItems, `rc` files |
| **Shell Startup** | Terminal startup files (`.zshrc` and relatives) and additions to the search path |
| **Plug-in Directories** | plug-ins that macOS loads by their location: audio drivers, screen savers, input methods … |
| **Network** | programs that accept network connections, and firewall rules |
| **Profiles / MDM** | configuration profiles |
| **Privacy (TCC)** | privacy permissions |

A LaunchAgent with a schedule appears in both: under **Launch Items**, because it is one, and
under **Scheduled**, because it runs on a schedule.

## The sidebar

At the very top, under **Inventory**:

- **All entries** — everything LaunchKeeper found.
- **Orphaned** — entries whose program or file is missing. Typical leftovers of uninstalled
  software.

Below that, the **Categories**. The number after each row counts the entries; it follows
**Hide Apple**, but not the search — so it stays put while you type.

## The list

Each row is one entry. The columns:

| Column | Content |
|---|---|
| (checkbox) | marks the entry for the queue ([chapter 6](06-the-queue.md)) |
| (icons) | up to three markers, the most important first (see below) |
| **Name** | the display name; on hover, the internal key |
| **Category** | one of the categories above |
| **Origin** | where the entry comes from: `apple`, `homebrew`, `app-store`, `receipt` (from an installer package), `manual` (an app no receipt knows about) or `unknown` |
| **Signature** | the state of the code signature, as the check reports it |
| **Path** | the file behind the entry, otherwise the program |

**Sorting:** A click on a column header sorts by it, a second click reverses the order. Initially
the list is sorted by name.

**Searching:** The search field in the toolbar (“Name, label, path, team …”) filters the list as
you type. It searches name, label, key, path, program, bundle ID, team ID and associated app,
ignoring upper and lower case.

### The icons

| Icon | Color | Meaning |
|---|---|---|
| Warning triangle | orange | **Orphaned** — the source is missing; the program the entry points to no longer exists |
| Leaf | gray | **Leftover** — only an entry left in macOS's Background Task Management (BTM for short), with no file behind it |
| Signature | red | **Not signed** — the program carries no code signature |
| Eye | yellow | **Worth a look** — something stands out; the detail column says what |
| Pause | gray | **Disabled** — present, but doesn't start |
| Play | green | **Running** — currently active |

A **leftover** is more specific than “orphaned”: the file is already gone, macOS just keeps a
record. Such rows therefore carry the leaf instead of the triangle.

> **Red and yellow are not a verdict on malware.** An unsigned program can be a harmless tool, a
> yellow-marked entry a perfectly ordinary script. The icons say: worth taking a look here.

## The detail column

Select a row, and the right side says what it means. In **Basic mode** — which is how the app
starts — that is four parts.

### The traffic light

At the very top, an icon in a color and a short finding:

| Light | Finding |
|---|---|
| green | “Nothing unusual” |
| gray | “Only a leftover record — harmless, macOS cleans it up itself” |
| yellow | “Worth a look: …” with the reason |
| orange | “Orphaned: …” with what is missing |

It turns yellow, for example, when a third-party entry starts a macOS program, when a shell or an
interpreter runs as a service, when the program lives in a temporary folder or directly in
“Downloads”, or when it is not signed.

### The plain-language sentence

Below that, one sentence saying what the entry is — for example “Starts at login (LaunchAgent)”,
“System service, starts with the Mac (LaunchDaemon)” or “App extension — loaded by other apps”.

### The facts

A gray line with the essentials: is it running right now, is it switched off, who signed it
(“signed by …”, “not signed”, “part of macOS”), where it comes from (“from package …”,
“installed via Homebrew”), which app it belongs to.

If the entry only starts an interpreter such as `bash` or `python`, the line starts with what
**actually** runs: “runs: script … (via bash)”.

### Next steps

Last, the **Next steps** — only what is safely possible for this entry:

- **Actions** such as “Disable (reversible)”, “Enable again”, “Remove” or “Move into
  quarantine”, each with a sentence on what happens and the **Run…** button. A lock next to the
  title means: needs administrator rights. What happens next is in
  [chapter 5](05-changing-entries.md).
- **Copy hash for VirusTotal** — for program files that are not part of macOS. **Copy hash**
  computes the file's SHA-256 and puts it on the clipboard; on virustotal.com you paste it into
  the search. The file itself does not leave the Mac, and LaunchKeeper does not send the hash
  anywhere either.
- **Show in Finder** — opens a Finder window with the file.
- **Not controllable here** — when LaunchKeeper may not change the entry, with the reason and
  the place where the switch is instead.

Only what passes the same check that also applies when running is offered. If an action is not
there, it would be refused.

### All details and Expert mode

**Show all details** below the next steps expands everything LaunchKeeper knows for **this**
entry. At the next entry it is collapsed again.

**Expert mode** always shows these details — switch it with the left toolbar button, via
**View › Expert mode** or with **⌥⌘E**. LaunchKeeper remembers your choice.

Expert mode shows:

- Name, Category, Type, Label, Key and the **State** (“enabled · loaded · running (PID …)”),
- **Files** — Source, Program, Arguments, App; next to an existing path, a magnifying glass that
  shows it in Finder,
- **Finding** — the reasons for “orphaned” and “worth a look”,
- **Origin & signature** — Origin, Signature, Team, Developer,
- **Control** — what is possible, through which mechanism, and why,
- **Sources** — where LaunchKeeper knows about the entry from,
- **Details** — all other metadata.

### The thorough signature check

Under **Origin & signature** is **Verify signature thoroughly**. It checks the program (for
extensions, plug-ins and drivers, the whole bundle) as strictly as `codesign --verify --strict`,
asks Gatekeeper, and then shows:

- **Seal** — “intact” or what is wrong,
- **Gatekeeper** — the verdict and its source,
- **Hardened Runtime** — yes or no,
- **Chain** — the certificate chain,
- **SHA-256** — the checksum.

The check takes a moment per file; that is why it runs only on a click and not during a scan.

## Hide Apple

The middle toolbar button hides **Apple's own system entries**. It is on at launch: there are
hundreds of them, and LaunchKeeper doesn't let you change them anyway.

An entry counts as Apple's if it has a label starting with `com.apple.` and is signed as part of
macOS (or has no signature information at all). If a `com.apple.` entry has a file that belongs
to **you** instead of the system, it stays visible — then it is not part of macOS.

If you jump to a hidden entry from somewhere else — for example from the **Background** view or
from a notification — LaunchKeeper shows Apple's entries again by itself.

## Rescan: ⌘R and ⇧⌘R

| Shortcut | Menu | What happens |
|---|---|---|
| **⌘R** | **View › Rescan** | scans again and reuses the list of background tasks from this session — in seconds |
| **⇧⌘R** | **View › Full rescan** | also asks macOS's Background Task Management for fresh data |

The **Rescan** button in the toolbar is ⌘R. That is enough for almost everything. You need
**⇧⌘R** when you switched something in System Settings under Login Items & Extensions and want
LaunchKeeper to see it.

> The fresh query of Background Task Management can take minutes after a longer idle period, and
> without the helper macOS asks for Touch ID or your password for it
> ([chapter 4](04-the-helper.md)).

While a scan is running, the button is grayed out.

## When the inventory is incomplete

If a source doesn't answer — Background Task Management, the list of extensions, the list of
network connections — its part is missing from the inventory. The status bar at the bottom then
reports “Inventory incomplete: … — ⇧⌘R tries again” with the sources that are missing.

This happens most often when you cancel the Touch ID prompt for Background Task Management.
**⇧⌘R** tries again. As long as the message is showing, entries are missing from the list —
“not there” then does not mean “does not exist”.

## Next

- [Chapter 3 — The views](03-the-views.md)
